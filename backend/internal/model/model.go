package model

import (
	"time"

	"gorm.io/gorm"
)

type User struct {
	ID          uint           `gorm:"primarykey" json:"id"`
	CreatedAt   time.Time      `json:"created_at"`
	UpdatedAt   time.Time      `json:"updated_at"`
	DeletedAt   gorm.DeletedAt `gorm:"index" json:"-"`
	OpenID      string         `gorm:"uniqueIndex;size:64" json:"open_id"` // 微信 openid
	Email       string         `gorm:"uniqueIndex;size:128" json:"email"`
	Nickname    string         `gorm:"size:128" json:"nickname"`
	Avatar      string         `gorm:"size:512" json:"avatar"`
	Plan        string         `gorm:"size:16;index;default:free" json:"plan"`
	Status      string         `gorm:"size:16;default:active" json:"status"`
	IsAdmin     bool           `gorm:"index;default:false" json:"is_admin"`
	QuotaTotal  int            `json:"quota_total"`
	QuotaUsed   int            `json:"quota_used"`
	AdCredits   int            `json:"ad_credits"`
	LastLoginAt *time.Time     `json:"last_login_at"`
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
	Category      string         `gorm:"size:16;index" json:"category"`
	Tags          string         `gorm:"type:text" json:"tags"`
}

type FieldNote struct {
	ID               uint           `gorm:"primarykey" json:"id"`
	CreatedAt        time.Time      `json:"created_at"`
	UpdatedAt        time.Time      `json:"updated_at"`
	DeletedAt        gorm.DeletedAt `gorm:"index" json:"-"`
	UserID           uint           `gorm:"index" json:"user_id"`
	ImageID          uint           `gorm:"index" json:"image_id"`
	ResultID         *uint          `gorm:"index" json:"result_id"`
	ImageURL         string         `gorm:"size:512" json:"image_url"`
	Note             string         `gorm:"type:text" json:"note"`
	Category         string         `gorm:"size:16;index" json:"category"`
	RawText          string         `gorm:"type:text" json:"raw_text"`
	CropType         string         `gorm:"size:64;index" json:"crop_type"`
	Confidence       float64        `json:"confidence"`
	Description      string         `gorm:"type:text" json:"description"`
	GrowthStage      *string        `json:"growth_stage"`
	PossibleIssue    *string        `json:"possible_issue"`
	Provider         string         `gorm:"size:32" json:"provider"`
	Tags             string         `gorm:"type:text" json:"tags"`
	IsCorrect        *bool          `json:"is_correct"`
	CorrectedType    string         `gorm:"size:64" json:"corrected_type"`
	FeedbackNote     string         `gorm:"type:text" json:"feedback_note"`
	FeedbackCategory string         `gorm:"size:16;index" json:"feedback_category"`
	FeedbackTags     string         `gorm:"type:text" json:"feedback_tags"`
	LabelStatus      string         `gorm:"size:16;index" json:"label_status"` // pending/labeled/approved/rejected
	LabelCategory    string         `gorm:"size:16;index" json:"label_category"`
	LabelCropType    string         `gorm:"size:64;index" json:"label_crop_type"`
	LabelTags        string         `gorm:"type:text" json:"label_tags"`
	LabelNote        string         `gorm:"type:text" json:"label_note"`
	ReviewedBy       string         `gorm:"size:64" json:"reviewed_by"`
	ReviewedAt       *time.Time     `json:"reviewed_at"`
}

type ExportTemplate struct {
	ID        uint           `gorm:"primarykey" json:"id"`
	CreatedAt time.Time      `json:"created_at"`
	UpdatedAt time.Time      `json:"updated_at"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
	UserID    uint           `gorm:"index" json:"user_id"`
	Type      string         `gorm:"size:32;index" json:"type"` // e.g. notes
	Name      string         `gorm:"size:64" json:"name"`
	Fields    string         `gorm:"type:text" json:"fields"`
}

type Crop struct {
	ID        uint           `gorm:"primarykey" json:"id"`
	CreatedAt time.Time      `json:"created_at"`
	UpdatedAt time.Time      `json:"updated_at"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
	Code      string         `gorm:"size:32;index" json:"code"`
	Name      string         `gorm:"size:64" json:"name"`
	Aliases   string         `gorm:"type:text" json:"aliases"`
	Active    bool           `gorm:"index" json:"active"`
}

