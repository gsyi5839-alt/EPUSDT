package comm

import (
	"github.com/assimon/luuu/model/response"
	"github.com/assimon/luuu/model/service"
	"github.com/labstack/echo/v4"
)

// CheckStatus 支付状态检测
func (c *BaseCommController) CheckStatus(ctx echo.Context) (err error) {
	tradeId := ctx.Param("trade_id")
	order, err := service.GetOrderInfoByTradeId(tradeId)
	if err != nil {
		return c.FailJson(ctx, err)
	}
	resp := response.CheckStatusResponse{
		TradeId: order.TradeId,
		Status:  order.Status,
	}
	return c.SucJson(ctx, resp)
}
