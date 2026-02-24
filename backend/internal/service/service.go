package service

import (
	"agri-scan/internal/llm"
	"agri-scan/internal/model"
	"agri-scan/internal/repository"
	"bytes"
	"context"
	"encoding/base64"
	"fmt"
	"io"
	"mime/multipart"
	"path/filepath"
	"strings"
	"time"

	"gorm.io/gorm"
)

type Service struct {
	repo    *repository.Repository
	llm     llm.Provider
	storage StorageInterface
}

type StorageInterface interface {
	Upload(ctx context.Context, key string, reader io.Reader) (string, error)
	GenerateKey(userID uint, filename string) string
}

// NewService 创建服务
func NewService(repo *repository.Repository, provider llm.Provider, storage StorageInterface) *Service {
	return &Service{
		repo:    repo,
		llm:     provider,
		storage: storage,
	}
}

func (s *Service) ensureStorage() error {
	if s.storage == nil {
		return fmt.Errorf("storage not configured")
	}
	return nil
}

// UploadImage 上传图片
func (s *Service) UploadImage(userID uint, file *multipart.FileHeader) (*model.Image, error) {
	if err := s.ensureStorage(); err != nil {
		return nil, err
	}
	// 读取文件
	src, err := file.Open()
	if err != nil {
		return nil, fmt.Errorf("failed to open file: %w", err)
	}
	defer src.Close()

	// 生成存储 key
	ext := strings.ToLower(filepath.Ext(file.Filename))
	filename := fmt.Sprintf("%d%s", time.Now().Unix(), ext)
	key := s.storage.GenerateKey(userID, filename)

	// 上传到对象存储
	// 注意：这里需要将 context 转换为标准 context
	// 在实际使用中，应传入 context.Context
	url, err := s.storage.Upload(context.Background(), key, src)
	if err != nil {
		return nil, fmt.Errorf("failed to upload: %w", err)
	}

	// 保存到数据库
	img := &model.Image{
		UserID:        userID,
		OriginalURL:   url,
		CompressedURL: url, // TODO: 压缩后再存储
		FileSize:      file.Size,
	}

	err = s.repo.CreateImage(img)
	if err != nil {
		return nil, fmt.Errorf("failed to save image: %w", err)
	}

	return img, nil
}

// UploadImageBase64 上传 Base64 编码的图片（Web 端）
func (s *Service) UploadImageBase64(userID uint, base64Data string) (*model.Image, error) {
	if err := s.ensureStorage(); err != nil {
		return nil, err
	}
	// 解码 base64
	data, err := base64.StdEncoding.DecodeString(base64Data)
	if err != nil {
		if strings.HasPrefix(base64Data, "data:") {
			if comma := strings.Index(base64Data, ","); comma >= 0 {
				return s.UploadImageBase64(userID, base64Data[comma+1:])
			}
		}
		return nil, fmt.Errorf("failed to decode base64: %w", err)
	}

	if len(data) == 0 {
		return nil, fmt.Errorf("empty image data")
	}

	// 生成存储 key
	filename := fmt.Sprintf("%d.jpg", time.Now().Unix())
	key := s.storage.GenerateKey(userID, filename)

	// 上传到对象存储
	url, err := s.storage.Upload(context.Background(), key, bytes.NewReader(data))
	if err != nil {
		return nil, fmt.Errorf("failed to upload: %w", err)
	}

	// 保存到数据库
	img := &model.Image{
		UserID:        userID,
		OriginalURL:   url,
		CompressedURL: url,
		FileSize:      int64(len(data)),
	}

	err = s.repo.CreateImage(img)
	if err != nil {
		return nil, fmt.Errorf("failed to save image: %w", err)
	}

	return img, nil
}

// GetImage 获取图片
func (s *Service) GetImage(id uint) (*model.Image, error) {
	return s.repo.GetImageByID(id)
}

// CreateImageFromURL 创建外部图片记录
func (s *Service) CreateImageFromURL(userID uint, imageURL string) (*model.Image, error) {
	img := &model.Image{
		UserID:        userID,
		OriginalURL:   imageURL,
		CompressedURL: imageURL,
		FileSize:      0,
	}

	err := s.repo.CreateImage(img)
	if err != nil {
		return nil, fmt.Errorf("failed to save image: %w", err)
	}

	return img, nil
}

