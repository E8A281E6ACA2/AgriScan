package service

import (
	"agri-scan/internal/model"
	"context"
	"crypto/rand"
	"crypto/tls"
	"encoding/hex"
	"errors"
	"fmt"
	"net/smtp"
	urlpkg "net/url"
	"strings"
	"time"

	"gorm.io/gorm"
)

var (
	ErrLoginRequired   = errors.New("login_required")
	ErrAdRequired      = errors.New("ad_required")
	ErrQuotaExceeded   = errors.New("quota_exceeded")
	ErrInvalidOTP      = errors.New("invalid_otp")
	ErrTooManyRequests = errors.New("too_many_requests")
)

type Entitlements struct {
	UserID             uint
	Plan               string
	RequireLogin       bool
	RequireAd          bool
	AdCredits          int
	QuotaTotal         int
	QuotaUsed          int
	QuotaRemaining     int
	AnonymousRemaining int
	RetentionDays      int
}

type UserUpdate struct {
	Plan          string
	QuotaTotal    int
	QuotaUsed     int
	Status        string
	AdCredits     int
	RetentionDays int
}

func (s *Service) GetUserByToken(token string) (*model.User, error) {
	if strings.TrimSpace(token) == "" {
		return nil, gorm.ErrRecordNotFound
	}
	session, err := s.repo.GetSessionByToken(token)
	if err != nil {
		return nil, err
	}
	if time.Now().After(session.ExpiresAt) {
		_ = s.repo.DeleteSessionByToken(token)
		return nil, gorm.ErrRecordNotFound
	}
	return s.repo.GetUserByID(session.UserID)
}

func (s *Service) GetUserByID(id uint) (*model.User, error) {
	return s.repo.GetUserByID(id)
}

func (s *Service) ListUsers(limit, offset int, keyword string) ([]model.User, error) {
	return s.repo.ListUsers(limit, offset, keyword)
}

func (s *Service) ListEmailLogs(limit, offset int, email string) ([]model.EmailLog, error) {
	return s.repo.ListEmailLogs(limit, offset, email)
}

func (s *Service) CreateMembershipRequest(userID uint, plan, note string) (*model.MembershipRequest, error) {
	plan = strings.TrimSpace(strings.ToLower(plan))
	if plan == "" || plan == "free" {
		return nil, fmt.Errorf("invalid plan")
	}
	if _, err := s.repo.GetPendingMembershipRequestByUser(userID); err == nil {
		return nil, fmt.Errorf("pending request exists")
	}
	item := &model.MembershipRequest{
		UserID: userID,
		Plan:   plan,
		Status: "pending",
		Note:   note,
	}
	if err := s.repo.CreateMembershipRequest(item); err != nil {
		return nil, err
	}
	return item, nil
}

func (s *Service) ListMembershipRequests(limit, offset int, status string) ([]model.MembershipRequest, error) {
	return s.repo.ListMembershipRequests(limit, offset, status)
}

func (s *Service) ApproveMembershipRequest(id uint, plan string, quotaTotal *int) (*model.User, error) {
	req, err := s.repo.GetMembershipRequestByID(id)
	if err != nil {
		return nil, err
	}
	if req.Status != "pending" {
		return nil, fmt.Errorf("request not pending")
	}
	if plan == "" {
		plan = req.Plan
	}
	cfg := s.getPlanSetting(plan)
	quota := cfg.QuotaTotal
	if quotaTotal != nil && *quotaTotal >= 0 {
		quota = *quotaTotal
	}
	user, err := s.UpdateUserByID(req.UserID, UserUpdate{
		Plan:       plan,
		QuotaTotal: quota,
		QuotaUsed:  0,
		Status:     "active",
		AdCredits:  0,
	})
	if err != nil {
		return nil, err
	}
	_ = s.repo.UpdateMembershipRequestStatus(req.ID, "approved")
	return user, nil
}

