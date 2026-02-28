package repository

import (
	"agri-scan/internal/model"
	"time"

	"gorm.io/gorm/clause"
)

type QCResultRow struct {
	ResultID   uint
	ImageID    uint
	ImageURL   string
	CropType   string
	Confidence float64
	Provider   string
	CreatedAt  time.Time
}

func (r *Repository) CreateQCSamples(samples []model.QCSample) (int64, error) {
	if len(samples) == 0 {
		return 0, nil
	}
	res := r.db.Clauses(clause.OnConflict{Columns: []clause.Column{{Name: "result_id"}}, DoNothing: true}).Create(&samples)
	return res.RowsAffected, res.Error
}

func (r *Repository) ListQCSamples(limit, offset int, status, reason string) ([]model.QCSample, error) {
	var items []model.QCSample
	query := r.db.Model(&model.QCSample{})
	if status != "" {
		query = query.Where("status = ?", status)
	}
	if reason != "" {
		query = query.Where("reason = ?", reason)
	}
	err := query.Order("created_at DESC").Limit(limit).Offset(offset).Find(&items).Error
	return items, err
}

func (r *Repository) ListQCResultRowsByIDs(ids []uint) ([]QCResultRow, error) {
	if len(ids) == 0 {
		return []QCResultRow{}, nil
	}
	var items []QCResultRow
	err := r.db.Model(&model.RecognitionResult{}).
		Select("recognition_results.id as result_id, recognition_results.image_id as image_id, recognition_results.crop_type, recognition_results.confidence, recognition_results.provider, recognition_results.created_at as created_at, images.original_url as image_url").
		Joins("JOIN images ON images.id = recognition_results.image_id").
		Where("recognition_results.id IN ?", ids).
		Scan(&items).Error
	return items, err
}

func (r *Repository) ListQCSamplesAll(limit, offset int, status, reason string, start, end *time.Time) ([]model.QCSample, error) {
	var items []model.QCSample
	query := r.db.Model(&model.QCSample{})
	if status != "" {
		query = query.Where("status = ?", status)
	}
	if reason != "" {
		query = query.Where("reason = ?", reason)
	}
	if start != nil {
		query = query.Where("created_at >= ?", *start)
	}
	if end != nil {
		query = query.Where("created_at < ?", *end)
	}
	err := query.Order("created_at DESC").Limit(limit).Offset(offset).Find(&items).Error
	return items, err
}

func (r *Repository) UpdateQCSampleStatus(id uint, fields map[string]interface{}) error {
	return r.db.Model(&model.QCSample{}).Where("id = ?", id).Updates(fields).Error
}

func (r *Repository) UpdateQCSamplesStatus(ids []uint, fields map[string]interface{}) (int64, error) {
	if len(ids) == 0 {
		return 0, nil
	}
	res := r.db.Model(&model.QCSample{}).Where("id IN ?", ids).Updates(fields)
	return res.RowsAffected, res.Error
}

func (r *Repository) GetQCSampleByID(id uint) (*model.QCSample, error) {
	var item model.QCSample
	err := r.db.First(&item, id).Error
	if err != nil {
		return nil, err
	}
	return &item, nil
}
