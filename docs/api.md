# AgriScan API 文档

## 基础信息

- 基础URL: `http://localhost:8080/api/v1`
- 认证方式:
  - 匿名设备: Header `X-Device-ID`
  - 已登录用户: Header `X-Auth-Token`（可选携带 `X-Device-ID` 用于数据迁移）
- Content-Type: `application/json`

---

## 接口列表

### 0. 登录/权限

**POST** `/auth/anonymous`

```json
{
  "device_id": "device_xxx"
}
```

**POST** `/auth/send-otp`

```json
{
  "email": "you@example.com"
}
```
说明：同邮箱 60 秒内限发 1 次。

**POST** `/auth/verify-otp`

```json
{
  "email": "you@example.com",
  "code": "123456",
  "device_id": "device_xxx"
}
```

响应示例:
```json
{
  "token": "xxxx",
  "user": { "id": 1, "email": "you@example.com", "plan": "free" }
}
```

**GET** `/entitlements`

响应示例:
```json
{
  "user_id": 1,
  "plan": "free",
  "require_login": false,
  "require_ad": true,
  "ad_credits": 0,
  "quota_total": 0,
  "quota_used": 0,
  "quota_remaining": -1,
  "anonymous_remaining": 3,
  "retention_days": 7
}
```
说明：`plan` 可选值 `free/silver/gold/diamond`。

**POST** `/usage/reward` 广告奖励

---

### 0.2 会员申请

**POST** `/membership/request`

```json
{
  "plan": "silver",
  "note": "需要更高额度"
}
```

---

### 0.1 管理后台

Header: `X-Admin-Token` 或管理员用户的 `X-Auth-Token`

说明：首个完成邮箱登录的用户自动成为管理员。

**GET** `/admin/users`

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| limit | int | 20 | 分页大小 |
| offset | int | 0 | 偏移 |
| q | string | - | 关键字（邮箱/昵称） |
| plan | string | - | free/silver/gold/diamond |
| status | string | - | active/guest/disabled |

**PUT** `/admin/users/:id`

```json
{
  "plan": "silver",
  "status": "active",
  "quota_total": 5000,
  "quota_used": 100,
  "ad_credits": 0
}
```

**POST** `/admin/users/:id/purge`

按用户当前档次的留存天数清理手记。

**GET** `/admin/email-logs`

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| limit | int | 50 | 分页大小 |
| offset | int | 0 | 偏移 |
| email | string | - | 按邮箱过滤 |

**GET** `/admin/membership-requests`

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| limit | int | 50 | 分页大小 |
| offset | int | 0 | 偏移 |
| status | string | - | pending/approved/rejected |

**POST** `/admin/membership-requests/:id/approve`

```json
{
  "plan": "gold",
  "quota_total": 20000
}
```

**POST** `/admin/membership-requests/:id/reject`

**POST** `/admin/users/:id/quota`

```json
{
  "delta": 1000
}
```

**GET** `/admin/stats`

返回统计汇总。

**GET** `/admin/metrics`

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| days | int | 30 | 统计天数 |

返回字段新增：
- `low_confidence_total`
- `low_confidence_ratio`
- `low_confidence_threshold`

**GET** `/admin/settings`

**PUT** `/admin/settings/:key`

```json
{
  "value": "3"
}
```

说明：
- `auth_anon_limit` 匿名识别次数上限（int）
- `auth_anonymous_require_ad` 匿名识别是否必须看广告（bool）
- `label_flow_enabled` 标注流程开关（bool）

**GET** `/admin/plan-settings`

**PUT** `/admin/plan-settings/:code`

```json
{
  "name": "白银",
  "description": "适合频繁识别",
  "quota_total": 5000,
  "retention_days": 90,
  "require_ad": false,
  "price_cents": 9900,
  "billing_unit": "month"
}
```

**GET** `/admin/audit-logs`

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| limit | int | 50 | 分页大小 |
| offset | int | 0 | 偏移 |
| action | string | - | 操作类型 |

**GET** `/admin/labels`

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| limit | int | 20 | 分页大小 |
| offset | int | 0 | 偏移 |
| status | string | pending | pending/labeled/approved/rejected |

