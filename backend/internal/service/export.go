package service

import (
	"agri-scan/internal/model"
	"encoding/csv"
	"encoding/json"
	"io"
	"strconv"
	"strings"
	"time"
)

// ExportNotesCSV 导出手记为 CSV
func (s *Service) ExportNotesCSV(w io.Writer, userID uint, limit, offset int, category, cropType string, startDate, endDate *time.Time, fields string) error {
	notes, err := s.GetNotes(userID, limit, offset, category, cropType, startDate, endDate)
	if err != nil {
		return err
	}
	imageMap, err := s.loadImageMap(notes)
	if err != nil {
		return err
	}

	writer := csv.NewWriter(w)
	defer writer.Flush()

	columns := parseFields(fields)
	_ = writer.Write(columns)

	for _, n := range notes {
		resultID := ""
		if n.ResultID != nil {
			resultID = strconv.FormatUint(uint64(*n.ResultID), 10)
		}
		growth := ""
		if n.GrowthStage != nil {
			growth = *n.GrowthStage
		}
		issue := ""
		if n.PossibleIssue != nil {
			issue = *n.PossibleIssue
		}

		img := imageMap[n.ImageID]
		lat := ""
		lng := ""
		if img != nil && img.Latitude != nil {
			lat = strconv.FormatFloat(*img.Latitude, 'f', 6, 64)
		}
		if img != nil && img.Longitude != nil {
			lng = strconv.FormatFloat(*img.Longitude, 'f', 6, 64)
		}
		row := map[string]string{
			"id":             strconv.FormatUint(uint64(n.ID), 10),
			"created_at":     n.CreatedAt.Format("2006-01-02 15:04:05"),
			"image_id":       strconv.FormatUint(uint64(n.ImageID), 10),
			"result_id":      resultID,
			"image_url":      n.ImageURL,
			"latitude":       lat,
			"longitude":      lng,
			"category":       n.Category,
			"crop_type":      n.CropType,
			"confidence":     strconv.FormatFloat(n.Confidence, 'f', 4, 64),
			"description":    n.Description,
			"growth_stage":   growth,
			"possible_issue": issue,
			"provider":       n.Provider,
			"note":           n.Note,
			"raw_text":       n.RawText,
			"tags":           n.Tags,
		}

		out := make([]string, 0, len(columns))
		for _, col := range columns {
			out = append(out, row[col])
		}
		_ = writer.Write(out)
	}

	return writer.Error()
}

// ExportNotesJSON 导出手记为 JSON
func (s *Service) ExportNotesJSON(w io.Writer, userID uint, limit, offset int, category, cropType string, startDate, endDate *time.Time, fields string) error {
	notes, err := s.GetNotes(userID, limit, offset, category, cropType, startDate, endDate)
	if err != nil {
		return err
	}
	imageMap, err := s.loadImageMap(notes)
	if err != nil {
		return err
	}

	columns := parseFields(fields)
	items := make([]map[string]any, 0, len(notes))

	for _, n := range notes {
		var resultID any
		if n.ResultID != nil {
			resultID = *n.ResultID
		}
		var growth any
		if n.GrowthStage != nil {
			growth = *n.GrowthStage
		}
		var issue any
		if n.PossibleIssue != nil {
			issue = *n.PossibleIssue
		}

		img := imageMap[n.ImageID]
		var lat any
		var lng any
		if img != nil {
			lat = img.Latitude
			lng = img.Longitude
		}
		row := map[string]any{
			"id":             n.ID,
			"created_at":     n.CreatedAt.Format("2006-01-02 15:04:05"),
			"image_id":       n.ImageID,
			"result_id":      resultID,
			"image_url":      n.ImageURL,
			"latitude":       lat,
			"longitude":      lng,
			"category":       n.Category,
			"crop_type":      n.CropType,
			"confidence":     n.Confidence,
			"description":    n.Description,
			"growth_stage":   growth,
			"possible_issue": issue,
			"provider":       n.Provider,
			"note":           n.Note,
			"raw_text":       n.RawText,
			"tags":           n.Tags,
		}

		out := make(map[string]any, len(columns))
		for _, col := range columns {
			out[col] = row[col]
		}
		items = append(items, out)
	}

	enc := json.NewEncoder(w)
	enc.SetEscapeHTML(false)
	return enc.Encode(items)
}

func parseFields(fields string) []string {
	defaultCols := []string{
		"id",
		"created_at",
		"image_id",
		"result_id",
		"image_url",
		"latitude",
		"longitude",
		"category",
		"crop_type",
		"confidence",
		"description",
		"growth_stage",
		"possible_issue",
		"provider",
		"note",
		"tags",
	}
	if strings.TrimSpace(fields) == "" {
		return defaultCols
	}

	allowed := map[string]bool{}
	for _, c := range append(defaultCols, "raw_text", "tags") {
		allowed[c] = true
	}

	parts := strings.Split(fields, ",")
	out := make([]string, 0, len(parts))
	seen := map[string]bool{}
	for _, p := range parts {
		col := strings.TrimSpace(p)
		if col == "" || !allowed[col] || seen[col] {
			continue
		}
		seen[col] = true
		out = append(out, col)
	}
	if len(out) == 0 {
		return defaultCols
	}
	return out
}

func (s *Service) loadImageMap(notes []model.FieldNote) (map[uint]*model.Image, error) {
	ids := make([]uint, 0, len(notes))
	seen := map[uint]bool{}
	for _, n := range notes {
		if n.ImageID == 0 || seen[n.ImageID] {
			continue
		}
		seen[n.ImageID] = true
		ids = append(ids, n.ImageID)
	}
	imgs, err := s.repo.GetImagesByIDs(ids)
	if err != nil {
		return nil, err
	}
	out := make(map[uint]*model.Image, len(imgs))
	for i := range imgs {
		out[imgs[i].ID] = &imgs[i]
	}
	return out, nil
}
