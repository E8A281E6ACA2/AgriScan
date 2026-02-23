package storage

import (
	"context"
	"fmt"
	"io"
	"os"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/credentials"
	"github.com/aws/aws-sdk-go-v2/service/s3"
)

// StorageInterface 存储接口
type StorageInterface interface {
	Upload(ctx context.Context, key string, reader io.Reader) (string, error)
	GenerateKey(userID uint, filename string) string
	Delete(ctx context.Context, key string) error
}

// S3Storage S3 兼容存储（支持 Cloudflare R2、AWS S3 等）
type S3Storage struct {
	client     *s3.Client
	bucket     string
	baseURL    string
	publicURL  string // R2 的自定义域名
}

type S3Config struct {
	Endpoint        string // R2 的 endpoint，如 https://xxxx.r2.cloudflarestorage.com
	Region          string // R2 使用任意值，如 auto
	AccessKeyID     string
	SecretAccessKey string
	Bucket          string
	PublicURL       string // 自定义域名，用于生成访问 URL
}

// NewS3Storage 创建 S3 存储客户端
func NewS3Storage(cfg S3Config) (*S3Storage, error) {
	// 使用静态凭证
	cred := credentials.NewStaticCredentialsProvider(
		cfg.AccessKeyID,
		cfg.SecretAccessKey,
		"",
	)

	// 加载 AWS 配置
	awsCfg, err := config.LoadDefaultConfig(context.TODO(),
		config.WithCredentialsProvider(cred),
		config.WithRegion(cfg.Region),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to load AWS config: %w", err)
	}

	// 创建 S3 客户端
	var clientOpts []func(*s3.Options)
	if cfg.Endpoint != "" {
		clientOpts = append(clientOpts, func(o *s3.Options) {
			o.BaseEndpoint = aws.String(cfg.Endpoint)
			o.UsePathStyle = true // R2 需要 path-style
		})
	}

	client := s3.NewFromConfig(awsCfg, func(o *s3.Options) {
		o.Region = cfg.Region
		for _, opt := range clientOpts {
			opt(o)
		}
	})

	return &S3Storage{
		client:    client,
		bucket:    cfg.Bucket,
		baseURL:   cfg.Endpoint,
		publicURL: cfg.PublicURL,
	}, nil
}

// Upload 上传文件，返回访问 URL
func (s *S3Storage) Upload(ctx context.Context, key string, reader io.Reader) (string, error) {
	// 读取内容
	data, err := io.ReadAll(reader)
	if err != nil {
		return "", fmt.Errorf("failed to read data: %w", err)
	}

	_, err = s.client.PutObject(ctx, &s3.PutObjectInput{
		Bucket: aws.String(s.bucket),
		Key:    aws.String(key),
		Body:   createReadCloser(data),
	})
	if err != nil {
		return "", fmt.Errorf("failed to upload to S3: %w", err)
	}

	// 返回 public URL 或生成 URL
	if s.publicURL != "" {
		return s.publicURL + "/" + key, nil
	}
	return s.baseURL + "/" + s.bucket + "/" + key, nil
}

// UploadFile 上传本地文件
func (s *S3Storage) UploadFile(ctx context.Context, key, filePath string) (string, error) {
	file, err := os.Open(filePath)
	if err != nil {
		return "", fmt.Errorf("failed to open file: %w", err)
	}
	defer file.Close()

	return s.Upload(ctx, key, file)
}

// GenerateKey 生成存储 key
func (s *S3Storage) GenerateKey(userID uint, filename string) string {
	t := time.Now()
	return fmt.Sprintf("images/%d/%d%02d%02d/%s",
		userID, t.Year(), t.Month(), t.Day(), filename)
}

// Delete 删除文件
func (s *S3Storage) Delete(ctx context.Context, key string) error {
	_, err := s.client.DeleteObject(ctx, &s3.DeleteObjectInput{
		Bucket: aws.String(s.bucket),
		Key:    aws.String(key),
	})
	return err
}

// createReadCloser 创建 io.ReadCloser
func createReadCloser(data []byte) io.ReadCloser {
	return &readCloser{data: data}
}

type readCloser struct {
	data []byte
	pos  int
}

func (r *readCloser) Read(p []byte) (n int, err error) {
	if r.pos >= len(r.data) {
		return 0, io.EOF
	}
	n = copy(p, r.data[r.pos:])
	r.pos += n
	return n, nil
}

func (r *readCloser) Close() error {
	return nil
}