**POST** `/admin/labels/:id`

```json
{
  "category": "crop",
  "crop_type": "wheat",
  "tags": ["病害", "锈病"],
  "note": "人工标注"
}
```

**POST** `/admin/labels/:id/review`

```json
{
  "status": "approved",
  "reviewer": "admin"
}
```

**GET** `/admin/eval/summary`

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| days | int | 30 | 评测天数 |

返回字段：
- total / correct / accuracy
- by_crop：按标注作物统计准确率
- confusions：Top N 混淆对（actual->predicted）

**POST** `/admin/eval/runs`

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| days | int | 30 | 评测天数 |

**GET** `/admin/eval/runs`

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| limit | int | 20 | 分页大小 |
| offset | int | 0 | 偏移 |

**POST** `/admin/eval-sets`

```json
{
  "name": "baseline-v1",
  "description": "首批基线评测集",
  "days": 30,
  "limit": 200
}
```

**GET** `/admin/eval-sets`

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| limit | int | 20 | 分页大小 |
| offset | int | 0 | 偏移 |

**POST** `/admin/eval-sets/:id/run`

```json
{
  "baseline_id": 1
}
```

**GET** `/admin/eval-sets/:id/runs`

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| limit | int | 20 | 分页大小 |
| offset | int | 0 | 偏移 |

**GET** `/admin/eval-sets/:id/export`

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| format | string | csv | csv/json |
| start_date | string | - | 开始日期(YYYY-MM-DD) |
| end_date | string | - | 结束日期(YYYY-MM-DD) |

**POST** `/admin/qc/samples`

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| days | int | 30 | 样本时间范围 |
| low_limit | int | 0 | 低置信度样本数 |
| random_limit | int | 0 | 随机样本数 |
| feedback_limit | int | 0 | 错误反馈样本数 |
| low_conf_threshold | float | 0.5 | 低置信度阈值 |

**GET** `/admin/qc/samples`

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| limit | int | 20 | 分页大小 |
| offset | int | 0 | 偏移 |
| status | string | - | pending/keep/discard |
| reason | string | - | low_confidence/random/feedback_incorrect |

**POST** `/admin/qc/samples/:id/review`

```json
{
  "status": "keep",
  "reviewer": "admin",
  "review_note": "保留样本"
}
```

**POST** `/admin/qc/samples/batch-review`

```json
{
  "ids": [1, 2, 3],
  "status": "keep",
  "reviewer": "admin",
  "review_note": "批量保留"
}
```

**GET** `/admin/qc/samples/export`

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| format | string | csv | csv/json |
| status | string | - | pending/keep/discard |
| reason | string | - | low_confidence/random/feedback_incorrect |
| start_date | string | - | 开始日期(YYYY-MM-DD) |
| end_date | string | - | 结束日期(YYYY-MM-DD) |

**GET** `/admin/results/low-confidence`

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| days | int | 30 | 统计天数 |
| limit | int | 20 | 分页大小 |
| offset | int | 0 | 偏移 |
| threshold | float | 0.5 | 低置信度阈值 |
| provider | string | - | 提供商过滤 |
| crop_type | string | - | 作物过滤 |

返回字段：
- result_id / image_id / image_url / crop_type / confidence / provider / created_at

**GET** `/admin/results/failed`

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| days | int | 30 | 统计天数 |
| limit | int | 20 | 分页大小 |
| offset | int | 0 | 偏移 |
| provider | string | - | 提供商过滤 |
| crop_type | string | - | 作物过滤 |

**GET** `/admin/results/low-confidence/export`

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| format | string | csv | csv/json |
| days | int | 30 | 统计天数 |
| threshold | float | 0.5 | 低置信度阈值 |
| provider | string | - | 提供商过滤 |
| crop_type | string | - | 作物过滤 |

**GET** `/admin/results/failed/export`

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| format | string | csv | csv/json |
| days | int | 30 | 统计天数 |
| provider | string | - | 提供商过滤 |
| crop_type | string | - | 作物过滤 |

**POST** `/admin/qc/samples/from-results`

```json
{
  "ids": [1, 2, 3],
  "reason": "low_confidence"
}
```

