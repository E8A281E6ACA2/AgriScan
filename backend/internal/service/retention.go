package service

import (
	"context"
	"log"
	"time"
)

type RetentionSummary struct {
	Users  int
	Purged int64
}

func (s *Service) PurgeAllUsersRetention() (RetentionSummary, error) {
	summary := RetentionSummary{}
	limit := s.auth.RetentionPurgeBatchSize
	if limit <= 0 {
		limit = 200
	}
	offset := 0
	for {
		users, err := s.repo.ListUsers(limit, offset, "")
		if err != nil {
			return summary, err
		}
		if len(users) == 0 {
			break
		}
		for _, u := range users {
			count, err := s.PurgeUserNotesByRetention(&u)
			if err != nil {
				return summary, err
			}
			summary.Users++
			summary.Purged += count
		}
		offset += len(users)
	}
	return summary, nil
}

func (s *Service) StartRetentionWorker(ctx context.Context) {
	if !s.auth.RetentionPurgeEnabled {
		return
	}
	interval := time.Duration(s.auth.RetentionPurgeIntervalHours) * time.Hour
	if interval <= 0 {
		interval = 24 * time.Hour
	}
	go func() {
		ticker := time.NewTicker(interval)
		defer ticker.Stop()
		for {
			select {
			case <-ctx.Done():
				return
			default:
			}
			summary, err := s.PurgeAllUsersRetention()
			if err != nil {
				log.Printf("retention purge failed: %v", err)
			} else {
				log.Printf("retention purge done: users=%d purged=%d", summary.Users, summary.Purged)
			}
			select {
			case <-ctx.Done():
				return
			case <-ticker.C:
			}
		}
	}()
}
