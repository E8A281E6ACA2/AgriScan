package service

import (
	"agri-scan/internal/llm"
	"agri-scan/internal/model"
	"agri-scan/internal/repository"
	"bytes"
	"context"
	"encoding/base64"
	"encoding/csv"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"mime/multipart"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"gorm.io/gorm"
)

type Service struct {
	repo    *repository.Repository
	llm     llm.Provider
	storage StorageInterface
	auth    AuthConfig
}

type StorageInterface interface {
	Upload(ctx context.Context, key string, reader io.Reader) (string, error)
	GenerateKey(userID uint, filename string) string
	Delete(ctx context.Context, key string) error
}

// NewService 创建服务
func NewService(repo *repository.Repository, provider llm.Provider, storage StorageInterface) *Service {
	return &Service{
		repo:    repo,
		llm:     provider,
		storage: storage,
		auth:    loadAuthConfig(),
	}
}

func (s *Service) ensureStorage() error {
	if s.storage == nil {
		return fmt.Errorf("storage not configured")
	}
	return nil
}

// UploadImage 上传图片
func (s *Service) UploadImage(userID uint, file *multipart.FileHeader, lat, lng *float64) (*model.Image, error) {
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
		Latitude:      lat,
		Longitude:     lng,
	}

	err = s.repo.CreateImage(img)
	if err != nil {
		return nil, fmt.Errorf("failed to save image: %w", err)
	}

	return img, nil
}