**POST** `/admin/qc/samples/:id/label`

```json
{
  "category": "crop",
  "crop_type": "wheat",
  "tags": ["锈病"],
  "note": "人工标注",
  "approved": true,
  "reviewer": "admin"
}
```

**GET** `/admin/export/eval`

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| format | string | csv | csv/json |
| start_date | string | - | 开始日期(YYYY-MM-DD) |
| end_date | string | - | 结束日期(YYYY-MM-DD) |

**GET** `/admin/export/users`  
**GET** `/admin/export/notes`  
**GET** `/admin/export/feedback`

---

### 0.3 支付占位

**POST** `/payment/checkout`

```json
{
  "plan": "gold",
  "method": "wechat"
}
```

**POST** `/payment/webhook`

**留存说明**
- 列表/导出接口默认仅返回留存期内数据
- 服务端会按间隔自动清理（`RETENTION_PURGE_*`）

### 1. 上传图片

**POST** `/upload`

Content-Type: `multipart/form-data`

| 参数 | 类型 | 说明 |
|------|------|------|
| image | file | 图片文件 |
| latitude | float | 纬度（可选） |
| longitude | float | 经度（可选） |

Web/跨端 Base64 方式：
| 参数 | 类型 | 说明 |
|------|------|------|
| image | string | base64 字符串 |
| type | string | 固定为 `base64` |
| latitude | float | 纬度（可选） |
| longitude | float | 经度（可选） |

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
  "is_correct": false,
  "category": "pest",
  "tags": ["蚜虫", "螟虫"]
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

### 7. 导出手记（CSV/JSON）

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
| format | string | csv | 导出格式（csv/json） |

可选字段：
`id,created_at,image_id,result_id,image_url,category,crop_type,confidence,description,growth_stage,possible_issue,provider,note,raw_text,tags`

字段预设（前端使用）：
- 轻量：`id,created_at,image_url,category,crop_type,confidence,note`
- 完整：`id,created_at,image_id,result_id,image_url,category,crop_type,confidence,description,growth_stage,possible_issue,provider,note,tags`
- 研究用：完整 + `raw_text`

返回：
- `format=csv`：`text/csv` 文件
- `format=json`：`application/json` 文件（数组）

**JSON 响应示例:**
```json
[
  {
    "id": 1,
    "created_at": "2026-02-24 20:31:42",
    "image_id": 10,
    "result_id": 20,
    "image_url": "https://example.com/xxx.jpg",
    "category": "crop",
    "crop_type": "水稻",
    "confidence": 0.9234,
    "description": "长势正常",
    "growth_stage": "拔节期",
    "possible_issue": null,
    "provider": "qwen",
    "note": "示例手记",
    "tags": "虫害,杂草"
  }
]
```

---

### 8. 标签库

**GET** `/tags`

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| category | string | - | 指定分类（disease/pest/weed） |

**响应示例:**
```json
{
  "categories": {
    "disease": ["锈病", "白粉病"],
    "pest": ["蚜虫", "螟虫"],
    "weed": ["稗草", "马齿苋"]
  }
}
```

或：
```json
{
  "category": "pest",
  "tags": ["蚜虫", "螟虫"]
}
```

---

### 9. 作物列表

**GET** `/crops`

**响应示例:**
```json
{
  "results": [
    { "id": 1, "code": "corn", "name": "玉米", "active": true }
  ]
}
```

---

### 10. 导出模板

**GET** `/export-templates?type=notes`

**响应示例:**
```json
{
  "results": [
    {
      "id": 1,
      "type": "notes",
      "name": "研究导出",
      "fields": "id,created_at,image_id,crop_type,confidence,raw_text"
    }
  ]
}
```

**POST** `/export-templates`
```json
{
  "type": "notes",
  "name": "研究导出",
  "fields": "id,created_at,image_id,crop_type,confidence,raw_text"
}
```

**DELETE** `/export-templates/:id`

---

### 11. 创建手记

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

### 12. 获取支持的提供商

**GET** `/providers`

**响应示例:**
```json
{
  "providers": ["mock", "qwen", "baidu", "openai"]
}
```

---

### 13. 获取会员档次

**GET** `/plans`

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
