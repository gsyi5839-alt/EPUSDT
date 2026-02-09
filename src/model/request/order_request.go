package request

import (
	"fmt"
	"math"

	"github.com/gookit/validate"
)

// 金额安全限制常量
const (
	MaxOrderAmount   = 1000000.0 // 最大订单金额
	MaxDecimalPlaces = 2         // 最大小数位数
)

// CreateTransactionRequest 创建交易请求
type CreateTransactionRequest struct {
	OrderId     string  `json:"order_id" validate:"required|maxLen:32"`
	Amount      float64 `json:"amount" validate:"required|isFloat|gt:0.01"`
	NotifyUrl   string  `json:"notify_url" validate:"required"`
	Signature   string  `json:"signature"  validate:"required"`
	RedirectUrl string  `json:"redirect_url"`
	Chain       string  `json:"chain"`
	Timestamp   int64   `json:"timestamp"`
	Nonce       string  `json:"nonce"`
}

func (r CreateTransactionRequest) Translates() map[string]string {
	return validate.MS{
		"OrderId":   "订单号",
		"Amount":    "支付金额",
		"NotifyUrl": "异步回调网址",
		"Signature": "签名",
		"Chain":     "链",
	}
}

// ValidateAmount 验证金额安全性（最大金额 + 小数位数）
// 在业务层调用此方法进行额外校验
func (r CreateTransactionRequest) ValidateAmount() error {
	// 验证金额上限
	if r.Amount > MaxOrderAmount {
		return fmt.Errorf("支付金额不能超过 %.0f", MaxOrderAmount)
	}
	// 验证小数位数（最多2位）
	rounded := math.Round(r.Amount*100) / 100
	if math.Abs(r.Amount-rounded) > 1e-9 {
		return fmt.Errorf("支付金额小数位数不能超过 %d 位", MaxDecimalPlaces)
	}
	return nil
}

// OrderProcessingRequest 订单处理
type OrderProcessingRequest struct {
	Token              string
	Amount             float64
	TradeId            string
	BlockTransactionId string
}
