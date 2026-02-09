#!/bin/bash

# Epusdt Redis 启动脚本
# 本脚本用于启动项目所需的Redis服务

REDIS_SERVER="/Users/macbook/Downloads/redis-6.2.14/src/redis-server"
REDIS_PORT=6379
REDIS_PID_FILE="/tmp/epusdt-redis.pid"
REDIS_LOG_FILE="./logs/redis.log"

# 创建日志目录
mkdir -p ./logs

echo "🚀 启动 Redis 服务..."
echo "Redis Server: $REDIS_SERVER"
echo "Redis Port: $REDIS_PORT"
echo "Log File: $REDIS_LOG_FILE"

# 检查Redis是否已在运行
if [ -f "$REDIS_PID_FILE" ]; then
    OLD_PID=$(cat "$REDIS_PID_FILE")
    if ps -p $OLD_PID > /dev/null 2>&1; then
        echo "⚠️  Redis 已在运行 (PID: $OLD_PID)"
        exit 0
    fi
fi

# 启动Redis
$REDIS_SERVER --port $REDIS_PORT --daemonize yes --pidfile "$REDIS_PID_FILE" --logfile "$REDIS_LOG_FILE" --databases 16

if [ $? -eq 0 ]; then
    echo "✅ Redis 启动成功！"
    echo "PID: $(cat $REDIS_PID_FILE)"
    echo ""
    echo "查看日志: tail -f $REDIS_LOG_FILE"
    echo "停止Redis: kill $(cat $REDIS_PID_FILE)"
else
    echo "❌ Redis 启动失败"
    exit 1
fi
