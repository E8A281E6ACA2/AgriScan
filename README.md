# AgriScan 项目结构

## 技术栈

- **后端**：Go + Gin + GORM
- **前端**：Flutter
- **数据库**：PostgreSQL
- **对象存储**：腾讯云 COS（可扩展）

## 目录结构

```
AgriScan/
├── backend/           # Go 后端
│   ├── cmd/
│   │   └── server/    # 入口
│   ├── internal/
│   │   ├── config/   # 配置
│   │   ├── handler/  # HTTP 处理
│   │   ├── model/    # 数据模型
│   │   ├── service/  # 业务逻辑
│   │   ├── repository/ # 数据层
│   │   └── llm/      # 大模型抽象
│   ├── pkg/
│   │   └── storage/  # 对象存储
│   └── go.mod
├── frontend/          # Flutter 前端
│   ├── lib/
│   ├── ios/
│   ├── android/
│   └── pubspec.yaml
└── docs/
    └── api.md
```

## 开发阶段

### V1
1. 图像采集模块
2. 作物识别（云端大模型）
3. 结果展示
4. 数据资产存储

### V2
1. 病害识别
2. 生育期识别
3. 本地 TFLite 模型
