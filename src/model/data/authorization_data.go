package data

import (
	"github.com/assimon/luuu/model/dao"
	"github.com/assimon/luuu/model/mdb"
	"gorm.io/gorm"
)

// ===================== Authorization CRUD =====================

// CreateAuthorization 创建授权记录
func CreateAuthorization(auth *mdb.Authorization) error {
	return dao.Mdb.Create(auth).Error
}

// GetAuthorizationByNo 通过授权编号获取
func GetAuthorizationByNo(authNo string) (*mdb.Authorization, error) {
	auth := new(mdb.Authorization)
	err := dao.Mdb.Model(auth).Where("auth_no = ?", authNo).First(auth).Error
	return auth, err
}

// GetAuthorizationByMerchantAndNo 通过商家ID和授权编号获取
func GetAuthorizationByMerchantAndNo(merchantID uint64, authNo string) (*mdb.Authorization, error) {
	auth := new(mdb.Authorization)
	err := dao.Mdb.Model(auth).Where("merchant_id = ? AND auth_no = ?", merchantID, authNo).First(auth).Error
	return auth, err
}

// GetPendingAuthorizationsByChain 获取某条链上所有待确认的授权
func GetPendingAuthorizationsByChain(chainName string) ([]mdb.Authorization, error) {
	var auths []mdb.Authorization
	err := dao.Mdb.Model(&mdb.Authorization{}).
		Where("status = ? AND chain = ?", mdb.AuthorizationStatusPending, chainName).
		Find(&auths).Error
	return auths, err
}

// GetPendingAuthorizations 获取所有待确认的授权
func GetPendingAuthorizations() ([]mdb.Authorization, error) {
	var auths []mdb.Authorization
	err := dao.Mdb.Model(&mdb.Authorization{}).
		Where("status = ?", mdb.AuthorizationStatusPending).
		Order("created_at DESC").
		Find(&auths).Error
	return auths, err
}

// GetActiveAuthorizations 获取所有有效授权
func GetActiveAuthorizations() ([]mdb.Authorization, error) {
	var auths []mdb.Authorization
	err := dao.Mdb.Model(&mdb.Authorization{}).
		Where("status = ?", mdb.AuthorizationStatusActive).
		Order("created_at DESC").
		Find(&auths).Error
	return auths, err
}

// GetAuthorizationsByMerchant 按商家获取授权列表（分页）
func GetAuthorizationsByMerchant(merchantID uint64, page, pageSize, status int) ([]mdb.Authorization, int64, error) {
	var auths []mdb.Authorization
	var total int64
	query := dao.Mdb.Model(&mdb.Authorization{}).Where("merchant_id = ?", merchantID)
	if status > 0 {
		query = query.Where("status = ?", status)
	}
	if err := query.Count(&total).Error; err != nil {
		return nil, 0, err
	}
	err := query.Order("created_at DESC").
		Offset((page - 1) * pageSize).
		Limit(pageSize).
		Find(&auths).Error
	return auths, total, err
}

// ActivateAuthorization 激活授权（由 Approval 监控调用）
func ActivateAuthorization(authNo, customerWallet, txHash string, authorizeTime int64) error {
	return dao.Mdb.Model(&mdb.Authorization{}).Where("auth_no = ?", authNo).
		Updates(map[string]interface{}{
			"status":          mdb.AuthorizationStatusActive,
			"customer_wallet": customerWallet,
			"tx_hash":         txHash,
			"authorize_time":  authorizeTime,
		}).Error
}

// UpdateAuthorizationUsed 更新已使用额度
func UpdateAuthorizationUsed(tx *gorm.DB, authID uint64, usedAmount float64) error {
	return tx.Model(&mdb.Authorization{}).Where("id = ?", authID).
		Updates(map[string]interface{}{
			"used_usdt":      gorm.Expr("used_usdt + ?", usedAmount),
			"remaining_usdt": gorm.Expr("remaining_usdt - ?", usedAmount),
		}).Error
}

// UpdateAuthorizationStatus 更新授权状态
func UpdateAuthorizationStatus(authID uint64, status int) error {
	return dao.Mdb.Model(&mdb.Authorization{}).Where("id = ?", authID).
		Update("status", status).Error
}

// GetWalletsByMerchant 获取商家的钱包列表
func GetWalletsByMerchant(merchantID uint64) ([]mdb.WalletAddress, error) {
	var wallets []mdb.WalletAddress
	err := dao.Mdb.Model(&mdb.WalletAddress{}).
		Where("merchant_id = ?", merchantID).
		Find(&wallets).Error
	return wallets, err
}

// GetWalletsByMerchantAndChain 获取商家某条链的钱包
func GetWalletsByMerchantAndChain(merchantID uint64, chainName string) ([]mdb.WalletAddress, error) {
	var wallets []mdb.WalletAddress
	err := dao.Mdb.Model(&mdb.WalletAddress{}).
		Where("merchant_id = ? AND chain = ? AND status = ?", merchantID, chainName, mdb.TokenStatusEnable).
		Find(&wallets).Error
	return wallets, err
}

// AddWalletForMerchant 为商家添加钱包
func AddWalletForMerchant(merchantID uint64, token, chainName string, chainID int64) (*mdb.WalletAddress, error) {
	// 检查是否已存在
	var count int64
	dao.Mdb.Model(&mdb.WalletAddress{}).
		Where("merchant_id = ? AND token = ? AND chain = ?", merchantID, token, chainName).
		Count(&count)
	if count > 0 {
		return nil, gorm.ErrDuplicatedKey
	}
	wallet := &mdb.WalletAddress{
		Token:      token,
		Chain:      chainName,
		ChainID:    chainID,
		MerchantID: merchantID,
		Status:     mdb.TokenStatusEnable,
	}
	err := dao.Mdb.Create(wallet).Error
	return wallet, err
}

// GetAllMerchantWalletsByChain 获取所有商家在某条链上的钱包（供监控用）
func GetAllMerchantWalletsByChain(chainName string) ([]mdb.WalletAddress, error) {
	var wallets []mdb.WalletAddress
	err := dao.Mdb.Model(&mdb.WalletAddress{}).
		Where("chain = ? AND status = ?", chainName, mdb.TokenStatusEnable).
		Find(&wallets).Error
	return wallets, err
}
