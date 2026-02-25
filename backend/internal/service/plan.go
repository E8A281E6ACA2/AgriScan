package service

import (
	"errors"
	"strings"

	"gorm.io/gorm"
)

type PlanSettingView struct {
	Code          string `json:"code"`
	Name          string `json:"name"`
	Description   string `json:"description"`
	QuotaTotal    int    `json:"quota_total"`
	RetentionDays int    `json:"retention_days"`
	RequireAd     bool   `json:"require_ad"`
}

type PlanSettingUpdate struct {
	Name          *string `json:"name"`
	Description   *string `json:"description"`
	QuotaTotal    *int    `json:"quota_total"`
	RetentionDays *int    `json:"retention_days"`
	RequireAd     *bool   `json:"require_ad"`
}

func (s *Service) GetPlanSettings() ([]PlanSettingView, error) {
	codes := []string{"free", "silver", "gold", "diamond"}
	items := make([]PlanSettingView, 0, len(codes))
	for _, code := range codes {
		view, err := s.getPlanSettingView(code)
		if err != nil {
			return nil, err
		}
		items = append(items, view)
	}
	return items, nil
}

func (s *Service) UpdatePlanSetting(code string, update PlanSettingUpdate) (PlanSettingView, error) {
	code = strings.ToLower(strings.TrimSpace(code))
	if code == "" {
		return PlanSettingView{}, errors.New("invalid code")
	}
	if update.QuotaTotal != nil && *update.QuotaTotal < 0 {
		return PlanSettingView{}, errors.New("invalid quota_total")
	}
	if update.RetentionDays != nil && *update.RetentionDays < 0 {
		return PlanSettingView{}, errors.New("invalid retention_days")
	}
	current, err := s.getPlanSettingView(code)
	if err != nil {
		return PlanSettingView{}, err
	}
	payload := map[string]interface{}{
		"code":           code,
		"name":           current.Name,
		"description":    current.Description,
		"quota_total":    current.QuotaTotal,
		"retention_days": current.RetentionDays,
		"require_ad":     current.RequireAd,
	}
	if update.Name != nil {
		payload["name"] = strings.TrimSpace(*update.Name)
	}
	if update.Description != nil {
		payload["description"] = strings.TrimSpace(*update.Description)
	}
	if update.QuotaTotal != nil {
		payload["quota_total"] = *update.QuotaTotal
	}
	if update.RetentionDays != nil {
		payload["retention_days"] = *update.RetentionDays
	}
	if update.RequireAd != nil {
		payload["require_ad"] = *update.RequireAd
	}
	if _, err := s.repo.UpsertPlanSetting(code, payload); err != nil {
		return PlanSettingView{}, err
	}
	return s.getPlanSettingView(code)
}

func (s *Service) getPlanSettingView(code string) (PlanSettingView, error) {
	code = strings.ToLower(strings.TrimSpace(code))
	if code == "" {
		return PlanSettingView{}, errors.New("invalid code")
	}
	item, err := s.repo.GetPlanSettingByCode(code)
	if err == nil && item != nil {
		return PlanSettingView{
			Code:          item.Code,
			Name:          item.Name,
			Description:   item.Description,
			QuotaTotal:    item.QuotaTotal,
			RetentionDays: item.RetentionDays,
			RequireAd:     item.RequireAd,
		}, nil
	}
	if err != nil && !errors.Is(err, gorm.ErrRecordNotFound) {
		return PlanSettingView{}, err
	}
	return s.defaultPlanSettingView(code), nil
}

func (s *Service) defaultPlanSettingView(code string) PlanSettingView {
	switch code {
	case "silver":
		return PlanSettingView{
			Code:          "silver",
			Name:          "白银",
			Description:   "适合频繁识别",
			QuotaTotal:    s.auth.PlanSilver.QuotaTotal,
			RetentionDays: s.auth.PlanSilver.RetentionDays,
			RequireAd:     s.auth.PlanSilver.RequireAd,
		}
	case "gold":
		return PlanSettingView{
			Code:          "gold",
			Name:          "黄金",
			Description:   "更高额度",
			QuotaTotal:    s.auth.PlanGold.QuotaTotal,
			RetentionDays: s.auth.PlanGold.RetentionDays,
			RequireAd:     s.auth.PlanGold.RequireAd,
		}
	case "diamond":
		return PlanSettingView{
			Code:          "diamond",
			Name:          "钻石",
			Description:   "最高额度",
			QuotaTotal:    s.auth.PlanDiamond.QuotaTotal,
			RetentionDays: s.auth.PlanDiamond.RetentionDays,
			RequireAd:     s.auth.PlanDiamond.RequireAd,
		}
	default:
		return PlanSettingView{
			Code:          "free",
			Name:          "免费",
			Description:   "基础功能",
			QuotaTotal:    s.auth.FreeQuotaTotal,
			RetentionDays: s.auth.FreeRetentionDays,
			RequireAd:     true,
		}
	}
}
