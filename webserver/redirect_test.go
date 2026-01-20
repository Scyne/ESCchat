package webserver

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"

	"github.com/jech/galene/group"
)

func TestCanonicalHostRedirect(t *testing.T) {
	// Setup temporary directory for config
	dir := t.TempDir()
	originalDataDir := group.DataDirectory
	group.DataDirectory = dir
	defer func() {
		group.DataDirectory = originalDataDir
	}()

	tests := []struct {
		name              string
		canonicalHost     string
		requestHost       string
		expectRedirect    bool
		expectedLocation  string // Only checked if expectRedirect is true
	}{
		{
			name:           "No Port Config - Request with Port",
			canonicalHost:  "ec2-44-215-70-124.compute-1.amazonaws.com",
			requestHost:    "ec2-44-215-70-124.compute-1.amazonaws.com:9090",
			expectRedirect: true,
			expectedLocation: "https://ec2-44-215-70-124.compute-1.amazonaws.com/",
		},
		{
			name:           "With Port Config - Request with Port",
			canonicalHost:  "ec2-44-215-70-124.compute-1.amazonaws.com:9090",
			requestHost:    "ec2-44-215-70-124.compute-1.amazonaws.com:9090",
			expectRedirect: false,
		},
		{
			name:           "With Port Config - Request without Port (Standard HTTPS)",
			canonicalHost:  "ec2-44-215-70-124.compute-1.amazonaws.com:9090",
			requestHost:    "ec2-44-215-70-124.compute-1.amazonaws.com",
			expectRedirect: true,
			expectedLocation: "https://ec2-44-215-70-124.compute-1.amazonaws.com:9090/",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Write config
			conf := group.Configuration{
				CanonicalHost: tt.canonicalHost,
			}
			c, err := json.Marshal(conf)
			if err != nil {
				t.Fatalf("Marshal: %v", err)
			}
			err = os.WriteFile(
				filepath.Join(dir, "config.json"),
				c,
				0600,
			)
			if err != nil {
				t.Fatalf("Write: %v", err)
			}

			// Force reload of configuration
			// Since GetConfiguration caches based on modtime, and we just wrote a new file, it should reload.
			// However, the test runs are fast, modtime might be same if resolution is low.
			// But creating a new file usually updates modtime.
			// Also we need to make sure we are not using a cached version from previous test run if we were running multiple tests in loop.
			// But since we are creating a fresh config file each time (overwriting), os.WriteFile handles it.
			// To be safe, we can sleep or just rely on file size/content changes if modtime isn't enough, but GetConfiguration uses ModTime.
			// Let's modify the file size if needed, but here we just write.
			// Wait, GetConfiguration caches in a global variable `configuration`.
			// We need to verify if we can force reload.
			// Looking at group.go, it checks modtime and filesize.

			req := httptest.NewRequest("GET", "/", nil)
			req.Host = tt.requestHost
			w := httptest.NewRecorder()

			redirected := redirect(w, req)

			if redirected != tt.expectRedirect {
				t.Errorf("expected redirect %v, got %v", tt.expectRedirect, redirected)
			}

			if tt.expectRedirect {
				resp := w.Result()
				if resp.StatusCode != http.StatusMovedPermanently {
					t.Errorf("expected status 301, got %v", resp.StatusCode)
				}
				loc, err := resp.Location()
				if err != nil {
					t.Errorf("Location header missing: %v", err)
				} else if loc.String() != tt.expectedLocation {
					t.Errorf("expected location %v, got %v", tt.expectedLocation, loc.String())
				}
			}
		})
	}
}
