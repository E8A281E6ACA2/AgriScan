package config

import (
	"os"

	"github.com/joho/godotenv"
)

type Config struct {
	Server   ServerConfig
	Database DatabaseConfig
	COS      COSConfig
	S3       S3Config
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
	SecretID     string
	SecretKey    string
	Bucket       string
	Region       string
	BaseURL      string
}

type S3Config struct {
	Endpoint        string // Cloudflare R2 endpoint
	Region          string // 任意值，如 auto
	AccessKeyID     string
	SecretAccessKey string
	Bucket          string
	PublicURL       string // 自定义域名
}

type LLMConfig struct {
	Provider string // baidu, openai, qwen
	APIKey   string
	Endpoint string
	Model    string
}

func Load() *Config {
	// 加载 .env 文件（开发环境）
	_ = godotenv.Load()
	
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
		LLM: LLMConfig{
			Provider: getEnv("LLM_PROVIDER", "qwen"),
			APIKey:   getEnv("LLM_API_KEY", ""),
			Endpoint: getEnv("LLM_ENDPOINT", ""),
			Model:    getEnv("LLM_MODEL", "gpt-4o"),
		},
	}
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}
