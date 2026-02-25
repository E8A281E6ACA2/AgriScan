package repository

import (
	"agri-scan/internal/model"
	"time"

	"gorm.io/gorm"
)

// User
func (r *Repository) GetUserByEmail(email string) (*model.User, error) {
	var user model.User
	err := r.db.Where("email = ?", email).First(&user).Error
	return &user, err
}

func (r *Repository) GetUserByID(id uint) (*model.User, error) {
	var user model.User
	err := r.db.First(&user, id).Error
	return &user, err
}

func (r *Repository) CreateUser(user *model.User) error {
	return r.db.Create(user).Error
}

func (r *Repository) UpdateUser(user *model.User) error {
	return r.db.Save(user).Error
}

// Session
func (r *Repository) CreateSession(session *model.UserSession) error {
	return r.db.Create(session).Error
}

func (r *Repository) GetSessionByToken(token string) (*model.UserSession, error) {
	var s model.UserSession
	err := r.db.Where("token = ?", token).First(&s).Error
	return &s, err
}

func (r *Repository) DeleteSessionByToken(token string) error {
	return r.db.Where("token = ?", token).Delete(&model.UserSession{}).Error
}

// OTP
func (r *Repository) CreateEmailOTP(otp *model.EmailOTP) error {
	return r.db.Create(otp).Error
}

func (r *Repository) GetLatestEmailOTP(email string) (*model.EmailOTP, error) {
	var otp model.EmailOTP
	err := r.db.Where("email = ?", email).Order("created_at DESC").First(&otp).Error
	return &otp, err
}

func (r *Repository) CreateEmailLog(logItem *model.EmailLog) error {
	return r.db.Create(logItem).Error
}

func (r *Repository) ListEmailLogs(limit, offset int, email string) ([]model.EmailLog, error) {
	var items []model.EmailLog
	query := r.db.Model(&model.EmailLog{})
	if email != "" {
		query = query.Where("email = ?", email)
	}
	err := query.Order("created_at DESC").Limit(limit).Offset(offset).Find(&items).Error
	return items, err
}

// Membership requests
func (r *Repository) CreateMembershipRequest(req *model.MembershipRequest) error {
	return r.db.Create(req).Error
}

func (r *Repository) GetPendingMembershipRequestByUser(userID uint) (*model.MembershipRequest, error) {
	var req model.MembershipRequest
	err := r.db.Where("user_id = ? AND status = ?", userID, "pending").Order("created_at DESC").First(&req).Error
	return &req, err
}

func (r *Repository) ListMembershipRequests(limit, offset int, status string) ([]model.MembershipRequest, error) {
	var items []model.MembershipRequest
	query := r.db.Model(&model.MembershipRequest{})
	if status != "" {
		query = query.Where("status = ?", status)
	}
	err := query.Order("created_at DESC").Limit(limit).Offset(offset).Find(&items).Error
	return items, err
}

func (r *Repository) UpdateMembershipRequestStatus(id uint, status string) error {
	return r.db.Model(&model.MembershipRequest{}).Where("id = ?", id).Update("status", status).Error
}

func (r *Repository) GetMembershipRequestByID(id uint) (*model.MembershipRequest, error) {
	var req model.MembershipRequest
	err := r.db.First(&req, id).Error
	return &req, err
}

func (r *Repository) GetValidEmailOTP(email, code string, now time.Time) (*model.EmailOTP, error) {
	var otp model.EmailOTP
	err := r.db.Where("email = ? AND code = ? AND used_at IS NULL AND expires_at > ?", email, code, now).First(&otp).Error
	return &otp, err
}

func (r *Repository) MarkEmailOTPUsed(id uint, usedAt time.Time) error {
	return r.db.Model(&model.EmailOTP{}).Where("id = ?", id).Update("used_at", usedAt).Error
}

// Device
func (r *Repository) GetDeviceByDeviceID(deviceID string) (*model.Device, error) {
	var dev model.Device
	err := r.db.Where("device_id = ?", deviceID).First(&dev).Error
	return &dev, err
}

func (r *Repository) CreateDevice(dev *model.Device) error {
	return r.db.Create(dev).Error
}

func (r *Repository) UpdateDeviceUser(deviceID string, userID uint) error {
	return r.db.Model(&model.Device{}).Where("device_id = ?", deviceID).Update("user_id", userID).Error
}

// DeviceUsage
func (r *Repository) GetDeviceUsage(deviceID string) (*model.DeviceUsage, error) {
	var usage model.DeviceUsage
	err := r.db.Where("device_id = ?", deviceID).First(&usage).Error
	return &usage, err
}

func (r *Repository) CreateDeviceUsage(usage *model.DeviceUsage) error {
	return r.db.Create(usage).Error
}

func (r *Repository) UpdateDeviceUsage(usage *model.DeviceUsage) error {
	return r.db.Save(usage).Error
}

func (r *Repository) IncrementDeviceRecognize(deviceID string) error {
	return r.db.Model(&model.DeviceUsage{}).
		Where("device_id = ?", deviceID).
		Update("recognize_count", gorm.Expr("recognize_count + 1")).Error
}

func (r *Repository) IncrementDeviceAdCredits(deviceID string, delta int) error {
	return r.db.Model(&model.DeviceUsage{}).
		Where("device_id = ?", deviceID).
		Update("ad_credits", gorm.Expr("ad_credits + ?", delta)).Error
}

func (r *Repository) DecrementDeviceAdCredits(deviceID string) (bool, error) {
	res := r.db.Model(&model.DeviceUsage{}).
		Where("device_id = ? AND ad_credits > 0", deviceID).
		Update("ad_credits", gorm.Expr("ad_credits - 1"))
	return res.RowsAffected > 0, res.Error
}

// User usage
func (r *Repository) IncrementUserQuotaUsed(userID uint) error {
	return r.db.Model(&model.User{}).
		Where("id = ?", userID).
		Update("quota_used", gorm.Expr("quota_used + 1")).Error
}

func (r *Repository) IncrementUserAdCredits(userID uint, delta int) error {
	return r.db.Model(&model.User{}).
		Where("id = ?", userID).
		Update("ad_credits", gorm.Expr("ad_credits + ?", delta)).Error
}

func (r *Repository) DecrementUserAdCredits(userID uint) (bool, error) {
	res := r.db.Model(&model.User{}).
		Where("id = ? AND ad_credits > 0", userID).
		Update("ad_credits", gorm.Expr("ad_credits - 1"))
	return res.RowsAffected > 0, res.Error
}

func (r *Repository) TransferUserData(fromUserID, toUserID uint) error {
	if fromUserID == 0 || toUserID == 0 || fromUserID == toUserID {
		return nil
	}
	if err := r.db.Model(&model.Image{}).Where("user_id = ?", fromUserID).Update("user_id", toUserID).Error; err != nil {
		return err
	}
	if err := r.db.Model(&model.FieldNote{}).Where("user_id = ?", fromUserID).Update("user_id", toUserID).Error; err != nil {
		return err
	}
	if err := r.db.Model(&model.ExportTemplate{}).Where("user_id = ?", fromUserID).Update("user_id", toUserID).Error; err != nil {
		return err
	}
	return nil
}

func (r *Repository) ListUsers(limit, offset int, keyword string) ([]model.User, error) {
	var users []model.User
	query := r.db.Model(&model.User{})
	if keyword != "" {
		kw := "%" + keyword + "%"
		query = query.Where("email ILIKE ? OR nickname ILIKE ?", kw, kw)
	}
	err := query.Order("created_at DESC").Limit(limit).Offset(offset).Find(&users).Error
	return users, err
}
