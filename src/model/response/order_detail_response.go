package response

import (
	"fmt"
	"strings"

	"github.com/assimon/luuu/model/mdb"
)

// OrderDetailResponse 订单详情响应结构体
type OrderDetailResponse struct {
	// 订单基本信息
	TradeId            string  `json:"trade_id"`             // epusdt订单号
	OrderId            string  `json:"order_id"`             // 客户交易id
	Amount             float64 `json:"amount"`               // 订单金额
	ActualAmount       float64 `json:"actual_amount"`        // 实际支付金额
	Token              string  `json:"token"`                // 收款钱包地址
	Chain              string  `json:"chain"`                // 链
	Status             int     `json:"status"`               // 订单状态 1:等待支付 2:支付成功 3:已过期
	StatusText         string  `json:"status_text"`          // 状态文本
	BlockTransactionId string  `json:"block_transaction_id"` // 区块交易ID

	// 回调信息
	NotifyUrl       string `json:"notify_url"`        // 异步回调地址
	RedirectUrl     string `json:"redirect_url"`      // 同步回调地址
	CallbackNum     int    `json:"callback_num"`      // 回调次数
	CallBackConfirm int    `json:"callback_confirm"`  // 回调确认状态 1:已确认 2:未确认
	CallbackText    string `json:"callback_text"`     // 回调确认文本

	// 区块链浏览器URL
	BlockExplorerUrl string `json:"block_explorer_url"` // 区块链浏览器交易链接
	WalletExplorerUrl string `json:"wallet_explorer_url"` // 钱包地址浏览器链接

	// 时间线
	CreatedAt string `json:"created_at"` // 创建时间
	UpdatedAt string `json:"updated_at"` // 更新时间

	// 回调日志列表
	CallbackLogs []CallbackLogItem `json:"callback_logs"` // 回调日志
}

// CallbackLogItem 回调日志条目
type CallbackLogItem struct {
	NotifyUrl    string `json:"notify_url"`
	StatusCode   int    `json:"status_code"`
	Success      int    `json:"success"`
	ErrorMessage string `json:"error_message"`
	CreatedAt    string `json:"created_at"`
}

// GetStatusText 获取订单状态文本
func GetStatusText(status int) string {
	switch status {
	case mdb.StatusWaitPay:
		return "等待支付"
	case mdb.StatusPaySuccess:
		return "支付成功"
	case mdb.StatusExpired:
		return "已过期"
	default:
		return "未知状态"
	}
}

// GetCallbackText 获取回调确认文本
func GetCallbackText(confirm int) string {
	switch confirm {
	case mdb.CallBackConfirmOk:
		return "已确认"
	case mdb.CallBackConfirmNo:
		return "未确认"
	default:
		return "未知"
	}
}

// GetBlockExplorerUrl 根据链类型生成区块链浏览器交易URL
func GetBlockExplorerUrl(chain string, txId string) string {
	if txId == "" {
		return ""
	}
	chainUpper := strings.ToUpper(strings.TrimSpace(chain))
	switch chainUpper {
	case "TRON":
		return fmt.Sprintf("https://tronscan.org/#/transaction/%s", txId)
	case "BSC":
		return fmt.Sprintf("https://bscscan.com/tx/%s", txId)
	case "EVM", "ETH":
		return fmt.Sprintf("https://etherscan.io/tx/%s", txId)
	case "POLYGON":
		return fmt.Sprintf("https://polygonscan.com/tx/%s", txId)
	default:
		return ""
	}
}

// GetWalletExplorerUrl 根据链类型生成钱包地址浏览器URL
func GetWalletExplorerUrl(chain string, address string) string {
	if address == "" {
		return ""
	}
	chainUpper := strings.ToUpper(strings.TrimSpace(chain))
	switch chainUpper {
	case "TRON":
		return fmt.Sprintf("https://tronscan.org/#/address/%s", address)
	case "BSC":
		return fmt.Sprintf("https://bscscan.com/address/%s", address)
	case "EVM", "ETH":
		return fmt.Sprintf("https://etherscan.io/address/%s", address)
	case "POLYGON":
		return fmt.Sprintf("https://polygonscan.com/address/%s", address)
	default:
		return ""
	}
}
