// Package js embeds the site's static JavaScript assets.
package js

import "embed"

// Assets are our static files for sharing.
//go:embed *
var Assets embed.FS
