package service

import (
	"encoding/csv"
	"io"
	"strconv"
)

// ExportNotesCSV 导出手记为 CSV
func (s *Service) ExportNotesCSV(w io.Writer, userID uint, limit, offset int, category, cropType string) error {
	notes, err := s.GetNotes(userID, limit, offset, category, cropType)
	if err != nil {
		return err
	}

	writer := csv.NewWriter(w)
	defer writer.Flush()

	_ = writer.Write([]string{
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
	})

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

		_ = writer.Write([]string{
			strconv.FormatUint(uint64(n.ID), 10),
			n.CreatedAt.Format("2006-01-02 15:04:05"),
			strconv.FormatUint(uint64(n.ImageID), 10),
			resultID,
			n.ImageURL,
			n.Category,
			n.CropType,
			strconv.FormatFloat(n.Confidence, 'f', 4, 64),
			n.Description,
			growth,
			issue,
			n.Provider,
			n.Note,
		})
	}

	return writer.Error()
}
