package route

import (
	"github.com/assimon/luuu/controller/comm"
	"github.com/assimon/luuu/middleware"
	"github.com/labstack/echo/v4"
	"net/http"
)

// RegisterRoute 路由注册
func RegisterRoute(e *echo.Echo) {
	e.Any("/", func(c echo.Context) error {
		return c.String(http.StatusOK, "hello epusdt, https://github.com/assimon/epusdt")
	})
	// ==== 支付相关=====
	payRoute := e.Group("/pay")
	// 收银台
	payRoute.GET("/checkout-counter/:trade_id", comm.Ctrl.CheckoutCounter)
	// 状态检测
	payRoute.GET("/check-status/:trade_id", comm.Ctrl.CheckStatus)

	apiV1Route := e.Group("/api/v1")
	// ====订单相关====
	orderRoute := apiV1Route.Group("/order", middleware.CheckApiSign())
	// 创建订单
	orderRoute.POST("/create-transaction", comm.Ctrl.CreateTransaction)

	// ==== 授权支付（钱包授权扣款） ====
	// H5页面
	e.GET("/auth/:auth_no", comm.Ctrl.AuthorizePage)                // 客户授权页面
	e.GET("/auth-manager", comm.Ctrl.AuthorizeManagerPage)          // 授权管理页面

	// 授权支付 API
	authRoute := apiV1Route.Group("/auth")
	authRoute.POST("/create", comm.Ctrl.CreateAuthorization)        // 创建授权
	authRoute.POST("/confirm", comm.Ctrl.ConfirmAuthorization)      // 确认授权
	authRoute.POST("/deduct", comm.Ctrl.DeductFromAuthorization)    // 扣款
	authRoute.GET("/info/:password", comm.Ctrl.GetAuthorizationInfo)     // 获取授权信息
	authRoute.GET("/history/:password", comm.Ctrl.GetDeductionHistory)   // 扣款历史
	authRoute.GET("/list", comm.Ctrl.GetActiveAuthorizations)       // 所有有效授权
}
