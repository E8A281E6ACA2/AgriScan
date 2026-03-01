package handler

import (
	"encoding/json"
	"io"
	"net/http"
	"os"
	"strconv"
	"strings"

	"agri-scan/internal/service"

	"github.com/gin-gonic/gin"
	"github.com/stripe/stripe-go/v81"
	"github.com/stripe/stripe-go/v81/checkout/session"
	"github.com/stripe/stripe-go/v81/webhook"
)

type stripeConfig struct {
	SecretKey     string
	WebhookSecret string
	SuccessURL    string
	CancelURL     string
	Currency      string
}

func loadStripeConfig() (stripeConfig, error) {
	cfg := stripeConfig{
		SecretKey:     strings.TrimSpace(os.Getenv("STRIPE_SECRET_KEY")),
		WebhookSecret: strings.TrimSpace(os.Getenv("STRIPE_WEBHOOK_SECRET")),
		SuccessURL:    strings.TrimSpace(os.Getenv("STRIPE_SUCCESS_URL")),
		CancelURL:     strings.TrimSpace(os.Getenv("STRIPE_CANCEL_URL")),
		Currency:      strings.TrimSpace(os.Getenv("STRIPE_CURRENCY")),
	}
	if cfg.Currency == "" {
		cfg.Currency = "cny"
	}
	if cfg.SecretKey == "" || cfg.SuccessURL == "" || cfg.CancelURL == "" {
		return cfg, ErrInvalidConfig("stripe_not_configured")
	}
	return cfg, nil
}

type ErrInvalidConfig string

func (e ErrInvalidConfig) Error() string { return string(e) }

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
	actor, ok := h.requireActor(c)
	if !ok {
		return
	}
	if actor.User == nil || actor.User.ID == 0 {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "login_required"})
		return
	}
	planCode := strings.TrimSpace(strings.ToLower(req.Plan))
	if planCode == "" || planCode == "free" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid plan"})
		return
	}
	method := strings.TrimSpace(strings.ToLower(req.Method))
	if method == "" {
		method = "stripe"
	}
	if method != "stripe" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "payment_method_not_supported"})
		return
	}
	cfg, err := loadStripeConfig()
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	plan, err := h.svc.GetPlanSetting(planCode)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid plan"})
		return
	}
	if plan.PriceCents <= 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid plan price"})
		return
	}
	stripe.Key = cfg.SecretKey
	successURL := cfg.SuccessURL
	if !strings.Contains(successURL, "{CHECKOUT_SESSION_ID}") {
		if strings.Contains(successURL, "?") {
			successURL += "&session_id={CHECKOUT_SESSION_ID}"
		} else {
			successURL += "?session_id={CHECKOUT_SESSION_ID}"
		}
	}
	params := &stripe.CheckoutSessionParams{
		Mode:              stripe.String(string(stripe.CheckoutSessionModePayment)),
		SuccessURL:        stripe.String(successURL),
		CancelURL:         stripe.String(cfg.CancelURL),
		ClientReferenceID: stripe.String(strconv.FormatUint(uint64(actor.User.ID), 10)),
		LineItems: []*stripe.CheckoutSessionLineItemParams{
			{
				PriceData: &stripe.CheckoutSessionLineItemPriceDataParams{
					Currency: stripe.String(cfg.Currency),
					ProductData: &stripe.CheckoutSessionLineItemPriceDataProductDataParams{
						Name:        stripe.String(plan.Name + "会员"),
						Description: stripe.String(plan.Description),
					},
					UnitAmount: stripe.Int64(int64(plan.PriceCents)),
				},
				Quantity: stripe.Int64(1),
			},
		},
		Metadata: map[string]string{
			"user_id": strconv.FormatUint(uint64(actor.User.ID), 10),
			"plan":    plan.Code,
		},
	}
	if email := strings.TrimSpace(actor.User.Email); email != "" && !strings.HasPrefix(email, "device:") {
		params.CustomerEmail = stripe.String(email)
	}
	sess, err := session.New(params)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"checkout_url": sess.URL,
		"session_id":   sess.ID,
		"plan":         plan.Code,
	})
}

// POST /api/v1/payment/webhook
func (h *Handler) PaymentWebhook(c *gin.Context) {
	cfg, err := loadStripeConfig()
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	payload, err := io.ReadAll(c.Request.Body)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid payload"})
		return
	}
	sig := c.GetHeader("Stripe-Signature")
	event, err := webhook.ConstructEvent(payload, sig, cfg.WebhookSecret)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "signature verification failed"})
		return
	}
	switch event.Type {
	case "checkout.session.completed", "checkout.session.async_payment_succeeded":
		var sess stripe.CheckoutSession
		if err := json.Unmarshal(event.Data.Raw, &sess); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid session"})
			return
		}
		planCode := strings.TrimSpace(sess.Metadata["plan"])
		userIDStr := strings.TrimSpace(sess.Metadata["user_id"])
		if planCode == "" || userIDStr == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "missing metadata"})
			return
		}
		userID, err := strconv.ParseUint(userIDStr, 10, 64)
		if err != nil || userID == 0 {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid user_id"})
			return
		}
		plan, err := h.svc.GetPlanSetting(planCode)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid plan"})
			return
		}
		_, err = h.svc.UpdateUserByID(uint(userID), service.UserUpdate{
			Plan:       plan.Code,
			QuotaTotal: plan.QuotaTotal,
			QuotaUsed:  0,
			Status:     "active",
			AdCredits:  0,
		})
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
	}
	c.JSON(http.StatusOK, gin.H{"ok": true})
}
