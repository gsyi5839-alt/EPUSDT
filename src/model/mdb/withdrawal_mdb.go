package mdb

const (
	WithdrawalStatusPending   = 1 // 待审核
	WithdrawalStatusApproved  = 2 // 已批准（转账中）
	WithdrawalStatusCompleted = 3 // 已完成
	WithdrawalStatusRejected  = 4 // 已拒绝
)

// MerchantWithdrawal 商家提现表
type MerchantWithdrawal struct {
	WithdrawNo   string  `gorm:"column:withdraw_no;type:varchar(64);uniqueIndex" json:"withdraw_no"` // 提现单号
	MerchantID   uint64  `gorm:"column:merchant_id;index" json:"merchant_id"`                        // 商家ID
	Amount       float64 `gorm:"column:amount;type:decimal(19,6)" json:"amount"`                     // 提现金额(USDT)
	ToWallet     string  `gorm:"column:to_wallet;type:varchar(128)" json:"to_wallet"`                // 提现目标钱包地址
	Chain        string  `gorm:"column:chain;type:varchar(20);default:BSC" json:"chain"`             // 链(BSC)
	Status       int     `gorm:"column:status;default:1" json:"status"`                              // 1:待审核 2:已批准(转账中) 3:已完成 4:已拒绝
	TxHash       string  `gorm:"column:tx_hash;type:varchar(128)" json:"tx_hash"`                    // 转账交易哈希
	RejectReason string  `gorm:"column:reject_reason;type:varchar(256)" json:"reject_reason"`        // 拒绝原因
	ReviewedBy   string  `gorm:"column:reviewed_by;type:varchar(64)" json:"reviewed_by"`             // 审核人
	ReviewedAt   int64   `gorm:"column:reviewed_at" json:"reviewed_at"`                              // 审核时间
	BaseModel
}

func (m *MerchantWithdrawal) TableName() string {
	return "merchant_withdrawals"
}
