package service

import (
	"encoding/csv"
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

		row := map[string]string{
			"id":             strconv.FormatUint(uint64(n.ID), 10),
			"created_at":     n.CreatedAt.Format("2006-01-02 15:04:05"),
			"image_id":       strconv.FormatUint(uint64(n.ImageID), 10),
			"result_id":      resultID,
			"image_url":      n.ImageURL,
			"category":       n.Category,
			"crop_type":      n.CropType,
			"confidence":     strconv.FormatFloat(n.Confidence, 'f', 4, 64),
			"description":    n.Description,
			"growth_stage":   growth,
			"possible_issue": issue,
			"provider":       n.Provider,
			"note":           n.Note,
			"raw_text":       n.RawText,
		}

		out := make([]string, 0, len(columns))
		for _, col := range columns {
			out = append(out, row[col])
		}
		_ = writer.Write(out)
	}

	return writer.Error()
}

func parseFields(fields string) []string {
	defaultCols := []string{
		"id",
		"created_at",
		"image_id",
		"result_id",
		"image_url",
		"category",
		"crop_type",
		"confidence",
		"description",
		"growth_stage",
		"possible_issue",
		"provider",
		"note",
	}
	if strings.TrimSpace(fields) == "" {
		return defaultCols
	}

	allowed := map[string]bool{}
	for _, c := range append(defaultCols, "raw_text") {
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
