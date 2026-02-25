package service

import (
	"agri-scan/internal/model"
	"encoding/csv"
	"encoding/json"
	"fmt"
	"io"
	"sort"
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
	Total      int64           `json:"total"`
	Correct    int64           `json:"correct"`
	Accuracy   float64         `json:"accuracy"`
	ByCrop     []EvalCropStat  `json:"by_crop"`
	Confusions []EvalConfusion `json:"confusions"`
}

type EvalCropStat struct {
	CropType string  `json:"crop_type"`
	Total    int64   `json:"total"`
	Correct  int64   `json:"correct"`
	Accuracy float64 `json:"accuracy"`
}

type EvalConfusion struct {
	Actual    string `json:"actual"`
	Predicted string `json:"predicted"`
	Count     int64  `json:"count"`
}

type EvalDatasetRow struct {
	ID            uint    `json:"id"`
	UserID        uint    `json:"user_id"`
	ImageID       uint    `json:"image_id"`
	ResultID      *uint   `json:"result_id"`
	ImageURL      string  `json:"image_url"`
	Category      string  `json:"category"`
	CropType      string  `json:"crop_type"`
	Confidence    float64 `json:"confidence"`
	LabelCategory string  `json:"label_category"`
	LabelCropType string  `json:"label_crop_type"`
	LabelTags     string  `json:"label_tags"`
	LabelNote     string  `json:"label_note"`
	CreatedAt     string  `json:"created_at"`
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
	if !s.getSettingBool(settingLabelEnabled, false) {
		return []model.FieldNote{}, nil
	}
	return s.repo.ListLabelNotes(limit, offset, status, category, cropType)
}

func (s *Service) UpdateLabelNote(noteID uint, category, cropType string, tags []string, note string) error {
	if !s.getSettingBool(settingLabelEnabled, false) {
		return fmt.Errorf("label flow disabled")
	}
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
	if !s.getSettingBool(settingLabelEnabled, false) {
		return fmt.Errorf("label flow disabled")
	}
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
	cropStats := map[string]*EvalCropStat{}
	confusions := map[string]map[string]int64{}
	for {
		items, err := s.repo.ListApprovedLabels(limit, offset, &since, nil)
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
			stat, ok := cropStats[n.LabelCropType]
			if !ok {
				stat = &EvalCropStat{CropType: n.LabelCropType}
				cropStats[n.LabelCropType] = stat
			}
			stat.Total++
			if n.LabelCropType == n.CropType {
				correct++
				stat.Correct++
			}
			if _, ok := confusions[n.LabelCropType]; !ok {
				confusions[n.LabelCropType] = map[string]int64{}
			}
			confusions[n.LabelCropType][n.CropType]++
		}
		offset += len(items)
	}
	acc := 0.0
	if total > 0 {
		acc = float64(correct) / float64(total)
	}
	byCrop := make([]EvalCropStat, 0, len(cropStats))
	for _, stat := range cropStats {
		if stat.Total > 0 {
			stat.Accuracy = float64(stat.Correct) / float64(stat.Total)
		}
		byCrop = append(byCrop, *stat)
	}
	sort.Slice(byCrop, func(i, j int) bool {
		if byCrop[i].Total == byCrop[j].Total {
			return byCrop[i].CropType < byCrop[j].CropType
		}
		return byCrop[i].Total > byCrop[j].Total
	})
	confusionList := make([]EvalConfusion, 0, 32)
	for actual, preds := range confusions {
		for predicted, count := range preds {
			if actual == predicted {
				continue
			}
			confusionList = append(confusionList, EvalConfusion{Actual: actual, Predicted: predicted, Count: count})
		}
	}
	sort.Slice(confusionList, func(i, j int) bool {
		if confusionList[i].Count == confusionList[j].Count {
			if confusionList[i].Actual == confusionList[j].Actual {
				return confusionList[i].Predicted < confusionList[j].Predicted
			}
			return confusionList[i].Actual < confusionList[j].Actual
		}
		return confusionList[i].Count > confusionList[j].Count
	})
	if len(confusionList) > 20 {
		confusionList = confusionList[:20]
	}
	return EvalSummary{Total: total, Correct: correct, Accuracy: acc, ByCrop: byCrop, Confusions: confusionList}, nil
}

func (s *Service) ExportEvalDatasetCSV(w io.Writer, start, end *time.Time) error {
	writer := csv.NewWriter(w)
	defer writer.Flush()
	_ = writer.Write([]string{"id", "user_id", "image_id", "result_id", "image_url", "category", "crop_type", "confidence", "label_category", "label_crop_type", "label_tags", "label_note", "created_at"})
	limit := 1000
	offset := 0
	for {
		items, err := s.repo.ListApprovedLabels(limit, offset, start, end)
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
				n.ImageURL,
				n.Category,
				n.CropType,
				strconv.FormatFloat(n.Confidence, 'f', 4, 64),
				n.LabelCategory,
				n.LabelCropType,
				n.LabelTags,
				n.LabelNote,
				n.CreatedAt.Format("2006-01-02 15:04:05"),
			})
		}
		offset += len(items)
	}
	return writer.Error()
}

func (s *Service) ExportEvalDatasetJSON(w io.Writer, start, end *time.Time) error {
	encoder := json.NewEncoder(w)
	_, err := io.WriteString(w, "[")
	if err != nil {
		return err
	}
	limit := 1000
	offset := 0
	first := true
	for {
		items, err := s.repo.ListApprovedLabels(limit, offset, start, end)
		if err != nil {
			return err
		}
		if len(items) == 0 {
			break
		}
		for _, n := range items {
			row := EvalDatasetRow{
				ID:            n.ID,
				UserID:        n.UserID,
				ImageID:       n.ImageID,
				ResultID:      n.ResultID,
				ImageURL:      n.ImageURL,
				Category:      n.Category,
				CropType:      n.CropType,
				Confidence:    n.Confidence,
				LabelCategory: n.LabelCategory,
				LabelCropType: n.LabelCropType,
				LabelTags:     n.LabelTags,
				LabelNote:     n.LabelNote,
				CreatedAt:     n.CreatedAt.Format("2006-01-02 15:04:05"),
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
