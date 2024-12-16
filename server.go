package main

import (
	"fmt"
	"html/template"
	"net/http"
	"os"
	"strconv"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/go-chi/cors"
	"github.com/icco/gutil/logging"
	"github.com/icco/gutil/render"
	"github.com/icco/inspiration/db"
	"github.com/icco/inspiration/public"
	"github.com/icco/inspiration/public/css"
	"github.com/icco/inspiration/public/js"
	"github.com/icco/inspiration/views"
	"github.com/unrolled/secure"
	"go.uber.org/zap"
)

var (
	log = logging.Must(logging.NewLogger("inspiration"))
)

const (
	PerPage = 100
)

func main() {
	port := "8080"
	if fromEnv := os.Getenv("PORT"); fromEnv != "" {
		port = fromEnv
	}
	log.Infow("Starting up", "host", fmt.Sprintf("http://localhost:%s", port))

	r := chi.NewRouter()
	r.Use(middleware.RealIP)
	r.Use(logging.Middleware(log.Desugar(), "icco-cloud"))
	r.Use(cors.New(cors.Options{
		AllowCredentials:   true,
		OptionsPassthrough: true,
		AllowedOrigins:     []string{"*"},
		AllowedMethods:     []string{"GET", "POST", "OPTIONS"},
		AllowedHeaders:     []string{"Accept", "Authorization", "Content-Type", "X-CSRF-Token"},
		ExposedHeaders:     []string{"Link"},
		MaxAge:             300, // Maximum value not ignored by any of major browsers
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

	r.Get("/", func(w http.ResponseWriter, r *http.Request) {
		tmpl, err := template.ParseFS(views.Assets, "layout.tmpl", "index.tmpl")
		if err != nil {
			log.Errorw("index page template parse fail", zap.Error(err))
			http.Error(w, `{"error": "server error"}`, http.StatusInternalServerError)
			return
		}

		if err := tmpl.ExecuteTemplate(w, "index.tmpl", nil); err != nil {
			log.Errorw("index page template execute fail", zap.Error(err))
			http.Error(w, `{"error": "server error"}`, http.StatusInternalServerError)
			return
		}
	})

	r.Get("/about", func(w http.ResponseWriter, r *http.Request) {
		tmpl, err := template.ParseFS(views.Assets, "layout.tmpl", "about.tmpl")
		if err != nil {
			log.Errorw("about page template parse fail", zap.Error(err))
			http.Error(w, `{"error": "server error"}`, http.StatusInternalServerError)
			return
		}

		if err := tmpl.ExecuteTemplate(w, "about.tmpl", nil); err != nil {
			log.Errorw("about page template execute fail", zap.Error(err))
			http.Error(w, `{"error": "server error"}`, http.StatusInternalServerError)
			return
		}
	})

	r.Get("/healthz", func(w http.ResponseWriter, r *http.Request) {
		render.JSON(log, w, http.StatusOK, map[string]string{"status": "ok"})
	})

	r.Get("/data/{page}/file.json", func(w http.ResponseWriter, r *http.Request) {
		page, err := strconv.ParseInt(chi.URLParam(r, "page"), 10, 64)
		if err != nil {
			log.Errorw("failed parsing page", zap.Error(err))
			http.Error(w, `{"error": "bad page number"}`, http.StatusBadRequest)
			return
		}

		ctx := r.Context()
		entries, err := db.Page(ctx, page, PerPage)
		if err != nil {
			log.Errorw("failed getting page", zap.Error(err))
			http.Error(w, `{"error": "server error"}`, http.StatusInternalServerError)
			return
		}

		render.JSON(log, w, http.StatusOK, entries)
	})

	r.Get("/stats.json", func(w http.ResponseWriter, r *http.Request) {
		ctx := r.Context()
		cnt, err := db.Count(ctx)
		if err != nil {
			log.Errorw("failed getting count", zap.Error(err))
			http.Error(w, `{"error": "server error"}`, http.StatusInternalServerError)
			return
		}

		stats := map[string]int64{
			"per_page": PerPage,
			"images":   cnt,
			"pages":    cnt / PerPage,
		}

		render.JSON(log, w, http.StatusOK, stats)
	})

	r.Handle("/js/*", http.StripPrefix("/js/", http.FileServer(http.FS(js.Assets))))
	r.Handle("/css/*", http.StripPrefix("/css/", http.FileServer(http.FS(css.Assets))))
	r.Handle("/robots.txt", http.FileServer(http.FS(public.Assets)))
	r.Handle("/favicon.ico", http.FileServer(http.FS(public.Assets)))

	srv := &http.Server{
		Addr:         ":" + port,
		Handler:      r,
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 10 * time.Second,
	}

	log.Fatal(srv.ListenAndServe())
}
