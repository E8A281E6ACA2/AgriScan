package repository

import (
	"agri-scan/internal/model"
	"fmt"

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
		&model.Image{},
		&model.RecognitionResult{},
		&model.UserFeedback{},
	)
	if err != nil {
		return nil, fmt.Errorf("failed to migrate: %w", err)
	}

	return &Repository{db: db}, nil
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

// RecognitionResult 操作
func (r *Repository) CreateResult(result *model.RecognitionResult) error {
	return r.db.Create(result).Error
}

func (r *Repository) GetResultByImageID(imageID uint) (*model.RecognitionResult, error) {
	var result model.RecognitionResult
	err := r.db.Where("image_id = ?", imageID).First(&result).Error
	return &result, err
}

func (r *Repository) GetResultsByUserID(userID uint, limit, offset int) ([]model.RecognitionResult, error) {
	var results []model.RecognitionResult
	err := r.db.Where("user_id IN (SELECT id FROM images WHERE user_id = ?)", userID).
		Limit(limit).Offset(offset).Find(&results).Error
	return results, err
}

// UserFeedback 操作
func (r *Repository) CreateFeedback(feedback *model.UserFeedback) error {
	return r.db.Create(feedback).Error
}

// User 操作
func (r *Repository) CreateUser(user *model.User) error {
	return r.db.Create(user).Error
}

func (r *Repository) GetUserByOpenID(openID string) (*model.User, error) {
	var user model.User
	err := r.db.Where("open_id = ?", openID).First(&user).Error
	return &user, err
}
