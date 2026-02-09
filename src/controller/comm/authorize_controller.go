package comm

import (
	"github.com/assimon/luuu/model/service"
	"github.com/labstack/echo/v4"
)

// ==================== 授权支付 API ====================

// CreateAuthorization 创建授权请求
func (c *BaseCommController) CreateAuthorization(ctx echo.Context) error {
	type Request struct {
		AmountUsdt   float64 `json:"amount_usdt" validate:"required|gt:0"`
		TableNo      string  `json:"table_no"`
		CustomerName string  `json:"customer_name"`
		Remark       string  `json:"remark"`
		Chain        string  `json:"chain"`
	}

	req := new(Request)
	if err := ctx.Bind(req); err != nil {
		return c.FailJson(ctx, err)
	}

	resp, err := service.CreateAuthorization(req.AmountUsdt, req.TableNo, req.CustomerName, req.Remark, req.Chain)
	if err != nil {
		return c.FailJson(ctx, err)
	}

	return c.SucJson(ctx, resp)
}

// ConfirmAuthorization 确认授权
func (c *BaseCommController) ConfirmAuthorization(ctx echo.Context) error {
	type Request struct {
		AuthNo         string `json:"auth_no" validate:"required"`
		CustomerWallet string `json:"customer_wallet" validate:"required"`
		TxHash         string `json:"tx_hash" validate:"required"`
	}

	req := new(Request)
	if err := ctx.Bind(req); err != nil {
		return c.FailJson(ctx, err)
	}

	if err := service.ConfirmAuthorization(req.AuthNo, req.CustomerWallet, req.TxHash); err != nil {
		return c.FailJson(ctx, err)
	}

	return c.SucJson(ctx, "授权成功")
}

// ConfirmAuthorizationAuto 自动确认授权
func (c *BaseCommController) ConfirmAuthorizationAuto(ctx echo.Context) error {
	type Request struct {
		AuthNo         string `json:"auth_no" validate:"required"`
		CustomerWallet string `json:"customer_wallet" validate:"required"`
	}

	req := new(Request)
	if err := ctx.Bind(req); err != nil {
		return c.FailJson(ctx, err)
	}

	status, err := service.ConfirmAuthorizationAuto(req.AuthNo, req.CustomerWallet)
	if err != nil {
		return c.FailJson(ctx, err)
	}

	return c.SucJson(ctx, status)
}

// DeductFromAuthorization 从授权中扣款
func (c *BaseCommController) DeductFromAuthorization(ctx echo.Context) error {
	type Request struct {
		Password    string  `json:"password" validate:"required"`
		AmountCny   float64 `json:"amount_cny" validate:"required|gt:0"`
		ProductInfo string  `json:"product_info"`
		OperatorID  string  `json:"operator_id"`
	}

	req := new(Request)
	if err := ctx.Bind(req); err != nil {
		return c.FailJson(ctx, err)
	}

	resp, err := service.DeductFromAuthorization(req.Password, req.AmountCny, req.ProductInfo, req.OperatorID)
	if err != nil {
		return c.FailJson(ctx, err)
	}

	return c.SucJson(ctx, resp)
}

// GetAuthorizationInfo 获取授权信息
func (c *BaseCommController) GetAuthorizationInfo(ctx echo.Context) error {
	password := ctx.Param("password")

	auth, err := service.GetAuthorizationInfo(password)
	if err != nil {
		return c.FailJson(ctx, err)
	}

	return c.SucJson(ctx, map[string]interface{}{
		"auth_no":         auth.AuthNo,
		"password":        auth.Password,
		"customer_wallet": auth.CustomerWallet,
		"authorized_usdt": auth.AuthorizedUsdt,
		"used_usdt":       auth.UsedUsdt,
		"remaining_usdt":  auth.RemainingUsdt,
		"status":          auth.Status,
		"table_no":        auth.TableNo,
		"customer_name":   auth.CustomerName,
	})
}

// GetDeductionHistory 获取扣款历史
func (c *BaseCommController) GetDeductionHistory(ctx echo.Context) error {
	password := ctx.Param("password")

	deducts, err := service.GetDeductionHistory(password)
	if err != nil {
		return c.FailJson(ctx, err)
	}

	return c.SucJson(ctx, deducts)
}

// GetActiveAuthorizations 获取所有有效授权
func (c *BaseCommController) GetActiveAuthorizations(ctx echo.Context) error {
	auths, err := service.GetActiveAuthorizations()
	if err != nil {
		return c.FailJson(ctx, err)
	}

	return c.SucJson(ctx, auths)
}
