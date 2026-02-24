package repository

import (
	"agri-scan/internal/model"
	"gorm.io/gorm"
)

func seedDefaults(db *gorm.DB) error {
	if err := seedCrops(db); err != nil {
		return err
	}
	if err := seedTags(db); err != nil {
		return err
	}
	return nil
}

func seedCrops(db *gorm.DB) error {
	var count int64
	if err := db.Model(&model.Crop{}).Count(&count).Error; err != nil {
		return err
	}
	if count > 0 {
		return nil
	}
	items := []model.Crop{
		{Code: "corn", Name: "玉米", Aliases: "玉米", Active: true},
		{Code: "wheat", Name: "小麦", Aliases: "小麦", Active: true},
		{Code: "rice", Name: "水稻", Aliases: "稻", Active: true},
		{Code: "soybean", Name: "大豆", Aliases: "黄豆", Active: true},
		{Code: "tomato", Name: "番茄", Aliases: "西红柿", Active: true},
	}
	return db.Create(&items).Error
}

func seedTags(db *gorm.DB) error {
	var count int64
	if err := db.Model(&model.Tag{}).Count(&count).Error; err != nil {
		return err
	}
	if count > 0 {
		return nil
	}
	items := []model.Tag{
		{Category: "disease", Name: "锈病", Active: true},
		{Category: "disease", Name: "白粉病", Active: true},
		{Category: "disease", Name: "叶斑病", Active: true},
		{Category: "disease", Name: "枯萎病", Active: true},
		{Category: "disease", Name: "纹枯病", Active: true},
		{Category: "disease", Name: "霜霉病", Active: true},
		{Category: "pest", Name: "蚜虫", Active: true},
		{Category: "pest", Name: "螟虫", Active: true},
		{Category: "pest", Name: "红蜘蛛", Active: true},
		{Category: "pest", Name: "蓟马", Active: true},
		{Category: "pest", Name: "粘虫", Active: true},
		{Category: "pest", Name: "象甲", Active: true},
		{Category: "weed", Name: "稗草", Active: true},
		{Category: "weed", Name: "马齿苋", Active: true},
		{Category: "weed", Name: "狗尾草", Active: true},
		{Category: "weed", Name: "牛筋草", Active: true},
		{Category: "weed", Name: "藜", Active: true},
		{Category: "weed", Name: "苍耳", Active: true},
	}
	return db.Create(&items).Error
}
