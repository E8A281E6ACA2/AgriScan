package handler

import (
	"agri-scan/internal/model"
	"agri-scan/internal/service"
	"fmt"
	"log"
	"mime/multipart"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
)

type Handler struct {
	svc *service.Service
}

func NewHandler(svc *service.Service) *Handler {
	return &Handler{svc: svc}
}

// UploadResponse 上传响应
type UploadResponse struct {
	ImageID       uint   `json:"image_id"`
	OriginalURL   string `json:"original_url"`
	CompressedURL string `json:"compressed_url"`
}

// RecognizeResponse 识别响应
type RecognizeResponse struct {
	RawText        string   `json:"raw_text"`
	ResultID       uint     `json:"result_id"`
	ImageID        uint     `json:"image_id"`
	CropType       string   `json:"crop_type"`
	Confidence     float64  `json:"confidence"`
	ConfidenceLow  float64  `json:"confidence_low"`
	ConfidenceHigh float64  `json:"confidence_high"`
	Description    string   `json:"description"`
	GrowthStage    *string  `json:"growth_stage"`
	PossibleIssue  *string  `json:"possible_issue"`
	Provider       string   `json:"provider"`
	ImageURL       string   `json:"image_url,omitempty"`
	Latitude       *float64 `json:"latitude,omitempty"`
	Longitude      *float64 `json:"longitude,omitempty"`
	RiskLevel      string   `json:"risk_level"`
	RiskNote       string   `json:"risk_note"`
}

type RecognizeURLRequest struct {
	ImageURL string `json:"image_url" binding:"required"`
}

