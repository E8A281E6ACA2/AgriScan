package repository

import (
	"agri-scan/internal/model"
	"errors"

	"gorm.io/gorm"
)

func (r *Repository) ListAppSettings() ([]model.AppSetting, error) {
	var items []model.AppSetting
	err := r.db.Order("id ASC").Find(&items).Error
	return items, err
}

func (r *Repository) GetAppSettingByKey(key string) (*model.AppSetting, error) {
	var item model.AppSetting
	err := r.db.Where("key = ?", key).First(&item).Error
	if err != nil {
		return nil, err
	}
	return &item, nil
}

func (r *Repository) UpsertAppSetting(key, value string) (*model.AppSetting, error) {
	item, err := r.GetAppSettingByKey(key)
	if err == nil && item != nil {
		if err := r.db.Model(&model.AppSetting{}).Where("id = ?", item.ID).Updates(map[string]interface{}{
			"value": value,
		}).Error; err != nil {
			return nil, err
		}
		return r.GetAppSettingByKey(key)
	}
	if err != nil && !errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, err
	}
	if err := r.db.Create(&model.AppSetting{Key: key, Value: value}).Error; err != nil {
		return nil, err
	}
	return r.GetAppSettingByKey(key)
}
