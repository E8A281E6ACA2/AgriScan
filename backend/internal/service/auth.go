package service

import (
	"agri-scan/internal/model"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"strings"
	"time"

	"gorm.io/gorm"
)

var (
	ErrLoginRequired = errors.New("login_required")
	ErrAdRequired    = errors.New("ad_required")
	ErrQuotaExceeded = errors.New("quota_exceeded")
	ErrInvalidOTP    = errors.New("invalid_otp")
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
		ent.UserID = user.ID
		ent.Plan = user.Plan
		ent.AdCredits = user.AdCredits
		ent.QuotaTotal = user.QuotaTotal
		ent.QuotaUsed = user.QuotaUsed
		if user.Plan == "paid" {
			ent.RequireAd = false
			ent.RetentionDays = s.auth.PaidRetentionDays
		} else {
			ent.RequireAd = user.AdCredits <= 0
			ent.RetentionDays = s.auth.FreeRetentionDays
		}
		if user.QuotaTotal > 0 {
			ent.QuotaRemaining = user.QuotaTotal - user.QuotaUsed
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
	ent.AnonymousRemaining = s.auth.AnonLimit - usage.RecognizeCount
	if ent.AnonymousRemaining < 0 {
		ent.AnonymousRemaining = 0
	}
	ent.RequireLogin = usage.RecognizeCount >= s.auth.AnonLimit
	ent.AdCredits = usage.AdCredits
	ent.RequireAd = !ent.RequireLogin && usage.AdCredits <= 0
	return ent, nil
}

func (s *Service) ConsumeRecognition(user *model.User, deviceID string) error {
	if user != nil && user.ID > 0 && !isGuestUser(user) {
		if user.Plan == "paid" {
			if user.QuotaTotal > 0 && user.QuotaUsed >= user.QuotaTotal {
				return ErrQuotaExceeded
			}
			_ = s.repo.IncrementUserQuotaUsed(user.ID)
			return nil
		}
		if ok, err := s.repo.DecrementUserAdCredits(user.ID); err != nil {
			return err
		} else if !ok {
			return ErrAdRequired
		}
		_ = s.repo.IncrementUserQuotaUsed(user.ID)
		return nil
	}

	if strings.TrimSpace(deviceID) == "" {
		return ErrLoginRequired
	}
	usage := s.ensureDeviceUsage(deviceID)
	if usage.RecognizeCount >= s.auth.AnonLimit {
		return ErrLoginRequired
	}
	if ok, err := s.repo.DecrementDeviceAdCredits(deviceID); err != nil {
		return err
	} else if !ok {
		return ErrAdRequired
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
