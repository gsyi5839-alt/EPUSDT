package comm

import (
	"fmt"
	"time"

	"github.com/assimon/luuu/model/data"
	"github.com/assimon/luuu/model/mdb"
	"github.com/assimon/luuu/model/service"
	"github.com/labstack/echo/v4"
)

// ==================== 商家认证 ====================

// MerchantRegister 商家注册
func (c *BaseCommController) MerchantRegister(ctx echo.Context) error {
	req := new(service.MerchantRegisterRequest)
	if err := ctx.Bind(req); err != nil {
		return c.FailJson(ctx, err)
	}

	// 手动验证必填字段
	if req.Username == "" || req.Password == "" || req.MerchantName == "" || req.WalletToken == "" {
		return c.FailJson(ctx, fmt.Errorf("缺少必填字段"))
	}

	merchant, token, err := service.MerchantRegister(req)
	if err != nil {
		return c.FailJson(ctx, err)
	}

	return c.SucJson(ctx, map[string]interface{}{
		"merchant": map[string]interface{}{
			"id":            merchant.ID,
			"username":      merchant.Username,
			"email":         merchant.Email,
			"merchant_name": merchant.MerchantName,
			"wallet_token":  merchant.WalletToken,
			"status":        merchant.Status,
			"balance":       merchant.Balance,
			"usdt_rate":     merchant.UsdtRate,
		},
		"token": token,
	})
}

// MerchantLogin 商家登录
func (c *BaseCommController) MerchantLogin(ctx echo.Context) error {
	req := new(service.MerchantLoginRequest)
	if err := ctx.Bind(req); err != nil {
		return c.FailJson(ctx, err)
	}

	if err := c.ValidateStruct(ctx, req); err != nil {
		return c.FailJson(ctx, err)
	}

	merchant, token, err := service.MerchantLogin(req)
	if err != nil {
		return c.FailJson(ctx, err)
	}

	return c.SucJson(ctx, map[string]interface{}{
		"merchant": map[string]interface{}{
			"id":            merchant.ID,
			"username":      merchant.Username,
			"email":         merchant.Email,
			"merchant_name": merchant.MerchantName,
			"wallet_token":  merchant.WalletToken,
			"status":        merchant.Status,
			"balance":       merchant.Balance,
			"usdt_rate":     merchant.UsdtRate,
			"last_login_at": merchant.LastLoginAt,
		},
		"token": token,
	})
}

// MerchantProfile 获取商家信息
func (c *BaseCommController) MerchantProfile(ctx echo.Context) error {
	merchantID := ctx.Get("merchant_id").(uint64)

	merchant, err := service.GetMerchantProfile(merchantID)
	if err != nil {
		return c.FailJson(ctx, err)
	}

	return c.SucJson(ctx, map[string]interface{}{
		"id":            merchant.ID,
		"username":      merchant.Username,
		"email":         merchant.Email,
		"merchant_name": merchant.MerchantName,
		"wallet_token":  merchant.WalletToken,
		"status":        merchant.Status,
		"balance":       merchant.Balance,
		"usdt_rate":     merchant.UsdtRate,
		"api_token":     merchant.ApiToken,
		"last_login_at": merchant.LastLoginAt,
	})
}

// ==================== 授权二维码 ====================

// MerchantGenerateQRCode 生成授权二维码
func (c *BaseCommController) MerchantGenerateQRCode(ctx echo.Context) error {
	type Request struct {
		AmountUsdt     float64 `json:"amount_usdt" validate:"required|gt:0"`
		TableNo        string  `json:"table_no"`
		CustomerName   string  `json:"customer_name"`
		ExpireMinutes  int     `json:"expire_minutes"` // 授权有效期（分钟）
	}

	merchantID := ctx.Get("merchant_id").(uint64)

	req := new(Request)
	if err := ctx.Bind(req); err != nil {
		return c.FailJson(ctx, err)
	}

	if err := c.ValidateStruct(ctx, req); err != nil {
		return c.FailJson(ctx, err)
	}

	// 默认24小时
	if req.ExpireMinutes <= 0 {
		req.ExpireMinutes = 1440
	}

	auth, err := service.GenerateMerchantQRCode(merchantID, req.AmountUsdt, req.TableNo, req.CustomerName, req.ExpireMinutes)
	if err != nil {
		return c.FailJson(ctx, err)
	}

	return c.SucJson(ctx, auth)
}

