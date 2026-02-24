package llm

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/url"
	"path/filepath"
	"strings"
	"time"
)

// OpenAIProvider OpenAI 兼容 Provider
type OpenAIProvider struct {
	BaseProvider
	HTTPClient *http.Client
	Model      string
	ImageInput string
}

// NewOpenAIProvider 创建 OpenAI Provider
func NewOpenAIProvider(apiKey, endpoint, model, imageInput string) *OpenAIProvider {
	if model == "" {
		model = "gpt-4o"
	}
	return &OpenAIProvider{
		BaseProvider: BaseProvider{
			NameVal:  "openai",
			APIKey:   apiKey,
			Endpoint: endpoint,
		},
		HTTPClient: &http.Client{Timeout: 60 * time.Second},
		Model:      model,
		ImageInput: imageInput,
	}
}

// Recognize 调用 OpenAI API 进行图像识别
func (p *OpenAIProvider) Recognize(imageURL string) (*RecognitionResult, error) {
	resolvedURL, err := p.resolveImageURL(imageURL)
	if err != nil {
		return nil, err
	}

	// 构建请求
	reqBody := map[string]interface{}{
		"model": p.Model,
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
							"url": resolvedURL,
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

	req, err := http.NewRequest("POST", p.Endpoint+"/chat/completions", bytes.NewBuffer(jsonData))
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

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read response: %w", err)
	}

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("API returned status %d: %s", resp.StatusCode, strings.TrimSpace(string(body)))
	}

	var result map[string]interface{}
	if err := json.Unmarshal(body, &result); err != nil {
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

func (p *OpenAIProvider) resolveImageURL(imageURL string) (string, error) {
	mode := strings.ToLower(strings.TrimSpace(p.ImageInput))
	if mode == "" {
		mode = "auto"
	}

	if strings.HasPrefix(imageURL, "data:") {
		return imageURL, nil
	}

	switch mode {
	case "url":
		return imageURL, nil
	case "base64", "auto":
		// continue
	default:
		return imageURL, nil
	}

	inline := mode == "base64"
	if mode == "auto" {
		u, err := url.Parse(imageURL)
		if err != nil {
			inline = true
		} else {
			if u.Scheme != "https" {
				inline = true
			}
			host := u.Hostname()
			if host == "" {
				inline = true
			} else if isPrivateHost(host) {
				inline = true
			} else if strings.HasSuffix(host, ".local") {
				inline = true
			}
		}
	}

	if !inline {
		return imageURL, nil
	}

	dataURL, err := p.fetchAsDataURL(imageURL)
	if err != nil {
		return "", err
	}
	return dataURL, nil
}

func isPrivateHost(host string) bool {
	if host == "localhost" {
		return true
	}
	ip := net.ParseIP(host)
	if ip == nil {
		return false
	}
	return ip.IsPrivate() || ip.IsLoopback() || ip.IsLinkLocalUnicast()
}

func (p *OpenAIProvider) fetchAsDataURL(imageURL string) (string, error) {
	req, err := http.NewRequest("GET", imageURL, nil)
	if err != nil {
		return "", fmt.Errorf("failed to create image request: %w", err)
	}
	resp, err := p.HTTPClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("failed to download image: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("failed to download image: status %d", resp.StatusCode)
	}

	data, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", fmt.Errorf("failed to read image: %w", err)
	}

	contentType := resp.Header.Get("Content-Type")
	if contentType == "" {
		contentType = contentTypeFromExt(imageURL)
	}
	if contentType == "" {
		contentType = "image/jpeg"
	}

	encoded := base64.StdEncoding.EncodeToString(data)
	return fmt.Sprintf("data:%s;base64,%s", contentType, encoded), nil
}

func contentTypeFromExt(imageURL string) string {
	ext := strings.ToLower(filepath.Ext(imageURL))
	switch ext {
	case ".jpg", ".jpeg":
		return "image/jpeg"
	case ".png":
		return "image/png"
	case ".webp":
		return "image/webp"
	case ".gif":
		return "image/gif"
	default:
		return ""
	}
}

// parseCropResponse 解析作物识别的 JSON 响应
func parseCropResponse(content string) (*RecognitionResult, error) {
	// 先尝试直接解析
	var result RecognitionResult
	if err := json.Unmarshal([]byte(content), &result); err == nil {
		result.RawText = content
		return &result, nil
	}

	// 尝试从内容中提取 JSON
	start := strings.Index(content, "{")
	end := strings.LastIndex(content, "}")
	if start >= 0 && end > start {
		trimmed := strings.TrimSpace(content[start : end+1])
		if err := json.Unmarshal([]byte(trimmed), &result); err == nil {
			result.RawText = content
			return &result, nil
		}
	}

	return nil, fmt.Errorf("failed to parse response")
}
