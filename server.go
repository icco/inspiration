package main

import (
	"fmt"
	"html/template"
	"net/http"
	"os"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/icco/gutil/logging"
	"github.com/icco/gutil/render"
	"github.com/icco/inspiration/views"
	"go.uber.org/zap"
)

var (
	log = logging.Must(logging.NewLogger("inspiration"))
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

		if err := tmpl.Execute(w, nil); err != nil {
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

		if err := tmpl.Execute(w, nil); err != nil {
			log.Errorw("about page template execute fail", zap.Error(err))
			http.Error(w, `{"error": "server error"}`, http.StatusInternalServerError)
			return
		}
	})

	r.Get("/healthz", func(w http.ResponseWriter, r *http.Request) {
		render.JSON(log, w, http.StatusOK, map[string]string{"status": "ok"})
	})

	r.Get("/data/:page/file.json", func(w http.ResponseWriter, r *http.Request) {

	})

	r.Get("/stats.json", func(w http.ResponseWriter, r *http.Request) {

	})

	log.Fatal(http.ListenAndServe(":"+port, r))
}
