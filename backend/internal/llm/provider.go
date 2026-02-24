package llm

import (
	"encoding/json"
	"fmt"
)

// RecognitionResult 识别结果结构
type RecognitionResult struct {
	RawText     string  `json:"raw_text"`
	CropType     string  `json:"crop_type"`
	Confidence   float64 `json:"confidence"`
	Description  string  `json:"description"`
	GrowthStage  *string `json:"growth_stage"`
	PossibleIssue *string `json:"possible_issue"`
}

// Provider 大模型提供商接口
type Provider interface {
	Name() string
	Recognize(imageURL string) (*RecognitionResult, error)
}

// BaseProvider 基础提供商
type BaseProvider struct {
	NameVal    string
	APIKey     string
	Endpoint   string
}

// GetName 获取提供商名称
func (p *BaseProvider) Name() string {
	return p.NameVal
}

// RegisterProvider 注册提供商
var providers = make(map[string]Provider)

func RegisterProvider(name string, p Provider) {
	providers[name] = p
}

// GetProvider 获取已注册的提供商
func GetProvider(name string) (Provider, error) {
	p, ok := providers[name]
	if !ok {
		return nil, fmt.Errorf("provider %s not registered", name)
	}
	return p, nil
}

// ListProviders 列出所有已注册的提供商
func ListProviders() []string {
	names := make([]string, 0, len(providers))
	for name := range providers {
		names = append(names, name)
	}
	return names
}

// MockProvider 用于测试的 Mock 提供商
type MockProvider struct {
	BaseProvider
	Result *RecognitionResult
}

func NewMockProvider() *MockProvider {
	result := &RecognitionResult{
		CropType:    "wheat",
		Confidence:  0.92,
		Description: "小麦（Triticum aestivum）是一种重要的谷类作物",
	}
	return &MockProvider{
		BaseProvider: BaseProvider{NameVal: "mock"},
		Result:       result,
	}
}

func (p *MockProvider) Recognize(imageURL string) (*RecognitionResult, error) {
	// 模拟延迟
	// time.Sleep(500 * time.Millisecond)
	return p.Result, nil
}

// ParseResult 解析 JSON 结果
func ParseResult(data []byte) (*RecognitionResult, error) {
	var result RecognitionResult
	err := json.Unmarshal(data, &result)
	if err != nil {
		return nil, fmt.Errorf("failed to parse result: %w", err)
	}
	return &result, nil
}
