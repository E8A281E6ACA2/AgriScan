package storage

import (
	"context"
	"io"
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
	_ = userID
	return generateObjectKey(filename)
}

func (s *COSStorage) Delete(ctx context.Context, key string) error {
	return nil
}
