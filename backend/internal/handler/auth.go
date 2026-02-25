package handler

import (
	"agri-scan/internal/model"
	"agri-scan/internal/service"
	"errors"
	"net/http"
	"strconv"
	"strings"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

type Actor struct {
	User     *model.User
	UserID   uint
	DeviceID string
}

func (h *Handler) resolveActor(c *gin.Context) (*Actor, error) {
	token := strings.TrimSpace(c.GetHeader("X-Auth-Token"))
	if token != "" {
		if user, err := h.svc.GetUserByToken(token); err == nil && user != nil && user.ID > 0 {
			return &Actor{User: user, UserID: user.ID, DeviceID: c.GetHeader("X-Device-ID")}, nil
		}
	}

	userIDStr := strings.TrimSpace(c.GetHeader("X-User-ID"))
	if userIDStr != "" {
		if v, err := strconv.ParseUint(userIDStr, 10, 64); err == nil && v > 0 {
			return &Actor{UserID: uint(v), DeviceID: c.GetHeader("X-Device-ID")}, nil
		}
	}

	deviceID := strings.TrimSpace(c.GetHeader("X-Device-ID"))
	if deviceID != "" {
		user, err := h.svc.EnsureDeviceUser(deviceID)
		if err != nil {
			return nil, err
		}
		return &Actor{User: user, UserID: user.ID, DeviceID: deviceID}, nil
	}

	return nil, errors.New("unauthorized")
}

func (h *Handler) requireActor(c *gin.Context) (*Actor, bool) {
	actor, err := h.resolveActor(c)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return nil, false
	}
	return actor, true
}

// AuthAnonymous 初始化匿名设备
// POST /api/v1/auth/anonymous
func (h *Handler) AuthAnonymous(c *gin.Context) {
	var req struct {
		DeviceID string `json:"device_id"`
	}
	_ = c.ShouldBindJSON(&req)
	deviceID := strings.TrimSpace(req.DeviceID)
	if deviceID == "" {
		deviceID = strings.TrimSpace(c.GetHeader("X-Device-ID"))
	}
	if deviceID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "device_id required"})
		return
	}

	user, err := h.svc.EnsureDeviceUser(deviceID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	ent, err := h.svc.GetEntitlements(nil, deviceID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"device_id":    deviceID,
		"user_id":      user.ID,
		"plan":         ent.Plan,
		"entitlements": ent,
	})
}

// SendOTP 发送邮箱验证码
// POST /api/v1/auth/send-otp
func (h *Handler) SendOTP(c *gin.Context) {
	var req struct {
		Email string `json:"email" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request"})
		return
	}

	code, err := h.svc.SendEmailOTP(req.Email)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	resp := gin.H{"ok": true}
	if h.svcAuthDebug() {
		resp["debug_code"] = code
	}
	c.JSON(http.StatusOK, resp)
}

// VerifyOTP 校验邮箱验证码并登录
// POST /api/v1/auth/verify-otp
func (h *Handler) VerifyOTP(c *gin.Context) {
	var req struct {
		Email    string `json:"email" binding:"required"`
		Code     string `json:"code" binding:"required"`
		DeviceID string `json:"device_id"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request"})
		return
	}

	user, token, err := h.svc.VerifyEmailOTP(req.Email, req.Code, req.DeviceID)
	if err != nil {
		if errors.Is(err, service.ErrInvalidOTP) {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid code"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"token": token,
		"user":  user,
	})
}

// Logout 退出登录
// POST /api/v1/auth/logout
func (h *Handler) Logout(c *gin.Context) {
	token := strings.TrimSpace(c.GetHeader("X-Auth-Token"))
	if token != "" {
		_ = h.svc.DeleteSession(token)
	}
	c.JSON(http.StatusOK, gin.H{"ok": true})
}

// GetEntitlements 获取权限信息
// GET /api/v1/entitlements
func (h *Handler) GetEntitlements(c *gin.Context) {
	actor, _ := h.resolveActor(c)
	var user *model.User
	deviceID := ""
	if actor != nil {
		user = actor.User
		deviceID = actor.DeviceID
	}
	if deviceID == "" {
		deviceID = strings.TrimSpace(c.GetHeader("X-Device-ID"))
	}

	ent, err := h.svc.GetEntitlements(user, deviceID)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
			return
		}
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, ent)
}

// RewardAd 广告奖励
// POST /api/v1/usage/reward
func (h *Handler) RewardAd(c *gin.Context) {
	actor, err := h.resolveActor(c)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	if err := h.svc.RewardAd(actor.User, actor.DeviceID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	ent, err := h.svc.GetEntitlements(actor.User, actor.DeviceID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, ent)
}

func (h *Handler) svcAuthDebug() bool {
	return h.svc.IsDebugOTP()
}

func mapEntitlementError(c *gin.Context, err error) {
	switch {
	case errors.Is(err, service.ErrLoginRequired):
		c.JSON(http.StatusUnauthorized, gin.H{"error": "login_required"})
	case errors.Is(err, service.ErrAdRequired):
		c.JSON(http.StatusForbidden, gin.H{"error": "ad_required"})
	case errors.Is(err, service.ErrQuotaExceeded):
		c.JSON(http.StatusPaymentRequired, gin.H{"error": "quota_exceeded"})
	default:
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
	}
}
