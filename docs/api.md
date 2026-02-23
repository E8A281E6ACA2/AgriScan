# AgriScan API 文档

## 基础信息

- 基础URL: `http://localhost:8080/api/v1`
- 认证方式: Header `X-User-ID`
- Content-Type: `application/json`

---

## 接口列表

### 1. 上传图片

**POST** `/upload`

Content-Type: `multipart/form-data`

| 参数 | 类型 | 说明 |
|------|------|------|
| image | file | 图片文件 |

**响应示例:**
```json
{
  "image_id": 1,
  "original_url": "https://cos.example.com/images/1/20240101/1700000000.jpg",
  "compressed_url": "https://cos.example.com/images/1/20240101/1700000000.jpg"
}
```

---

### 2. 发起识别

**POST** `/recognize`

```json
{
  "image_id": 1
}
```

**响应示例:**
```json
{
  "result_id": 1,
  "image_id": 1,
  "crop_type": "wheat",
  "confidence": 0.92,
  "description": "小麦（Triticum aestivum）是一种重要的谷类作物",
  "growth_stage": null,
  "possible_issue": null,
  "provider": "qwen"
}
```

---

### 3. 获取识别结果

**GET** `/result/:id`

**响应示例:**
```json
{
  "id": 1,
  "image_id": 1,
  "crop_type": "wheat",
  "confidence": 0.92,
  "description": "小麦（Triticum aestivum）是一种重要的谷类作物",
  "growth_stage": null,
  "possible_issue": null,
  "provider": "qwen",
  "created_at": "2024-01-01T12:00:00Z"
}
```

---

### 4. 获取历史记录

**GET** `/history`

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| limit | int | 20 | 数量限制 |
| offset | int | 0 | 偏移量 |

**响应示例:**
```json
{
  "results": [...],
  "limit": 20,
  "offset": 0
}
```

---

### 5. 提交反馈

**POST** `/feedback`

```json
{
  "result_id": 1,
  "corrected_type": "corn",
  "feedback_note": "实际是玉米",
  "is_correct": false
}
```

---

### 6. 获取支持的提供商

**GET** `/providers`

**响应示例:**
```json
{
  "providers": ["mock", "qwen", "baidu", "openai"]
}
```

---

## 错误响应

```json
{
  "error": "错误信息"
}
```

HTTP 状态码:
- 200: 成功
- 400: 请求错误
- 404: 资源不存在
- 500: 服务器错误
