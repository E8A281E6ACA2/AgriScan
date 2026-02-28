package config

import (
	"os"
	"path/filepath"

	"github.com/joho/godotenv"
)

type Config struct {
	Server   ServerConfig
	Database DatabaseConfig
	COS      COSConfig
	S3       S3Config
	Local    LocalStorageConfig
	LLM      LLMConfig
}

type ServerConfig struct {
	Port string
	Mode string
}

type DatabaseConfig struct {
	Host     string
	Port     string
	User     string
	Password string
	DBName   string
	SSLMode  string
}

type COSConfig struct {
	SecretID  string
	SecretKey string
	Bucket    string
	Region    string
	BaseURL   string
}

type S3Config struct {
	Endpoint        string // Cloudflare R2 endpoint
	Region          string // 任意值，如 auto
	AccessKeyID     string
	SecretAccessKey string
	Bucket          string
	PublicURL       string // 自定义域名
}

type LocalStorageConfig struct {
	BasePath string
	BaseURL  string
}

type LLMConfig struct {
	Provider   string // baidu, openai, qwen
	APIKey     string
	Endpoint   string
	Model      string
	ImageInput string // url, base64, auto
}

func Load() *Config {
	// 加载 .env 文件（开发环境）
	loadDotEnv()

	return &Config{
		Server: ServerConfig{
			Port: getEnv("SERVER_PORT", "8080"),
			Mode: getEnv("GIN_MODE", "debug"),
		},
		Database: DatabaseConfig{
			Host:     getEnv("DB_HOST", "localhost"),
			Port:     getEnv("DB_PORT", "5432"),
			User:     getEnv("DB_USER", "agriscan"),
			Password: getEnv("DB_PASSWORD", "password"),
			DBName:   getEnv("DB_NAME", "agriscan"),
			SSLMode:  getEnv("DB_SSLMODE", "disable"),
		},
		COS: COSConfig{
			SecretID:  getEnv("COS_SECRET_ID", ""),
			SecretKey: getEnv("COS_SECRET_KEY", ""),
			Bucket:    getEnv("COS_BUCKET", ""),
			Region:    getEnv("COS_REGION", "ap-guangzhou"),
			BaseURL:   getEnv("COS_BASE_URL", ""),
		},
		S3: S3Config{
			Endpoint:        getEnv("S3_ENDPOINT", ""),
			Region:          getEnv("S3_REGION", "auto"),
			AccessKeyID:     getEnv("S3_ACCESS_KEY_ID", ""),
			SecretAccessKey: getEnv("S3_SECRET_ACCESS_KEY", ""),
			Bucket:          getEnv("S3_BUCKET", ""),
			PublicURL:       getEnv("S3_PUBLIC_URL", ""),
		},
		Local: LocalStorageConfig{
			BasePath: getEnv("LOCAL_STORAGE_PATH", "./uploads"),
			BaseURL:  getEnv("LOCAL_STORAGE_BASE_URL", ""),
		},
		LLM: LLMConfig{
			Provider:   getEnv("LLM_PROVIDER", "mock"),
			APIKey:     getEnv("LLM_API_KEY", ""),
			Endpoint:   getEnv("LLM_ENDPOINT", "https://api.openai.com/v1"),
			Model:      getEnv("LLM_MODEL", "gpt-4o"),
			ImageInput: getEnv("LLM_IMAGE_INPUT", "auto"),
		},
	}
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func loadDotEnv() {
	// 优先当前目录
	if _, err := os.Stat(".env"); err == nil {
		_ = godotenv.Load()
		return
	}

	cwd, err := os.Getwd()
	if err != nil {
		_ = godotenv.Load()
		return
	}

	dir := cwd
	for i := 0; i < 4; i++ {
		candidate := filepath.Join(dir, ".env")
		if _, err := os.Stat(candidate); err == nil {
			_ = godotenv.Load(candidate)
			return
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			break
		}
		dir = parent
	}
}
