package llm

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"time"
)

// OpenAIProvider OpenAI 兼容 Provider
type OpenAIProvider struct {
	BaseProvider
	HTTPClient *http.Client
}

// NewOpenAIProvider 创建 OpenAI Provider
func NewOpenAIProvider(apiKey, endpoint string) *OpenAIProvider {
	return &OpenAIProvider{
		BaseProvider: BaseProvider{
			NameVal:  "openai",
			APIKey:   apiKey,
			Endpoint: endpoint,
		},
		HTTPClient: &http.Client{Timeout: 60 * time.Second},
	}
}

// Recognize 调用 OpenAI API 进行图像识别
func (p *OpenAIProvider) Recognize(imageURL string) (*RecognitionResult, error) {
	// 构建请求
	reqBody := map[string]interface{}{
		"model": "gpt-4o",
		"messages": []map[string]interface{}{
			{
				"role": "user",
				"content": []map[string]interface{}{
					{
						"type": "text",
						"text": "请识别这是什么作物植物，提供JSON格式回复：{\"crop_type\":\"作物类型英文名\",\"confidence\":0.0-1.0,\"description\":\"简短描述\"}",
					},
					{
						"type": "image_url",
						"image_url": map[string]string{
							"url": imageURL,
						},
					},
				},
			},
		},
		"max_tokens": 500,
	}

	jsonData, err := json.Marshal(reqBody)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal request: %w", err)
	}

	req, err := http.NewRequest("POST", p.Endpoint+"/v1/chat/completions", bytes.NewBuffer(jsonData))
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+p.APIKey)

	resp, err := p.HTTPClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to call API: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("API returned status %d", resp.StatusCode)
	}

	var result map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, fmt.Errorf("failed to decode response: %w", err)
	}

	// 解析响应
	choices, ok := result["choices"].([]interface{})
	if !ok || len(choices) == 0 {
		return nil, fmt.Errorf("no choices in response")
	}

	message, ok := choices[0].(map[string]interface{})["message"].(map[string]interface{})
	if !ok {
		return nil, fmt.Errorf("no message in choice")
	}

	content, ok := message["content"].(string)
	if !ok {
		return nil, fmt.Errorf("no content in message")
	}

	// 解析 JSON 内容
	return parseCropResponse(content)
}

// parseCropResponse 解析作物识别的 JSON 响应
func parseCropResponse(content string) (*RecognitionResult, error) {
	// 尝试直接解析
	var result RecognitionResult
	if err := json.Unmarshal([]byte(content), &result); err != nil {
		// 如果失败，尝试提取 JSON
		return nil, fmt.Errorf("failed to parse response: %w", err)
	}
	return &result, nil
}