// RecognizeByURL 使用外部图片 URL 识别
// POST /api/v1/recognize-url
func (h *Handler) RecognizeByURL(c *gin.Context) {
	var req RecognizeURLRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request"})
		return
	}

	actor, ok := h.requireActor(c)
	if !ok {
		return
	}

	if !h.consumeRecognition(c, actor) {
		return
	}

	img, err := h.svc.CreateImageFromURL(actor.UserID, req.ImageURL)
	if err != nil {
		h.svc.RecordFailure(actor.UserID, nil, "", "create_image_url", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	result, err := h.svc.Recognize(img.OriginalURL)
	if err != nil {
		h.svc.RecordFailure(actor.UserID, &img.ID, "", "recognize", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	savedResult, err := h.svc.SaveResult(img.ID, result)
	if err != nil {
		h.svc.RecordFailure(actor.UserID, &img.ID, "", "save_result", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	_, _ = h.svc.CreateNote(actor.UserID, img.ID, &savedResult.ID, "", "crop", nil)
	low, high, riskLevel, riskNote := explainConfidence(savedResult.Confidence)

	c.JSON(http.StatusOK, RecognizeResponse{
		RawText:        savedResult.RawText,
		ResultID:       savedResult.ID,
		ImageID:        savedResult.ImageID,
		CropType:       savedResult.CropType,
		Confidence:     savedResult.Confidence,
		ConfidenceLow:  low,
		ConfidenceHigh: high,
		Description:    savedResult.Description,
		GrowthStage:    savedResult.GrowthStage,
		PossibleIssue:  savedResult.PossibleIssue,
		Provider:       savedResult.Provider,
		ImageURL:       img.OriginalURL,
		Latitude:       img.Latitude,
		Longitude:      img.Longitude,
		RiskLevel:      riskLevel,
		RiskNote:       riskNote,
	})
}

// UploadImage 上传图片
// POST /api/v1/upload
func (h *Handler) UploadImage(c *gin.Context) {
	actor, ok := h.requireActor(c)
	if !ok {
		return
	}

	// 检查是否是 base64 上传
	imageData := c.PostForm("image")
	imageType := c.PostForm("type")
	latStr := c.PostForm("latitude")
	lngStr := c.PostForm("longitude")
	var lat *float64
	var lng *float64
	if latStr != "" {
		if v, err := strconv.ParseFloat(latStr, 64); err == nil {
			lat = &v
		}
	}
	if lngStr != "" {
		if v, err := strconv.ParseFloat(lngStr, 64); err == nil {
			lng = &v
		}
	}

	if imageType == "base64" && imageData != "" {
		// Base64 上传（Web 端）
		img, err := h.svc.UploadImageBase64(actor.UserID, imageData, lat, lng)
		if err != nil {
			log.Printf("UploadImageBase64 failed: %v", err)
			h.svc.RecordFailure(actor.UserID, nil, "", "upload_base64", err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusOK, UploadResponse{
			ImageID:       img.ID,
			OriginalURL:   img.OriginalURL,
			CompressedURL: img.CompressedURL,
		})
		return
	}

	// 文件上传（移动端）
	file, err := c.FormFile("image")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "no image file"})
		return
	}

	// 上传到对象存储
	img, err := h.svc.UploadImage(actor.UserID, file, lat, lng)
	if err != nil {
		h.svc.RecordFailure(actor.UserID, nil, "", "upload_file", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, UploadResponse{
		ImageID:       img.ID,
		OriginalURL:   img.OriginalURL,
		CompressedURL: img.CompressedURL,
	})
}

// Recognize 发起识别
// POST /api/v1/recognize
func (h *Handler) Recognize(c *gin.Context) {
	var req struct {
		ImageID uint `json:"image_id" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request"})
		return
	}

	actor, ok := h.requireActor(c)
	if !ok {
		return
	}

	// 获取图片信息
	img, err := h.svc.GetImage(req.ImageID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "image not found"})
		return
	}

	if !h.consumeRecognition(c, actor) {
		return
	}

	// 调用大模型识别
	result, err := h.svc.Recognize(img.OriginalURL)
	if err != nil {
		h.svc.RecordFailure(actor.UserID, &img.ID, "", "recognize", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	// 保存识别结果
	savedResult, err := h.svc.SaveResult(req.ImageID, result)
	if err != nil {
		h.svc.RecordFailure(actor.UserID, &img.ID, "", "save_result", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	// 自动创建手记
	_, _ = h.svc.CreateNote(actor.UserID, req.ImageID, &savedResult.ID, "", "crop", nil)
	low, high, riskLevel, riskNote := explainConfidence(savedResult.Confidence)

	c.JSON(http.StatusOK, RecognizeResponse{
		RawText:        savedResult.RawText,
		ResultID:       savedResult.ID,
		ImageID:        savedResult.ImageID,
		CropType:       savedResult.CropType,
		Confidence:     savedResult.Confidence,
		ConfidenceLow:  low,
		ConfidenceHigh: high,
		Description:    savedResult.Description,
		GrowthStage:    savedResult.GrowthStage,
		PossibleIssue:  savedResult.PossibleIssue,
		Provider:       savedResult.Provider,
		ImageURL:       img.OriginalURL,
		Latitude:       img.Latitude,
		Longitude:      img.Longitude,
		RiskLevel:      riskLevel,
		RiskNote:       riskNote,
	})
}

// GetResult 获取识别结果
// GET /api/v1/result/:id
func (h *Handler) GetResult(c *gin.Context) {
	idStr := c.Param("id")
	id, err := strconv.ParseUint(idStr, 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid id"})
		return
	}

	result, err := h.svc.GetResultByID(uint(id))
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "result not found"})
		return
	}

	imageURL := ""
	var lat *float64
	var lng *float64
	if img, err := h.svc.GetImage(result.ImageID); err == nil {
		imageURL = img.OriginalURL
		lat = img.Latitude
		lng = img.Longitude
	}

	low, high, riskLevel, riskNote := explainConfidence(result.Confidence)
	c.JSON(http.StatusOK, RecognizeResponse{
		RawText:        result.RawText,
		ResultID:       result.ID,
		ImageID:        result.ImageID,
		CropType:       result.CropType,
		Confidence:     result.Confidence,
		ConfidenceLow:  low,
		ConfidenceHigh: high,
		Description:    result.Description,
		GrowthStage:    result.GrowthStage,
		PossibleIssue:  result.PossibleIssue,
		Provider:       result.Provider,
		ImageURL:       imageURL,
		Latitude:       lat,
		Longitude:      lng,
		RiskLevel:      riskLevel,
		RiskNote:       riskNote,
	})
}

// GetHistory 获取历史记录
// GET /api/v1/history
func (h *Handler) GetHistory(c *gin.Context) {
	actor, ok := h.requireActor(c)
	if !ok {
		return
	}

	ent, err := h.svc.GetEntitlements(actor.User, actor.DeviceID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	if ent.RequireLogin {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "login_required"})
		return
	}

	limitStr := c.DefaultQuery("limit", "20")
	offsetStr := c.DefaultQuery("offset", "0")
	cropType := strings.TrimSpace(c.DefaultQuery("crop_type", ""))
	minConfStr := strings.TrimSpace(c.DefaultQuery("min_conf", ""))
	maxConfStr := strings.TrimSpace(c.DefaultQuery("max_conf", ""))
	startDateStr := c.DefaultQuery("start_date", "")
	endDateStr := c.DefaultQuery("end_date", "")

	limit, _ := strconv.Atoi(limitStr)
	offset, _ := strconv.Atoi(offsetStr)

	startDate, endDate, err := parseDateRange(startDateStr, endDateStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	var minConf *float64
	var maxConf *float64
	if minConfStr != "" {
		if v, err := strconv.ParseFloat(minConfStr, 64); err == nil {
			if v < 0 || v > 1 {
				c.JSON(http.StatusBadRequest, gin.H{"error": "invalid min_conf"})
				return
			}
			minConf = &v
		} else {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid min_conf"})
			return
		}
	}
	if maxConfStr != "" {
		if v, err := strconv.ParseFloat(maxConfStr, 64); err == nil {
			if v < 0 || v > 1 {
				c.JSON(http.StatusBadRequest, gin.H{"error": "invalid max_conf"})
				return
			}
			maxConf = &v
		} else {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid max_conf"})
			return
		}
	}
	if minConf != nil && maxConf != nil && *minConf > *maxConf {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid confidence range"})
		return
	}

	if ent.RetentionDays > 0 {
		cutoff := time.Now().AddDate(0, 0, -ent.RetentionDays)
		if startDate == nil || startDate.Before(cutoff) {
			startDate = &cutoff
		}
	}
	results, err := h.svc.GetHistory(actor.UserID, limit, offset, startDate, endDate, cropType, minConf, maxConf)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	response := make([]RecognizeResponse, 0, len(results))
	for _, r := range results {
		low, high, riskLevel, riskNote := explainConfidence(r.Confidence)
		resp := RecognizeResponse{
			RawText:        r.RawText,
			ResultID:       r.ID,
			ImageID:        r.ImageID,
			CropType:       r.CropType,
			Confidence:     r.Confidence,
			ConfidenceLow:  low,
			ConfidenceHigh: high,
			Description:    r.Description,
			GrowthStage:    r.GrowthStage,
			PossibleIssue:  r.PossibleIssue,
			Provider:       r.Provider,
			ImageURL:       r.Image.OriginalURL,
			Latitude:       r.Image.Latitude,
			Longitude:      r.Image.Longitude,
			RiskLevel:      riskLevel,
			RiskNote:       riskNote,
		}
		response = append(response, resp)
	}

	c.JSON(http.StatusOK, gin.H{
		"results": response,
		"limit":   limit,
		"offset":  offset,
	})
}

// ExportHistory 导出历史记录 CSV/JSON
// GET /api/v1/history/export
func (h *Handler) ExportHistory(c *gin.Context) {
	actor, ok := h.requireActor(c)
	if !ok {
		return
	}

	ent, err := h.svc.GetEntitlements(actor.User, actor.DeviceID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	if ent.RequireLogin {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "login_required"})
		return
	}

	cropType := strings.TrimSpace(c.DefaultQuery("crop_type", ""))
	minConfStr := strings.TrimSpace(c.DefaultQuery("min_conf", ""))
	maxConfStr := strings.TrimSpace(c.DefaultQuery("max_conf", ""))
	startDateStr := c.DefaultQuery("start_date", "")
	endDateStr := c.DefaultQuery("end_date", "")
	format := strings.ToLower(strings.TrimSpace(c.DefaultQuery("format", "csv")))

	startDate, endDate, err := parseDateRange(startDateStr, endDateStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	var minConf *float64
	var maxConf *float64
	if minConfStr != "" {
		if v, err := strconv.ParseFloat(minConfStr, 64); err == nil {
			if v < 0 || v > 1 {
				c.JSON(http.StatusBadRequest, gin.H{"error": "invalid min_conf"})
				return
			}
			minConf = &v
		} else {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid min_conf"})
			return
		}
	}
	if maxConfStr != "" {
		if v, err := strconv.ParseFloat(maxConfStr, 64); err == nil {
			if v < 0 || v > 1 {
				c.JSON(http.StatusBadRequest, gin.H{"error": "invalid max_conf"})
				return
			}
			maxConf = &v
		} else {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid max_conf"})
			return
		}
	}
	if minConf != nil && maxConf != nil && *minConf > *maxConf {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid confidence range"})
		return
	}

	if ent.RetentionDays > 0 {
		cutoff := time.Now().AddDate(0, 0, -ent.RetentionDays)
		if startDate == nil || startDate.Before(cutoff) {
			startDate = &cutoff
		}
	}

	if format == "json" {
		c.Header("Content-Type", "application/json; charset=utf-8")
		c.Header("Content-Disposition", "attachment; filename=history.json")
		if err := h.svc.ExportHistoryJSON(c.Writer, actor.UserID, startDate, endDate, cropType, minConf, maxConf); err != nil {
			c.Status(http.StatusInternalServerError)
		}
		return
	}
	c.Header("Content-Type", "text/csv; charset=utf-8")
	c.Header("Content-Disposition", "attachment; filename=history.csv")
	if err := h.svc.ExportHistoryCSV(c.Writer, actor.UserID, startDate, endDate, cropType, minConf, maxConf); err != nil {
		c.Status(http.StatusInternalServerError)
	}
}

// SubmitFeedback 提交用户反馈
// POST /api/v1/feedback
func (h *Handler) SubmitFeedback(c *gin.Context) {
	var req struct {
		ResultID      uint     `json:"result_id" binding:"required"`
		CorrectedType string   `json:"corrected_type"`
		FeedbackNote  string   `json:"feedback_note"`
		IsCorrect     bool     `json:"is_correct"`
		Category      string   `json:"category"`
		Tags          []string `json:"tags"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request"})
		return
	}

	feedback := &model.UserFeedback{
		ResultID:      req.ResultID,
		CorrectedType: req.CorrectedType,
		FeedbackNote:  req.FeedbackNote,
		IsCorrect:     req.IsCorrect,
		Category:      req.Category,
		Tags:          strings.Join(req.Tags, ","),
	}

	err := h.svc.SaveFeedback(feedback)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "feedback saved"})
}

// CreateNote 创建手记
// POST /api/v1/notes
func (h *Handler) CreateNote(c *gin.Context) {
	var req struct {
		ImageID  uint     `json:"image_id" binding:"required"`
		ResultID *uint    `json:"result_id"`
		Note     string   `json:"note"`
		Category string   `json:"category"`
		Tags     []string `json:"tags"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request"})
		return
	}

	actor, ok := h.requireActor(c)
	if !ok {
		return
	}

	note, err := h.svc.CreateNote(actor.UserID, req.ImageID, req.ResultID, req.Note, req.Category, req.Tags)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, note)
}

// GetNotes 获取手记列表
// GET /api/v1/notes
func (h *Handler) GetNotes(c *gin.Context) {
	actor, ok := h.requireActor(c)
	if !ok {
		return
	}

	limitStr := c.DefaultQuery("limit", "20")
	offsetStr := c.DefaultQuery("offset", "0")
	category := c.DefaultQuery("category", "")
	cropType := c.DefaultQuery("crop_type", "")
	startDateStr := c.DefaultQuery("start_date", "")
	endDateStr := c.DefaultQuery("end_date", "")

	limit, _ := strconv.Atoi(limitStr)
	offset, _ := strconv.Atoi(offsetStr)

	startDate, endDate, err := parseDateRange(startDateStr, endDateStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	ent, err := h.svc.GetEntitlements(actor.User, actor.DeviceID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	if ent.RequireLogin {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "login_required"})
		return
	}
	if ent.RetentionDays > 0 {
		cutoff := time.Now().AddDate(0, 0, -ent.RetentionDays)
		if startDate == nil || startDate.Before(cutoff) {
			startDate = &cutoff
		}
	}

	notes, err := h.svc.GetNotes(actor.UserID, limit, offset, category, cropType, startDate, endDate)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"results": normalizeNoteTags(notes),
		"limit":   limit,
		"offset":  offset,
	})
}

// ExportNotes 导出手记 CSV/JSON
// GET /api/v1/notes/export
func (h *Handler) ExportNotes(c *gin.Context) {
	actor, ok := h.requireActor(c)
	if !ok {
		return
	}

	limitStr := c.DefaultQuery("limit", "1000")
	offsetStr := c.DefaultQuery("offset", "0")
	category := c.DefaultQuery("category", "")
	cropType := c.DefaultQuery("crop_type", "")
	startDateStr := c.DefaultQuery("start_date", "")
	endDateStr := c.DefaultQuery("end_date", "")
	fields := c.DefaultQuery("fields", "")
	format := strings.ToLower(c.DefaultQuery("format", "csv"))

	limit, _ := strconv.Atoi(limitStr)
	offset, _ := strconv.Atoi(offsetStr)

	startDate, endDate, err := parseDateRange(startDateStr, endDateStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	ent, err := h.svc.GetEntitlements(actor.User, actor.DeviceID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	if ent.RequireLogin {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "login_required"})
		return
	}
	if ent.RetentionDays > 0 {
		cutoff := time.Now().AddDate(0, 0, -ent.RetentionDays)
		if startDate == nil || startDate.Before(cutoff) {
			startDate = &cutoff
		}
	}

	if format == "json" {
		c.Header("Content-Type", "application/json; charset=utf-8")
		c.Header("Content-Disposition", "attachment; filename=notes.json")
		if err := h.svc.ExportNotesJSON(c.Writer, actor.UserID, limit, offset, category, cropType, startDate, endDate, fields); err != nil {
			c.Status(http.StatusInternalServerError)
		}
		return
	}

	c.Header("Content-Type", "text/csv; charset=utf-8")
	c.Header("Content-Disposition", "attachment; filename=notes.csv")
	if err := h.svc.ExportNotesCSV(c.Writer, actor.UserID, limit, offset, category, cropType, startDate, endDate, fields); err != nil {
		c.Status(http.StatusInternalServerError)
	}
}

// GetLLMProviders 获取已注册的大模型提供商
// GET /api/v1/providers
func (h *Handler) GetLLMProviders(c *gin.Context) {
	providers := h.svc.ListProviders()
	c.JSON(http.StatusOK, gin.H{"providers": providers})
}

// SetupRoutes 设置路由
func (h *Handler) SetupRoutes(r *gin.Engine) {
	v1 := r.Group("/api/v1")
	{
		v1.GET("/admin/users", h.AdminListUsers)
		v1.GET("/admin/stats", h.AdminStats)
		v1.GET("/admin/metrics", h.AdminMetrics)
		v1.GET("/admin/failures/top", h.AdminFailureTop)
		v1.GET("/admin/settings", h.AdminSettings)
		v1.PUT("/admin/settings/:key", h.AdminUpdateSetting)
		v1.GET("/admin/plan-settings", h.AdminPlanSettings)
		v1.PUT("/admin/plan-settings/:code", h.AdminUpdatePlanSetting)
		v1.PUT("/admin/users/:id", h.AdminUpdateUser)
		v1.POST("/admin/users/:id/purge", h.AdminPurgeUser)
		v1.GET("/admin/email-logs", h.AdminEmailLogs)
		v1.GET("/admin/audit-logs", h.AdminAuditLogs)
		v1.GET("/admin/audit-logs/export", h.AdminExportAuditLogs)
		v1.GET("/admin/membership-requests", h.AdminMembershipRequests)
		v1.POST("/admin/membership-requests/:id/approve", h.AdminApproveMembership)
		v1.POST("/admin/membership-requests/:id/reject", h.AdminRejectMembership)
		v1.POST("/admin/users/:id/quota", h.AdminAddQuota)
		v1.GET("/admin/labels", h.AdminLabelQueue)
		v1.POST("/admin/labels/:id", h.AdminLabelNote)
		v1.POST("/admin/labels/:id/review", h.AdminReviewLabel)
		v1.POST("/admin/labels/batch-approve", h.AdminBatchApproveLabels)
		v1.GET("/admin/notes/by-result/:id", h.AdminGetNoteByResult)
		v1.GET("/admin/eval/summary", h.AdminEvalSummary)
		v1.POST("/admin/eval/runs", h.AdminCreateEvalRun)
		v1.GET("/admin/eval/runs", h.AdminListEvalRuns)
		v1.POST("/admin/eval-sets", h.AdminCreateEvalSet)
		v1.GET("/admin/eval-sets", h.AdminListEvalSets)
		v1.POST("/admin/eval-sets/:id/run", h.AdminRunEvalSet)
		v1.GET("/admin/eval-sets/:id/runs", h.AdminListEvalSetRuns)
		v1.GET("/admin/eval-sets/:id/export", h.AdminExportEvalSet)
		v1.POST("/admin/qc/samples", h.AdminGenerateQCSamples)
		v1.GET("/admin/qc/samples", h.AdminListQCSamples)
		v1.POST("/admin/qc/samples/:id/review", h.AdminReviewQCSample)
		v1.POST("/admin/qc/samples/batch-review", h.AdminBatchReviewQCSamples)
		v1.POST("/admin/qc/samples/from-results", h.AdminCreateQCSamplesFromResults)
		v1.POST("/admin/qc/samples/:id/label", h.AdminLabelQCSample)
		v1.GET("/admin/qc/samples/export", h.AdminExportQCSamples)
		v1.GET("/admin/results/low-confidence", h.AdminListLowConfidenceResults)
		v1.GET("/admin/results/failed", h.AdminListFailedResults)
		v1.GET("/admin/results/search", h.AdminSearchResults)
		v1.GET("/admin/results/low-confidence/export", h.AdminExportLowConfidenceResults)
		v1.GET("/admin/results/failed/export", h.AdminExportFailedResults)
		v1.GET("/admin/export/eval", h.AdminExportEval)
		v1.GET("/admin/export/users", h.AdminExportUsers)
		v1.GET("/admin/export/notes", h.AdminExportNotes)
		v1.GET("/admin/export/feedback", h.AdminExportFeedback)
		v1.POST("/auth/anonymous", h.AuthAnonymous)
		v1.POST("/auth/send-otp", h.SendOTP)
		v1.POST("/auth/verify-otp", h.VerifyOTP)
		v1.POST("/auth/logout", h.Logout)
		v1.GET("/entitlements", h.GetEntitlements)
		v1.POST("/usage/reward", h.RewardAd)
		v1.POST("/membership/request", h.MembershipRequest)
		v1.POST("/payment/checkout", h.PaymentCheckout)
		v1.POST("/payment/webhook", h.PaymentWebhook)
		v1.POST("/upload", h.UploadImage)
		v1.POST("/recognize", h.Recognize)
		v1.POST("/recognize-url", h.RecognizeByURL)
		v1.GET("/result/:id", h.GetResult)
		v1.GET("/history", h.GetHistory)
		v1.GET("/history/export", h.ExportHistory)
		v1.POST("/feedback", h.SubmitFeedback)
		v1.GET("/providers", h.GetLLMProviders)
		v1.GET("/plans", h.GetPlans)
		v1.GET("/crops", h.GetCrops)
		v1.POST("/notes", h.CreateNote)
		v1.GET("/notes", h.GetNotes)
		v1.GET("/notes/export", h.ExportNotes)
		v1.GET("/tags", h.GetTags)
		v1.GET("/export-templates", h.GetExportTemplates)
		v1.POST("/export-templates", h.CreateExportTemplate)
		v1.DELETE("/export-templates/:id", h.DeleteExportTemplate)
	}
}

// GetFile 获取上传的文件
func GetFile(c *gin.Context, key string) (*multipart.FileHeader, error) {
	return c.FormFile(key)
}

func parseDateRange(start, end string) (*time.Time, *time.Time, error) {
	if start == "" && end == "" {
		return nil, nil, nil
	}
	var startTime *time.Time
	var endTime *time.Time
	if start != "" {
		t, err := time.ParseInLocation("2006-01-02", start, time.Local)
		if err != nil {
			return nil, nil, fmt.Errorf("invalid start_date")
		}
		startTime = &t
	}
	if end != "" {
		t, err := time.ParseInLocation("2006-01-02", end, time.Local)
		if err != nil {
			return nil, nil, fmt.Errorf("invalid end_date")
		}
		// endDate 取到次日 0 点（左闭右开）
		t = t.Add(24 * time.Hour)
		endTime = &t
	}
	if startTime != nil && endTime != nil && !startTime.Before(*endTime) {
		return nil, nil, fmt.Errorf("invalid date range")
	}
	return startTime, endTime, nil
}

func normalizeNoteTags(notes []model.FieldNote) []gin.H {
	out := make([]gin.H, 0, len(notes))
	for _, n := range notes {
		tags := []string{}
		if n.Tags != "" {
			for _, t := range strings.Split(n.Tags, ",") {
				if strings.TrimSpace(t) != "" {
					tags = append(tags, strings.TrimSpace(t))
				}
			}
		}
		fbTags := []string{}
		if n.FeedbackTags != "" {
			for _, t := range strings.Split(n.FeedbackTags, ",") {
				if strings.TrimSpace(t) != "" {
					fbTags = append(fbTags, strings.TrimSpace(t))
				}
			}
		}
		out = append(out, gin.H{
			"id":                n.ID,
			"created_at":        n.CreatedAt,
			"image_id":          n.ImageID,
			"result_id":         n.ResultID,
			"image_url":         n.ImageURL,
			"note":              n.Note,
			"category":          n.Category,
			"raw_text":          n.RawText,
			"crop_type":         n.CropType,
			"confidence":        n.Confidence,
			"description":       n.Description,
			"growth_stage":      n.GrowthStage,
			"possible_issue":    n.PossibleIssue,
			"provider":          n.Provider,
			"tags":              tags,
			"is_correct":        n.IsCorrect,
			"corrected_type":    n.CorrectedType,
			"feedback_note":     n.FeedbackNote,
			"feedback_category": n.FeedbackCategory,
			"feedback_tags":     fbTags,
		})
	}
	return out
}

// GetTags 获取标签库
// GET /api/v1/tags?category=...
func (h *Handler) GetTags(c *gin.Context) {
	category := c.DefaultQuery("category", "")
	items, err := h.svc.GetTags(category)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	if category == "" {
		categories := map[string][]string{}
		for _, t := range items {
			categories[t.Category] = append(categories[t.Category], t.Name)
		}
		c.JSON(http.StatusOK, gin.H{"categories": categories})
		return
	}
	tags := make([]string, 0, len(items))
	for _, t := range items {
		tags = append(tags, t.Name)
	}
	c.JSON(http.StatusOK, gin.H{"category": category, "tags": tags})
}

// ExportTemplate handlers
// GET /api/v1/export-templates?type=notes
func (h *Handler) GetExportTemplates(c *gin.Context) {
	actor, ok := h.requireActor(c)
	if !ok {
		return
	}

	typ := c.DefaultQuery("type", "notes")
	items, err := h.svc.GetExportTemplates(actor.UserID, typ)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"results": items})
}

// POST /api/v1/export-templates
func (h *Handler) CreateExportTemplate(c *gin.Context) {
	actor, ok := h.requireActor(c)
	if !ok {
		return
	}
	var req struct {
		Type   string `json:"type"`
		Name   string `json:"name" binding:"required"`
		Fields string `json:"fields" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request"})
		return
	}
	item, err := h.svc.CreateExportTemplate(actor.UserID, req.Type, req.Name, req.Fields)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, item)
}

// DELETE /api/v1/export-templates/:id
func (h *Handler) DeleteExportTemplate(c *gin.Context) {
	actor, ok := h.requireActor(c)
	if !ok {
		return
	}
	idStr := c.Param("id")
	id, err := strconv.ParseUint(idStr, 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid id"})
		return
	}
	if err := h.svc.DeleteExportTemplate(actor.UserID, uint(id)); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "deleted"})
}

// GET /api/v1/crops
func (h *Handler) GetCrops(c *gin.Context) {
	items, err := h.svc.GetCrops()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"results": items})
}

// GET /api/v1/plans
func (h *Handler) GetPlans(c *gin.Context) {
	items, err := h.svc.GetPlanSettings()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"results": items})
}

func explainConfidence(conf float64) (float64, float64, string, string) {
	c := conf
	if c < 0 {
		c = 0
	}
	if c > 1 {
		c = 1
	}
	delta := 0.1
	switch {
	case c >= 0.9:
		delta = 0.05
	case c >= 0.75:
		delta = 0.08
	default:
		delta = 0.12
	}
	low := c - delta
	high := c + delta
	if low < 0 {
		low = 0
	}
	if high > 1 {
		high = 1
	}
	riskLevel := "high"
	riskNote := "不确定性较高，建议补拍清晰照片或手动标注。"
	if c >= 0.85 {
		riskLevel = "low"
		riskNote = "可信度较高，可直接参考结果。"
	} else if c >= 0.6 {
		riskLevel = "medium"
		riskNote = "存在一定不确定性，建议结合肉眼判断。"
	}
	return low, high, riskLevel, riskNote
}
