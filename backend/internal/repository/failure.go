package repository

import (
	"agri-scan/internal/model"
	"time"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

type FailureTopRow struct {
	Stage        string `json:"stage"`
	ErrorCode    string `json:"error_code"`
	ErrorMessage string `json:"error_message"`
	Count        int64  `json:"count"`
	RetryTotal   int64  `json:"retry_total"`
	SuccessCount int64  `json:"success_count"`
}

func (r *Repository) UpsertRecognitionFailure(item *model.RecognitionFailure) error {
	if item == nil {
		return nil
	}
	if item.ImageID == nil {
		return r.db.Create(item).Error
	}
	now := time.Now()
	return r.db.Clauses(clause.OnConflict{
		Columns: []clause.Column{
			{Name: "image_id"},
			{Name: "stage"},
		},
		DoUpdates: clause.Assignments(map[string]interface{}{
			"error_code":    item.ErrorCode,
			"error_message": item.ErrorMessage,
			"provider":      item.Provider,
			"user_id":       item.UserID,
			"last_tried_at": item.LastTriedAt,
			"retry_count":   gorm.Expr("retry_count + 1"),
			"updated_at":    now,
		}),
	}).Create(item).Error
}

func (r *Repository) ListFailureTop(since time.Time, limit int, stage string) ([]FailureTopRow, error) {
	rows := make([]FailureTopRow, 0)
	query := r.db.Model(&model.RecognitionFailure{}).
		Select("recognition_failures.stage, recognition_failures.error_code, max(recognition_failures.error_message) as error_message, count(*) as count, sum(recognition_failures.retry_count) as retry_total, sum(case when recognition_results.id is not null then 1 else 0 end) as success_count").
		Joins("LEFT JOIN recognition_results ON recognition_results.image_id = recognition_failures.image_id").
		Where("recognition_failures.created_at >= ?", since)
	if stage != "" {
		query = query.Where("recognition_failures.stage = ?", stage)
	}
	err := query.Group("recognition_failures.stage, recognition_failures.error_code").
		Order("count DESC").
		Limit(limit).
		Scan(&rows).Error
	return rows, err
}
