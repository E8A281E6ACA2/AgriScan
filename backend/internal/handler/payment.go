package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

// POST /api/v1/payment/checkout
func (h *Handler) PaymentCheckout(c *gin.Context) {
	var req struct {
		Plan   string `json:"plan" binding:"required"`
		Method string `json:"method"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request"})
		return
	}
	c.JSON(http.StatusNotImplemented, gin.H{
		"error":  "payment_not_implemented",
		"plan":   req.Plan,
		"method": req.Method,
	})
}

// POST /api/v1/payment/webhook
func (h *Handler) PaymentWebhook(c *gin.Context) {
	c.JSON(http.StatusNotImplemented, gin.H{"error": "payment_not_implemented"})
}
