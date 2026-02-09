package mdb

// 授权状态
const (
	AuthorizationStatusPending  = 1 // 等待授权
	AuthorizationStatusActive   = 2 // 授权有效
	AuthorizationStatusRevoked  = 3 // 已撤销
	AuthorizationStatusDepleted = 4 // 额度已用尽
	AuthorizationStatusExpired  = 5 // 已过期
)

// 扣款状态
const (
	DeductionStatusProcessing = 1 // 处理中
	DeductionStatusSuccess    = 2 // 成功
	DeductionStatusFailed     = 3 // 失败
)

// Authorization 客户授权表
type Authorization struct {
	AuthNo          string  `gorm:"column:auth_no;type:varchar(50);uniqueIndex" json:"auth_no"`               // 授权编号
	MerchantID      uint64  `gorm:"column:merchant_id;index" json:"merchant_id"`                              // 商家ID
	CustomerWallet  string  `gorm:"column:customer_wallet;type:varchar(100);index" json:"customer_wallet"`    // 客户钱包地址
	MerchantWallet  string  `gorm:"column:merchant_wallet;type:varchar(100)" json:"merchant_wallet"`          // 商家收款钱包
	Chain           string  `gorm:"column:chain;type:varchar(20);default:BSC" json:"chain"`                   // 链标识
	ChainID         int64   `gorm:"column:chain_id" json:"chain_id"`                                          // 链ID (56=BSC, 1=ETH, 137=Polygon, 0=TRON)
	ContractAddress string  `gorm:"column:contract_address;type:varchar(100)" json:"contract_address"`        // USDT合约地址
	AuthorizedUsdt  float64 `gorm:"column:authorized_usdt" json:"authorized_usdt"`                            // 授权额度(USDT)
	UsedUsdt        float64 `gorm:"column:used_usdt;default:0" json:"used_usdt"`                              // 已使用额度(USDT)
	RemainingUsdt   float64 `gorm:"column:remaining_usdt" json:"remaining_usdt"`                              // 剩余额度(USDT)
	Status          int     `gorm:"column:status;default:1" json:"status"`                                    // 状态
	Reference       string  `gorm:"column:reference;type:varchar(100)" json:"reference"`                      // 业务参考号
	CustomerName    string  `gorm:"column:customer_name;type:varchar(100)" json:"customer_name"`              // 客户名称
	TxHash          string  `gorm:"column:tx_hash;type:varchar(128)" json:"tx_hash"`                          // 授权交易哈希
	AuthorizeTime   int64   `gorm:"column:authorize_time" json:"authorize_time"`                              // 授权确认时间
	ExpireTime      int64   `gorm:"column:expire_time" json:"expire_time"`                                    // 过期时间
	Remark          string  `gorm:"column:remark;type:varchar(255)" json:"remark"`                            // 备注
	QrContent       string  `gorm:"column:qr_content;type:varchar(500)" json:"qr_content"`                   // QR码内容(EIP-681 URI)
	BaseModel
}

func (a *Authorization) TableName() string {
	return "authorizations"
}

// Deduction 扣款记录表
type Deduction struct {
	DeductNo    string  `gorm:"column:deduct_no;type:varchar(50);uniqueIndex" json:"deduct_no"` // 扣款单号
	AuthID      uint64  `gorm:"column:auth_id;index" json:"auth_id"`                            // 授权ID
	AuthNo      string  `gorm:"column:auth_no;type:varchar(50)" json:"auth_no"`                 // 授权编号
	MerchantID  uint64  `gorm:"column:merchant_id;index" json:"merchant_id"`                    // 商家ID
	AmountUsdt  float64 `gorm:"column:amount_usdt" json:"amount_usdt"`                          // 扣款金额(USDT)
	AmountCny   float64 `gorm:"column:amount_cny" json:"amount_cny"`                            // 扣款金额(CNY)
	TxHash      string  `gorm:"column:tx_hash;type:varchar(128)" json:"tx_hash"`                // 扣款交易哈希
	Status      int     `gorm:"column:status;default:1" json:"status"`                          // 1:处理中 2:成功 3:失败
	FailReason  string  `gorm:"column:fail_reason;type:varchar(255)" json:"fail_reason"`        // 失败原因
	ProductInfo string  `gorm:"column:product_info;type:varchar(500)" json:"product_info"`      // 消费内容
	OperatorID  string  `gorm:"column:operator_id;type:varchar(50)" json:"operator_id"`         // 操作员
	DeductTime  int64   `gorm:"column:deduct_time" json:"deduct_time"`                          // 扣款时间
	BaseModel
}

func (d *Deduction) TableName() string {
	return "deductions"
}
