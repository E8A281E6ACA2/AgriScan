# MVP 验收清单

## 前置
- 数据库可连接（PostgreSQL）
- 后端 `backend/.env` 已配置
- 对象存储可用（S3/R2 或本地存储兜底）
- OpenAI 兼容接口可用（`LLM_API_KEY`、`LLM_ENDPOINT`、`LLM_MODEL`）

## 后端启动
- `go run ./cmd/server` 无报错
- 控制台看到数据库连接成功日志
- 如无 S3/R2 配置，日志显示本地存储初始化成功

## API 基础检查
- `GET /api/v1/providers` 返回 200
- `POST /api/v1/upload` 成功返回 `image_id`
- `POST /api/v1/recognize` 成功返回 `result_id`
- `GET /api/v1/result/:id` 返回完整识别信息
- `GET /api/v1/history` 有新记录
- `POST /api/v1/feedback` 返回成功

## Web 端
- 相册选择或拍照后可看到结果页
- 结果页图片可显示（内存图片）
- 识别结果、置信度、描述显示正常
- 历史记录能展示并查看详情

## Android
- 允许 http 调试（仅开发）
- 拍照/相册上传无崩溃
- 结果页图片和文本完整

## iOS
- 允许 http 调试（仅开发）
- 拍照/相册上传无崩溃
- 结果页图片和文本完整

## 验收结果
- 端到端流程可跑通
- 错误提示明确可读
