package middleware

import (
	"bytes"
	"context"
	"fmt"
	"time"

	"github.com/assimon/luuu/config"
	"github.com/assimon/luuu/model/dao"
	"github.com/assimon/luuu/util/constant"
	"github.com/assimon/luuu/util/json"
	"github.com/assimon/luuu/util/sign"
	"github.com/labstack/echo/v4"
	"io/ioutil"
)

// 重放防护: nonce 在 Redis 中缓存的过期时间
const nonceExpiration = 5 * time.Minute

// 重放防护: 允许的时间戳偏差（前后各5分钟）
const timestampTolerance = 5 * time.Minute

func CheckApiSign() echo.MiddlewareFunc {
	return func(next echo.HandlerFunc) echo.HandlerFunc {
		return func(ctx echo.Context) error {
			params, err := ioutil.ReadAll(ctx.Request().Body)
			if err != nil {
				return constant.SignatureErr
			}
			m := make(map[string]interface{})
			err = json.Cjson.Unmarshal(params, &m)
			signature, ok := m["signature"]
			if !ok {
				return constant.SignatureErr
			}

			// ========== 重放防护: 验证时间戳 ==========
			timestampVal, ok := m["timestamp"]
			if !ok {
				return echo.NewHTTPError(400, "缺少 timestamp 参数")
			}
			var ts int64
			switch v := timestampVal.(type) {
			case float64:
				ts = int64(v)
			case int64:
				ts = v
			default:
				return echo.NewHTTPError(400, "timestamp 参数格式错误")
			}
			now := time.Now().Unix()
			diff := now - ts
			if diff < 0 {
				diff = -diff
			}
			if diff > int64(timestampTolerance.Seconds()) {
				return echo.NewHTTPError(400, "请求已过期，timestamp 超出允许范围")
			}

			// ========== 重放防护: 验证 nonce 唯一性 ==========
			nonceVal, ok := m["nonce"]
			if !ok {
				return echo.NewHTTPError(400, "缺少 nonce 参数")
			}
			nonce, ok := nonceVal.(string)
			if !ok || nonce == "" {
				return echo.NewHTTPError(400, "nonce 参数格式错误")
			}

			// 检查 nonce 是否已使用（Redis SETNX 原子操作）
			nonceKey := fmt.Sprintf("api_nonce:%s", nonce)
			redisCtx := context.Background()
			set, err := dao.Rdb.SetNX(redisCtx, nonceKey, 1, nonceExpiration).Result()
			if err != nil {
				// Redis 不可用时拒绝请求，防止重放
				return echo.NewHTTPError(500, "服务暂时不可用")
			}
			if !set {
				// nonce 已存在，说明是重放请求
				return echo.NewHTTPError(400, "重复请求，nonce 已使用")
			}

			// ========== 签名验证（支持 MD5 和 HMAC-SHA256 双版本）==========
			// 获取签名算法版本（支持渐进式升级）
			signVersion, _ := m["sign_version"].(string)
			var checkSignature string

			if signVersion == "v2" {
				// 使用 HMAC-SHA256（推荐）
				checkSignature, err = sign.GetHMAC(m, config.GetApiAuthToken())
			} else {
				// 兼容旧版 MD5（默认，6个月后移除）
				checkSignature, err = sign.Get(m, config.GetApiAuthToken())
			}

			if err != nil {
				return constant.SignatureErr
			}
			if checkSignature != signature {
				return constant.SignatureErr
			}
			ctx.Request().Body = ioutil.NopCloser(bytes.NewBuffer(params))
			return next(ctx)
		}
	}
}
