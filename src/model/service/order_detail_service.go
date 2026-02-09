package service

import (
	"github.com/assimon/luuu/model/dao"
	"github.com/assimon/luuu/model/data"
	"github.com/assimon/luuu/model/mdb"
	"github.com/assimon/luuu/model/response"
	"github.com/assimon/luuu/util/constant"
)

// GetOrderDetailByTradeId 通过交易号获取订单详情
func GetOrderDetailByTradeId(tradeId string) (*response.OrderDetailResponse, error) {
	// 查询订单信息
	order, err := data.GetOrderInfoByTradeId(tradeId)
	if err != nil {
		return nil, err
	}
	if order.ID <= 0 {
		return nil, constant.OrderNotExists
	}

	// 查询回调日志
	var callbackLogs []mdb.CallbackLog
	dao.Mdb.Model(&mdb.CallbackLog{}).
		Where("trade_id = ?", tradeId).
		Order("id desc").
		Find(&callbackLogs)

	// 构建回调日志列表
	logItems := make([]response.CallbackLogItem, 0, len(callbackLogs))
	for _, log := range callbackLogs {
		logItems = append(logItems, response.CallbackLogItem{
			NotifyUrl:    log.NotifyUrl,
			StatusCode:   log.StatusCode,
			Success:      log.Success,
			ErrorMessage: log.ErrorMessage,
			CreatedAt:    log.CreatedAt.ToDateTimeString(),
		})
	}

	// 构建响应
	resp := &response.OrderDetailResponse{
		TradeId:            order.TradeId,
		OrderId:            order.OrderId,
		Amount:             order.Amount,
		ActualAmount:       order.ActualAmount,
		Token:              order.Token,
		Chain:              order.Chain,
		Status:             order.Status,
		StatusText:         response.GetStatusText(order.Status),
		BlockTransactionId: order.BlockTransactionId,
		NotifyUrl:          order.NotifyUrl,
		RedirectUrl:        order.RedirectUrl,
		CallbackNum:        order.CallbackNum,
		CallBackConfirm:    order.CallBackConfirm,
		CallbackText:       response.GetCallbackText(order.CallBackConfirm),
		BlockExplorerUrl:   response.GetBlockExplorerUrl(order.Chain, order.BlockTransactionId),
		WalletExplorerUrl:  response.GetWalletExplorerUrl(order.Chain, order.Token),
		CreatedAt:          order.CreatedAt.ToDateTimeString(),
		UpdatedAt:          order.UpdatedAt.ToDateTimeString(),
		CallbackLogs:       logItems,
	}

	return resp, nil
}
