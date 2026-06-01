// Package public embeds top-level static assets (robots.txt, favicon.ico, etc.).
package public

import "embed"

// Assets are our static files for sharing.
//go:embed *
var Assets embed.FS
