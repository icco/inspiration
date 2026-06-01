// Command inspiration serves the mood-board HTTP frontend.
package main

import (
	"context"
	"errors"
	"fmt"
	"html/template"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"syscall"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/cors"
	"github.com/icco/gutil/logging"
	"github.com/icco/gutil/render"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"github.com/unrolled/secure"
	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"go.opentelemetry.io/otel"
	otelprom "go.opentelemetry.io/otel/exporters/prometheus"
	sdkmetric "go.opentelemetry.io/otel/sdk/metric"
	semconv "go.opentelemetry.io/otel/semconv/v1.40.0"
	"go.uber.org/zap"

	"github.com/icco/inspiration/db"
	"github.com/icco/inspiration/public"
	"github.com/icco/inspiration/public/css"
	"github.com/icco/inspiration/public/js"
	"github.com/icco/inspiration/views"
)

// serverName is the otelhttp span/metric scope.
const serverName = "inspiration"

// PerPage caps how many entries each /data page returns.
const PerPage = 100

func main() {
	log := logging.Must(logging.NewLogger(serverName))
	defer func() {
		if err := log.Sync(); err != nil {
			log.Debugw("logger sync", zap.Error(err))
		}
	}()

	port := "8080"
	if fromEnv := os.Getenv("PORT"); fromEnv != "" {
		port = fromEnv
	}

	registry := prometheus.NewRegistry()
	exporter, err := otelprom.New(otelprom.WithRegisterer(registry))
	if err != nil {
		log.Errorw("otel prometheus exporter", zap.Error(err))
		return
	}
	mp := sdkmetric.NewMeterProvider(sdkmetric.WithReader(exporter))
	otel.SetMeterProvider(mp)
	defer func() {
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		if err := mp.Shutdown(shutdownCtx); err != nil {
			log.Warnw("meter provider shutdown", zap.Error(err))
		}
	}()

	srv := &http.Server{
		Addr:              ":" + port,
		Handler:           router(log, promhttp.HandlerFor(registry, promhttp.HandlerOpts{})),
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       10 * time.Second,
		WriteTimeout:      10 * time.Second,
		IdleTimeout:       60 * time.Second,
	}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	go func() {
		log.Infow("http server starting", "addr", fmt.Sprintf("http://localhost:%s", port))
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Errorw("http server", zap.Error(err))
			stop()
		}
	}()

	<-ctx.Done()
	log.Info("shutting down")

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := srv.Shutdown(shutdownCtx); err != nil {
		log.Errorw("http shutdown", zap.Error(err))
	}
}

// router builds the chi handler, wrapped with otelhttp (excluding /metrics).
func router(log *zap.SugaredLogger, metrics http.Handler) http.Handler {
	r := chi.NewRouter()
	r.Use(logging.Middleware(log.Desugar()))
	r.Use(routeTag)
	r.Use(cors.New(cors.Options{
		AllowCredentials:   false,
		OptionsPassthrough: true,
		AllowedOrigins:     []string{"*"},
		AllowedMethods:     []string{"GET", "POST", "OPTIONS"},
		AllowedHeaders:     []string{"Accept", "Authorization", "Content-Type", "X-CSRF-Token"},
		ExposedHeaders:     []string{"Link"},
		MaxAge:             300,
	}).Handler)

	r.Use(func(h http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			w.Header().Set("report-to", `{"group":"default","max_age":10886400,"endpoints":[{"url":"https://reportd.natwelch.com/report/reportd"}]}`)
			w.Header().Set("reporting-endpoints", `default="https://reportd.natwelch.com/reporting/reportd"`)
			h.ServeHTTP(w, r)
		})
	})

	secureMiddleware := secure.New(secure.Options{
		SSLRedirect:        false,
		SSLProxyHeaders:    map[string]string{"X-Forwarded-Proto": "https"},
		FrameDeny:          true,
		ContentTypeNosniff: true,
		BrowserXssFilter:   true,
		ReferrerPolicy:     "no-referrer",
		FeaturePolicy:      "geolocation 'none'; midi 'none'; sync-xhr 'none'; microphone 'none'; camera 'none'; magnetometer 'none'; gyroscope 'none'; fullscreen 'none'; payment 'none'; usb 'none'",
	})
	r.Use(secureMiddleware.Handler)

	r.Get("/", handleTemplate("index.tmpl"))
	r.Get("/about", handleTemplate("about.tmpl"))
	r.Get("/healthz", handleHealthz)
	r.Get("/data/{page}/file.json", handlePage)
	r.Get("/stats.json", handleStats)

	r.Handle("/js/*", http.StripPrefix("/js/", http.FileServer(http.FS(js.Assets))))
	r.Handle("/css/*", http.StripPrefix("/css/", http.FileServer(http.FS(css.Assets))))
	r.Handle("/robots.txt", http.FileServer(http.FS(public.Assets)))
	r.Handle("/favicon.ico", http.FileServer(http.FS(public.Assets)))

	if metrics != nil {
		r.Method(http.MethodGet, "/metrics", metrics)
	}

	return otelhttp.NewHandler(r, serverName,
		otelhttp.WithFilter(func(req *http.Request) bool {
			return req.URL.Path != "/metrics"
		}),
	)
}

