package handler

import (
	"agri-scan/internal/service"
	"net/http"
	"os"
	"strconv"
	"strings"

	"github.com/gin-gonic/gin"
)

func (h *Handler) requireAdmin(c *gin.Context) bool {
	token := strings.TrimSpace(c.GetHeader("X-Admin-Token"))
	adminToken := strings.TrimSpace(os.Getenv("ADMIN_TOKEN"))
	if adminToken == "" {
		adminToken = "admin-token"
	}
	if token == "" || token != adminToken {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return false
	}
	return true
}

// GET /api/v1/admin/users
func (h *Handler) AdminListUsers(c *gin.Context) {
	if !h.requireAdmin(c) {
		return
	}
	limitStr := c.DefaultQuery("limit", "20")
	offsetStr := c.DefaultQuery("offset", "0")
	keyword := c.DefaultQuery("q", "")
	limit, _ := strconv.Atoi(limitStr)
	offset, _ := strconv.Atoi(offsetStr)

	items, err := h.svc.ListUsers(limit, offset, keyword)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"results": items, "limit": limit, "offset": offset})
}

// PUT /api/v1/admin/users/:id
func (h *Handler) AdminUpdateUser(c *gin.Context) {
	if !h.requireAdmin(c) {
		return
	}
	idStr := c.Param("id")
	id, err := strconv.ParseUint(idStr, 10, 64)
	if err != nil || id == 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid id"})
		return
	}
	var req struct {
		Plan       string `json:"plan"`
		Status     string `json:"status"`
		QuotaTotal *int   `json:"quota_total"`
		QuotaUsed  *int   `json:"quota_used"`
		AdCredits  *int   `json:"ad_credits"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request"})
		return
	}

	update := service.UserUpdate{
		Plan:       strings.TrimSpace(req.Plan),
		Status:     strings.TrimSpace(req.Status),
		QuotaTotal: -1,
		QuotaUsed:  -1,
		AdCredits:  -1,
	}
	if req.QuotaTotal != nil {
		update.QuotaTotal = *req.QuotaTotal
	}
	if req.QuotaUsed != nil {
		update.QuotaUsed = *req.QuotaUsed
	}
	if req.AdCredits != nil {
		update.AdCredits = *req.AdCredits
	}
	user, err := h.svc.UpdateUserByID(uint(id), update)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, user)
}

// POST /api/v1/admin/users/:id/purge
func (h *Handler) AdminPurgeUser(c *gin.Context) {
	if !h.requireAdmin(c) {
		return
	}
	idStr := c.Param("id")
	id, err := strconv.ParseUint(idStr, 10, 64)
	if err != nil || id == 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid id"})
		return
	}
	user, err := h.svc.GetUserByID(uint(id))
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "user not found"})
		return
	}
	count, err := h.svc.PurgeUserNotesByRetention(user)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"purged": count})
}

// GET /api/v1/admin/email-logs
func (h *Handler) AdminEmailLogs(c *gin.Context) {
	if !h.requireAdmin(c) {
		return
	}
	limitStr := c.DefaultQuery("limit", "50")
	offsetStr := c.DefaultQuery("offset", "0")
	email := strings.TrimSpace(c.DefaultQuery("email", ""))
	limit, _ := strconv.Atoi(limitStr)
	offset, _ := strconv.Atoi(offsetStr)

	items, err := h.svc.ListEmailLogs(limit, offset, email)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"results": items, "limit": limit, "offset": offset})
}

// GET /api/v1/admin/membership-requests
func (h *Handler) AdminMembershipRequests(c *gin.Context) {
	if !h.requireAdmin(c) {
		return
	}
	limitStr := c.DefaultQuery("limit", "50")
	offsetStr := c.DefaultQuery("offset", "0")
	status := strings.TrimSpace(c.DefaultQuery("status", ""))
	limit, _ := strconv.Atoi(limitStr)
	offset, _ := strconv.Atoi(offsetStr)

	items, err := h.svc.ListMembershipRequests(limit, offset, status)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"results": items, "limit": limit, "offset": offset})
}

// POST /api/v1/admin/membership-requests/:id/approve
func (h *Handler) AdminApproveMembership(c *gin.Context) {
	if !h.requireAdmin(c) {
		return
	}
	idStr := c.Param("id")
	id, err := strconv.ParseUint(idStr, 10, 64)
	if err != nil || id == 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid id"})
		return
	}
	var req struct {
		Plan       string `json:"plan"`
		QuotaTotal *int   `json:"quota_total"`
	}
	_ = c.ShouldBindJSON(&req)
	user, err := h.svc.ApproveMembershipRequest(uint(id), strings.TrimSpace(req.Plan), req.QuotaTotal)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, user)
}

// POST /api/v1/admin/membership-requests/:id/reject
func (h *Handler) AdminRejectMembership(c *gin.Context) {
	if !h.requireAdmin(c) {
		return
	}
	idStr := c.Param("id")
	id, err := strconv.ParseUint(idStr, 10, 64)
	if err != nil || id == 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid id"})
		return
	}
	if err := h.svc.RejectMembershipRequest(uint(id)); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"ok": true})
}
