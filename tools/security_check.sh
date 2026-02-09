#!/bin/bash

# EPUSDT 安全配置检查脚本
# 用途: 检查生产环境配置的安全性

set -e

echo "====== EPUSDT 安全配置检查 ======"
echo ""

ERRORS=0
WARNINGS=0

# 检查 .env 文件是否存在
if [ ! -f .env ]; then
    echo "❌ 错误: .env 文件不存在"
    echo "   请复制 .env.example 并配置"
    exit 1
fi

# 检查 .env 文件权限
PERM=$(stat -c "%a" .env 2>/dev/null || stat -f "%A" .env 2>/dev/null)
if [ "$PERM" != "600" ]; then
    echo "❌ 错误: .env 文件权限不安全（当前: $PERM，应为: 600）"
    echo "   运行: chmod 600 .env"
    ((ERRORS++))
else
    echo "✅ .env 文件权限正确 (600)"
fi

echo ""
echo "====== 检查关键配置 ======"

# 检查默认管理员密码
if grep -q "admin_init_password=admin123" .env; then
    echo "❌ 错误: 检测到默认管理员密码 'admin123'"
    echo "   请立即修改为强密码"
    ((ERRORS++))
else
    echo "✅ 管理员密码已修改"
fi

# 检查 JWT Secret
if grep -q "admin_jwt_secret=epusdt_admin_secret" .env; then
    echo "❌ 错误: 检测到默认 JWT Secret"
    echo "   请使用随机生成的密钥"
    echo "   生成方法: openssl rand -hex 32"
    ((ERRORS++))
else
    echo "✅ JWT Secret 已自定义"
fi

# 检查 API Auth Token
if grep -q "api_auth_token=$" .env || ! grep -q "api_auth_token=" .env; then
    echo "⚠️  警告: API Auth Token 未配置"
    echo "   请生成随机 Token: openssl rand -hex 32"
    ((WARNINGS++))
else
    echo "✅ API Auth Token 已配置"
fi

echo ""
echo "====== 检查私钥安全 ======"

# 检查明文私钥
if grep -q "^merchant_private_key=0x" .env; then
    echo "❌ 错误: 检测到明文私钥存储"
    echo "   请使用加密存储方案"
    echo "   运行: go run tools/encrypt_private_key.go generate-key"
    ((ERRORS++))
else
    echo "✅ 未检测到明文私钥"
fi

# 检查加密私钥配置
if grep -q "^merchant_private_key_encrypted=" .env; then
    echo "✅ 私钥已加密存储"
else
    echo "⚠️  警告: 未配置加密私钥"
    ((WARNINGS++))
fi

# 检查主加密密钥
if grep -q "^master_encryption_key=" .env && ! grep -q "^master_encryption_key=$" .env; then
    echo "✅ 主加密密钥已配置"
else
    echo "⚠️  警告: 主加密密钥未配置"
    ((WARNINGS++))
fi

echo ""
echo "====== 检查 HTTPS 配置 ======"

# 检查 TLS 配置
if grep -q "^tls_cert_file=" .env && grep -q "^tls_key_file=" .env; then
    if ! grep -q "^tls_cert_file=$" .env; then
        echo "✅ HTTPS 已配置"
    else
        echo "⚠️  警告: TLS 配置为空，生产环境必须启用 HTTPS"
        ((WARNINGS++))
    fi
else
    echo "⚠️  警告: 未配置 HTTPS，生产环境必须启用"
    echo "   建议使用 Nginx 反向代理配置 HTTPS"
    ((WARNINGS++))
fi

echo ""
echo "====== 检查 Redis 安全 ======"

# 检查 Redis 密码
if grep -q "^redis_passwd=$" .env; then
    echo "⚠️  警告: Redis 未设置密码"
    echo "   生产环境建议启用 Redis 密码认证"
    ((WARNINGS++))
else
    echo "✅ Redis 密码已配置"
fi

echo ""
echo "====== 检查敏感信息泄露 ======"

# 检查 git 仓库中是否有敏感信息
if [ -d .git ]; then
    echo "检查 Git 仓库中的敏感文件..."

    # 检查 .gitignore 是否包含 .env
    if grep -q "^\.env$" .gitignore 2>/dev/null; then
        echo "✅ .env 已添加到 .gitignore"
    else
        echo "⚠️  警告: .env 未添加到 .gitignore"
        echo "   请添加: echo '.env' >> .gitignore"
        ((WARNINGS++))
    fi

    # 检查是否有 .env 文件被提交到 git
    if git ls-files | grep -q "^\.env$"; then
        echo "❌ 错误: .env 文件已被提交到 Git 仓库"
        echo "   请移除: git rm --cached .env"
        ((ERRORS++))
    else
        echo "✅ .env 未被提交到 Git"
    fi
fi

echo ""
echo "====== 检查调试模式 ======"

# 检查是否启用了调试模式
if grep -q "^app_debug=true" .env; then
    echo "⚠️  警告: 调试模式已启用"
    echo "   生产环境请设置: app_debug=false"
    ((WARNINGS++))
else
    echo "✅ 调试模式已关闭"
fi

echo ""
echo "====== 检查摘要 ======"
echo "错误: $ERRORS"
echo "警告: $WARNINGS"
echo ""

if [ $ERRORS -gt 0 ]; then
    echo "❌ 发现 $ERRORS 个严重安全问题，请立即修复"
    exit 1
elif [ $WARNINGS -gt 0 ]; then
    echo "⚠️  发现 $WARNINGS 个潜在安全问题，建议修复"
    exit 0
else
    echo "✅ 安全配置检查通过"
    exit 0
fi