func (s *Service) RejectMembershipRequest(id uint) error {
	req, err := s.repo.GetMembershipRequestByID(id)
	if err != nil {
		return err
	}
	if req.Status != "pending" {
		return fmt.Errorf("request not pending")
	}
	return s.repo.UpdateMembershipRequestStatus(req.ID, "rejected")
}

func (s *Service) AddUserQuota(userID uint, delta int) (*model.User, error) {
	if delta <= 0 {
		return nil, fmt.Errorf("invalid delta")
	}
	if err := s.repo.IncrementUserQuotaTotal(userID, delta); err != nil {
		return nil, err
	}
	return s.repo.GetUserByID(userID)
}

func (s *Service) UpdateUserByID(id uint, update UserUpdate) (*model.User, error) {
	user, err := s.repo.GetUserByID(id)
	if err != nil {
		return nil, err
	}
	if update.Plan != "" {
		user.Plan = update.Plan
	}
	if update.Status != "" {
		user.Status = update.Status
	}
	if update.QuotaTotal >= 0 {
		user.QuotaTotal = update.QuotaTotal
	}
	if update.QuotaUsed >= 0 {
		user.QuotaUsed = update.QuotaUsed
	}
	if update.AdCredits >= 0 {
		user.AdCredits = update.AdCredits
	}
	if err := s.repo.UpdateUser(user); err != nil {
		return nil, err
	}
	return user, nil
}

func (s *Service) EnsureDeviceUser(deviceID string) (*model.User, error) {
	if strings.TrimSpace(deviceID) == "" {
		return nil, fmt.Errorf("device_id required")
	}

	dev, err := s.repo.GetDeviceByDeviceID(deviceID)
	if err != nil && !errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, err
	}

	if dev == nil || dev.ID == 0 {
		user := &model.User{
			Email:      fmt.Sprintf("device:%s", deviceID),
			Nickname:   "Guest",
			Plan:       "free",
			Status:     "guest",
			QuotaTotal: s.auth.FreeQuotaTotal,
		}
		if err := s.repo.CreateUser(user); err != nil {
			return nil, err
		}
		if err := s.repo.CreateDevice(&model.Device{DeviceID: deviceID, UserID: user.ID}); err != nil {
			return nil, err
		}
		_ = s.ensureDeviceUsage(deviceID)
		return user, nil
	}

	_ = s.ensureDeviceUsage(deviceID)
	return s.repo.GetUserByID(dev.UserID)
}

func (s *Service) ensureDeviceUsage(deviceID string) *model.DeviceUsage {
	usage, err := s.repo.GetDeviceUsage(deviceID)
	if err == nil && usage != nil && usage.ID > 0 {
		return usage
	}
	usage = &model.DeviceUsage{DeviceID: deviceID}
	_ = s.repo.CreateDeviceUsage(usage)
	return usage
}

func (s *Service) SendEmailOTP(email string) (string, error) {
	email = strings.TrimSpace(strings.ToLower(email))
	if email == "" || !strings.Contains(email, "@") {
		return "", fmt.Errorf("invalid email")
	}
	if last, err := s.repo.GetLatestEmailOTP(email); err == nil && last != nil && time.Since(last.CreatedAt) < time.Minute {
		return "", ErrTooManyRequests
	}
	code, err := randomDigits(6)
	if err != nil {
		return "", err
	}
	otp := &model.EmailOTP{
		Email:     email,
		Code:      code,
		ExpiresAt: time.Now().Add(time.Duration(s.auth.OTPMinutes) * time.Minute),
	}
	if err := s.repo.CreateEmailOTP(otp); err != nil {
		return "", err
	}
	status := "sent"
	errMsg := ""
	if s.auth.DebugOTP {
		status = "debug"
	} else {
		if err := s.sendOTPEmail(email, code); err != nil {
			status = "failed"
			errMsg = err.Error()
		}
	}
	_ = s.repo.CreateEmailLog(&model.EmailLog{
		Email:  email,
		Code:   code,
		Status: status,
		Error:  errMsg,
	})
	if status == "failed" {
		return "", fmt.Errorf(errMsg)
	}
	return code, nil
}

