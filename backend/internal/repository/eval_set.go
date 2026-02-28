package repository

import (
	"agri-scan/internal/model"
	"time"
)

func (r *Repository) CreateEvalSet(set *model.EvalSet) error {
	return r.db.Create(set).Error
}

func (r *Repository) ListEvalSets(limit, offset int) ([]model.EvalSet, error) {
	var items []model.EvalSet
	err := r.db.Order("created_at DESC").Limit(limit).Offset(offset).Find(&items).Error
	return items, err
}

func (r *Repository) GetEvalSetByID(id uint) (*model.EvalSet, error) {
	var item model.EvalSet
	err := r.db.First(&item, id).Error
	if err != nil {
		return nil, err
	}
	return &item, nil
}

func (r *Repository) CreateEvalSetItems(items []model.EvalSetItem) error {
	if len(items) == 0 {
		return nil
	}
	return r.db.Create(&items).Error
}

func (r *Repository) CountEvalSetItems(setID uint) (int64, error) {
	var c int64
	err := r.db.Model(&model.EvalSetItem{}).Where("eval_set_id = ?", setID).Count(&c).Error
	return c, err
}

func (r *Repository) ListEvalSetItems(setID uint, limit, offset int) ([]model.EvalSetItem, error) {
	var items []model.EvalSetItem
	err := r.db.Where("eval_set_id = ?", setID).Order("created_at DESC").Limit(limit).Offset(offset).Find(&items).Error
	return items, err
}

func (r *Repository) ListEvalSetItemsAll(setID uint, limit, offset int, start, end *time.Time) ([]model.EvalSetItem, error) {
	var items []model.EvalSetItem
	query := r.db.Where("eval_set_id = ?", setID)
	if start != nil {
		query = query.Where("created_at >= ?", *start)
	}
	if end != nil {
		query = query.Where("created_at < ?", *end)
	}
	err := query.Order("created_at DESC").Limit(limit).Offset(offset).Find(&items).Error
	return items, err
}

func (r *Repository) CreateEvalSetRun(run *model.EvalSetRun) error {
	return r.db.Create(run).Error
}

func (r *Repository) ListEvalSetRuns(setID uint, limit, offset int) ([]model.EvalSetRun, error) {
	var items []model.EvalSetRun
	err := r.db.Where("eval_set_id = ?", setID).Order("created_at DESC").Limit(limit).Offset(offset).Find(&items).Error
	return items, err
}

func (r *Repository) GetEvalSetRunByID(id uint) (*model.EvalSetRun, error) {
	var item model.EvalSetRun
	err := r.db.First(&item, id).Error
	if err != nil {
		return nil, err
	}
	return &item, nil
}
