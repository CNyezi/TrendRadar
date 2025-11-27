#!/bin/bash
set -e

# 检查配置文件
if [ ! -f "/app/config/config.yaml" ] || [ ! -f "/app/config/frequency_words.txt" ]; then
    echo "❌ 配置文件缺失"
    exit 1
fi

# 保存环境变量
env >> /etc/environment

# MCP 服务启动函数
start_mcp_server() {
    if [ "${ENABLE_MCP:-true}" = "true" ]; then
        echo "🔌 启动 MCP 服务 (${MCP_HOST:-0.0.0.0}:${MCP_PORT:-3333})"
        /usr/local/bin/python -m mcp_server.server \
            --transport http \
            --host "${MCP_HOST:-0.0.0.0}" \
            --port "${MCP_PORT:-3333}" &
        MCP_PID=$!
        echo "✅ MCP 服务已启动 (PID: $MCP_PID)"
    fi
}

# 信号处理：优雅关闭
cleanup() {
    echo "🛑 收到停止信号，正在关闭服务..."
    if [ -n "$MCP_PID" ]; then
        kill $MCP_PID 2>/dev/null || true
    fi
    if [ -n "$CRON_PID" ]; then
        kill $CRON_PID 2>/dev/null || true
    fi
    exit 0
}

trap cleanup SIGTERM SIGINT

case "${RUN_MODE:-cron}" in
"once")
    echo "🔄 单次执行模式"
    start_mcp_server
    exec /usr/local/bin/python main.py
    ;;
"mcp-only")
    echo "🔌 仅 MCP 服务模式"
    exec /usr/local/bin/python -m mcp_server.server \
        --transport http \
        --host "${MCP_HOST:-0.0.0.0}" \
        --port "${MCP_PORT:-3333}"
    ;;
"cron")
    # 生成 crontab
    echo "${CRON_SCHEDULE:-*/30 * * * *} cd /app && /usr/local/bin/python main.py" > /tmp/crontab

    echo "📅 生成的crontab内容:"
    cat /tmp/crontab

    if ! /usr/local/bin/supercronic -test /tmp/crontab; then
        echo "❌ crontab格式验证失败"
        exit 1
    fi

    # 启动 MCP 服务（后台运行）
    start_mcp_server

    # 立即执行一次（如果配置了）
    if [ "${IMMEDIATE_RUN:-false}" = "true" ]; then
        echo "▶️ 立即执行一次爬虫"
        /usr/local/bin/python main.py
    fi

    echo "⏰ 启动 supercronic: ${CRON_SCHEDULE:-*/30 * * * *}"

    # supercronic 在前台运行
    /usr/local/bin/supercronic -passthrough-logs /tmp/crontab &
    CRON_PID=$!

    # 等待任一进程退出
    wait -n
    cleanup
    ;;
*)
    exec "$@"
    ;;
esac
