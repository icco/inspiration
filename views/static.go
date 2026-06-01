// Package views embeds the site's HTML templates.
package views

import "embed"

// Assets are our static files for sharing.
//go:embed *
var Assets embed.FS