func (s *Service) VerifyEmailOTP(email, code, deviceID string) (*model.User, string, error) {
	email = strings.TrimSpace(strings.ToLower(email))
	code = strings.TrimSpace(code)
	if email == "" || code == "" {
		return nil, "", ErrInvalidOTP
	}

	otp, err := s.repo.GetValidEmailOTP(email, code, time.Now())
	if err != nil {
		return nil, "", ErrInvalidOTP
	}
	_ = s.repo.MarkEmailOTPUsed(otp.ID, time.Now())

	user, err := s.repo.GetUserByEmail(email)
	if err != nil {
		if !errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, "", err
		}
		user = &model.User{
			Email:      email,
			Plan:       "free",
			Status:     "active",
			QuotaTotal: s.auth.FreeQuotaTotal,
		}
		if count, err := s.repo.CountRealUsers(); err == nil && count == 0 {
			user.IsAdmin = true
		}
		if err := s.repo.CreateUser(user); err != nil {
			return nil, "", err
		}
	}

	now := time.Now()
	user.LastLoginAt = &now
	_ = s.repo.UpdateUser(user)

	token, err := randomToken(32)
	if err != nil {
		return nil, "", err
	}
	session := &model.UserSession{
		UserID:    user.ID,
		Token:     token,
		ExpiresAt: time.Now().Add(time.Duration(s.auth.SessionDays) * 24 * time.Hour),
	}
	if err := s.repo.CreateSession(session); err != nil {
		return nil, "", err
	}

	if deviceID != "" {
		_ = s.attachDeviceToUser(deviceID, user.ID)
	}

	return user, token, nil
}

func (s *Service) attachDeviceToUser(deviceID string, userID uint) error {
	dev, err := s.repo.GetDeviceByDeviceID(deviceID)
	if err != nil && !errors.Is(err, gorm.ErrRecordNotFound) {
		return err
	}

	if dev == nil || dev.ID == 0 {
		if err := s.repo.CreateDevice(&model.Device{DeviceID: deviceID, UserID: userID}); err != nil {
			return err
		}
		return nil
	}

	if dev.UserID != userID {
		oldUserID := dev.UserID
		if err := s.repo.UpdateDeviceUser(deviceID, userID); err != nil {
			return err
		}
		_ = s.repo.TransferUserData(oldUserID, userID)

		usage, err := s.repo.GetDeviceUsage(deviceID)
		if err == nil && usage != nil && usage.AdCredits > 0 {
			_ = s.repo.IncrementUserAdCredits(userID, usage.AdCredits)
			usage.AdCredits = 0
			_ = s.repo.UpdateDeviceUsage(usage)
		}
	}

	return nil
}

func (s *Service) GetEntitlements(user *model.User, deviceID string) (Entitlements, error) {
	ent := Entitlements{
		Plan:           "free",
		QuotaRemaining: -1,
		RetentionDays:  s.auth.FreeRetentionDays,
	}

	if user != nil && user.ID > 0 && !isGuestUser(user) {
		planCfg := s.getPlanSetting(user.Plan)
		quotaTotal := user.QuotaTotal
		if quotaTotal == 0 {
			quotaTotal = planCfg.QuotaTotal
		}

		ent.UserID = user.ID
		ent.Plan = planCfg.Name
		ent.AdCredits = user.AdCredits
		ent.QuotaTotal = quotaTotal
		ent.QuotaUsed = user.QuotaUsed
		ent.RetentionDays = planCfg.RetentionDays
		if planCfg.RequireAd {
			ent.RequireAd = user.AdCredits <= 0
		} else {
			ent.RequireAd = false
		}
		if quotaTotal > 0 {
			ent.QuotaRemaining = quotaTotal - user.QuotaUsed
			if ent.QuotaRemaining < 0 {
				ent.QuotaRemaining = 0
			}
		}
		return ent, nil
	}

	if strings.TrimSpace(deviceID) == "" {
		return ent, fmt.Errorf("device_id required")
	}
	usage := s.ensureDeviceUsage(deviceID)
	anonLimit := s.getSettingInt(settingAnonLimit, s.auth.AnonLimit)
	anonRequireAd := s.getSettingBool(settingAnonRequireAd, true)
	ent.AnonymousRemaining = anonLimit - usage.RecognizeCount
	if ent.AnonymousRemaining < 0 {
		ent.AnonymousRemaining = 0
	}
	ent.RequireLogin = anonLimit <= 0 || usage.RecognizeCount >= anonLimit
	ent.AdCredits = usage.AdCredits
	ent.RequireAd = anonRequireAd && !ent.RequireLogin && usage.AdCredits <= 0
	return ent, nil
}

