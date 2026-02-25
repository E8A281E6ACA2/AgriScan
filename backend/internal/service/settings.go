package service

import (
	"errors"
	"strconv"
	"strings"
)

const (
	settingAnonLimit     = "auth_anon_limit"
	settingAnonRequireAd = "auth_anonymous_require_ad"
	settingLabelEnabled  = "label_flow_enabled"
)

type SettingItem struct {
	Key         string `json:"key"`
	Value       string `json:"value"`
	Type        string `json:"type"`
	Description string `json:"description"`
}

type SettingUpdate struct {
	Value string `json:"value"`
}

type settingDef struct {
	Key         string
	Type        string
	Description string
	Default     string
}

func (s *Service) settingDefs() []settingDef {
	return []settingDef{
		{
			Key:         settingAnonLimit,
			Type:        "int",
			Description: "匿名识别次数上限",
			Default:     strconv.Itoa(s.auth.AnonLimit),
		},
		{
			Key:         settingAnonRequireAd,
			Type:        "bool",
			Description: "匿名识别是否必须看广告",
			Default:     "true",
		},
		{
			Key:         settingLabelEnabled,
			Type:        "bool",
			Description: "标注流程开关",
			Default:     "false",
		},
	}
}

func (s *Service) GetAppSettings() ([]SettingItem, error) {
	defs := s.settingDefs()
	items := make([]SettingItem, 0, len(defs))
	for _, def := range defs {
		value := def.Default
		if stored, err := s.repo.GetAppSettingByKey(def.Key); err == nil && stored != nil {
			value = stored.Value
		}
		items = append(items, SettingItem{
			Key:         def.Key,
			Value:       value,
			Type:        def.Type,
			Description: def.Description,
		})
	}
	return items, nil
}

func (s *Service) UpdateAppSetting(key, value string) (SettingItem, error) {
	key = strings.TrimSpace(key)
	value = strings.TrimSpace(value)
	def, ok := s.getSettingDef(key)
	if !ok {
		return SettingItem{}, errors.New("invalid key")
	}
	normalized, err := normalizeSettingValue(def.Type, value)
	if err != nil {
		return SettingItem{}, err
	}
	if _, err := s.repo.UpsertAppSetting(key, normalized); err != nil {
		return SettingItem{}, err
	}
	return SettingItem{
		Key:         key,
		Value:       normalized,
		Type:        def.Type,
		Description: def.Description,
	}, nil
}

func (s *Service) getSettingDef(key string) (settingDef, bool) {
	for _, def := range s.settingDefs() {
		if def.Key == key {
			return def, true
		}
	}
	return settingDef{}, false
}

func normalizeSettingValue(typ, value string) (string, error) {
	switch typ {
	case "int":
		if value == "" {
			return "", errors.New("value required")
		}
		v, err := strconv.Atoi(value)
		if err != nil || v < 0 {
			return "", errors.New("invalid int value")
		}
		return strconv.Itoa(v), nil
	case "bool":
		if value == "" {
			return "", errors.New("value required")
		}
		if value == "1" || strings.EqualFold(value, "true") {
			return "true", nil
		}
		if value == "0" || strings.EqualFold(value, "false") {
			return "false", nil
		}
		return "", errors.New("invalid bool value")
	default:
		return value, nil
	}
}

func (s *Service) getSettingInt(key string, def int) int {
	item, err := s.repo.GetAppSettingByKey(key)
	if err != nil || item == nil {
		return def
	}
	v, err := strconv.Atoi(strings.TrimSpace(item.Value))
	if err != nil || v < 0 {
		return def
	}
	return v
}

func (s *Service) getSettingBool(key string, def bool) bool {
	item, err := s.repo.GetAppSettingByKey(key)
	if err != nil || item == nil {
		return def
	}
	value := strings.TrimSpace(item.Value)
	if value == "1" || strings.EqualFold(value, "true") {
		return true
	}
	if value == "0" || strings.EqualFold(value, "false") {
		return false
	}
	return def
}
