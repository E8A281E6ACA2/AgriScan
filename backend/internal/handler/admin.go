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
	if token != "" && token == adminToken {
		return true
	}
	user, err := h.svc.GetUserByToken(strings.TrimSpace(c.GetHeader("X-Auth-Token")))
	if err == nil && user != nil && user.IsAdmin {
		return true
	}
	c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
	return false
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

// GET /api/v1/admin/stats
func (h *Handler) AdminStats(c *gin.Context) {
	if !h.requireAdmin(c) {
		return
	}
	stats, err := h.svc.GetAdminStats()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, stats)
}

// GET /api/v1/admin/plan-settings
func (h *Handler) AdminPlanSettings(c *gin.Context) {
	if !h.requireAdmin(c) {
		return
	}
	items, err := h.svc.GetPlanSettings()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"results": items})
}

// PUT /api/v1/admin/plan-settings/:code
func (h *Handler) AdminUpdatePlanSetting(c *gin.Context) {
	if !h.requireAdmin(c) {
		return
	}
	code := strings.TrimSpace(c.Param("code"))
	if code == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid code"})
		return
	}
	var req service.PlanSettingUpdate
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request"})
		return
	}
	item, err := h.svc.UpdatePlanSetting(code, req)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	h.svc.RecordAdminAudit("update_plan", "plan", 0, code, c.ClientIP())
	c.JSON(http.StatusOK, item)
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
	h.svc.RecordAdminAudit("update_user", "user", uint(id), "update", c.ClientIP())
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
	h.svc.RecordAdminAudit("purge_user", "user", uint(id), "retention purge", c.ClientIP())
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

// GET /api/v1/admin/audit-logs
func (h *Handler) AdminAuditLogs(c *gin.Context) {
	if !h.requireAdmin(c) {
		return
	}
	limitStr := c.DefaultQuery("limit", "50")
	offsetStr := c.DefaultQuery("offset", "0")
	action := strings.TrimSpace(c.DefaultQuery("action", ""))
	limit, _ := strconv.Atoi(limitStr)
	offset, _ := strconv.Atoi(offsetStr)
	items, err := h.svc.ListAdminAuditLogs(limit, offset, action)
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
	h.svc.RecordAdminAudit("approve_membership", "membership_request", uint(id), "approve", c.ClientIP())
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
	h.svc.RecordAdminAudit("reject_membership", "membership_request", uint(id), "reject", c.ClientIP())
	c.JSON(http.StatusOK, gin.H{"ok": true})
}

// POST /api/v1/admin/users/:id/quota
func (h *Handler) AdminAddQuota(c *gin.Context) {
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
		Delta int `json:"delta" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil || req.Delta <= 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid delta"})
		return
	}
	user, err := h.svc.AddUserQuota(uint(id), req.Delta)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	h.svc.RecordAdminAudit("add_quota", "user", uint(id), "delta", c.ClientIP())
	c.JSON(http.StatusOK, user)
}

// GET /api/v1/admin/labels
func (h *Handler) AdminLabelQueue(c *gin.Context) {
	if !h.requireAdmin(c) {
		return
	}
	limitStr := c.DefaultQuery("limit", "20")
	offsetStr := c.DefaultQuery("offset", "0")
	status := c.DefaultQuery("status", "pending")
	category := c.DefaultQuery("category", "")
	cropType := c.DefaultQuery("crop_type", "")
	limit, _ := strconv.Atoi(limitStr)
	offset, _ := strconv.Atoi(offsetStr)
	items, err := h.svc.ListLabelNotes(limit, offset, status, category, cropType)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"results": items, "limit": limit, "offset": offset})
}

// POST /api/v1/admin/labels/:id
func (h *Handler) AdminLabelNote(c *gin.Context) {
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
		Category string   `json:"category"`
		CropType string   `json:"crop_type"`
		Tags     []string `json:"tags"`
		Note     string   `json:"note"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request"})
		return
	}
	if err := h.svc.UpdateLabelNote(uint(id), req.Category, req.CropType, req.Tags, req.Note); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	h.svc.RecordAdminAudit("label_note", "note", uint(id), "label", c.ClientIP())
	c.JSON(http.StatusOK, gin.H{"ok": true})
}