func (s *Service) ConsumeRecognition(user *model.User, deviceID string) error {
	if user != nil && user.ID > 0 && !isGuestUser(user) {
		planCfg := s.getPlanSetting(user.Plan)
		quotaTotal := user.QuotaTotal
		if quotaTotal == 0 {
			quotaTotal = planCfg.QuotaTotal
		}
		if quotaTotal > 0 && user.QuotaUsed >= quotaTotal {
			return ErrQuotaExceeded
		}
		if planCfg.RequireAd {
			if ok, err := s.repo.DecrementUserAdCredits(user.ID); err != nil {
				return err
			} else if !ok {
				return ErrAdRequired
			}
		}
		_ = s.repo.IncrementUserQuotaUsed(user.ID)
		return nil
	}

	if strings.TrimSpace(deviceID) == "" {
		return ErrLoginRequired
	}
	usage := s.ensureDeviceUsage(deviceID)
	anonLimit := s.getSettingInt(settingAnonLimit, s.auth.AnonLimit)
	if anonLimit <= 0 || usage.RecognizeCount >= anonLimit {
		return ErrLoginRequired
	}
	if s.getSettingBool(settingAnonRequireAd, true) {
		if ok, err := s.repo.DecrementDeviceAdCredits(deviceID); err != nil {
			return err
		} else if !ok {
			return ErrAdRequired
		}
	}
	_ = s.repo.IncrementDeviceRecognize(deviceID)
	return nil
}

func (s *Service) RewardAd(user *model.User, deviceID string) error {
	if user != nil && user.ID > 0 && !isGuestUser(user) {
		return s.repo.IncrementUserAdCredits(user.ID, 1)
	}
	if strings.TrimSpace(deviceID) == "" {
		return fmt.Errorf("device_id required")
	}
	return s.repo.IncrementDeviceAdCredits(deviceID, 1)
}

func isGuestUser(user *model.User) bool {
	if user == nil {
		return false
	}
	if user.Status == "guest" {
		return true
	}
	return strings.HasPrefix(user.Email, "device:")
}

func randomDigits(n int) (string, error) {
	if n <= 0 {
		return "", fmt.Errorf("invalid length")
	}
	buf := make([]byte, n)
	for i := 0; i < n; i++ {
		b := make([]byte, 1)
		if _, err := rand.Read(b); err != nil {
			return "", err
		}
		buf[i] = '0' + (b[0] % 10)
	}
	return string(buf), nil
}

func randomToken(bytesLen int) (string, error) {
	if bytesLen <= 0 {
		bytesLen = 32
	}
	buf := make([]byte, bytesLen)
	if _, err := rand.Read(buf); err != nil {
		return "", err
	}
	return hex.EncodeToString(buf), nil
}

func (s *Service) IsDebugOTP() bool {
	return s.auth.DebugOTP
}

func (s *Service) DeleteSession(token string) error {
	if strings.TrimSpace(token) == "" {
		return nil
	}
	return s.repo.DeleteSessionByToken(token)
}

func (s *Service) getPlanSetting(plan string) PlanSetting {
	view, err := s.getPlanSettingView(plan)
	if err != nil {
		view = s.defaultPlanSettingView("free")
	}
	return PlanSetting{
		Name:          view.Code,
		QuotaTotal:    view.QuotaTotal,
		RetentionDays: view.RetentionDays,
		RequireAd:     view.RequireAd,
	}
}

