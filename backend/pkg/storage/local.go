package storage

import (
	"context"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
)

// LocalStorage 本地文件存储（用于开发/自托管）
type LocalStorage struct {
	basePath string
	baseURL  string
}

type LocalConfig struct {
	BasePath string // 本地存储目录
	BaseURL  string // 对外访问 URL 前缀，如 http://localhost:8080/uploads
}

func NewLocalStorage(cfg LocalConfig) (*LocalStorage, error) {
	if cfg.BasePath == "" {
		cfg.BasePath = "./uploads"
	}
	if err := os.MkdirAll(cfg.BasePath, 0o755); err != nil {
		return nil, fmt.Errorf("failed to create local storage dir: %w", err)
	}
	return &LocalStorage{
		basePath: cfg.BasePath,
		baseURL:  strings.TrimRight(cfg.BaseURL, "/"),
	}, nil
}

func (s *LocalStorage) Upload(_ context.Context, key string, reader io.Reader) (string, error) {
	path := filepath.Join(s.basePath, filepath.FromSlash(key))
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return "", fmt.Errorf("failed to create dir: %w", err)
	}

	f, err := os.Create(path)
	if err != nil {
		return "", fmt.Errorf("failed to create file: %w", err)
	}
	defer f.Close()

	if _, err := io.Copy(f, reader); err != nil {
		return "", fmt.Errorf("failed to write file: %w", err)
	}

	if s.baseURL == "" {
		return key, nil
	}
	return s.baseURL + "/" + key, nil
}

func (s *LocalStorage) GenerateKey(userID uint, filename string) string {
	_ = userID
	return generateObjectKey(filename)
}

func (s *LocalStorage) Delete(_ context.Context, key string) error {
	path := filepath.Join(s.basePath, filepath.FromSlash(key))
	if err := os.Remove(path); err != nil && !os.IsNotExist(err) {
		return err
	}
	return nil
}
