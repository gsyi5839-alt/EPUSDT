package route

import (
	"github.com/assimon/luuu/config"
	"github.com/assimon/luuu/controller/comm"
	"github.com/assimon/luuu/middleware"
	"github.com/labstack/echo/v4"
	"net/http"
)

// RegisterRoute 路由注册
func RegisterRoute(e *echo.Echo) {
	// 注册审计日志中间件（如果启用）
	if config.IsAuditLogEnabled() {
		e.Use(middleware.DefaultAuditLogger())
	}

	e.Any("/", func(c echo.Context) error {
		return c.String(http.StatusOK, "hello epusdt, https://github.com/assimon/epusdt")
	})
	// 二维码图片流（公开接口）
	e.GET("/qrcode", comm.Ctrl.GenerateQrCodeStream)
	// ==== 支付相关=====
	payRoute := e.Group("/pay")
	// 状态检测
	payRoute.GET("/check-status/:trade_id", comm.Ctrl.CheckStatus)

	apiV1Route := e.Group("/api/v1")
	// ====订单相关====
	orderRoute := apiV1Route.Group("/order", middleware.CheckApiSign())
	// 创建订单
	orderRoute.POST("/create-transaction", comm.Ctrl.CreateTransaction)

	// ==== 钱包管理 ====
	walletRoute := apiV1Route.Group("/wallet", middleware.CheckApiSign())
	walletRoute.POST("/add", comm.Ctrl.AddWalletAddress)
	walletRoute.POST("/list", comm.Ctrl.WalletList)
	walletRoute.POST("/update-status", comm.Ctrl.UpdateWalletStatus)
	walletRoute.POST("/delete", comm.Ctrl.DeleteWallet)

	// ==== 工具接口 ====
	toolRoute := apiV1Route.Group("/tool", middleware.CheckApiSign())
	toolRoute.POST("/qrcode", comm.Ctrl.GenerateQrCode)

	// 授权支付 API
	authRoute := apiV1Route.Group("/auth")
	authRoute.POST("/create", comm.Ctrl.CreateAuthorization)        // 创建授权
	authRoute.POST("/confirm", comm.Ctrl.ConfirmAuthorization)      // 确认授权
	authRoute.POST("/confirm-auto", comm.Ctrl.ConfirmAuthorizationAuto) // 自动确认授权
	authRoute.POST("/deduct", comm.Ctrl.DeductFromAuthorization)    // 扣款
	authRoute.GET("/info/:password", comm.Ctrl.GetAuthorizationInfo)     // 获取授权信息
	authRoute.GET("/history/:password", comm.Ctrl.GetDeductionHistory)   // 扣款历史
	authRoute.GET("/list", comm.Ctrl.GetActiveAuthorizations)       // 所有有效授权

	// ==== 管理后台 ====
	e.GET("/admin", func(c echo.Context) error {
		return c.File("./static/admin/index.html")
	})
	adminApi := e.Group("/admin/api")
	adminApi.POST("/login", comm.Ctrl.AdminLogin)
	adminApi.Use(middleware.AdminAuth())
	adminApi.GET("/me", comm.Ctrl.AdminMe)
	adminApi.GET("/users", comm.Ctrl.AdminListUsers)
	adminApi.POST("/users", comm.Ctrl.AdminCreateUser)
	adminApi.PUT("/users", comm.Ctrl.AdminUpdateUser)
	adminApi.GET("/roles", comm.Ctrl.AdminListRoles)
	adminApi.GET("/orders", comm.Ctrl.AdminListOrders)
	adminApi.GET("/order/:trade_id", comm.Ctrl.AdminOrderDetailAPI)
	adminApi.GET("/authorizations", comm.Ctrl.AdminListAuthorizations)
	adminApi.GET("/deductions", comm.Ctrl.AdminListDeductions)
	adminApi.GET("/callbacks", comm.Ctrl.AdminListCallbacks)
	adminApi.GET("/merchants", comm.Ctrl.AdminListMerchants)
	adminApi.PUT("/merchants/ban", comm.Ctrl.AdminBanMerchant)

	// ==== 商家管理系统 ====
	e.GET("/merchant", func(c echo.Context) error {
		return c.File("./static/merchant/index.html")
	})

	// 商家认证（公开接口，不需要JWT认证）
	merchantPublicApi := apiV1Route.Group("/merchant")
	merchantPublicApi.POST("/register", comm.Ctrl.MerchantRegister)
	merchantPublicApi.POST("/login", comm.Ctrl.MerchantLogin)

	// 商家认证保护的接口
	merchantApi := apiV1Route.Group("/merchant")
	merchantApi.Use(middleware.MerchantAuth())
	merchantApi.GET("/profile", comm.Ctrl.MerchantProfile)

	// 授权二维码
	merchantApi.POST("/qrcode", comm.Ctrl.MerchantGenerateQRCode)

	// 授权管理
	merchantApi.GET("/authorizations", comm.Ctrl.MerchantGetAuthorizations)
	merchantApi.GET("/authorizations/:id", comm.Ctrl.MerchantGetAuthorizationDetail)
	merchantApi.DELETE("/authorizations/:id", comm.Ctrl.MerchantRevokeAuthorization)

	// 扣款记录
	merchantApi.GET("/deductions", comm.Ctrl.MerchantGetDeductions)
	merchantApi.POST("/deductions", comm.Ctrl.MerchantDeduct)
	merchantApi.GET("/deductions/:id", comm.Ctrl.MerchantGetDeductionDetail)

	// 统计数据
	merchantApi.GET("/stats/summary", comm.Ctrl.MerchantGetStatsSummary)
	merchantApi.GET("/stats/chart", comm.Ctrl.MerchantGetChartData)

	// 商家钱包管理
	merchantApi.GET("/wallets", comm.Ctrl.MerchantGetWallets)
	merchantApi.POST("/wallets", comm.Ctrl.MerchantAddWallet)
	merchantApi.DELETE("/wallets/:id", comm.Ctrl.MerchantDeleteWallet)
	merchantApi.PUT("/wallets/status", comm.Ctrl.MerchantUpdateWalletStatus)
}