type Tag struct {
	ID        uint           `gorm:"primarykey" json:"id"`
	CreatedAt time.Time      `json:"created_at"`
	UpdatedAt time.Time      `json:"updated_at"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
	Category  string         `gorm:"size:16;index" json:"category"`
	Name      string         `gorm:"size:64" json:"name"`
	Active    bool           `gorm:"index" json:"active"`
}

type PlanSetting struct {
	ID            uint           `gorm:"primarykey" json:"id"`
	CreatedAt     time.Time      `json:"created_at"`
	UpdatedAt     time.Time      `json:"updated_at"`
	DeletedAt     gorm.DeletedAt `gorm:"index" json:"-"`
	Code          string         `gorm:"size:16;uniqueIndex" json:"code"`
	Name          string         `gorm:"size:32" json:"name"`
	Description   string         `gorm:"type:text" json:"description"`
	QuotaTotal    int            `json:"quota_total"`
	RetentionDays int            `json:"retention_days"`
	RequireAd     bool           `json:"require_ad"`
}

type EmailOTP struct {
	ID        uint           `gorm:"primarykey" json:"id"`
	CreatedAt time.Time      `json:"created_at"`
	UpdatedAt time.Time      `json:"updated_at"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
	Email     string         `gorm:"index;size:128" json:"email"`
	Code      string         `gorm:"size:10" json:"code"`
	ExpiresAt time.Time      `gorm:"index" json:"expires_at"`
	UsedAt    *time.Time     `json:"used_at"`
}

type EmailLog struct {
	ID        uint           `gorm:"primarykey" json:"id"`
	CreatedAt time.Time      `json:"created_at"`
	UpdatedAt time.Time      `json:"updated_at"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
	Email     string         `gorm:"index;size:128" json:"email"`
	Code      string         `gorm:"size:10" json:"code"`
	Status    string         `gorm:"size:16" json:"status"` // sent/failed/debug
	Error     string         `gorm:"type:text" json:"error"`
}

type MembershipRequest struct {
	ID        uint           `gorm:"primarykey" json:"id"`
	CreatedAt time.Time      `json:"created_at"`
	UpdatedAt time.Time      `json:"updated_at"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
	UserID    uint           `gorm:"index" json:"user_id"`
	Plan      string         `gorm:"size:16;index" json:"plan"`
	Status    string         `gorm:"size:16;index" json:"status"` // pending/approved/rejected
	Note      string         `gorm:"type:text" json:"note"`
}

type AdminAuditLog struct {
	ID         uint           `gorm:"primarykey" json:"id"`
	CreatedAt  time.Time      `json:"created_at"`
	UpdatedAt  time.Time      `json:"updated_at"`
	DeletedAt  gorm.DeletedAt `gorm:"index" json:"-"`
	Action     string         `gorm:"size:64;index" json:"action"`
	TargetType string         `gorm:"size:64;index" json:"target_type"`
	TargetID   uint           `gorm:"index" json:"target_id"`
	Detail     string         `gorm:"type:text" json:"detail"`
	IP         string         `gorm:"size:64" json:"ip"`
}

type UserSession struct {
	ID        uint           `gorm:"primarykey" json:"id"`
	CreatedAt time.Time      `json:"created_at"`
	UpdatedAt time.Time      `json:"updated_at"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
	UserID    uint           `gorm:"index" json:"user_id"`
	Token     string         `gorm:"uniqueIndex;size:64" json:"token"`
	ExpiresAt time.Time      `gorm:"index" json:"expires_at"`
}

type Device struct {
	ID        uint           `gorm:"primarykey" json:"id"`
	CreatedAt time.Time      `json:"created_at"`
	UpdatedAt time.Time      `json:"updated_at"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
	DeviceID  string         `gorm:"uniqueIndex;size:64" json:"device_id"`
	UserID    uint           `gorm:"index" json:"user_id"`
}

type DeviceUsage struct {
	ID             uint           `gorm:"primarykey" json:"id"`
	CreatedAt      time.Time      `json:"created_at"`
	UpdatedAt      time.Time      `json:"updated_at"`
	DeletedAt      gorm.DeletedAt `gorm:"index" json:"-"`
	DeviceID       string         `gorm:"uniqueIndex;size:64" json:"device_id"`
	RecognizeCount int            `json:"recognize_count"`
	AdCredits      int            `json:"ad_credits"`
}