// routeTag stamps the chi route pattern onto otelhttp metric labels.
func routeTag(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		next.ServeHTTP(w, r)
		labeler, ok := otelhttp.LabelerFromContext(r.Context())
		if !ok {
			return
		}
		if pattern := chi.RouteContext(r.Context()).RoutePattern(); pattern != "" {
			labeler.Add(semconv.HTTPRoute(pattern))
		}
	})
}

// handleTemplate renders the named template wrapped in layout.tmpl.
func handleTemplate(name string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		l := logging.FromContext(r.Context())
		tmpl, err := template.ParseFS(views.Assets, "layout.tmpl", name)
		if err != nil {
			l.Errorw("template parse", "name", name, zap.Error(err))
			http.Error(w, `{"error": "server error"}`, http.StatusInternalServerError)
			return
		}
		if err := tmpl.ExecuteTemplate(w, name, nil); err != nil {
			l.Errorw("template execute", "name", name, zap.Error(err))
			http.Error(w, `{"error": "server error"}`, http.StatusInternalServerError)
			return
		}
	}
}

// handleHealthz is the liveness/readiness probe.
func handleHealthz(w http.ResponseWriter, r *http.Request) {
	render.JSON(logging.FromContext(r.Context()), w, http.StatusOK, map[string]string{"status": "ok"})
}

// handlePage returns a paginated slice of cached entries.
func handlePage(w http.ResponseWriter, r *http.Request) {
	l := logging.FromContext(r.Context())
	page, err := strconv.ParseInt(chi.URLParam(r, "page"), 10, 64)
	if err != nil {
		l.Errorw("parse page", zap.Error(err))
		http.Error(w, `{"error": "bad page number"}`, http.StatusBadRequest)
		return
	}

	entries, err := db.Page(r.Context(), page, PerPage)
	if err != nil {
		l.Errorw("db page", zap.Error(err))
		http.Error(w, `{"error": "server error"}`, http.StatusInternalServerError)
		return
	}

	render.JSON(l, w, http.StatusOK, entries)
}

// handleStats returns aggregate counts for the cache.
func handleStats(w http.ResponseWriter, r *http.Request) {
	l := logging.FromContext(r.Context())
	cnt, err := db.Count(r.Context())
	if err != nil {
		l.Errorw("db count", zap.Error(err))
		http.Error(w, `{"error": "server error"}`, http.StatusInternalServerError)
		return
	}

	render.JSON(l, w, http.StatusOK, map[string]int64{
		"per_page": PerPage,
		"images":   cnt,
		"pages":    cnt / PerPage,
	})
}