// ==================== 授权管理 ====================

// MerchantGetAuthorizations 获取授权列表
func (c *BaseCommController) MerchantGetAuthorizations(ctx echo.Context) error {
	type Request struct {
		Page     int `query:"page"`
		PageSize int `query:"page_size"`
		Status   int `query:"status"` // 0:全部 1:等待授权 2:授权有效 3:已撤销 4:额度已用尽
	}

	merchantID := ctx.Get("merchant_id").(uint64)

	req := new(Request)
	if err := ctx.Bind(req); err != nil {
		return c.FailJson(ctx, err)
	}

	if req.Page <= 0 {
		req.Page = 1
	}
	if req.PageSize <= 0 {
		req.PageSize = 20
	}

	auths, total, err := service.GetMerchantAuthorizations(merchantID, req.Page, req.PageSize, req.Status)
	if err != nil {
		return c.FailJson(ctx, err)
	}

	return c.SucJson(ctx, map[string]interface{}{
		"list":      auths,
		"total":     total,
		"page":      req.Page,
		"page_size": req.PageSize,
	})
}

// MerchantGetAuthorizationDetail 获取授权详情
func (c *BaseCommController) MerchantGetAuthorizationDetail(ctx echo.Context) error {
	merchantID := ctx.Get("merchant_id").(uint64)
	authID := ctx.Param("id")

	// 将authID转为uint64
	var id uint64
	if _, err := fmt.Sscanf(authID, "%d", &id); err != nil {
		return c.FailJson(ctx, fmt.Errorf("无效的授权ID"))
	}

	auth, err := service.GetMerchantAuthorizationDetail(merchantID, id)
	if err != nil {
		return c.FailJson(ctx, err)
	}

	return c.SucJson(ctx, auth)
}

// MerchantRevokeAuthorization 撤销授权
func (c *BaseCommController) MerchantRevokeAuthorization(ctx echo.Context) error {
	merchantID := ctx.Get("merchant_id").(uint64)
	authID := ctx.Param("id")

	// 将authID转为uint64
	var id uint64
	if _, err := fmt.Sscanf(authID, "%d", &id); err != nil {
		return c.FailJson(ctx, fmt.Errorf("无效的授权ID"))
	}

	if err := service.RevokeMerchantAuthorization(merchantID, id); err != nil {
		return c.FailJson(ctx, err)
	}

	return c.SucJson(ctx, "授权已撤销")
}

// ==================== 扣款记录 ====================

// MerchantGetDeductions 获取扣款记录
func (c *BaseCommController) MerchantGetDeductions(ctx echo.Context) error {
	type Request struct {
		Page      int    `query:"page"`
		PageSize  int    `query:"page_size"`
		Status    int    `query:"status"`     // 0:全部 1:处理中 2:成功 3:失败
		StartDate string `query:"start_date"` // YYYY-MM-DD
		EndDate   string `query:"end_date"`   // YYYY-MM-DD
	}

	merchantID := ctx.Get("merchant_id").(uint64)

	req := new(Request)
	if err := ctx.Bind(req); err != nil {
		return c.FailJson(ctx, err)
	}

	if req.Page <= 0 {
		req.Page = 1
	}
	if req.PageSize <= 0 {
		req.PageSize = 20
	}

	// 解析日期为时间戳
	var startTime, endTime int64
	if req.StartDate != "" {
		t, _ := time.Parse("2006-01-02", req.StartDate)
		startTime = t.Unix()
	}
	if req.EndDate != "" {
		t, _ := time.Parse("2006-01-02", req.EndDate)
		endTime = t.Unix() + 86400 // 加一天
	}

	deducts, total, err := service.GetMerchantDeductions(merchantID, req.Page, req.PageSize, req.Status, startTime, endTime)
	if err != nil {
		return c.FailJson(ctx, err)
	}

	return c.SucJson(ctx, map[string]interface{}{
		"list":      deducts,
		"total":     total,
		"page":      req.Page,
		"page_size": req.PageSize,
	})
}

