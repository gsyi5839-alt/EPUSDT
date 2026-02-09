package middleware

import (
	"strings"

	"github.com/assimon/luuu/model/data"
	"github.com/assimon/luuu/model/service"
	"github.com/labstack/echo/v4"
)

// MerchantAuth 商家JWT认证中间件
func MerchantAuth() echo.MiddlewareFunc {
	return func(next echo.HandlerFunc) echo.HandlerFunc {
		return func(ctx echo.Context) error {
			// 获取Authorization header
			authHeader := ctx.Request().Header.Get("Authorization")
			if authHeader == "" {
				return echo.NewHTTPError(401, "缺少认证信息")
			}

			// 解析Bearer Token
			parts := strings.SplitN(authHeader, " ", 2)
			if len(parts) != 2 || parts[0] != "Bearer" {
				return echo.NewHTTPError(401, "认证格式错误")
			}

			tokenString := parts[1]

			// 验证JWT
			claims, err := service.ValidateMerchantJWT(tokenString)
			if err != nil {
				return echo.NewHTTPError(401, "认证失败")
			}

			// 检查商家账户状态（封禁检查）
			merchant, err := data.GetMerchantByID(claims.MerchantID)
			if err != nil || merchant.ID == 0 {
				return echo.NewHTTPError(401, "商家账户不存在")
			}
			if merchant.Status != 1 {
				return echo.NewHTTPError(403, "账户已被封禁，禁止操作。如有疑问请联系管理员。")
			}

			// 将商家ID和用户名存入context
			ctx.Set("merchant_id", claims.MerchantID)
			ctx.Set("merchant_username", claims.Username)

			return next(ctx)
		}
	}
}