// Recognize 调用大模型识别
func (s *Service) Recognize(imageURL string) (*llm.RecognitionResult, error) {
	return s.llm.Recognize(imageURL)
}

// SaveResult 保存识别结果
func (s *Service) SaveResult(imageID uint, result *llm.RecognitionResult) (*model.RecognitionResult, error) {
	// 检查是否已存在结果
	existing, err := s.repo.GetResultByImageID(imageID)
	if err == nil && existing != nil {
		// 已存在，更新
		existing.RawText = result.RawText
		existing.CropType = result.CropType
		existing.Confidence = result.Confidence
		existing.Description = result.Description
		existing.GrowthStage = result.GrowthStage
		existing.PossibleIssue = result.PossibleIssue
		existing.Provider = s.llm.Name()
		return existing, s.repo.DB().Save(existing).Error
	}

	// 创建新结果
	saved := &model.RecognitionResult{
		ImageID:       imageID,
		RawText:       result.RawText,
		CropType:      result.CropType,
		Confidence:    result.Confidence,
		Description:   result.Description,
		GrowthStage:   result.GrowthStage,
		PossibleIssue: result.PossibleIssue,
		Provider:      s.llm.Name(),
	}

	err = s.repo.CreateResult(saved)
	if err != nil {
		return nil, fmt.Errorf("failed to save result: %w", err)
	}

	return saved, nil
}

// GetResultByImageID 根据图片 ID 获取识别结果
func (s *Service) GetResultByImageID(imageID uint) (*model.RecognitionResult, error) {
	return s.repo.GetResultByImageID(imageID)
}

func (s *Service) GetResultByID(id uint) (*model.RecognitionResult, error) {
	return s.repo.GetResultByID(id)
}

// GetHistory 获取用户历史记录
func (s *Service) GetHistory(userID uint, limit, offset int) ([]model.RecognitionResult, error) {
	return s.repo.GetResultsByUserID(userID, limit, offset)
}

// SaveFeedback 保存用户反馈
func (s *Service) SaveFeedback(feedback *model.UserFeedback) error {
	return s.repo.CreateFeedback(feedback)
}

// CreateNote 创建手记
func (s *Service) CreateNote(userID uint, imageID uint, resultID *uint, note string, category string) (*model.FieldNote, error) {
	img, err := s.repo.GetImageByID(imageID)
	if err != nil {
		return nil, fmt.Errorf("failed to get image: %w", err)
	}

	if category == "" {
		category = "crop"
	}

	var result *model.RecognitionResult
	if resultID != nil {
		res, err := s.repo.GetResultByID(*resultID)
		if err != nil {
			return nil, fmt.Errorf("failed to get result: %w", err)
		}
		result = res
	}

	item := &model.FieldNote{
		UserID:   userID,
		ImageID:  imageID,
		ResultID: resultID,
		ImageURL: img.OriginalURL,
		Note:     note,
		Category: category,
	}
	if result != nil {
		item.RawText = result.RawText
		item.CropType = result.CropType
		item.Confidence = result.Confidence
		item.Description = result.Description
		item.GrowthStage = result.GrowthStage
		item.PossibleIssue = result.PossibleIssue
		item.Provider = result.Provider
	}
	if err := s.repo.CreateNote(item); err != nil {
		return nil, fmt.Errorf("failed to save note: %w", err)
	}
	return item, nil
}

// GetNotes 获取手记列表
func (s *Service) GetNotes(userID uint, limit, offset int, category, cropType string) ([]model.FieldNote, error) {
	return s.repo.GetNotesByUserID(userID, limit, offset, category, cropType)
}

// ListProviders 列出所有大模型提供商
func (s *Service) ListProviders() []string {
	return llm.ListProviders()
}

// SetLLMProvider 设置大模型提供商
func (s *Service) SetLLMProvider(name string) error {
	provider, err := llm.GetProvider(name)
	if err != nil {
		return err
	}
	s.llm = provider
	return nil
}

// GetDB 获取数据库连接（用于事务）
func (s *Service) GetDB() *gorm.DB {
	return s.repo.DB()
}
