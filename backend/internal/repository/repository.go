package repository

import (
	"agri-scan/internal/model"
	"fmt"
	"time"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

type Repository struct {
	db *gorm.DB
}

func NewRepository(dsn string) (*Repository, error) {
	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{})
	if err != nil {
		return nil, fmt.Errorf("failed to connect database: %w", err)
	}

	// 自动迁移
	err = db.AutoMigrate(
		&model.User{},
		&model.EmailOTP{},
		&model.EmailLog{},
		&model.MembershipRequest{},
		&model.AdminAuditLog{},
		&model.EvalRun{},
		&model.QCSample{},
		&model.EvalSet{},
		&model.EvalSetItem{},
		&model.EvalSetRun{},
		&model.UserSession{},
		&model.Device{},
		&model.DeviceUsage{},
		&model.Image{},
		&model.RecognitionResult{},
		&model.RecognitionFailure{},
		&model.UserFeedback{},
		&model.FieldNote{},
		&model.ExportTemplate{},
		&model.Crop{},
		&model.Tag{},
		&model.AppSetting{},
		&model.PlanSetting{},
	)
	if err != nil {
		return nil, fmt.Errorf("failed to migrate: %w", err)
	}

	if err := seedDefaults(db); err != nil {
		return nil, fmt.Errorf("failed to seed defaults: %w", err)
	}

	return &Repository{db: db}, nil
}

func (r *Repository) GetCrops(activeOnly bool) ([]model.Crop, error) {
	var items []model.Crop
	query := r.db
	if activeOnly {
		query = query.Where("active = ?", true)
	}
	err := query.Order("created_at DESC").Find(&items).Error
	return items, err
}

func (r *Repository) GetTags(category string) ([]model.Tag, error) {
	var items []model.Tag
	query := r.db.Where("active = ?", true)
	if category != "" {
		query = query.Where("category = ?", category)
	}
	err := query.Order("created_at DESC").Find(&items).Error
	return items, err
}

// ExportTemplate 操作
func (r *Repository) CreateExportTemplate(tpl *model.ExportTemplate) error {
	return r.db.Create(tpl).Error
}

func (r *Repository) GetExportTemplates(userID uint, typ string) ([]model.ExportTemplate, error) {
	var items []model.ExportTemplate
	query := r.db.Where("user_id = ?", userID)
	if typ != "" {
		query = query.Where("type = ?", typ)
	}
	err := query.Order("created_at DESC").Find(&items).Error
	return items, err
}

func (r *Repository) DeleteExportTemplate(id uint, userID uint) error {
	return r.db.Where("id = ? AND user_id = ?", id, userID).Delete(&model.ExportTemplate{}).Error
}

func (r *Repository) DB() *gorm.DB {
	return r.db
}

// Image 操作
func (r *Repository) CreateImage(img *model.Image) error {
	return r.db.Create(img).Error
}

func (r *Repository) GetImageByID(id uint) (*model.Image, error) {
	var img model.Image
	err := r.db.First(&img, id).Error
	return &img, err
}

func (r *Repository) GetImagesByIDs(ids []uint) ([]model.Image, error) {
	if len(ids) == 0 {
		return []model.Image{}, nil
	}
	var imgs []model.Image
	err := r.db.Where("id IN ?", ids).Find(&imgs).Error
	return imgs, err
}

// FieldNote 操作（按识别结果）
func (r *Repository) GetNoteByResultID(userID uint, resultID uint) (*model.FieldNote, error) {
	var note model.FieldNote
	err := r.db.Where("user_id = ? AND result_id = ?", userID, resultID).First(&note).Error
	return &note, err
}

// RecognitionResult 操作
func (r *Repository) CreateResult(result *model.RecognitionResult) error {
	return r.db.Create(result).Error
}

func (r *Repository) GetResultByImageID(imageID uint) (*model.RecognitionResult, error) {
	var result model.RecognitionResult
	err := r.db.Where("image_id = ?", imageID).First(&result).Error
	return &result, err
}

func (r *Repository) GetResultByID(id uint) (*model.RecognitionResult, error) {
	var result model.RecognitionResult
	err := r.db.First(&result, id).Error
	return &result, err
}

