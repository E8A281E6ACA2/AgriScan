package service

import (
	"agri-scan/internal/model"
	"encoding/csv"
	"fmt"
	"io"
	"strconv"
	"time"
)

type AdminStats struct {
	UsersTotal        int64 `json:"users_total"`
	UsersActive7d     int64 `json:"users_active_7d"`
	ImagesTotal       int64 `json:"images_total"`
	ResultsTotal      int64 `json:"results_total"`
	NotesTotal        int64 `json:"notes_total"`
	FeedbackTotal     int64 `json:"feedback_total"`
	MembershipPending int64 `json:"membership_pending"`
	LabelPending      int64 `json:"label_pending"`
	LabelApproved     int64 `json:"label_approved"`
}

type EvalSummary struct {
	Total       int64   `json:"total"`
	Correct     int64   `json:"correct"`
	Accuracy    float64 `json:"accuracy"`
	TotalByCrop int64   `json:"total_by_crop"`
}

func (s *Service) GetAdminStats() (AdminStats, error) {
	var stats AdminStats
	var err error
	if stats.UsersTotal, err = s.repo.CountUsers(); err != nil {
		return stats, err
	}
	since := time.Now().AddDate(0, 0, -7)
	if stats.UsersActive7d, err = s.repo.CountUsersSince(since); err != nil {
		return stats, err
	}
	if stats.ImagesTotal, err = s.repo.CountImages(); err != nil {
		return stats, err
	}
	if stats.ResultsTotal, err = s.repo.CountResults(); err != nil {
		return stats, err
	}
	if stats.NotesTotal, err = s.repo.CountNotes(); err != nil {
		return stats, err
	}
	if stats.FeedbackTotal, err = s.repo.CountFeedback(); err != nil {
		return stats, err
	}
	if stats.MembershipPending, err = s.repo.CountMembershipPending(); err != nil {
		return stats, err
	}
	if stats.LabelPending, err = s.repo.CountNotesByLabelStatus("pending"); err != nil {
		return stats, err
	}
	if stats.LabelApproved, err = s.repo.CountNotesByLabelStatus("approved"); err != nil {
		return stats, err
	}
	return stats, nil
}

func (s *Service) RecordAdminAudit(action, targetType string, targetID uint, detail, ip string) {
	_ = s.repo.CreateAdminAuditLog(&model.AdminAuditLog{
		Action:     action,
		TargetType: targetType,
		TargetID:   targetID,
		Detail:     detail,
		IP:         ip,
	})
}

func (s *Service) ListAdminAuditLogs(limit, offset int, action string) ([]model.AdminAuditLog, error) {
	return s.repo.ListAdminAuditLogs(limit, offset, action)
}

func (s *Service) ListLabelNotes(limit, offset int, status, category, cropType string) ([]model.FieldNote, error) {
	return s.repo.ListLabelNotes(limit, offset, status, category, cropType)
}

func (s *Service) UpdateLabelNote(noteID uint, category, cropType string, tags []string, note string) error {
	fields := map[string]interface{}{
		"label_status":    "labeled",
		"label_category":  category,
		"label_crop_type": cropType,
		"label_tags":      joinTags(tags),
		"label_note":      note,
	}
	return s.repo.UpdateLabelNote(noteID, fields)
}

func (s *Service) ReviewLabelNote(noteID uint, status, reviewer string) error {
	if status != "approved" && status != "rejected" {
		return fmt.Errorf("invalid status")
	}
	now := time.Now()
	fields := map[string]interface{}{
		"label_status": status,
		"reviewed_by":  reviewer,
		"reviewed_at":  &now,
	}
	return s.repo.UpdateLabelNote(noteID, fields)
}