// POST /api/v1/admin/labels/:id/review
func (h *Handler) AdminReviewLabel(c *gin.Context) {
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
		Status   string `json:"status"`
		Reviewer string `json:"reviewer"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request"})
		return
	}
	reviewer := strings.TrimSpace(req.Reviewer)
	if reviewer == "" {
		reviewer = "admin"
	}
	if err := h.svc.ReviewLabelNote(uint(id), strings.TrimSpace(req.Status), reviewer); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	h.svc.RecordAdminAudit("review_label", "note", uint(id), req.Status, c.ClientIP())
	c.JSON(http.StatusOK, gin.H{"ok": true})
}

// GET /api/v1/admin/eval/summary
func (h *Handler) AdminEvalSummary(c *gin.Context) {
	if !h.requireAdmin(c) {
		return
	}
	daysStr := c.DefaultQuery("days", "30")
	days, _ := strconv.Atoi(daysStr)
	summary, err := h.svc.GetEvalSummary(days)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, summary)
}

// GET /api/v1/admin/export/eval
func (h *Handler) AdminExportEval(c *gin.Context) {
	if !h.requireAdmin(c) {
		return
	}
	format := strings.ToLower(strings.TrimSpace(c.DefaultQuery("format", "csv")))
	startDate, endDate, err := parseDateRange(c.DefaultQuery("start_date", ""), c.DefaultQuery("end_date", ""))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	if format == "json" {
		c.Header("Content-Type", "application/json; charset=utf-8")
		c.Header("Content-Disposition", "attachment; filename=eval_dataset.json")
		if err := h.svc.ExportEvalDatasetJSON(c.Writer, startDate, endDate); err != nil {
			c.Status(http.StatusInternalServerError)
		}
		return
	}
	c.Header("Content-Type", "text/csv; charset=utf-8")
	c.Header("Content-Disposition", "attachment; filename=eval_dataset.csv")
	if err := h.svc.ExportEvalDatasetCSV(c.Writer, startDate, endDate); err != nil {
		c.Status(http.StatusInternalServerError)
	}
}

// GET /api/v1/admin/export/users
func (h *Handler) AdminExportUsers(c *gin.Context) {
	if !h.requireAdmin(c) {
		return
	}
	startDate, endDate, err := parseDateRange(c.DefaultQuery("start_date", ""), c.DefaultQuery("end_date", ""))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.Header("Content-Type", "text/csv; charset=utf-8")
	c.Header("Content-Disposition", "attachment; filename=users.csv")
	if err := h.svc.ExportAdminUsersCSV(c.Writer, startDate, endDate); err != nil {
		c.Status(http.StatusInternalServerError)
	}
}

// GET /api/v1/admin/export/notes
func (h *Handler) AdminExportNotes(c *gin.Context) {
	if !h.requireAdmin(c) {
		return
	}
	startDate, endDate, err := parseDateRange(c.DefaultQuery("start_date", ""), c.DefaultQuery("end_date", ""))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.Header("Content-Type", "text/csv; charset=utf-8")
	c.Header("Content-Disposition", "attachment; filename=notes_admin.csv")
	if err := h.svc.ExportAdminNotesCSV(c.Writer, startDate, endDate); err != nil {
		c.Status(http.StatusInternalServerError)
	}
}

// GET /api/v1/admin/export/feedback
func (h *Handler) AdminExportFeedback(c *gin.Context) {
	if !h.requireAdmin(c) {
		return
	}
	startDate, endDate, err := parseDateRange(c.DefaultQuery("start_date", ""), c.DefaultQuery("end_date", ""))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.Header("Content-Type", "text/csv; charset=utf-8")
	c.Header("Content-Disposition", "attachment; filename=feedback.csv")
	if err := h.svc.ExportAdminFeedbackCSV(c.Writer, startDate, endDate); err != nil {
		c.Status(http.StatusInternalServerError)
	}
}
