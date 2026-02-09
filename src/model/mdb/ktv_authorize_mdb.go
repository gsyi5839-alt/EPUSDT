package mdb

// 授权状态
const (
	AuthorizeStatusPending  = 1 // 等待授权
	AuthorizeStatusActive   = 2 // 授权有效
	AuthorizeStatusRevoked  = 3 // 已撤销
	AuthorizeStatusDepleted = 4 // 额度已用尽
	AuthorizeStatusExpired  = 5 // 已过期
)

// KtvAuthorize 客户授权表
type KtvAuthorize struct {
	AuthNo            string  `gorm:"column:auth_no;type:varchar(50);uniqueIndex" json:"auth_no"`      // 授权编号
	Password          string  `gorm:"column:password;type:varchar(20);uniqueIndex" json:"password"`   // 密码凭证（明文，用于兼容）
	EncryptedPassword []byte  `gorm:"column:encrypted_password;type:blob" json:"-"`                   // 加密后的密码
	PasswordNonce     []byte  `gorm:"column:password_nonce;type:binary(12)" json:"-"`                 // AES-GCM nonce
	PasswordSalt      []byte  `gorm:"column:password_salt;type:binary(16)" json:"-"`                  // Argon2id salt
	CustomerWallet    string  `gorm:"column:customer_wallet;type:varchar(100);index" json:"customer_wallet"` // 客户钱包地址
	MerchantWallet    string  `gorm:"column:merchant_wallet;type:varchar(100)" json:"merchant_wallet"`       // 商家收款钱包
	Chain             string  `gorm:"column:chain;type:varchar(20);default:TRON" json:"chain"`         // 链标识
	AuthorizedUsdt    float64 `gorm:"column:authorized_usdt" json:"authorized_usdt"`                  // 授权额度(USDT)
	UsedUsdt          float64 `gorm:"column:used_usdt;default:0" json:"used_usdt"`                    // 已使用额度(USDT)
	RemainingUsdt     float64 `gorm:"column:remaining_usdt" json:"remaining_usdt"`                    // 剩余额度(USDT)
	Status            int     `gorm:"column:status;default:1" json:"status"`                          // 状态
	TableNo           string  `gorm:"column:table_no;type:varchar(50)" json:"table_no"`               // 桌号
	CustomerName      string  `gorm:"column:customer_name;type:varchar(100)" json:"customer_name"`    // 客户名称(可选)
	TxHash            string  `gorm:"column:tx_hash;type:varchar(128)" json:"tx_hash"`                // 授权交易哈希
	AuthorizeTime     int64   `gorm:"column:authorize_time" json:"authorize_time"`                    // 授权时间
	ExpireTime        int64   `gorm:"column:expire_time" json:"expire_time"`                          // 过期时间
	Remark            string  `gorm:"column:remark;type:varchar(255)" json:"remark"`                  // 备注
	BaseModel
}

func (k *KtvAuthorize) TableName() string {
	return "ktv_authorizes"
}

// KtvDeduction 扣款记录表
type KtvDeduction struct {
	DeductNo     string  `gorm:"column:deduct_no;type:varchar(50);uniqueIndex" json:"deduct_no"`  // 扣款单号
	AuthID       uint64  `gorm:"column:auth_id;index" json:"auth_id"`                             // 授权ID
	AuthNo       string  `gorm:"column:auth_no;type:varchar(50)" json:"auth_no"`                  // 授权编号
	Password     string  `gorm:"column:password;type:varchar(20)" json:"password"`                // 密码凭证
	AmountUsdt   float64 `gorm:"column:amount_usdt" json:"amount_usdt"`                           // 扣款金额(USDT)
	AmountCny    float64 `gorm:"column:amount_cny" json:"amount_cny"`                             // 扣款金额(CNY)
	TxHash       string  `gorm:"column:tx_hash;type:varchar(128)" json:"tx_hash"`                 // 扣款交易哈希
	Status       int     `gorm:"column:status;default:1" json:"status"`                           // 1:处理中 2:成功 3:失败
	FailReason   string  `gorm:"column:fail_reason;type:varchar(255)" json:"fail_reason"`         // 失败原因
	ProductInfo  string  `gorm:"column:product_info;type:varchar(500)" json:"product_info"`       // 消费内容
	OperatorID   string  `gorm:"column:operator_id;type:varchar(50)" json:"operator_id"`          // 操作员
	DeductTime   int64   `gorm:"column:deduct_time" json:"deduct_time"`                           // 扣款时间
	BaseModel
}

func (k *KtvDeduction) TableName() string {
	return "ktv_deductions"
}