func (s *Service) GetEvalSummary(days int) (EvalSummary, error) {
	if days <= 0 {
		days = 30
	}
	since := time.Now().AddDate(0, 0, -days)
	limit := 1000
	offset := 0
	var total int64
	var correct int64
	for {
		items, err := s.repo.ListApprovedLabels(limit, offset, &since)
		if err != nil {
			return EvalSummary{}, err
		}
		if len(items) == 0 {
			break
		}
		for _, n := range items {
			if n.LabelCropType == "" || n.CropType == "" {
				continue
			}
			total++
			if n.LabelCropType == n.CropType {
				correct++
			}
		}
		offset += len(items)
	}
	acc := 0.0
	if total > 0 {
		acc = float64(correct) / float64(total)
	}
	return EvalSummary{Total: total, Correct: correct, Accuracy: acc, TotalByCrop: total}, nil
}

func (s *Service) ExportAdminUsersCSV(w io.Writer, start, end *time.Time) error {
	writer := csv.NewWriter(w)
	defer writer.Flush()
	_ = writer.Write([]string{"id", "email", "plan", "status", "quota_total", "quota_used", "ad_credits", "created_at"})
	limit := 1000
	offset := 0
	for {
		items, err := s.repo.ListUsersAll(limit, offset, start, end)
		if err != nil {
			return err
		}
		if len(items) == 0 {
			break
		}
		for _, u := range items {
			_ = writer.Write([]string{
				strconv.FormatUint(uint64(u.ID), 10),
				u.Email,
				u.Plan,
				u.Status,
				strconv.Itoa(u.QuotaTotal),
				strconv.Itoa(u.QuotaUsed),
				strconv.Itoa(u.AdCredits),
				u.CreatedAt.Format("2006-01-02 15:04:05"),
			})
		}
		offset += len(items)
	}
	return writer.Error()
}

func (s *Service) ExportAdminNotesCSV(w io.Writer, start, end *time.Time) error {
	writer := csv.NewWriter(w)
	defer writer.Flush()
	_ = writer.Write([]string{"id", "user_id", "image_id", "result_id", "category", "crop_type", "label_status", "label_crop_type", "label_category", "label_tags", "created_at"})
	limit := 1000
	offset := 0
	for {
		items, err := s.repo.ListNotesAll(limit, offset, start, end)
		if err != nil {
			return err
		}
		if len(items) == 0 {
			break
		}
		for _, n := range items {
			resultID := ""
			if n.ResultID != nil {
				resultID = strconv.FormatUint(uint64(*n.ResultID), 10)
			}
			_ = writer.Write([]string{
				strconv.FormatUint(uint64(n.ID), 10),
				strconv.FormatUint(uint64(n.UserID), 10),
				strconv.FormatUint(uint64(n.ImageID), 10),
				resultID,
				n.Category,
				n.CropType,
				n.LabelStatus,
				n.LabelCropType,
				n.LabelCategory,
				n.LabelTags,
				n.CreatedAt.Format("2006-01-02 15:04:05"),
			})
		}
		offset += len(items)
	}
	return writer.Error()
}

func (s *Service) ExportAdminFeedbackCSV(w io.Writer, start, end *time.Time) error {
	writer := csv.NewWriter(w)
	defer writer.Flush()
	_ = writer.Write([]string{"id", "result_id", "is_correct", "corrected_type", "category", "tags", "created_at"})
	limit := 1000
	offset := 0
	for {
		items, err := s.repo.ListFeedbackAll(limit, offset, start, end)
		if err != nil {
			return err
		}
		if len(items) == 0 {
			break
		}
		for _, f := range items {
			_ = writer.Write([]string{
				strconv.FormatUint(uint64(f.ID), 10),
				strconv.FormatUint(uint64(f.ResultID), 10),
				strconv.FormatBool(f.IsCorrect),
				f.CorrectedType,
				f.Category,
				f.Tags,
				f.CreatedAt.Format("2006-01-02 15:04:05"),
			})
		}
		offset += len(items)
	}
	return writer.Error()
}

func joinTags(tags []string) string {
	out := make([]string, 0, len(tags))
	seen := map[string]bool{}
	for _, t := range tags {
		if t == "" || seen[t] {
			continue
		}
		seen[t] = true
		out = append(out, t)
	}
	return stringsJoin(out)
}

func stringsJoin(tags []string) string {
	if len(tags) == 0 {
		return ""
	}
	out := tags[0]
	for i := 1; i < len(tags); i++ {
		out += "," + tags[i]
	}
	return out
}
