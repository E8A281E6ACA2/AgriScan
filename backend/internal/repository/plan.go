package repository

import (
	"agri-scan/internal/model"
	"errors"

	"gorm.io/gorm"
)

func (r *Repository) ListPlanSettings() ([]model.PlanSetting, error) {
	var items []model.PlanSetting
	err := r.db.Order("id ASC").Find(&items).Error
	return items, err
}

func (r *Repository) GetPlanSettingByCode(code string) (*model.PlanSetting, error) {
	var item model.PlanSetting
	err := r.db.Where("code = ?", code).First(&item).Error
	if err != nil {
		return nil, err
	}
	return &item, nil
}

func (r *Repository) UpsertPlanSetting(code string, updates map[string]interface{}) (*model.PlanSetting, error) {
	item, err := r.GetPlanSettingByCode(code)
	if err == nil && item != nil {
		if err := r.db.Model(&model.PlanSetting{}).Where("id = ?", item.ID).Updates(updates).Error; err != nil {
			return nil, err
		}
		return r.GetPlanSettingByCode(code)
	}
	if err != nil && !errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, err
	}
	if updates["code"] == nil {
		updates["code"] = code
	}
	if err := r.db.Model(&model.PlanSetting{}).Create(updates).Error; err != nil {
		return nil, err
	}
	return r.GetPlanSettingByCode(code)
}
