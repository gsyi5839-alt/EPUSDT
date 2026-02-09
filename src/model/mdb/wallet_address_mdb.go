package mdb

const (
	TokenStatusEnable  = 1
	TokenStatusDisable = 2
)

// WalletAddress 钱包表
type WalletAddress struct {
	Token      string `gorm:"index:wallet_address_token_index;column:token" json:"token"`             // 钱包地址
	Chain      string `gorm:"index:wallet_address_chain_index;column:chain;default:BSC" json:"chain"` // 链标识
	ChainID    int64  `gorm:"column:chain_id" json:"chain_id"`                                        // 链ID (56=BSC, 1=ETH, 137=Polygon)
	MerchantID uint64 `gorm:"column:merchant_id;index" json:"merchant_id"`                            // 所属商家ID
	Status     int64  `gorm:"column:status;default:1" json:"status"`                                  // 1:启用 2:禁用
	BaseModel
}

// TableName sets the insert table name for this struct type
func (w *WalletAddress) TableName() string {
	return "wallet_address"
}
