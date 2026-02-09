package comm

import (
	"errors"
	"fmt"
	"net/url"

	"github.com/assimon/luuu/model/data"
	"github.com/assimon/luuu/model/mdb"
	"github.com/assimon/luuu/util/chain"
	"github.com/labstack/echo/v4"
)

// AddWalletAddress 添加钱包地址
func (c *BaseCommController) AddWalletAddress(ctx echo.Context) error {
	type Request struct {
		Token string `json:"token" validate:"required"`
		Chain string `json:"chain"`
	}

	req := new(Request)
	if err := ctx.Bind(req); err != nil {
		return c.FailJson(ctx, err)
	}
	if err := c.ValidateStruct(ctx, req); err != nil {
		return c.FailJson(ctx, err)
	}
	normalizedChain := chain.NormalizeChain(req.Chain)
	if normalizedChain == "" {
		normalizedChain = chain.ChainTron
	}
	if !chain.IsSupported(normalizedChain) {
		return c.FailJson(ctx, errors.New("不支持的链"))
	}
	if err := chain.ValidateAddress(normalizedChain, req.Token); err != nil {
		return c.FailJson(ctx, err)
	}

	wallet, err := data.AddWalletAddress(req.Token, normalizedChain)
	if err != nil {
		return c.FailJson(ctx, err)
	}

	qrContent := req.Token
	qrUrl := fmt.Sprintf("/qrcode?content=%s", url.QueryEscape(qrContent))
	return c.SucJson(ctx, map[string]interface{}{
		"wallet":            wallet,
		"qrcode_content":    qrContent,
		"qrcode_stream_url": qrUrl,
	})
}

// WalletList 获取所有钱包地址
func (c *BaseCommController) WalletList(ctx echo.Context) error {
	wallets, err := data.GetAllWalletAddress()
	if err != nil {
		return c.FailJson(ctx, err)
	}
	return c.SucJson(ctx, wallets)
}

// UpdateWalletStatus 启用/禁用钱包地址
func (c *BaseCommController) UpdateWalletStatus(ctx echo.Context) error {
	type Request struct {
		ID     uint64 `json:"id" validate:"required,gt=0"`
		Status int    `json:"status" validate:"required,gt=0"`
	}

	req := new(Request)
	if err := ctx.Bind(req); err != nil {
		return c.FailJson(ctx, err)
	}
	if err := c.ValidateStruct(ctx, req); err != nil {
		return c.FailJson(ctx, err)
	}
	if req.Status != mdb.TokenStatusEnable && req.Status != mdb.TokenStatusDisable {
		return c.FailJson(ctx, errors.New("状态无效"))
	}

	if err := data.ChangeWalletAddressStatus(req.ID, req.Status); err != nil {
		return c.FailJson(ctx, err)
	}
	return c.SucJson(ctx, "ok")
}

// DeleteWallet 删除钱包地址
func (c *BaseCommController) DeleteWallet(ctx echo.Context) error {
	type Request struct {
		ID uint64 `json:"id" validate:"required,gt=0"`
	}

	req := new(Request)
	if err := ctx.Bind(req); err != nil {
		return c.FailJson(ctx, err)
	}
	if err := c.ValidateStruct(ctx, req); err != nil {
		return c.FailJson(ctx, err)
	}

	if err := data.DeleteWalletAddressById(req.ID); err != nil {
		return c.FailJson(ctx, err)
	}
	return c.SucJson(ctx, "ok")
}
