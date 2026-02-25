package repository

import (
	"agri-scan/internal/model"
	"time"
)

// Admin audit
func (r *Repository) CreateAdminAuditLog(item *model.AdminAuditLog) error {
	return r.db.Create(item).Error
}

func (r *Repository) ListAdminAuditLogs(limit, offset int, action string) ([]model.AdminAuditLog, error) {
	var items []model.AdminAuditLog
	query := r.db.Model(&model.AdminAuditLog{})
	if action != "" {
		query = query.Where("action = ?", action)
	}
	err := query.Order("created_at DESC").Limit(limit).Offset(offset).Find(&items).Error
	return items, err
}

// Stats
func (r *Repository) CountUsers() (int64, error) {
	var c int64
	err := r.db.Model(&model.User{}).Count(&c).Error
	return c, err
}

func (r *Repository) CountUsersSince(t time.Time) (int64, error) {
	var c int64
	err := r.db.Model(&model.User{}).Where("last_login_at >= ?", t).Count(&c).Error
	return c, err
}

func (r *Repository) CountImages() (int64, error) {
	var c int64
	err := r.db.Model(&model.Image{}).Count(&c).Error
	return c, err
}

func (r *Repository) CountResults() (int64, error) {
	var c int64
	err := r.db.Model(&model.RecognitionResult{}).Count(&c).Error
	return c, err
}

func (r *Repository) CountNotes() (int64, error) {
	var c int64
	err := r.db.Model(&model.FieldNote{}).Count(&c).Error
	return c, err
}

func (r *Repository) CountFeedback() (int64, error) {
	var c int64
	err := r.db.Model(&model.UserFeedback{}).Count(&c).Error
	return c, err
}

func (r *Repository) CountMembershipPending() (int64, error) {
	var c int64
	err := r.db.Model(&model.MembershipRequest{}).Where("status = ?", "pending").Count(&c).Error
	return c, err
}

func (r *Repository) CountNotesByLabelStatus(status string) (int64, error) {
	var c int64
	query := r.db.Model(&model.FieldNote{})
	if status != "" {
		if status == "pending" {
			query = query.Where("(label_status = ? OR label_status = '')", status)
		} else {
			query = query.Where("label_status = ?", status)
		}
	}
	err := query.Count(&c).Error
	return c, err
}

func (r *Repository) CountRealUsers() (int64, error) {
	var c int64
	err := r.db.Model(&model.User{}).
		Where("status <> ? AND email NOT LIKE ?", "guest", "device:%").
		Count(&c).Error
	return c, err
}

// Label queue
func (r *Repository) ListLabelNotes(limit, offset int, status, category, cropType string) ([]model.FieldNote, error) {
	var items []model.FieldNote
	query := r.db.Model(&model.FieldNote{})
	if status != "" {
		if status == "pending" {
			query = query.Where("(label_status = ? OR label_status = '')", status)
		} else {
			query = query.Where("label_status = ?", status)
		}
	}
	if category != "" {
		query = query.Where("category = ?", category)
	}
	if cropType != "" {
		query = query.Where("crop_type = ?", cropType)
	}
	err := query.Order("created_at DESC").Limit(limit).Offset(offset).Find(&items).Error
	return items, err
}

func (r *Repository) UpdateLabelNote(noteID uint, fields map[string]interface{}) error {
	return r.db.Model(&model.FieldNote{}).Where("id = ?", noteID).Updates(fields).Error
}

// Evaluation
func (r *Repository) ListApprovedLabels(limit, offset int, since *time.Time) ([]model.FieldNote, error) {
	var items []model.FieldNote
	query := r.db.Model(&model.FieldNote{}).Where("label_status = ?", "approved")
	if since != nil {
		query = query.Where("created_at >= ?", *since)
	}
	err := query.Order("created_at DESC").Limit(limit).Offset(offset).Find(&items).Error
	return items, err
}

// Export helpers
func (r *Repository) ListUsersAll(limit, offset int, start, end *time.Time) ([]model.User, error) {
	var items []model.User
	query := r.db.Model(&model.User{})
	if start != nil {
		query = query.Where("created_at >= ?", *start)
	}
	if end != nil {
		query = query.Where("created_at < ?", *end)
	}
	err := query.Order("created_at DESC").Limit(limit).Offset(offset).Find(&items).Error
	return items, err
}

func (r *Repository) ListNotesAll(limit, offset int, start, end *time.Time) ([]model.FieldNote, error) {
	var items []model.FieldNote
	query := r.db.Model(&model.FieldNote{})
	if start != nil {
		query = query.Where("created_at >= ?", *start)
	}
	if end != nil {
		query = query.Where("created_at < ?", *end)
	}
	err := query.Order("created_at DESC").Limit(limit).Offset(offset).Find(&items).Error
	return items, err
}

func (r *Repository) ListFeedbackAll(limit, offset int, start, end *time.Time) ([]model.UserFeedback, error) {
	var items []model.UserFeedback
	query := r.db.Model(&model.UserFeedback{})
	if start != nil {
		query = query.Where("created_at >= ?", *start)
	}
	if end != nil {
		query = query.Where("created_at < ?", *end)
	}
	err := query.Order("created_at DESC").Limit(limit).Offset(offset).Find(&items).Error
	return items, err
}
