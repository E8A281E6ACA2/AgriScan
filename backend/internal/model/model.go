package model

import (
	"time"

	"gorm.io/gorm"
)

type User struct {
	ID        uint           `gorm:"primarykey" json:"id"`
	CreatedAt time.Time      `json:"created_at"`
	UpdatedAt time.Time      `json:"updated_at"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
	OpenID    string         `gorm:"uniqueIndex;size:64" json:"open_id"` // 微信 openid
	Nickname  string         `gorm:"size:128" json:"nickname"`
	Avatar    string         `gorm:"size:512" json:"avatar"`
}

type Image struct {
	ID            uint           `gorm:"primarykey" json:"id"`
	CreatedAt     time.Time      `json:"created_at"`
	UpdatedAt     time.Time      `json:"updated_at"`
	DeletedAt     gorm.DeletedAt `gorm:"index" json:"-"`
	UserID        uint           `gorm:"index" json:"user_id"`
	OriginalURL   string         `gorm:"size:512" json:"original_url"`
	CompressedURL string         `gorm:"size:512" json:"compressed_url"`
	Latitude      *float64       `json:"latitude"`
	Longitude     *float64       `json:"longitude"`
	FileSize      int64          `json:"file_size"`
	Width         int            `json:"width"`
	Height        int            `json:"height"`
}

type RecognitionResult struct {
	ID            uint           `gorm:"primarykey" json:"id"`
	CreatedAt     time.Time      `json:"created_at"`
	UpdatedAt     time.Time      `json:"updated_at"`
	DeletedAt     gorm.DeletedAt `gorm:"index" json:"-"`
	ImageID       uint           `gorm:"uniqueIndex" json:"image_id"`
	Image         Image          `gorm:"foreignKey:ImageID" json:"image"`
	RawText       string         `gorm:"type:text" json:"raw_text"`
	CropType      string         `gorm:"size:64;index" json:"crop_type"`
	Confidence    float64        `json:"confidence"`
	Description   string         `gorm:"type:text" json:"description"`
	GrowthStage   *string        `json:"growth_stage"`
	PossibleIssue *string        `json:"possible_issue"`
	Provider      string         `gorm:"size:32" json:"provider"` // 识别提供商
}

type UserFeedback struct {
	ID            uint           `gorm:"primarykey" json:"id"`
	CreatedAt     time.Time      `json:"created_at"`
	UpdatedAt     time.Time      `json:"updated_at"`
	DeletedAt     gorm.DeletedAt `gorm:"index" json:"-"`
	ResultID      uint           `gorm:"index" json:"result_id"`
	CorrectedType string         `gorm:"size:64" json:"corrected_type"`
	FeedbackNote  string         `gorm:"type:text" json:"feedback_note"`
	IsCorrect     bool           `json:"is_correct"`
}

type FieldNote struct {
	ID            uint           `gorm:"primarykey" json:"id"`
	CreatedAt     time.Time      `json:"created_at"`
	UpdatedAt     time.Time      `json:"updated_at"`
	DeletedAt     gorm.DeletedAt `gorm:"index" json:"-"`
	UserID        uint           `gorm:"index" json:"user_id"`
	ImageID       uint           `gorm:"index" json:"image_id"`
	ResultID      *uint          `gorm:"index" json:"result_id"`
	ImageURL      string         `gorm:"size:512" json:"image_url"`
	Note          string         `gorm:"type:text" json:"note"`
	Category      string         `gorm:"size:16;index" json:"category"`
	RawText       string         `gorm:"type:text" json:"raw_text"`
	CropType      string         `gorm:"size:64;index" json:"crop_type"`
	Confidence    float64        `json:"confidence"`
	Description   string         `gorm:"type:text" json:"description"`
	GrowthStage   *string        `json:"growth_stage"`
	PossibleIssue *string        `json:"possible_issue"`
	Provider      string         `gorm:"size:32" json:"provider"`
	Tags          string         `gorm:"type:text" json:"tags"`
}
