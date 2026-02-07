package comm

import (
	"fmt"
	"html/template"
	"net/http"

	"github.com/assimon/luuu/config"
	"github.com/assimon/luuu/model/service"
	"github.com/labstack/echo/v4"
)

// ==================== 授权支付 API ====================

// CreateAuthorization 创建授权请求
func (c *BaseCommController) CreateAuthorization(ctx echo.Context) error {
	type Request struct {
		AmountUsdt   float64 `json:"amount_usdt" validate:"required,gt=0"`
		TableNo      string  `json:"table_no"`
		CustomerName string  `json:"customer_name"`
		Remark       string  `json:"remark"`
	}

	req := new(Request)
	if err := ctx.Bind(req); err != nil {
		return c.FailJson(ctx, err)
	}

	resp, err := service.CreateAuthorization(req.AmountUsdt, req.TableNo, req.CustomerName, req.Remark)
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

// DeductFromAuthorization 从授权中扣款
func (c *BaseCommController) DeductFromAuthorization(ctx echo.Context) error {
	type Request struct {
		Password    string  `json:"password" validate:"required"`
		AmountCny   float64 `json:"amount_cny" validate:"required,gt=0"`
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

// ==================== H5 页面 ====================

// AuthorizePage 授权页面（客户扫码看到）
func (c *BaseCommController) AuthorizePage(ctx echo.Context) error {
	authNo := ctx.Param("auth_no")

	// 获取授权信息
	auth, err := service.GetAuthorizationByNo(authNo)
	if err != nil {
		return ctx.String(http.StatusOK, "授权请求不存在或已过期")
	}

	tmpl, err := template.ParseFiles(fmt.Sprintf(".%s/%s", config.StaticPath, "authorize.html"))
	if err != nil {
		return ctx.String(http.StatusOK, err.Error())
	}

	return tmpl.Execute(ctx.Response(), map[string]interface{}{
		"AuthNo":         auth.AuthNo,
		"Password":       auth.Password,
		"AmountUsdt":     auth.AuthorizedUsdt,
		"MerchantWallet": auth.MerchantWallet,
		"TableNo":        auth.TableNo,
		"Status":         auth.Status,
		"ExpireTime":     auth.ExpireTime * 1000,
	})
}

// AuthorizeManagerPage 授权管理页面（服务员用）
func (c *BaseCommController) AuthorizeManagerPage(ctx echo.Context) error {
	tmpl, err := template.ParseFiles(fmt.Sprintf(".%s/%s", config.StaticPath, "authorize_manager.html"))
	if err != nil {
		return ctx.String(http.StatusOK, err.Error())
	}

	return tmpl.Execute(ctx.Response(), nil)
}