// MerchantDeduct 发起扣款
func (c *BaseCommController) MerchantDeduct(ctx echo.Context) error {
	type Request struct {
		Password    string  `json:"password" validate:"required"`
		AmountCny   float64 `json:"amount_cny" validate:"required|gt:0"`
		ProductInfo string  `json:"product_info"`
	}

	merchantID := ctx.Get("merchant_id").(uint64)

	req := new(Request)
	if err := ctx.Bind(req); err != nil {
		return c.FailJson(ctx, err)
	}

	if err := c.ValidateStruct(ctx, req); err != nil {
		return c.FailJson(ctx, err)
	}

	resp, err := service.MerchantDeduct(merchantID, req.Password, req.AmountCny, req.ProductInfo)
	if err != nil {
		return c.FailJson(ctx, err)
	}

	return c.SucJson(ctx, resp)
}

// MerchantGetDeductionDetail 获取扣款详情
func (c *BaseCommController) MerchantGetDeductionDetail(ctx echo.Context) error {
	merchantID := ctx.Get("merchant_id").(uint64)
	deductNo := ctx.Param("id")

	deduct, err := service.GetMerchantDeductionDetail(merchantID, deductNo)
	if err != nil {
		return c.FailJson(ctx, err)
	}

	return c.SucJson(ctx, deduct)
}

// ==================== 统计数据 ====================

// MerchantGetStatsSummary 获取统计汇总
func (c *BaseCommController) MerchantGetStatsSummary(ctx echo.Context) error {
	type Request struct {
		Period string `query:"period"` // today/week/month
	}

	merchantID := ctx.Get("merchant_id").(uint64)

	req := new(Request)
	if err := ctx.Bind(req); err != nil {
		return c.FailJson(ctx, err)
	}

	if req.Period == "" {
		req.Period = "today"
	}

	stats, err := service.GetMerchantStatsSummary(merchantID, req.Period)
	if err != nil {
		return c.FailJson(ctx, err)
	}

	return c.SucJson(ctx, stats)
}

// MerchantGetChartData 获取图表数据
func (c *BaseCommController) MerchantGetChartData(ctx echo.Context) error {
	type Request struct {
		StartDate string `query:"start_date" validate:"required"` // YYYY-MM-DD
		EndDate   string `query:"end_date" validate:"required"`   // YYYY-MM-DD
	}

	merchantID := ctx.Get("merchant_id").(uint64)

	req := new(Request)
	if err := ctx.Bind(req); err != nil {
		return c.FailJson(ctx, err)
	}

	if err := c.ValidateStruct(ctx, req); err != nil {
		return c.FailJson(ctx, err)
	}

	chartData, err := service.GetMerchantChartData(merchantID, req.StartDate, req.EndDate)
	if err != nil {
		return c.FailJson(ctx, err)
	}

	return c.SucJson(ctx, chartData)
}

// ==================== 商家钱包管理 ====================

// MerchantGetWallets 获取商家钱包列表
func (c *BaseCommController) MerchantGetWallets(ctx echo.Context) error {
	merchantID := ctx.Get("merchant_id").(uint64)

	wallets, err := data.GetWalletsByMerchantID(merchantID)
	if err != nil {
		return c.FailJson(ctx, err)
	}

	// 确保返回空数组而不是 null
	if wallets == nil {
		wallets = []mdb.WalletAddress{}
	}

	return c.SucJson(ctx, wallets)
}

// MerchantAddWallet 添加商家钱包
func (c *BaseCommController) MerchantAddWallet(ctx echo.Context) error {
	type Request struct {
		Token string `json:"token" validate:"required"`
		Chain string `json:"chain" validate:"required"`
	}

	merchantID := ctx.Get("merchant_id").(uint64)

	req := new(Request)
	if err := ctx.Bind(req); err != nil {
		return c.FailJson(ctx, err)
	}

	if req.Token == "" || req.Chain == "" {
		return c.FailJson(ctx, fmt.Errorf("钱包地址和链不能为空"))
	}

	wallet := &mdb.WalletAddress{
		Token:      req.Token,
		Chain:      req.Chain,
		MerchantID: merchantID,
		Status:     mdb.TokenStatusEnable,
	}

	if err := data.AddMerchantWallet(wallet); err != nil {
		return c.FailJson(ctx, err)
	}

	return c.SucJson(ctx, wallet)
}

