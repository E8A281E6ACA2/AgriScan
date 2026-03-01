package service

import (
	"agri-scan/internal/model"
	"agri-scan/internal/repository"
	"encoding/csv"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"sort"
	"strconv"
	"strings"
	"time"

	"gorm.io/gorm"
)

type AdminStats struct {
	UsersTotal        int64 `json:"users_total"`
	UsersReal         int64 `json:"users_real"`
	UsersGuest        int64 `json:"users_guest"`
	UsersActive7d     int64 `json:"users_active_7d"`
	ImagesTotal       int64 `json:"images_total"`
	ResultsTotal      int64 `json:"results_total"`
	NotesTotal        int64 `json:"notes_total"`
	FeedbackTotal     int64 `json:"feedback_total"`
	MembershipPending int64 `json:"membership_pending"`
	LabelPending      int64 `json:"label_pending"`
	LabelApproved     int64 `json:"label_approved"`
}

type AdminMetrics struct {
	ResultsByDay           []DayCount   `json:"results_by_day"`
	UsersByPlan            []NamedCount `json:"users_by_plan"`
	UsersByStatus          []NamedCount `json:"users_by_status"`
	ResultsByProvider      []NamedCount `json:"results_by_provider"`
	ResultsByCrop          []NamedCount `json:"results_by_crop"`
	FeedbackTotal          int64        `json:"feedback_total"`
	FeedbackCorrect        int64        `json:"feedback_correct"`
	FeedbackAccuracy       float64      `json:"feedback_accuracy"`
	LowConfidenceTotal     int64        `json:"low_confidence_total"`
	LowConfidenceRatio     float64      `json:"low_confidence_ratio"`
	LowConfidenceThreshold float64      `json:"low_confidence_threshold"`
}

type DayCount struct {
	Day   string `json:"day"`
	Count int64  `json:"count"`
}