// UploadImageBase64 上传 Base64 编码的图片（Web 端）
func (s *Service) UploadImageBase64(userID uint, base64Data string, lat, lng *float64) (*model.Image, error) {
	if err := s.ensureStorage(); err != nil {
		return nil, err
	}
	// 解码 base64
	data, err := base64.StdEncoding.DecodeString(base64Data)
	if err != nil {
		if strings.HasPrefix(base64Data, "data:") {
			if comma := strings.Index(base64Data, ","); comma >= 0 {
				return s.UploadImageBase64(userID, base64Data[comma+1:], lat, lng)
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
		Latitude:      lat,
		Longitude:     lng,
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
func (s *Service) SaveResult(imageID uint, result *llm.RecognitionResult, source string, durationMs int) (*model.RecognitionResult, error) {
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
		if source != "" {
			existing.Source = source
		}
		if durationMs > 0 {
			existing.DurationMs = durationMs
		}
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
		Source:        source,
		DurationMs:    durationMs,
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
func (s *Service) GetHistory(userID uint, limit, offset int, startDate, endDate *time.Time, cropType string, minConf, maxConf, minLat, maxLat, minLng, maxLng *float64) ([]model.RecognitionResult, error) {
	return s.repo.GetResultsByUserID(userID, limit, offset, startDate, endDate, cropType, minConf, maxConf, minLat, maxLat, minLng, maxLng)
}

func (s *Service) GetFeedbackMap(resultIDs []uint) (map[uint]model.UserFeedback, error) {
	if len(resultIDs) == 0 {
		return map[uint]model.UserFeedback{}, nil
	}
	items, err := s.repo.ListFeedbackByResultIDs(resultIDs)
	if err != nil {
		return nil, err
	}
	result := make(map[uint]model.UserFeedback, len(items))
	for _, item := range items {
		if _, exists := result[item.ResultID]; !exists {
			result[item.ResultID] = item
		}
	}
	return result, nil
}

func (s *Service) ExportHistoryCSV(w io.Writer, userID uint, startDate, endDate *time.Time, cropType string, minConf, maxConf, minLat, maxLat, minLng, maxLng *float64) error {
	writer := csv.NewWriter(w)
	defer writer.Flush()
	_ = writer.Write([]string{"result_id", "image_id", "image_url", "latitude", "longitude", "crop_type", "confidence", "provider", "feedback_correct", "created_at"})
	limit := 1000
	offset := 0
	for {
		items, err := s.repo.GetResultsByUserID(userID, limit, offset, startDate, endDate, cropType, minConf, maxConf, minLat, maxLat, minLng, maxLng)
		if err != nil {
			return err
		}
		if len(items) == 0 {
			break
		}
		resultIDs := make([]uint, 0, len(items))
		for _, r := range items {
			resultIDs = append(resultIDs, r.ID)
		}
		feedbackMap, err := s.GetFeedbackMap(resultIDs)
		if err != nil {
			return err
		}
		for _, r := range items {
			lat := ""
			lng := ""
			feedback := ""
			if r.Image.Latitude != nil {
				lat = strconv.FormatFloat(*r.Image.Latitude, 'f', 6, 64)
			}
			if r.Image.Longitude != nil {
				lng = strconv.FormatFloat(*r.Image.Longitude, 'f', 6, 64)
			}
			if fb, ok := feedbackMap[r.ID]; ok {
				feedback = strconv.FormatBool(fb.IsCorrect)
			}
			_ = writer.Write([]string{
				strconv.FormatUint(uint64(r.ID), 10),
				strconv.FormatUint(uint64(r.ImageID), 10),
				r.Image.OriginalURL,
				lat,
				lng,
				r.CropType,
				strconv.FormatFloat(r.Confidence, 'f', 4, 64),
				r.Provider,
				feedback,
				r.CreatedAt.Format("2006-01-02 15:04:05"),
			})
		}
		offset += len(items)
	}
	return writer.Error()
}

func (s *Service) ExportHistoryJSON(w io.Writer, userID uint, startDate, endDate *time.Time, cropType string, minConf, maxConf, minLat, maxLat, minLng, maxLng *float64) error {
	encoder := json.NewEncoder(w)
	_, err := io.WriteString(w, "[")
	if err != nil {
		return err
	}
	limit := 1000
	offset := 0
	first := true
	for {
		items, err := s.repo.GetResultsByUserID(userID, limit, offset, startDate, endDate, cropType, minConf, maxConf, minLat, maxLat, minLng, maxLng)
		if err != nil {
			return err
		}
		if len(items) == 0 {
			break
		}
		resultIDs := make([]uint, 0, len(items))
		for _, r := range items {
			resultIDs = append(resultIDs, r.ID)
		}
		feedbackMap, err := s.GetFeedbackMap(resultIDs)
		if err != nil {
			return err
		}
		for _, r := range items {
			row := map[string]interface{}{
				"result_id":  r.ID,
				"image_id":   r.ImageID,
				"image_url":  r.Image.OriginalURL,
				"latitude":   r.Image.Latitude,
				"longitude":  r.Image.Longitude,
				"crop_type":  r.CropType,
				"confidence": r.Confidence,
				"provider":   r.Provider,
				"created_at": r.CreatedAt.Format("2006-01-02 15:04:05"),
			}
			if fb, ok := feedbackMap[r.ID]; ok {
				row["feedback_correct"] = fb.IsCorrect
			}
			if !first {
				if _, err := io.WriteString(w, ","); err != nil {
					return err
				}
			}
			if err := encoder.Encode(row); err != nil {
				return err
			}
			first = false
		}
		offset += len(items)
	}
	_, err = io.WriteString(w, "]")
	return err
}

// SaveFeedback 保存用户反馈
func (s *Service) SaveFeedback(feedback *model.UserFeedback) error {
	if err := s.repo.CreateFeedback(feedback); err != nil {
		return err
	}
	_ = s.repo.UpdateNoteFeedback(feedback.ResultID, feedback)
	_ = s.ensureFeedbackNote(feedback)
	return nil
}

func (s *Service) ensureFeedbackNote(feedback *model.UserFeedback) error {
	if feedback == nil || feedback.ResultID == 0 {
		return nil
	}
	result, err := s.repo.GetResultByID(feedback.ResultID)
	if err != nil {
		return err
	}
	img, err := s.repo.GetImageByID(result.ImageID)
	if err != nil {
		return err
	}
	_, err = s.repo.GetNoteByResultID(img.UserID, result.ID)
	if err == nil {
		return nil
	}
	if !errors.Is(err, gorm.ErrRecordNotFound) {
		return err
	}

	category := feedback.Category
	if strings.TrimSpace(category) == "" {
		category = "crop"
	}
	isCorrect := feedback.IsCorrect
	item := &model.FieldNote{
		UserID:           img.UserID,
		ImageID:          img.ID,
		ResultID:         &result.ID,
		ImageURL:         img.OriginalURL,
		Category:         category,
		Tags:             "",
		RawText:          result.RawText,
		CropType:         result.CropType,
		Confidence:       result.Confidence,
		Description:      result.Description,
		GrowthStage:      result.GrowthStage,
		PossibleIssue:    result.PossibleIssue,
		Provider:         result.Provider,
		IsCorrect:        &isCorrect,
		CorrectedType:    feedback.CorrectedType,
		FeedbackNote:     feedback.FeedbackNote,
		FeedbackCategory: category,
		FeedbackTags:     feedback.Tags,
		LabelStatus:      "pending",
	}
	return s.repo.CreateNote(item)
}

// CreateNote 创建手记
func (s *Service) CreateNote(userID uint, imageID uint, resultID *uint, note string, category string, tags []string) (*model.FieldNote, error) {
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
		UserID:      userID,
		ImageID:     imageID,
		ResultID:    resultID,
		ImageURL:    img.OriginalURL,
		Note:        note,
		Category:    category,
		Tags:        strings.Join(tags, ","),
		LabelStatus: "pending",
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

func (s *Service) UpdateNoteContent(userID uint, noteID uint, note string) error {
	if strings.TrimSpace(note) == "" {
		return fmt.Errorf("note required")
	}
	rows, err := s.repo.UpdateNoteContent(userID, noteID, note)
	if err != nil {
		return err
	}
	if rows == 0 {
		return gorm.ErrRecordNotFound
	}
	return nil
}

// GetNotes 获取手记列表
func (s *Service) GetNotes(userID uint, limit, offset int, category, cropType string, startDate, endDate *time.Time, feedbackOnly bool) ([]model.FieldNote, error) {
	return s.repo.GetNotesByUserID(userID, limit, offset, category, cropType, startDate, endDate, feedbackOnly)
}

// ExportTemplate
func (s *Service) CreateExportTemplate(userID uint, typ, name, fields string) (*model.ExportTemplate, error) {
	if typ == "" {
		typ = "notes"
	}
	if name == "" || fields == "" {
		return nil, fmt.Errorf("name and fields required")
	}
	item := &model.ExportTemplate{
		UserID: userID,
		Type:   typ,
		Name:   name,
		Fields: fields,
	}
	if err := s.repo.CreateExportTemplate(item); err != nil {
		return nil, err
	}
	return item, nil
}

func (s *Service) GetExportTemplates(userID uint, typ string) ([]model.ExportTemplate, error) {
	return s.repo.GetExportTemplates(userID, typ)
}

func (s *Service) DeleteExportTemplate(userID uint, id uint) error {
	return s.repo.DeleteExportTemplate(id, userID)
}

// Crop & Tag
func (s *Service) GetCrops() ([]model.Crop, error) {
	return s.repo.GetCrops(true)
}

func (s *Service) GetTags(category string) ([]model.Tag, error) {
	return s.repo.GetTags(category)
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
