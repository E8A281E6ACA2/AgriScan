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
	PaidQuotaTotal    int
	DebugOTP          bool
}

func loadAuthConfig() AuthConfig {
	return AuthConfig{
		AnonLimit:         getEnvInt("AUTH_ANON_LIMIT", 3),
		OTPMinutes:        getEnvInt("AUTH_OTP_MINUTES", 10),
		SessionDays:       getEnvInt("AUTH_SESSION_DAYS", 30),
		FreeRetentionDays: getEnvInt("AUTH_FREE_RETENTION_DAYS", 7),
		PaidRetentionDays: getEnvInt("AUTH_PAID_RETENTION_DAYS", 90),
		FreeQuotaTotal:    getEnvInt("AUTH_FREE_QUOTA_TOTAL", 0),
		PaidQuotaTotal:    getEnvInt("AUTH_PAID_QUOTA_TOTAL", 10000),
		DebugOTP:          getEnvBool("AUTH_DEBUG_OTP", true),
	}
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