type NamedCount struct {
	Name  string `json:"name"`
	Count int64  `json:"count"`
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

type EvalRunView struct {
	ID         uint            `json:"id"`
	CreatedAt  string          `json:"created_at"`
	Days       int             `json:"days"`
	Total      int64           `json:"total"`
	Correct    int64           `json:"correct"`
	Accuracy   float64         `json:"accuracy"`
	ByCrop     []EvalCropStat  `json:"by_crop"`
	Confusions []EvalConfusion `json:"confusions"`
}

type EvalSetView struct {
	ID          uint   `json:"id"`
	CreatedAt   string `json:"created_at"`
	Name        string `json:"name"`
	Description string `json:"description"`
	Source      string `json:"source"`
	Size        int    `json:"size"`
}

type EvalSetRunView struct {
	ID         uint            `json:"id"`
	CreatedAt  string          `json:"created_at"`
	Total      int64           `json:"total"`
	Correct    int64           `json:"correct"`
	Accuracy   float64         `json:"accuracy"`
	ByCrop     []EvalCropStat  `json:"by_crop"`
	Confusions []EvalConfusion `json:"confusions"`
	BaselineID *uint           `json:"baseline_id"`
	DeltaAcc   float64         `json:"delta_acc"`
}

type QCSampleView struct {
	ID         uint    `json:"id"`
	ResultID   uint    `json:"result_id"`
	ImageID    uint    `json:"image_id"`
	ImageURL   string  `json:"image_url"`
	CropType   string  `json:"crop_type"`
	Confidence float64 `json:"confidence"`
	Provider   string  `json:"provider"`
	Reason     string  `json:"reason"`
	Status     string  `json:"status"`
	Reviewer   string  `json:"reviewer"`
	ReviewedAt *string `json:"reviewed_at"`
	ReviewNote string  `json:"review_note"`
	CreatedAt  string  `json:"created_at"`
}

type QCGenerateResult struct {
	Requested int `json:"requested"`
	Created   int `json:"created"`
}

type QCReviewUpdate struct {
	Status     string `json:"status"`
	Reviewer   string `json:"reviewer"`
	ReviewNote string `json:"review_note"`
}

type RecognizeResultView struct {
	ResultID   uint    `json:"result_id"`
	ImageID    uint    `json:"image_id"`
	ImageURL   string  `json:"image_url"`
	CropType   string  `json:"crop_type"`
	Confidence float64 `json:"confidence"`
	Provider   string  `json:"provider"`
	CreatedAt  string  `json:"created_at"`
}

func (s *Service) GetAdminStats() (AdminStats, error) {
	var stats AdminStats
	var err error
	if stats.UsersTotal, err = s.repo.CountUsers(); err != nil {
		return stats, err
	}
	if stats.UsersReal, err = s.repo.CountRealUsers(); err != nil {
		return stats, err
	}
	if stats.UsersGuest, err = s.repo.CountUsersByStatus("guest"); err != nil {
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

func (s *Service) GetAdminMetrics(days int) (AdminMetrics, error) {
	if days <= 0 {
		days = 30
	}
	since := time.Now().AddDate(0, 0, -days+1)
	lowConfidenceThreshold := 0.5
	db := s.repo.DB()
	metrics := AdminMetrics{}

	var daily []DayCount
	if err := db.Model(&model.RecognitionResult{}).
		Select("to_char(created_at, 'YYYY-MM-DD') as day, count(*) as count").
		Where("created_at >= ?", since).
		Group("day").
		Order("day").
		Scan(&daily).Error; err != nil {
		return metrics, err
	}
	dayMap := map[string]int64{}
	for _, d := range daily {
		dayMap[d.Day] = d.Count
	}
	resultsByDay := make([]DayCount, 0, days)
	for i := 0; i < days; i++ {
		day := since.AddDate(0, 0, i).Format("2006-01-02")
		resultsByDay = append(resultsByDay, DayCount{Day: day, Count: dayMap[day]})
	}
	metrics.ResultsByDay = resultsByDay

	if err := db.Model(&model.User{}).
		Select("plan as name, count(*) as count").
		Group("plan").
		Order("count desc").
		Scan(&metrics.UsersByPlan).Error; err != nil {
		return metrics, err
	}
	if err := db.Model(&model.User{}).
		Select("status as name, count(*) as count").
		Group("status").
		Order("count desc").
		Scan(&metrics.UsersByStatus).Error; err != nil {
		return metrics, err
	}
	if err := db.Model(&model.RecognitionResult{}).
		Select("provider as name, count(*) as count").
		Where("provider <> ''").
		Group("provider").
		Order("count desc").
		Limit(10).
		Scan(&metrics.ResultsByProvider).Error; err != nil {
		return metrics, err
	}
	if err := db.Model(&model.RecognitionResult{}).
		Select("crop_type as name, count(*) as count").
		Where("crop_type <> ''").
		Group("crop_type").
		Order("count desc").
		Limit(10).
		Scan(&metrics.ResultsByCrop).Error; err != nil {
		return metrics, err
	}
	if err := db.Model(&model.UserFeedback{}).Count(&metrics.FeedbackTotal).Error; err != nil {
		return metrics, err
	}
	if err := db.Model(&model.UserFeedback{}).Where("is_correct = ?", true).Count(&metrics.FeedbackCorrect).Error; err != nil {
		return metrics, err
	}
	if metrics.FeedbackTotal > 0 {
		metrics.FeedbackAccuracy = float64(metrics.FeedbackCorrect) / float64(metrics.FeedbackTotal)
	}
	var resultsTotal int64
	if err := db.Model(&model.RecognitionResult{}).
		Where("created_at >= ?", since).
		Count(&resultsTotal).Error; err != nil {
		return metrics, err
	}
	if err := db.Model(&model.RecognitionResult{}).
		Where("created_at >= ? AND confidence >= 0 AND confidence < ?", since, lowConfidenceThreshold).
		Count(&metrics.LowConfidenceTotal).Error; err != nil {
		return metrics, err
	}
	metrics.LowConfidenceThreshold = lowConfidenceThreshold
	if resultsTotal > 0 {
		metrics.LowConfidenceRatio = float64(metrics.LowConfidenceTotal) / float64(resultsTotal)
	}
	return metrics, nil
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

func (s *Service) ListAdminAuditLogs(limit, offset int, action, targetType string, start, end *time.Time) ([]model.AdminAuditLog, error) {
	return s.repo.ListAdminAuditLogs(limit, offset, action, targetType, start, end)
}

func (s *Service) ExportAdminAuditLogsCSV(w io.Writer, start, end *time.Time, action, targetType string) error {
	writer := csv.NewWriter(w)
	defer writer.Flush()
	_ = writer.Write([]string{"id", "action", "target_type", "target_id", "detail", "ip", "created_at"})
	limit := 1000
	offset := 0
	for {
		items, err := s.repo.ListAdminAuditLogs(limit, offset, action, targetType, start, end)
		if err != nil {
			return err
		}
		if len(items) == 0 {
			break
		}
		for _, a := range items {
			_ = writer.Write([]string{
				strconv.FormatUint(uint64(a.ID), 10),
				a.Action,
				a.TargetType,
				strconv.FormatUint(uint64(a.TargetID), 10),
				a.Detail,
				a.IP,
				a.CreatedAt.Format("2006-01-02 15:04:05"),
			})
		}
		offset += len(items)
	}
	return writer.Error()
}

func (s *Service) ExportAdminAuditLogsJSON(w io.Writer, start, end *time.Time, action, targetType string) error {
	encoder := json.NewEncoder(w)
	_, err := io.WriteString(w, "[")
	if err != nil {
		return err
	}
	limit := 1000
	offset := 0
	first := true
	for {
		items, err := s.repo.ListAdminAuditLogs(limit, offset, action, targetType, start, end)
		if err != nil {
			return err
		}
		if len(items) == 0 {
			break
		}
		for _, a := range items {
			if !first {
				if _, err := io.WriteString(w, ","); err != nil {
					return err
				}
			}
			if err := encoder.Encode(a); err != nil {
				return err
			}
			first = false
		}
		offset += len(items)
	}
	_, err = io.WriteString(w, "]")
	return err
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

func (s *Service) BatchApproveLabelNotes(status, category, cropType, reviewer string, start, end *time.Time) (int64, error) {
	if !s.getSettingBool(settingLabelEnabled, false) {
		return 0, fmt.Errorf("label flow disabled")
	}
	if strings.TrimSpace(reviewer) == "" {
		reviewer = "admin"
	}
	now := time.Now()
	return s.repo.BatchApproveLabelNotes(status, category, cropType, start, end, reviewer, now)
}

func (s *Service) LabelFromQCSample(sampleID uint, category, cropType string, tags []string, note string, approved bool, reviewer string) (uint, string, error) {
	if !s.getSettingBool(settingLabelEnabled, false) {
		return 0, "", fmt.Errorf("label flow disabled")
	}
	if sampleID == 0 {
		return 0, "", fmt.Errorf("invalid sample id")
	}
	sample, err := s.repo.GetQCSampleByID(sampleID)
	if err != nil {
		return 0, "", err
	}
	var existing model.FieldNote
	err = s.repo.DB().Where("result_id = ?", sample.ResultID).Order("id DESC").First(&existing).Error
	noteID := uint(0)
	if err == nil {
		noteID = existing.ID
	} else if errors.Is(err, gorm.ErrRecordNotFound) {
		res, err := s.repo.GetResultByID(sample.ResultID)
		if err != nil {
			return 0, "", err
		}
		img, err := s.repo.GetImageByID(sample.ImageID)
		if err != nil {
			return 0, "", err
		}
		cat := strings.TrimSpace(category)
		created, err := s.CreateNote(img.UserID, img.ID, &res.ID, "", cat, nil)
		if err != nil {
			return 0, "", err
		}
		noteID = created.ID
	} else {
		return 0, "", err
	}
	status := "labeled"
	fields := map[string]interface{}{
		"label_status":    status,
		"label_category":  strings.TrimSpace(category),
		"label_crop_type": strings.TrimSpace(cropType),
		"label_tags":      joinTags(tags),
		"label_note":      strings.TrimSpace(note),
	}
	if approved {
		status = "approved"
		fields["label_status"] = status
		now := time.Now()
		if strings.TrimSpace(reviewer) == "" {
			reviewer = "admin"
		}
		fields["reviewed_by"] = reviewer
		fields["reviewed_at"] = &now
	}
	if err := s.repo.UpdateLabelNote(noteID, fields); err != nil {
		return 0, "", err
	}
	return noteID, status, nil
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

func (s *Service) CreateEvalRun(days int) (EvalRunView, error) {
	if days <= 0 {
		days = 30
	}
	summary, err := s.GetEvalSummary(days)
	if err != nil {
		return EvalRunView{}, err
	}
	byCrop, _ := json.Marshal(summary.ByCrop)
	confusions, _ := json.Marshal(summary.Confusions)
	run := &model.EvalRun{
		Days:       days,
		Total:      summary.Total,
		Correct:    summary.Correct,
		Accuracy:   summary.Accuracy,
		ByCrop:     string(byCrop),
		Confusions: string(confusions),
	}
	if err := s.repo.CreateEvalRun(run); err != nil {
		return EvalRunView{}, err
	}
	return EvalRunView{
		ID:         run.ID,
		CreatedAt:  run.CreatedAt.Format("2006-01-02 15:04:05"),
		Days:       run.Days,
		Total:      run.Total,
		Correct:    run.Correct,
		Accuracy:   run.Accuracy,
		ByCrop:     summary.ByCrop,
		Confusions: summary.Confusions,
	}, nil
}

func (s *Service) ListEvalRuns(limit, offset int) ([]EvalRunView, error) {
	if limit <= 0 {
		limit = 20
	}
	items, err := s.repo.ListEvalRuns(limit, offset)
	if err != nil {
		return nil, err
	}
	out := make([]EvalRunView, 0, len(items))
	for _, item := range items {
		var byCrop []EvalCropStat
		var confusions []EvalConfusion
		_ = json.Unmarshal([]byte(item.ByCrop), &byCrop)
		_ = json.Unmarshal([]byte(item.Confusions), &confusions)
		out = append(out, EvalRunView{
			ID:         item.ID,
			CreatedAt:  item.CreatedAt.Format("2006-01-02 15:04:05"),
			Days:       item.Days,
			Total:      item.Total,
			Correct:    item.Correct,
			Accuracy:   item.Accuracy,
			ByCrop:     byCrop,
			Confusions: confusions,
		})
	}
	return out, nil
}

func (s *Service) GenerateQCSamples(days, lowLimit, randomLimit, feedbackLimit int, lowThreshold float64) (QCGenerateResult, error) {
	if days <= 0 {
		days = 30
	}
	if lowThreshold <= 0 {
		lowThreshold = 0.5
	}
	total := lowLimit + randomLimit + feedbackLimit
	if total <= 0 {
		lowLimit = 50
		randomLimit = 30
		feedbackLimit = 20
		total = lowLimit + randomLimit + feedbackLimit
	}
	since := time.Now().AddDate(0, 0, -days+1)
	db := s.repo.DB()

	seen := map[uint]bool{}
	samples := make([]model.QCSample, 0, total*2)
	addSamples := func(items []repository.QCResultRow, reason string) {
		for _, c := range items {
			if c.ResultID == 0 || seen[c.ResultID] {
				continue
			}
			seen[c.ResultID] = true
			samples = append(samples, model.QCSample{
				ResultID:   c.ResultID,
				ImageID:    c.ImageID,
				ImageURL:   c.ImageURL,
				CropType:   c.CropType,
				Confidence: c.Confidence,
				Provider:   c.Provider,
				Reason:     reason,
				Status:     "pending",
			})
		}
	}

	if lowLimit > 0 {
		var low []repository.QCResultRow
		err := db.Model(&model.RecognitionResult{}).
			Select("recognition_results.id as result_id, recognition_results.image_id as image_id, recognition_results.crop_type, recognition_results.confidence, recognition_results.provider, images.original_url as image_url").
			Joins("JOIN images ON images.id = recognition_results.image_id").
			Where("recognition_results.created_at >= ? AND recognition_results.confidence >= 0 AND recognition_results.confidence < ?", since, lowThreshold).
			Order("recognition_results.created_at DESC").
			Limit(lowLimit).
			Scan(&low).Error
		if err != nil {
			return QCGenerateResult{}, err
		}
		addSamples(low, "low_confidence")
	}
	if feedbackLimit > 0 {
		var fb []repository.QCResultRow
		err := db.Model(&model.UserFeedback{}).
			Select("recognition_results.id as result_id, recognition_results.image_id as image_id, recognition_results.crop_type, recognition_results.confidence, recognition_results.provider, images.original_url as image_url").
			Joins("JOIN recognition_results ON recognition_results.id = user_feedbacks.result_id").
			Joins("JOIN images ON images.id = recognition_results.image_id").
			Where("user_feedbacks.is_correct = ? AND recognition_results.created_at >= ?", false, since).
			Order("user_feedbacks.created_at DESC").
			Limit(feedbackLimit).
			Scan(&fb).Error
		if err != nil {
			return QCGenerateResult{}, err
		}
		addSamples(fb, "feedback_incorrect")
	}
	if randomLimit > 0 {
		var rnd []repository.QCResultRow
		err := db.Model(&model.RecognitionResult{}).
			Select("recognition_results.id as result_id, recognition_results.image_id as image_id, recognition_results.crop_type, recognition_results.confidence, recognition_results.provider, images.original_url as image_url").
			Joins("JOIN images ON images.id = recognition_results.image_id").
			Where("recognition_results.created_at >= ?", since).
			Order("RANDOM()").
			Limit(randomLimit).
			Scan(&rnd).Error
		if err != nil {
			return QCGenerateResult{}, err
		}
		addSamples(rnd, "random")
	}
	created, err := s.repo.CreateQCSamples(samples)
	if err != nil {
		return QCGenerateResult{}, err
	}
	return QCGenerateResult{Requested: total, Created: int(created)}, nil
}

func (s *Service) ListQCSamples(limit, offset int, status, reason string) ([]QCSampleView, error) {
	if limit <= 0 {
		limit = 20
	}
	items, err := s.repo.ListQCSamples(limit, offset, status, reason)
	if err != nil {
		return nil, err
	}
	out := make([]QCSampleView, 0, len(items))
	for _, item := range items {
		out = append(out, buildQCSampleView(item))
	}
	return out, nil
}

func (s *Service) ReviewQCSample(id uint, update QCReviewUpdate) error {
	status := strings.TrimSpace(update.Status)
	if status != "keep" && status != "discard" {
		return fmt.Errorf("invalid status")
	}
	reviewer := strings.TrimSpace(update.Reviewer)
	if reviewer == "" {
		reviewer = "admin"
	}
	now := time.Now()
	fields := map[string]interface{}{
		"status":      status,
		"reviewer":    reviewer,
		"reviewed_at": &now,
		"review_note": strings.TrimSpace(update.ReviewNote),
	}
	return s.repo.UpdateQCSampleStatus(id, fields)
}

func (s *Service) BatchReviewQCSamples(ids []uint, update QCReviewUpdate) (int64, error) {
	status := strings.TrimSpace(update.Status)
	if status != "keep" && status != "discard" {
		return 0, fmt.Errorf("invalid status")
	}
	reviewer := strings.TrimSpace(update.Reviewer)
	if reviewer == "" {
		reviewer = "admin"
	}
	now := time.Now()
	fields := map[string]interface{}{
		"status":      status,
		"reviewer":    reviewer,
		"reviewed_at": &now,
		"review_note": strings.TrimSpace(update.ReviewNote),
	}
	return s.repo.UpdateQCSamplesStatus(ids, fields)
}

func (s *Service) ExportQCSamplesCSV(w io.Writer, start, end *time.Time, status, reason string) error {
	writer := csv.NewWriter(w)
	defer writer.Flush()
	_ = writer.Write([]string{"id", "result_id", "image_id", "image_url", "crop_type", "confidence", "provider", "reason", "status", "reviewer", "reviewed_at", "review_note", "created_at"})
	limit := 1000
	offset := 0
	for {
		items, err := s.repo.ListQCSamplesAll(limit, offset, status, reason, start, end)
		if err != nil {
			return err
		}
		if len(items) == 0 {
			break
		}
		for _, item := range items {
			reviewedAt := ""
			if item.ReviewedAt != nil {
				reviewedAt = item.ReviewedAt.Format("2006-01-02 15:04:05")
			}
			_ = writer.Write([]string{
				strconv.FormatUint(uint64(item.ID), 10),
				strconv.FormatUint(uint64(item.ResultID), 10),
				strconv.FormatUint(uint64(item.ImageID), 10),
				item.ImageURL,
				item.CropType,
				strconv.FormatFloat(item.Confidence, 'f', 4, 64),
				item.Provider,
				item.Reason,
				item.Status,
				item.Reviewer,
				reviewedAt,
				item.ReviewNote,
				item.CreatedAt.Format("2006-01-02 15:04:05"),
			})
		}
		offset += len(items)
	}
	return writer.Error()
}

func (s *Service) ExportQCSamplesJSON(w io.Writer, start, end *time.Time, status, reason string) error {
	encoder := json.NewEncoder(w)
	_, err := io.WriteString(w, "[")
	if err != nil {
		return err
	}
	limit := 1000
	offset := 0
	first := true
	for {
		items, err := s.repo.ListQCSamplesAll(limit, offset, status, reason, start, end)
		if err != nil {
			return err
		}
		if len(items) == 0 {
			break
		}
		for _, item := range items {
			view := buildQCSampleView(item)
			if !first {
				if _, err := io.WriteString(w, ","); err != nil {
					return err
				}
			}
			if err := encoder.Encode(view); err != nil {
				return err
			}
			first = false
		}
		offset += len(items)
	}
	_, err = io.WriteString(w, "]")
	return err
}

func buildQCSampleView(item model.QCSample) QCSampleView {
	var reviewedAt *string
	if item.ReviewedAt != nil {
		v := item.ReviewedAt.Format("2006-01-02 15:04:05")
		reviewedAt = &v
	}
	return QCSampleView{
		ID:         item.ID,
		ResultID:   item.ResultID,
		ImageID:    item.ImageID,
		ImageURL:   item.ImageURL,
		CropType:   item.CropType,
		Confidence: item.Confidence,
		Provider:   item.Provider,
		Reason:     item.Reason,
		Status:     item.Status,
		Reviewer:   item.Reviewer,
		ReviewedAt: reviewedAt,
		ReviewNote: item.ReviewNote,
		CreatedAt:  item.CreatedAt.Format("2006-01-02 15:04:05"),
	}
}

func (s *Service) CreateEvalSet(name, description string, days, limit int) (EvalSetView, error) {
	if days <= 0 {
		days = 30
	}
	if limit <= 0 {
		limit = 200
	}
	name = strings.TrimSpace(name)
	if name == "" {
		name = time.Now().Format("2006-01-02") + " eval set"
	}
	since := time.Now().AddDate(0, 0, -days+1)
	items, err := s.repo.ListApprovedLabels(limit, 0, &since, nil)
	if err != nil {
		return EvalSetView{}, err
	}
	set := &model.EvalSet{
		Name:        name,
		Description: strings.TrimSpace(description),
		Source:      "approved_labels",
		Size:        len(items),
		Filters:     fmt.Sprintf("{\"days\":%d,\"limit\":%d}", days, limit),
	}
	if err := s.repo.CreateEvalSet(set); err != nil {
		return EvalSetView{}, err
	}
	setItems := make([]model.EvalSetItem, 0, len(items))
	for _, n := range items {
		setItems = append(setItems, model.EvalSetItem{
			EvalSetID:     set.ID,
			NoteID:        n.ID,
			ResultID:      n.ResultID,
			ImageID:       n.ImageID,
			ImageURL:      n.ImageURL,
			CropTypePred:  n.CropType,
			LabelCropType: n.LabelCropType,
			LabelCategory: n.LabelCategory,
			LabelTags:     n.LabelTags,
			Provider:      n.Provider,
			Confidence:    n.Confidence,
		})
	}
	if err := s.repo.CreateEvalSetItems(setItems); err != nil {
		return EvalSetView{}, err
	}
	return EvalSetView{
		ID:          set.ID,
		CreatedAt:   set.CreatedAt.Format("2006-01-02 15:04:05"),
		Name:        set.Name,
		Description: set.Description,
		Source:      set.Source,
		Size:        set.Size,
	}, nil
}

func (s *Service) ListEvalSets(limit, offset int) ([]EvalSetView, error) {
	if limit <= 0 {
		limit = 20
	}
	items, err := s.repo.ListEvalSets(limit, offset)
	if err != nil {
		return nil, err
	}
	out := make([]EvalSetView, 0, len(items))
	for _, item := range items {
		out = append(out, EvalSetView{
			ID:          item.ID,
			CreatedAt:   item.CreatedAt.Format("2006-01-02 15:04:05"),
			Name:        item.Name,
			Description: item.Description,
			Source:      item.Source,
			Size:        item.Size,
		})
	}
	return out, nil
}

func (s *Service) RunEvalSet(setID uint, baselineID *uint) (EvalSetRunView, error) {
	items, err := s.repo.ListEvalSetItems(setID, 200000, 0)
	if err != nil {
		return EvalSetRunView{}, err
	}
	var total int64
	var correct int64
	cropStats := map[string]*EvalCropStat{}
	confusions := map[string]map[string]int64{}
	for _, it := range items {
		if it.LabelCropType == "" || it.CropTypePred == "" {
			continue
		}
		total++
		stat, ok := cropStats[it.LabelCropType]
		if !ok {
			stat = &EvalCropStat{CropType: it.LabelCropType}
			cropStats[it.LabelCropType] = stat
		}
		stat.Total++
		if it.LabelCropType == it.CropTypePred {
			correct++
			stat.Correct++
		}
		if _, ok := confusions[it.LabelCropType]; !ok {
			confusions[it.LabelCropType] = map[string]int64{}
		}
		confusions[it.LabelCropType][it.CropTypePred]++
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
	confusionList := make([]EvalConfusion, 0, 20)
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
	byCropJSON, _ := json.Marshal(byCrop)
	confJSON, _ := json.Marshal(confusionList)
	run := &model.EvalSetRun{
		EvalSetID:  setID,
		Total:      total,
		Correct:    correct,
		Accuracy:   acc,
		ByCrop:     string(byCropJSON),
		Confusions: string(confJSON),
		BaselineID: baselineID,
		DeltaAcc:   0,
	}
	if baselineID != nil {
		if base, err := s.repo.GetEvalSetRunByID(*baselineID); err == nil && base != nil {
			run.DeltaAcc = acc - base.Accuracy
		}
	}
	if err := s.repo.CreateEvalSetRun(run); err != nil {
		return EvalSetRunView{}, err
	}
	return EvalSetRunView{
		ID:         run.ID,
		CreatedAt:  run.CreatedAt.Format("2006-01-02 15:04:05"),
		Total:      run.Total,
		Correct:    run.Correct,
		Accuracy:   run.Accuracy,
		ByCrop:     byCrop,
		Confusions: confusionList,
		BaselineID: run.BaselineID,
		DeltaAcc:   run.DeltaAcc,
	}, nil
}

func (s *Service) ListEvalSetRuns(setID uint, limit, offset int) ([]EvalSetRunView, error) {
	if limit <= 0 {
		limit = 20
	}
	items, err := s.repo.ListEvalSetRuns(setID, limit, offset)
	if err != nil {
		return nil, err
	}
	out := make([]EvalSetRunView, 0, len(items))
	for _, item := range items {
		var byCrop []EvalCropStat
		var confusions []EvalConfusion
		_ = json.Unmarshal([]byte(item.ByCrop), &byCrop)
		_ = json.Unmarshal([]byte(item.Confusions), &confusions)
		out = append(out, EvalSetRunView{
			ID:         item.ID,
			CreatedAt:  item.CreatedAt.Format("2006-01-02 15:04:05"),
			Total:      item.Total,
			Correct:    item.Correct,
			Accuracy:   item.Accuracy,
			ByCrop:     byCrop,
			Confusions: confusions,
			BaselineID: item.BaselineID,
			DeltaAcc:   item.DeltaAcc,
		})
	}
	return out, nil
}

func (s *Service) ExportEvalSetCSV(w io.Writer, setID uint, start, end *time.Time) error {
	writer := csv.NewWriter(w)
	defer writer.Flush()
	_ = writer.Write([]string{"id", "note_id", "result_id", "image_id", "image_url", "crop_type_pred", "label_crop_type", "label_category", "label_tags", "provider", "confidence", "created_at"})
	limit := 1000
	offset := 0
	for {
		items, err := s.repo.ListEvalSetItemsAll(setID, limit, offset, start, end)
		if err != nil {
			return err
		}
		if len(items) == 0 {
			break
		}
		for _, it := range items {
			resultID := ""
			if it.ResultID != nil {
				resultID = strconv.FormatUint(uint64(*it.ResultID), 10)
			}
			_ = writer.Write([]string{
				strconv.FormatUint(uint64(it.ID), 10),
				strconv.FormatUint(uint64(it.NoteID), 10),
				resultID,
				strconv.FormatUint(uint64(it.ImageID), 10),
				it.ImageURL,
				it.CropTypePred,
				it.LabelCropType,
				it.LabelCategory,
				it.LabelTags,
				it.Provider,
				strconv.FormatFloat(it.Confidence, 'f', 4, 64),
				it.CreatedAt.Format("2006-01-02 15:04:05"),
			})
		}
		offset += len(items)
	}
	return writer.Error()
}

func (s *Service) ExportEvalSetJSON(w io.Writer, setID uint, start, end *time.Time) error {
	encoder := json.NewEncoder(w)
	_, err := io.WriteString(w, "[")
	if err != nil {
		return err
	}
	limit := 1000
	offset := 0
	first := true
	for {
		items, err := s.repo.ListEvalSetItemsAll(setID, limit, offset, start, end)
		if err != nil {
			return err
		}
		if len(items) == 0 {
			break
		}
		for _, it := range items {
			if !first {
				if _, err := io.WriteString(w, ","); err != nil {
					return err
				}
			}
			if err := encoder.Encode(it); err != nil {
				return err
			}
			first = false
		}
		offset += len(items)
	}
	_, err = io.WriteString(w, "]")
	return err
}

func (s *Service) ListLowConfidenceResults(days, limit, offset int, threshold float64, provider, cropType string, start, end *time.Time) ([]RecognizeResultView, error) {
	if days <= 0 {
		days = 30
	}
	if limit <= 0 {
		limit = 20
	}
	if threshold <= 0 {
		threshold = 0.5
	}
	var items []repository.QCResultRow
	query := s.repo.DB().Model(&model.RecognitionResult{}).
		Select("recognition_results.id as result_id, recognition_results.image_id as image_id, recognition_results.crop_type, recognition_results.confidence, recognition_results.provider, recognition_results.created_at as created_at, images.original_url as image_url").
		Joins("JOIN images ON images.id = recognition_results.image_id").
		Where("recognition_results.confidence >= 0 AND recognition_results.confidence < ?", threshold)
	if start == nil && end == nil {
		since := time.Now().AddDate(0, 0, -days+1)
		query = query.Where("recognition_results.created_at >= ?", since)
	} else {
		if start != nil {
			query = query.Where("recognition_results.created_at >= ?", *start)
		}
		if end != nil {
			query = query.Where("recognition_results.created_at < ?", *end)
		}
	}
	if provider != "" {
		query = query.Where("recognition_results.provider = ?", provider)
	}
	if cropType != "" {
		query = query.Where("recognition_results.crop_type = ?", cropType)
	}
	err := query.Order("recognition_results.created_at DESC").
		Limit(limit).
		Offset(offset).
		Scan(&items).Error
	if err != nil {
		return nil, err
	}
	out := make([]RecognizeResultView, 0, len(items))
	for _, it := range items {
		out = append(out, RecognizeResultView{
			ResultID:   it.ResultID,
			ImageID:    it.ImageID,
			ImageURL:   it.ImageURL,
			CropType:   it.CropType,
			Confidence: it.Confidence,
			Provider:   it.Provider,
			CreatedAt:  it.CreatedAt.Format("2006-01-02 15:04:05"),
		})
	}
	return out, nil
}

func (s *Service) ListFailedResults(days, limit, offset int, provider, cropType string, start, end *time.Time) ([]RecognizeResultView, error) {
	if days <= 0 {
		days = 30
	}
	if limit <= 0 {
		limit = 20
	}
	var items []repository.QCResultRow
	query := s.repo.DB().Model(&model.RecognitionResult{}).
		Select("recognition_results.id as result_id, recognition_results.image_id as image_id, recognition_results.crop_type, recognition_results.confidence, recognition_results.provider, recognition_results.created_at as created_at, images.original_url as image_url").
		Joins("JOIN images ON images.id = recognition_results.image_id").
		Where("(recognition_results.crop_type = '' OR recognition_results.confidence <= 0)")
	if start == nil && end == nil {
		since := time.Now().AddDate(0, 0, -days+1)
		query = query.Where("recognition_results.created_at >= ?", since)
	} else {
		if start != nil {
			query = query.Where("recognition_results.created_at >= ?", *start)
		}
		if end != nil {
			query = query.Where("recognition_results.created_at < ?", *end)
		}
	}
	if provider != "" {
		query = query.Where("recognition_results.provider = ?", provider)
	}
	if cropType != "" {
		query = query.Where("recognition_results.crop_type = ?", cropType)
	}
	err := query.Order("recognition_results.created_at DESC").
		Limit(limit).
		Offset(offset).
		Scan(&items).Error
	if err != nil {
		return nil, err
	}
	out := make([]RecognizeResultView, 0, len(items))
	for _, it := range items {
		out = append(out, RecognizeResultView{
			ResultID:   it.ResultID,
			ImageID:    it.ImageID,
			ImageURL:   it.ImageURL,
			CropType:   it.CropType,
			Confidence: it.Confidence,
			Provider:   it.Provider,
			CreatedAt:  it.CreatedAt.Format("2006-01-02 15:04:05"),
		})
	}
	return out, nil
}

func (s *Service) ExportLowConfidenceResultsCSV(w io.Writer, days int, threshold float64, provider, cropType string, start, end *time.Time) error {
	items, err := s.ListLowConfidenceResults(days, 100000, 0, threshold, provider, cropType, start, end)
	if err != nil {
		return err
	}
	writer := csv.NewWriter(w)
	defer writer.Flush()
	_ = writer.Write([]string{"result_id", "image_id", "image_url", "crop_type", "confidence", "provider", "created_at"})
	for _, it := range items {
		_ = writer.Write([]string{
			strconv.FormatUint(uint64(it.ResultID), 10),
			strconv.FormatUint(uint64(it.ImageID), 10),
			it.ImageURL,
			it.CropType,
			strconv.FormatFloat(it.Confidence, 'f', 4, 64),
			it.Provider,
			it.CreatedAt,
		})
	}
	return writer.Error()
}

func (s *Service) ExportLowConfidenceResultsJSON(w io.Writer, days int, threshold float64, provider, cropType string, start, end *time.Time) error {
	items, err := s.ListLowConfidenceResults(days, 100000, 0, threshold, provider, cropType, start, end)
	if err != nil {
		return err
	}
	return json.NewEncoder(w).Encode(items)
}

func (s *Service) ExportFailedResultsCSV(w io.Writer, days int, provider, cropType string, start, end *time.Time) error {
	items, err := s.ListFailedResults(days, 100000, 0, provider, cropType, start, end)
	if err != nil {
		return err
	}
	writer := csv.NewWriter(w)
	defer writer.Flush()
	_ = writer.Write([]string{"result_id", "image_id", "image_url", "crop_type", "confidence", "provider", "created_at"})
	for _, it := range items {
		_ = writer.Write([]string{
			strconv.FormatUint(uint64(it.ResultID), 10),
			strconv.FormatUint(uint64(it.ImageID), 10),
			it.ImageURL,
			it.CropType,
			strconv.FormatFloat(it.Confidence, 'f', 4, 64),
			it.Provider,
			it.CreatedAt,
		})
	}
	return writer.Error()
}

func (s *Service) ExportFailedResultsJSON(w io.Writer, days int, provider, cropType string, start, end *time.Time) error {
	items, err := s.ListFailedResults(days, 100000, 0, provider, cropType, start, end)
	if err != nil {
		return err
	}
	return json.NewEncoder(w).Encode(items)
}

func (s *Service) CreateQCSamplesFromResults(ids []uint, reason string) (int, error) {
	reason = strings.TrimSpace(reason)
	if reason == "" {
		reason = "manual"
	}
	rows, err := s.repo.ListQCResultRowsByIDs(ids)
	if err != nil {
		return 0, err
	}
	samples := make([]model.QCSample, 0, len(rows))
	for _, r := range rows {
		samples = append(samples, model.QCSample{
			ResultID:   r.ResultID,
			ImageID:    r.ImageID,
			ImageURL:   r.ImageURL,
			CropType:   r.CropType,
			Confidence: r.Confidence,
			Provider:   r.Provider,
			Reason:     reason,
			Status:     "pending",
		})
	}
	created, err := s.repo.CreateQCSamples(samples)
	if err != nil {
		return 0, err
	}
	return int(created), nil
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
