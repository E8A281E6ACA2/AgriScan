package service

import (
	"agri-scan/internal/model"
	"agri-scan/internal/repository"
	"strings"
	"time"
)

type FailureTopView struct {
	Stage        string `json:"stage"`
	ErrorCode    string `json:"error_code"`
	ErrorMessage string `json:"error_message"`
	Count        int64  `json:"count"`
	RetryTotal   int64  `json:"retry_total"`
}

func (s *Service) RecordFailure(userID uint, imageID *uint, provider, stage string, err error) {
	if err == nil {
		return
	}
	code, msg := classifyFailure(err)
	if provider == "" && s.llm != nil {
		provider = s.llm.Name()
	}
	now := time.Now()
	item := &model.RecognitionFailure{
		UserID:       userID,
		ImageID:      imageID,
		Provider:     strings.TrimSpace(provider),
		Stage:        strings.TrimSpace(stage),
		ErrorCode:    code,
		ErrorMessage: msg,
		RetryCount:   1,
		LastTriedAt:  &now,
	}
	_ = s.repo.UpsertRecognitionFailure(item)
}

func (s *Service) ListFailureTop(days, limit int, stage string) ([]FailureTopView, error) {
	if days <= 0 {
		days = 7
	}
	if limit <= 0 {
		limit = 10
	}
	since := time.Now().AddDate(0, 0, -days)
	rows, err := s.repo.ListFailureTop(since, limit, strings.TrimSpace(stage))
	if err != nil {
		return nil, err
	}
	out := make([]FailureTopView, 0, len(rows))
	for _, r := range rows {
		out = append(out, FailureTopView{
			Stage:        r.Stage,
			ErrorCode:    r.ErrorCode,
			ErrorMessage: r.ErrorMessage,
			Count:        r.Count,
			RetryTotal:   r.RetryTotal,
		})
	}
	return out, nil
}

func classifyFailure(err error) (string, string) {
	msg := strings.TrimSpace(err.Error())
	lower := strings.ToLower(msg)
	code := "unknown"
	switch {
	case strings.Contains(lower, "invalid_request") || strings.Contains(lower, "invalid_parameter"):
		code = "invalid_request"
	case strings.Contains(lower, "download") && strings.Contains(lower, "image"):
		code = "download_failed"
	case strings.Contains(lower, "timeout"):
		code = "timeout"
	case strings.Contains(lower, "unauthorized") || strings.Contains(lower, "401"):
		code = "unauthorized"
	case strings.Contains(lower, "storage not configured"):
		code = "storage_not_configured"
	case strings.Contains(lower, "failed to upload"):
		code = "upload_failed"
	case strings.Contains(lower, "failed to decode base64"):
		code = "invalid_base64"
	case strings.Contains(lower, "no image file"):
		code = "missing_file"
	}
	if len(msg) > 400 {
		msg = msg[:400]
	}
	return code, msg
}
