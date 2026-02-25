package repository

import "agri-scan/internal/model"

func (r *Repository) CreateEvalRun(run *model.EvalRun) error {
	return r.db.Create(run).Error
}

func (r *Repository) ListEvalRuns(limit, offset int) ([]model.EvalRun, error) {
	var items []model.EvalRun
	err := r.db.Order("created_at DESC").Limit(limit).Offset(offset).Find(&items).Error
	return items, err
}