func (r *Repository) GetResultsByUserID(userID uint, limit, offset int, startDate, endDate *time.Time, cropType string, minConf, maxConf *float64, minLat, maxLat, minLng, maxLng *float64, source string) ([]model.RecognitionResult, error) {
	var results []model.RecognitionResult
	query := r.db.
		Joins("JOIN images ON images.id = recognition_results.image_id").
		Where("images.user_id = ?", userID)
	if startDate != nil {
		query = query.Where("recognition_results.created_at >= ?", *startDate)
	}
	if endDate != nil {
		query = query.Where("recognition_results.created_at < ?", *endDate)
	}
	if cropType != "" {
		query = query.Where("recognition_results.crop_type = ?", cropType)
	}
	if minConf != nil {
		query = query.Where("recognition_results.confidence >= ?", *minConf)
	}
	if maxConf != nil {
		query = query.Where("recognition_results.confidence <= ?", *maxConf)
	}
	if minLat != nil {
		query = query.Where("images.latitude >= ?", *minLat)
	}
	if maxLat != nil {
		query = query.Where("images.latitude <= ?", *maxLat)
	}
	if minLng != nil {
		query = query.Where("images.longitude >= ?", *minLng)
	}
	if maxLng != nil {
		query = query.Where("images.longitude <= ?", *maxLng)
	}
	if source != "" {
		query = query.Where("recognition_results.source = ?", source)
	}
	err := query.
		Order("recognition_results.created_at DESC").
		Limit(limit).
		Offset(offset).
		Preload("Image").
		Find(&results).Error
	return results, err
}

// UserFeedback 操作
func (r *Repository) CreateFeedback(feedback *model.UserFeedback) error {
	return r.db.Create(feedback).Error
}

func (r *Repository) ListFeedbackByResultIDs(resultIDs []uint) ([]model.UserFeedback, error) {
	if len(resultIDs) == 0 {
		return []model.UserFeedback{}, nil
	}
	var items []model.UserFeedback
	err := r.db.
		Where("result_id IN ?", resultIDs).
		Order("created_at DESC").
		Find(&items).Error
	return items, err
}

func (r *Repository) UpdateNoteFeedback(resultID uint, feedback *model.UserFeedback) error {
	update := map[string]interface{}{
		"is_correct":        feedback.IsCorrect,
		"corrected_type":    feedback.CorrectedType,
		"feedback_note":     feedback.FeedbackNote,
		"feedback_category": feedback.Category,
		"feedback_tags":     feedback.Tags,
	}
	return r.db.Model(&model.FieldNote{}).Where("result_id = ?", resultID).Updates(update).Error
}

// FieldNote 操作
func (r *Repository) CreateNote(note *model.FieldNote) error {
	return r.db.Create(note).Error
}

func (r *Repository) UpdateNoteContent(userID uint, noteID uint, note string) (int64, error) {
	res := r.db.Model(&model.FieldNote{}).
		Where("id = ? AND user_id = ?", noteID, userID).
		Update("note", note)
	return res.RowsAffected, res.Error
}

func (r *Repository) GetNotesByUserID(userID uint, limit, offset int, category, cropType string, startDate, endDate *time.Time, feedbackOnly bool) ([]model.FieldNote, error) {
	var notes []model.FieldNote
	query := r.db.Where("user_id = ?", userID)
	if category != "" {
		query = query.Where("category = ?", category)
	}
	if cropType != "" {
		query = query.Where("crop_type = ?", cropType)
	}
	if startDate != nil {
		query = query.Where("created_at >= ?", *startDate)
	}
	if endDate != nil {
		query = query.Where("created_at < ?", *endDate)
	}
	if feedbackOnly {
		query = query.Where("is_correct IS NOT NULL OR feedback_note <> '' OR feedback_category <> '' OR feedback_tags <> ''")
	}
	err := query.Order("created_at DESC").
		Limit(limit).
		Offset(offset).
		Find(&notes).Error
	return notes, err
}

func (r *Repository) PurgeNotesBefore(userID uint, cutoff time.Time) (int64, error) {
	res := r.db.Where("user_id = ? AND created_at < ?", userID, cutoff).Delete(&model.FieldNote{})
	return res.RowsAffected, res.Error
}

func (r *Repository) PurgeResultsBefore(userID uint, cutoff time.Time) (int64, error) {
	sub := r.db.Model(&model.Image{}).
		Select("id").
		Where("user_id = ? AND created_at < ?", userID, cutoff)
	res := r.db.Where("image_id IN (?)", sub).Delete(&model.RecognitionResult{})
	return res.RowsAffected, res.Error
}

func (r *Repository) PurgeImagesBefore(userID uint, cutoff time.Time) (int64, error) {
	res := r.db.Where("user_id = ? AND created_at < ?", userID, cutoff).Delete(&model.Image{})
	return res.RowsAffected, res.Error
}

func (r *Repository) ListImagesBefore(userID uint, cutoff time.Time, limit, offset int) ([]model.Image, error) {
	var items []model.Image
	err := r.db.Where("user_id = ? AND created_at < ?", userID, cutoff).
		Order("created_at ASC").
		Limit(limit).
		Offset(offset).
		Find(&items).Error
	return items, err
}

func (r *Repository) GetUserByOpenID(openID string) (*model.User, error) {
	var user model.User
	err := r.db.Where("open_id = ?", openID).First(&user).Error
	return &user, err
}
