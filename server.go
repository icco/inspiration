package main

import (
	"fmt"
	"net/http"
	"os"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/icco/gutil/logging"
	"github.com/icco/gutil/render"
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

	})

	r.Get("/about", func(w http.ResponseWriter, r *http.Request) {

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
