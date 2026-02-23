
package main

import (
	"agri-scan/internal/config"
	"agri-scan/internal/handler"
	"agri-scan/internal/llm"
	"agri-scan/internal/repository"
	"agri-scan/internal/service"
	"agri-scan/pkg/storage"
	"fmt"
	"log"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
)

func main() {
	// 加载配置
	cfg := config.Load()

	// 设置 Gin 模式
	gin.SetMode(cfg.Server.Mode)

	// 初始化数据库
	dsn := fmt.Sprintf(
		"host=%s user=%s password=%s dbname=%s port=%s sslmode=%s",
		cfg.Database.Host,
		cfg.Database.User,
		cfg.Database.Password,
		cfg.Database.DBName,
		cfg.Database.Port,
		cfg.Database.SSLMode,
	)

	repo, err := repository.NewRepository(dsn)
	if err != nil {
		log.Fatalf("Failed to connect database: %v", err)
	}
	log.Println("Database connected")

	// 初始化对象存储
	var stor storage.StorageInterface
	
	// 优先使用 S3/R2 配置
	if cfg.S3.AccessKeyID != "" && cfg.S3.SecretAccessKey != "" {
		stor, err = storage.NewS3Storage(storage.S3Config{
			Endpoint:        cfg.S3.Endpoint,
			Region:          cfg.S3.Region,
			AccessKeyID:     cfg.S3.AccessKeyID,
			SecretAccessKey: cfg.S3.SecretAccessKey,
			Bucket:          cfg.S3.Bucket,
			PublicURL:       cfg.S3.PublicURL,
		})
		if err != nil {
			log.Printf("Warning: Failed to init S3/R2: %v", err)
		} else {
			log.Println("S3/R2 storage initialized")
		}
	} else if cfg.COS.SecretID != "" && cfg.COS.SecretKey != "" {
		// 后备 COS
		stor, err = storage.NewCOSStorage(
			cfg.COS.SecretID,
			cfg.COS.SecretKey,
			cfg.COS.Bucket,
			cfg.COS.Region,
			cfg.COS.BaseURL,
		)
		if err != nil {
			log.Printf("Warning: Failed to init COS: %v", err)
		}
	} else {
		log.Println("Warning: No object storage configured")
	}

	// 初始化大模型提供商
	// 注册 Mock 提供商（用于测试）
	llm.RegisterProvider("mock", llm.NewMockProvider())

	// 注册 OpenAI 兼容 Provider
	if cfg.LLM.APIKey != "" {
		llm.RegisterProvider("openai", llm.NewOpenAIProvider(cfg.LLM.APIKey, cfg.LLM.Endpoint))
		log.Println("OpenAI provider registered")
	}

	// 获取配置的提供商
	provider, err := llm.GetProvider(cfg.LLM.Provider)
	if err != nil {
		log.Printf("Warning: Provider %s not found, using mock", cfg.LLM.Provider)
		provider = llm.NewMockProvider()
	}

	// 初始化服务
	svc := service.NewService(repo, provider, stor)

	// 初始化处理器
	h := handler.NewHandler(svc)

	// 创建路由
	r := gin.Default()
	
	// 添加 CORS 中间件
	r.Use(cors.New(cors.Config{
		AllowOrigins:     []string{"*"},
		AllowMethods:     []string{"GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"},
		AllowHeaders:     []string{"Origin", "Content-Type", "Accept", "Authorization", "X-User-ID"},
		ExposeHeaders:    []string{"Content-Length"},
		AllowCredentials: true,
	}))
	
	h.SetupRoutes(r)

	// 启动服务器
	addr := fmt.Sprintf(":%s", cfg.Server.Port)
	log.Printf("Server starting on %s", addr)
	if err := r.Run(addr); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}
