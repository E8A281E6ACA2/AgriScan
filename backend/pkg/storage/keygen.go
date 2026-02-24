package storage

import (
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"path/filepath"
	"strings"
	"time"
)

const baseDir = "agriscan"

func generateObjectKey(filename string) string {
	ext := strings.ToLower(filepath.Ext(filename))
	if ext == "" {
		ext = ".jpg"
	}

	name := randomHex(16)
	t := time.Now()
	return fmt.Sprintf("%s/%04d%02d%02d/%s%s",
		baseDir, t.Year(), t.Month(), t.Day(), name, ext)
}

func randomHex(n int) string {
	b := make([]byte, n)
	if _, err := rand.Read(b); err != nil {
		return fmt.Sprintf("%d", time.Now().UnixNano())
	}
	return hex.EncodeToString(b)
}
