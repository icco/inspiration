package main

import (
	"fmt"
	"html/template"
	"net/http"
	"os"
	"strconv"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/icco/gutil/logging"
	"github.com/icco/gutil/render"
	"github.com/icco/inspiration/db"
	"github.com/icco/inspiration/public"
	"github.com/icco/inspiration/public/css"
	"github.com/icco/inspiration/public/js"
	"github.com/icco/inspiration/views"
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
		entries, err := db.Page(ctx, page)
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

	log.Fatal(http.ListenAndServe(":"+port, r))
}
