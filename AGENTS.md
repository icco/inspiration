# AGENTS.md

Guidance for coding agents working on inspiration.

## Project Overview

Mood board web service written in Go (`github.com/icco/inspiration`), backed by BigQuery for post storage/caching and rendering HTML templates.

## Commands

```sh
go test ./...    # Run tests
go vet ./...     # Vet code
go run main.go   # Run locally (port 8080 by default)
go build .       # Build binary
```

## Architecture & Layout

- `main.go` — Entrypoint, HTTP router, and middleware.
- `handlers.go` — Page and JSON API endpoints (`/data/{page}/file.json`, `/stats.json`).
- `templates/` — HTML rendering templates.

## Conventions

- Follow icco Go conventions (`github.com/icco/gutil` for logging and helpers).
- PR titles and commits must follow Conventional Commits with lowercase subjects.
- Ensure all tests pass before submitting PRs.
