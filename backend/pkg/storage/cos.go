package storage

import (
	"context"
	"fmt"
	"io"
	"time"
)

// COSStorage 腾讯云 COS 存储（暂时禁用）
type COSStorage struct {
	bucket  string
	baseURL string
}

// NewCOSStorage 创建 COS 存储客户端（暂不可用）
func NewCOSStorage(secretID, secretKey, bucket, region, baseURL string) (*COSStorage, error) {
	return &COSStorage{bucket: bucket, baseURL: baseURL}, nil
}

func (s *COSStorage) Upload(ctx context.Context, key string, reader io.Reader) (string, error) {
	return "", nil
}

func (s *COSStorage) GenerateKey(userID uint, filename string) string {
	t := time.Now()
	return fmt.Sprintf("images/%d/%d%02d%02d/%s", userID, t.Year(), t.Month(), t.Day(), filename)
}

func (s *COSStorage) Delete(ctx context.Context, key string) error {
	return nil
}
