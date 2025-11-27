# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

TrendRadar 是一个轻量级热点新闻聚合监控工具，支持实时抓取多平台热点新闻、AI 智能分析和多渠道推送。

- **版本**: v3.4.0 (MCP v1.0.3)
- **语言**: Python 3.10+
- **核心框架**: FastMCP 2.0 (MCP 服务器)

## 常用命令

```bash
# 安装依赖
./setup-mac.sh              # Mac/Linux 一键安装
./setup-windows.bat         # Windows 一键安装
uv sync                     # 手动安装依赖

# 运行爬虫
uv run python main.py

# 启动 MCP 服务
./start-http.sh             # HTTP 模式 (端口 3333)
uv run python -m mcp_server.server --transport stdio  # Stdio 模式

# Docker 部署
cd docker && docker-compose up -d
```

## 代码架构

### 核心模块

```
main.py                     # 主爬虫程序（数据抓取、权重计算、推送）
mcp_server/
├── server.py               # FastMCP 2.0 应用入口
├── services/               # 数据访问层
│   ├── data_service.py     # 统一数据查询接口
│   ├── parser_service.py   # 文件解析（txt/yaml）
│   └── cache_service.py    # 15分钟TTL缓存
├── tools/                  # MCP 工具集
│   ├── data_query.py       # 核心：新闻数据查询
│   ├── analytics.py        # 高级分析（趋势、情感、关键词）
│   ├── search_tools.py     # 智能检索
│   ├── system.py           # 系统管理
│   └── config_mgmt.py      # 配置管理
└── utils/
    ├── date_parser.py      # 自然语言日期解析
    ├── validators.py       # 参数验证
    └── errors.py           # 自定义错误类
```

### 数据流

```
User Query → MCP Tool → Validators → Services → output/YYYY/MM/DD/*.txt → JSON Response
```

### 关键设计

1. **单例模式**: MCP 工具全局缓存，避免重复初始化
2. **权重算法**: 排名(60%) + 频次(30%) + 热度(10%)
3. **错误体系**: MCPError 基类及子类（DataNotFoundError、InvalidParameterError 等）

### 配置系统

- `config/config.yaml`: 主配置（爬虫、推送、权重、平台）
- `config/frequency_words.txt`: 监控关键词（空行分隔词组）
- `docker/.env`: 环境变量（优先级高于 YAML）

### 输出结构

```
output/YYYY/MM/DD/
├── HH_MM_SS.txt            # 平台|排名|标题|首次时间|最后时间|出现次数
├── HH_MM_SS.html           # HTML 报告
└── push_record.json        # 推送记录
```

## 推送渠道

支持 12 种：飞书、钉钉、企业微信、Telegram、邮件、ntfy、Bark、Slack 等

三种模式：
- `daily`: 当日全部匹配新闻
- `current`: 当前榜单匹配新闻
- `incremental`: 仅新增内容

## GitHub Actions

`.github/workflows/crawler.yml` 支持 Cron 定时和手动触发。

Cron 使用 UTC 时间，北京时间需 -8h：
```yaml
"0 * * * *"         # 每小时整点
"*/30 0-14 * * *"   # 每天北京时间 8:00-22:00 每30分钟
```
