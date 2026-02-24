package handler

import (
	"agri-scan/internal/model"
	"agri-scan/internal/service"
	"log"
	"mime/multipart"
	"net/http"
	"strconv"

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
	ImageID      uint   `json:"image_id"`
	OriginalURL  string `json:"original_url"`
	CompressedURL string `json:"compressed_url"`
}

// RecognizeResponse 识别响应
type RecognizeResponse struct {
	RawText     string  `json:"raw_text"`
	ResultID     uint    `json:"result_id"`
	CropType     string  `json:"crop_type"`
	Confidence   float64 `json:"confidence"`
	Description  string  `json:"description"`
	GrowthStage  *string `json:"growth_stage"`
	PossibleIssue *string `json:"possible_issue"`
	Provider     string  `json:"provider"`
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

	userIDStr := c.GetHeader("X-User-ID")
	userID, err := strconv.ParseUint(userIDStr, 10, 64)
	if err != nil || userID == 0 {
		userID = 1
	}

	img, err := h.svc.CreateImageFromURL(uint(userID), req.ImageURL)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	result, err := h.svc.Recognize(img.OriginalURL)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	savedResult, err := h.svc.SaveResult(img.ID, result)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, RecognizeResponse{
		RawText:     savedResult.RawText,
		ResultID:     savedResult.ID,
		CropType:     savedResult.CropType,
		Confidence:   savedResult.Confidence,
		Description:  savedResult.Description,
		GrowthStage:  savedResult.GrowthStage,
		PossibleIssue: savedResult.PossibleIssue,
		Provider:     savedResult.Provider,
	})
}

// UploadImage 上传图片
// POST /api/v1/upload
func (h *Handler) UploadImage(c *gin.Context) {
	// 从 header 获取用户 ID（实际应从 token 解析）
	userIDStr := c.GetHeader("X-User-ID")
	userID, err := strconv.ParseUint(userIDStr, 10, 64)
	if err != nil || userID == 0 {
		// 默认用户 ID 为 1（测试用）
		userID = 1
	}

	// 检查是否是 base64 上传
	imageData := c.PostForm("image")
	imageType := c.PostForm("type")

	if imageType == "base64" && imageData != "" {
		// Base64 上传（Web 端）
		img, err := h.svc.UploadImageBase64(uint(userID), imageData)
		if err != nil {
			log.Printf("UploadImageBase64 failed: %v", err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusOK, UploadResponse{
			ImageID:         img.ID,
			OriginalURL:     img.OriginalURL,
			CompressedURL:   img.CompressedURL,
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
	img, err := h.svc.UploadImage(uint(userID), file)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, UploadResponse{
		ImageID:      img.ID,
		OriginalURL:  img.OriginalURL,
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

	// 获取图片信息
	img, err := h.svc.GetImage(req.ImageID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "image not found"})
		return
	}

	// 调用大模型识别
	result, err := h.svc.Recognize(img.OriginalURL)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	// 保存识别结果
	savedResult, err := h.svc.SaveResult(req.ImageID, result)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, RecognizeResponse{
		RawText:     savedResult.RawText,
		ResultID:     savedResult.ID,
		CropType:     savedResult.CropType,
		Confidence:   savedResult.Confidence,
		Description:  savedResult.Description,
		GrowthStage:  savedResult.GrowthStage,
		PossibleIssue: savedResult.PossibleIssue,
		Provider:     savedResult.Provider,
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

	result, err := h.svc.GetResultByImageID(uint(id))
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "result not found"})
		return
	}

	c.JSON(http.StatusOK, result)
}

// GetHistory 获取历史记录
// GET /api/v1/history
func (h *Handler) GetHistory(c *gin.Context) {
	userIDStr := c.GetHeader("X-User-ID")
	userID, err := strconv.ParseUint(userIDStr, 10, 64)
	if err != nil || userID == 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid user id"})
		return
	}

	limitStr := c.DefaultQuery("limit", "20")
	offsetStr := c.DefaultQuery("offset", "0")

	limit, _ := strconv.Atoi(limitStr)
	offset, _ := strconv.Atoi(offsetStr)

	results, err := h.svc.GetHistory(uint(userID), limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"results": results,
		"limit":   limit,
		"offset":  offset,
	})
}

// SubmitFeedback 提交用户反馈
// POST /api/v1/feedback
func (h *Handler) SubmitFeedback(c *gin.Context) {
	var req struct {
		ResultID      uint   `json:"result_id" binding:"required"`
		CorrectedType string `json:"corrected_type"`
		FeedbackNote string `json:"feedback_note"`
		IsCorrect     bool   `json:"is_correct"`
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
	}

	err := h.svc.SaveFeedback(feedback)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "feedback saved"})
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
		v1.POST("/upload", h.UploadImage)
		v1.POST("/recognize", h.Recognize)
		v1.POST("/recognize-url", h.RecognizeByURL)
		v1.GET("/result/:id", h.GetResult)
		v1.GET("/history", h.GetHistory)
		v1.POST("/feedback", h.SubmitFeedback)
		v1.GET("/providers", h.GetLLMProviders)
	}
}

// GetFile 获取上传的文件
func GetFile(c *gin.Context, key string) (*multipart.FileHeader, error) {
	return c.FormFile(key)
}
