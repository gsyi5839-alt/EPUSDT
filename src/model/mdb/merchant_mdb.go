package mdb

// Merchant 商家表
type Merchant struct {
	Username     string  `gorm:"column:username;type:varchar(64);uniqueIndex" json:"username"`                    // 商家用户名
	PasswordHash string  `gorm:"column:password_hash;type:varchar(128)" json:"-"`                                 // 密码哈希
	Email        string  `gorm:"column:email;type:varchar(128)" json:"email"`                                     // 邮箱
	MerchantName string  `gorm:"column:merchant_name;type:varchar(128)" json:"merchant_name"`                     // 商家名称
	WalletToken  string  `gorm:"column:wallet_token;type:varchar(100)" json:"wallet_token"`                       // 关联钱包地址
	Status       int     `gorm:"column:status;default:1" json:"status"`                                           // 1:启用 2:禁用
	ApiToken     string  `gorm:"column:api_token;type:varchar(128);uniqueIndex" json:"api_token"`                 // API令牌
	UsdtRate     float64 `gorm:"column:usdt_rate;type:decimal(10,4);default:6.5" json:"usdt_rate"`                // USDT汇率（默认6.5）
	Balance      float64 `gorm:"column:balance;type:decimal(19,6);default:0" json:"balance"`                      // 商家余额（USDT）
	LastLoginAt  int64   `gorm:"column:last_login_at" json:"last_login_at"`                                       // 最后登录时间
	BaseModel
}

func (m *Merchant) TableName() string {
	return "merchants"
}
