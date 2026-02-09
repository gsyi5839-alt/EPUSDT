package middleware

import (
	"strings"
	"time"

	"github.com/assimon/luuu/config"
	"github.com/golang-jwt/jwt"
	"github.com/labstack/echo/v4"
)

func AdminAuth() echo.MiddlewareFunc {
	return func(next echo.HandlerFunc) echo.HandlerFunc {
		return func(ctx echo.Context) error {
			auth := ctx.Request().Header.Get("Authorization")
			if auth == "" {
				return echo.NewHTTPError(401, "unauthorized")
			}
			parts := strings.SplitN(auth, " ", 2)
			if len(parts) != 2 || strings.ToLower(parts[0]) != "bearer" {
				return echo.NewHTTPError(401, "unauthorized")
			}
			tokenStr := parts[1]
			token, err := jwt.Parse(tokenStr, func(t *jwt.Token) (interface{}, error) {
				// 确保签名算法一致，防止算法替换攻击
				if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
					return nil, echo.NewHTTPError(401, "无效的签名算法")
				}
				return []byte(config.GetAdminJwtSecret()), nil
			})
			if err != nil || !token.Valid {
				return echo.NewHTTPError(401, "unauthorized")
			}
			claims, ok := token.Claims.(jwt.MapClaims)
			if !ok {
				return echo.NewHTTPError(401, "unauthorized")
			}

			// 显式验证 exp 过期时间（双重保障）
			expVal, ok := claims["exp"]
			if !ok {
				return echo.NewHTTPError(401, "token 缺少过期时间")
			}
			expFloat, ok := expVal.(float64)
			if !ok {
				return echo.NewHTTPError(401, "token 过期时间格式错误")
			}
			if time.Now().Unix() > int64(expFloat) {
				return echo.NewHTTPError(401, "token 已过期")
			}

			ctx.Set("admin_user_id", claims["user_id"])
			ctx.Set("admin_username", claims["username"])
			return next(ctx)
		}
	}
}
