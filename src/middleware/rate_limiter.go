package middleware

import (
	"context"
	"fmt"
	"time"

	"github.com/assimon/luuu/model/dao"
	"github.com/go-redis/redis/v8"
	"github.com/labstack/echo/v4"
)

// RateLimitConfig 频率限制配置
type RateLimitConfig struct {
	Requests int           // 允许的请求数
	Window   time.Duration // 时间窗口
	KeyFunc  func(c echo.Context) string // 生成限流键的函数
}

// RateLimiter 频率限制中间件（基于 Redis 滑动窗口算法）
// 使用 Redis Sorted Set 实现滑动窗口，精确控制时间窗口内的请求数
func RateLimiter(config RateLimitConfig) echo.MiddlewareFunc {
	return func(next echo.HandlerFunc) echo.HandlerFunc {
		return func(ctx echo.Context) error {
			key := config.KeyFunc(ctx)
			allowed, remaining, err := checkRateLimit(key, config.Requests, config.Window)
			if err != nil {
				// Redis 不可用时，根据策略决定是否允许请求
				// 生产环境建议拒绝（fail-close），开发环境可允许（fail-open）
				return echo.NewHTTPError(503, "服务暂时不可用")
			}

			// 设置响应头，告知客户端限流状态
			ctx.Response().Header().Set("X-RateLimit-Limit", fmt.Sprintf("%d", config.Requests))
			ctx.Response().Header().Set("X-RateLimit-Remaining", fmt.Sprintf("%d", remaining))
			ctx.Response().Header().Set("X-RateLimit-Reset", fmt.Sprintf("%d", time.Now().Add(config.Window).Unix()))

			if !allowed {
				return echo.NewHTTPError(429, "请求过于频繁，请稍后再试")
			}
			return next(ctx)
		}
	}
}

// checkRateLimit 使用 Redis 滑动窗口算法检查频率限制
// 返回: (是否允许, 剩余次数, 错误)
func checkRateLimit(key string, maxRequests int, window time.Duration) (bool, int, error) {
	ctx := context.Background()
	now := time.Now().UnixNano()
	windowStart := now - int64(window)

	pipe := dao.Rdb.Pipeline()

	// 1. 移除窗口外的旧记录
	pipe.ZRemRangeByScore(ctx, key, "0", fmt.Sprintf("%d", windowStart))

	// 2. 统计当前窗口内的请求数
	pipe.ZCard(ctx, key)

	// 3. 添加当前请求记录
	pipe.ZAdd(ctx, key, &redis.Z{
		Score:  float64(now),
		Member: fmt.Sprintf("%d", now),
	})

	// 4. 设置 key 过期时间（防止内存泄露）
	pipe.Expire(ctx, key, window*2)

	results, err := pipe.Exec(ctx)
	if err != nil {
		return false, 0, err
	}

	// 获取当前请求数（第2步的结果）
	count := results[1].(*redis.IntCmd).Val()
	allowed := count < int64(maxRequests)
	remaining := maxRequests - int(count) - 1
	if remaining < 0 {
		remaining = 0
	}

	return allowed, remaining, nil
}

// IPRateLimiter 基于 IP 的频率限制
func IPRateLimiter(requests int, window time.Duration) echo.MiddlewareFunc {
	return RateLimiter(RateLimitConfig{
		Requests: requests,
		Window:   window,
		KeyFunc: func(c echo.Context) string {
			return fmt.Sprintf("rate_limit:ip:%s", c.RealIP())
		},
	})
}

// UserRateLimiter 基于用户的频率限制（需要先通过认证中间件）
func UserRateLimiter(requests int, window time.Duration) echo.MiddlewareFunc {
	return RateLimiter(RateLimitConfig{
		Requests: requests,
		Window:   window,
		KeyFunc: func(c echo.Context) string {
			// 根据 JWT 中的 user_id 限流
			userID := c.Get("admin_user_id")
			if userID == nil {
				// 未认证用户使用 IP 限流
				return fmt.Sprintf("rate_limit:anon:%s", c.RealIP())
			}
			return fmt.Sprintf("rate_limit:user:%v", userID)
		},
	})
}

// EndpointRateLimiter 基于特定端点的频率限制
func EndpointRateLimiter(endpoint string, requests int, window time.Duration) echo.MiddlewareFunc {
	return RateLimiter(RateLimitConfig{
		Requests: requests,
		Window:   window,
		KeyFunc: func(c echo.Context) string {
			return fmt.Sprintf("rate_limit:endpoint:%s:%s", endpoint, c.RealIP())
		},
	})
}