func (s *Service) PurgeUserNotesByRetention(user *model.User) (int64, error) {
	if user == nil || user.ID == 0 {
		return 0, fmt.Errorf("user required")
	}
	cfg := s.getPlanSetting(user.Plan)
	if cfg.RetentionDays <= 0 {
		cfg.RetentionDays = s.auth.FreeRetentionDays
	}
	cutoff := time.Now().AddDate(0, 0, -cfg.RetentionDays)
	if s.storage != nil {
		batch := s.auth.RetentionPurgeBatchSize
		if batch <= 0 {
			batch = 200
		}
		offset := 0
		for {
			images, err := s.repo.ListImagesBefore(user.ID, cutoff, batch, offset)
			if err != nil {
				return 0, err
			}
			if len(images) == 0 {
				break
			}
			for _, img := range images {
				key := extractObjectKey(img.OriginalURL)
				if key == "" {
					continue
				}
				if err := s.storage.Delete(context.Background(), key); err != nil {
					// 不阻断清理流程
					continue
				}
			}
			offset += len(images)
		}
	}
	var total int64
	if n, err := s.repo.PurgeNotesBefore(user.ID, cutoff); err != nil {
		return total, err
	} else {
		total += n
	}
	if n, err := s.repo.PurgeResultsBefore(user.ID, cutoff); err != nil {
		return total, err
	} else {
		total += n
	}
	if n, err := s.repo.PurgeImagesBefore(user.ID, cutoff); err != nil {
		return total, err
	} else {
		total += n
	}
	return total, nil
}

func extractObjectKey(url string) string {
	u := strings.TrimSpace(url)
	if u == "" {
		return ""
	}
	if strings.HasPrefix(u, "agriscan/") {
		return u
	}
	if idx := strings.Index(u, "agriscan/"); idx >= 0 {
		return u[idx:]
	}
	if strings.Contains(u, "://") {
		if parsed, err := urlpkg.Parse(u); err == nil {
			return strings.TrimPrefix(parsed.Path, "/")
		}
	}
	return strings.TrimPrefix(u, "/")
}

func (s *Service) sendOTPEmail(email, code string) error {
	cfg := s.auth.SMTP
	if cfg.Server == "" || cfg.Account == "" || cfg.Token == "" {
		return fmt.Errorf("smtp not configured")
	}
	from := cfg.From
	if from == "" {
		from = cfg.Account
	}
	addr := fmt.Sprintf("%s:%d", cfg.Server, cfg.Port)

	var client *smtp.Client
	var err error
	if cfg.SSLEnabled {
		conn, err := tls.Dial("tcp", addr, &tls.Config{ServerName: cfg.Server})
		if err != nil {
			return err
		}
		client, err = smtp.NewClient(conn, cfg.Server)
		if err != nil {
			return err
		}
	} else {
		client, err = smtp.Dial(addr)
		if err != nil {
			return err
		}
	}
	defer client.Quit()

	auth := smtp.PlainAuth("", cfg.Account, cfg.Token, cfg.Server)
	if err := client.Auth(auth); err != nil {
		return err
	}
	if err := client.Mail(from); err != nil {
		return err
	}
	if err := client.Rcpt(email); err != nil {
		return err
	}
	w, err := client.Data()
	if err != nil {
		return err
	}
	msg := buildOTPEmail(from, email, code, s.auth.OTPMinutes)
	if _, err := w.Write([]byte(msg)); err != nil {
		_ = w.Close()
		return err
	}
	return w.Close()
}

func buildOTPEmail(from, to, code string, minutes int) string {
	subject := "AgriScan 登录验证码"
	body := fmt.Sprintf("你的验证码是：%s\n有效期 %d 分钟。\n如非本人操作请忽略。", code, minutes)
	headers := []string{
		fmt.Sprintf("From: %s", from),
		fmt.Sprintf("To: %s", to),
		fmt.Sprintf("Subject: %s", subject),
		"MIME-Version: 1.0",
		"Content-Type: text/plain; charset=\"UTF-8\"",
		"",
	}
	return strings.Join(headers, "\r\n") + body
}
