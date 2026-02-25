package service

import (
	"os"
	"strconv"
)

type AuthConfig struct {
	AnonLimit         int
	OTPMinutes        int
	SessionDays       int
	FreeRetentionDays int
	PaidRetentionDays int
	FreeQuotaTotal    int
	DebugOTP          bool
	PlanSilver        PlanSetting
	PlanGold          PlanSetting
	PlanDiamond       PlanSetting
	SMTP              SMTPConfig
}

func loadAuthConfig() AuthConfig {
	return AuthConfig{
		AnonLimit:         getEnvInt("AUTH_ANON_LIMIT", 3),
		OTPMinutes:        getEnvInt("AUTH_OTP_MINUTES", 10),
		SessionDays:       getEnvInt("AUTH_SESSION_DAYS", 30),
		FreeRetentionDays: getEnvInt("AUTH_FREE_RETENTION_DAYS", 7),
		PaidRetentionDays: getEnvInt("AUTH_PAID_RETENTION_DAYS", 90),
		FreeQuotaTotal:    getEnvInt("AUTH_FREE_QUOTA_TOTAL", 0),
		DebugOTP:          getEnvBool("AUTH_DEBUG_OTP", true),
		PlanSilver: PlanSetting{
			Name:          "silver",
			QuotaTotal:    getEnvInt("PLAN_SILVER_QUOTA_TOTAL", 5000),
			RetentionDays: getEnvInt("PLAN_SILVER_RETENTION_DAYS", 90),
			RequireAd:     getEnvBool("PLAN_SILVER_REQUIRE_AD", false),
		},
		PlanGold: PlanSetting{
			Name:          "gold",
			QuotaTotal:    getEnvInt("PLAN_GOLD_QUOTA_TOTAL", 20000),
			RetentionDays: getEnvInt("PLAN_GOLD_RETENTION_DAYS", 180),
			RequireAd:     getEnvBool("PLAN_GOLD_REQUIRE_AD", false),
		},
		PlanDiamond: PlanSetting{
			Name:          "diamond",
			QuotaTotal:    getEnvInt("PLAN_DIAMOND_QUOTA_TOTAL", 100000),
			RetentionDays: getEnvInt("PLAN_DIAMOND_RETENTION_DAYS", 365),
			RequireAd:     getEnvBool("PLAN_DIAMOND_REQUIRE_AD", false),
		},
		SMTP: SMTPConfig{
			Server:     os.Getenv("FLOWAPI_SMTP_SERVER"),
			Port:       getEnvInt("FLOWAPI_SMTP_PORT", 465),
			SSLEnabled: getEnvBool("FLOWAPI_SMTP_SSL_ENABLED", true),
			Account:    os.Getenv("FLOWAPI_SMTP_ACCOUNT"),
			From:       os.Getenv("FLOWAPI_SMTP_FROM"),
			Token:      os.Getenv("FLOWAPI_SMTP_TOKEN"),
		},
	}
}

type PlanSetting struct {
	Name          string
	QuotaTotal    int
	RetentionDays int
	RequireAd     bool
}

type SMTPConfig struct {
	Server     string
	Port       int
	SSLEnabled bool
	Account    string
	From       string
	Token      string
}

func getEnvInt(key string, def int) int {
	if v := os.Getenv(key); v != "" {
		if i, err := strconv.Atoi(v); err == nil {
			return i
		}
	}
	return def
}

func getEnvBool(key string, def bool) bool {
	if v := os.Getenv(key); v != "" {
		if v == "1" || v == "true" || v == "TRUE" || v == "True" {
			return true
		}
		if v == "0" || v == "false" || v == "FALSE" || v == "False" {
			return false
		}
	}
	return def
}
