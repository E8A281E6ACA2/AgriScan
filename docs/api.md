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

Web/跨端 Base64 方式：
| 参数 | 类型 | 说明 |
|------|------|------|
| image | string | base64 字符串 |
| type | string | 固定为 `base64` |

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
  "raw_text": "...",
  "result_id": 1,
  "image_id": 1,
  "image_url": "https://oss.qs.al/agriscan/20260224/xxxx.jpg",
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

**GET** `/result/:id`  (id 为 result_id)

**响应示例:**
```json
{
  "raw_text": "...",
  "result_id": 1,
  "image_id": 1,
  "image_url": "https://oss.qs.al/agriscan/20260224/xxxx.jpg",
  "crop_type": "wheat",
  "confidence": 0.92,
  "description": "小麦（Triticum aestivum）是一种重要的谷类作物",
  "growth_stage": null,
  "possible_issue": null,
  "provider": "qwen"
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
  "results": [
    {
      "raw_text": "...",
      "result_id": 1,
      "image_id": 1,
      "image_url": "https://oss.qs.al/agriscan/20260224/xxxx.jpg",
      "crop_type": "wheat",
      "confidence": 0.92,
      "description": "小麦（Triticum aestivum）是一种重要的谷类作物",
      "growth_stage": null,
      "possible_issue": null,
      "provider": "qwen"
    }
  ],
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

### 6. 获取手记列表

**GET** `/notes`

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| limit | int | 20 | 数量限制 |
| offset | int | 0 | 偏移量 |
| category | string | - | 过滤分类（crop/disease/pest/weed/other） |
| crop_type | string | - | 过滤作物类型 |
| start_date | string | - | 开始日期（YYYY-MM-DD） |
| end_date | string | - | 结束日期（YYYY-MM-DD） |

**响应示例:**
```json
{
  "results": [
    {
      "id": 1,
      "image_id": 1,
      "result_id": 1,
      "image_url": "https://oss.qs.al/agriscan/20260224/xxxx.jpg",
      "crop_type": "wheat",
      "confidence": 0.92,
      "description": "小麦（Triticum aestivum）是一种重要的谷类作物",
      "growth_stage": null,
      "possible_issue": null,
      "provider": "qwen",
      "note": "叶片发黄，疑似缺氮",
      "tags": ["锈病", "蚜虫"],
      "category": "crop",
      "created_at": "2026-02-24T12:00:00Z"
    }
  ],
  "limit": 20,
  "offset": 0
}
```

---

### 7. 导出手记 CSV

**GET** `/notes/export`

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| limit | int | 1000 | 导出数量限制 |
| offset | int | 0 | 偏移量 |
| category | string | - | 过滤分类（crop/disease/pest/weed/other） |
| crop_type | string | - | 过滤作物类型 |
| start_date | string | - | 开始日期（YYYY-MM-DD） |
| end_date | string | - | 结束日期（YYYY-MM-DD） |
| fields | string | - | 选择导出字段（逗号分隔） |

可选字段：
`id,created_at,image_id,result_id,image_url,category,crop_type,confidence,description,growth_stage,possible_issue,provider,note,raw_text,tags`

字段预设（前端使用）：
- 轻量：`id,created_at,image_url,category,crop_type,confidence,note`
- 完整：`id,created_at,image_id,result_id,image_url,category,crop_type,confidence,description,growth_stage,possible_issue,provider,note,tags`
- 研究用：完整 + `raw_text`

返回 `text/csv` 文件。

---

### 8. 创建手记

**POST** `/notes`

```json
{
  "image_id": 1,
  "result_id": 1,
  "note": "叶片发黄，疑似缺氮",
  "category": "crop",
  "tags": ["锈病", "蚜虫"]
}
```

---

### 9. 获取支持的提供商

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