// MerchantDeleteWallet 删除商家钱包
func (c *BaseCommController) MerchantDeleteWallet(ctx echo.Context) error {
	merchantID := ctx.Get("merchant_id").(uint64)
	walletIDStr := ctx.Param("id")

	var walletID uint64
	if _, err := fmt.Sscanf(walletIDStr, "%d", &walletID); err != nil {
		return c.FailJson(ctx, fmt.Errorf("无效的钱包ID"))
	}

	if err := data.DeleteMerchantWallet(merchantID, walletID); err != nil {
		return c.FailJson(ctx, err)
	}

	return c.SucJson(ctx, "钱包已删除")
}

// MerchantUpdateWalletStatus 更新商家钱包状态
func (c *BaseCommController) MerchantUpdateWalletStatus(ctx echo.Context) error {
	type Request struct {
		ID     uint64 `json:"id"`
		Status int64  `json:"status"`
	}

	merchantID := ctx.Get("merchant_id").(uint64)

	req := new(Request)
	if err := ctx.Bind(req); err != nil {
		return c.FailJson(ctx, err)
	}

	if err := data.UpdateMerchantWalletStatus(merchantID, req.ID, req.Status); err != nil {
		return c.FailJson(ctx, err)
	}

	return c.SucJson(ctx, "状态已更新")
}

// ==================== 提现管理 ====================

// MerchantGetBalance 获取商家余额
func (c *BaseCommController) MerchantGetBalance(ctx echo.Context) error {
	merchantID := ctx.Get("merchant_id").(uint64)

	balance, err := data.GetMerchantBalance(merchantID)
	if err != nil {
		return c.FailJson(ctx, err)
	}

	return c.SucJson(ctx, map[string]interface{}{
		"balance": balance,
	})
}

// MerchantCreateWithdrawal 商家申请提现
func (c *BaseCommController) MerchantCreateWithdrawal(ctx echo.Context) error {
	type Request struct {
		Amount   float64 `json:"amount"`
		ToWallet string  `json:"to_wallet"`
		Chain    string  `json:"chain"`
	}

	merchantID := ctx.Get("merchant_id").(uint64)

	req := new(Request)
	if err := ctx.Bind(req); err != nil {
		return c.FailJson(ctx, err)
	}

	if req.Amount <= 0 {
		return c.FailJson(ctx, fmt.Errorf("提现金额必须大于0"))
	}
	if req.ToWallet == "" {
		return c.FailJson(ctx, fmt.Errorf("提现钱包地址不能为空"))
	}

	withdrawal, err := service.CreateMerchantWithdrawal(merchantID, req.Amount, req.ToWallet, req.Chain)
	if err != nil {
		return c.FailJson(ctx, err)
	}

	return c.SucJson(ctx, withdrawal)
}

// MerchantGetWithdrawals 获取商家提现记录
func (c *BaseCommController) MerchantGetWithdrawals(ctx echo.Context) error {
	type Request struct {
		Page     int `query:"page"`
		PageSize int `query:"page_size"`
	}

	merchantID := ctx.Get("merchant_id").(uint64)

	req := new(Request)
	if err := ctx.Bind(req); err != nil {
		return c.FailJson(ctx, err)
	}

	if req.Page <= 0 {
		req.Page = 1
	}
	if req.PageSize <= 0 {
		req.PageSize = 20
	}

	list, total, err := service.GetMerchantWithdrawals(merchantID, req.Page, req.PageSize)
	if err != nil {
		return c.FailJson(ctx, err)
	}

	return c.SucJson(ctx, map[string]interface{}{
		"list":      list,
		"total":     total,
		"page":      req.Page,
		"page_size": req.PageSize,
	})
}
