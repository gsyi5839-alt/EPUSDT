package data

import (
	"github.com/assimon/luuu/model/dao"
	"github.com/assimon/luuu/model/mdb"
	"gorm.io/gorm"
)

// CreateWithdrawal 创建提现申请
func CreateWithdrawal(withdrawal *mdb.MerchantWithdrawal) error {
	return dao.Mdb.Create(withdrawal).Error
}

// GetWithdrawalByNo 通过提现单号获取
func GetWithdrawalByNo(withdrawNo string) (*mdb.MerchantWithdrawal, error) {
	w := new(mdb.MerchantWithdrawal)
	err := dao.Mdb.Where("withdraw_no = ?", withdrawNo).First(w).Error
	return w, err
}

// GetWithdrawalsByMerchantID 获取商家的提现记录
func GetWithdrawalsByMerchantID(merchantID uint64, page, pageSize int) ([]mdb.MerchantWithdrawal, int64, error) {
	var list []mdb.MerchantWithdrawal
	var total int64

	query := dao.Mdb.Model(&mdb.MerchantWithdrawal{}).Where("merchant_id = ?", merchantID)
	query.Count(&total)

	offset := (page - 1) * pageSize
	err := query.Order("created_at DESC").Limit(pageSize).Offset(offset).Find(&list).Error
	return list, total, err
}

// GetAllWithdrawals 获取所有提现记录（管理员）
func GetAllWithdrawals(page, pageSize int) ([]mdb.MerchantWithdrawal, int64, error) {
	var list []mdb.MerchantWithdrawal
	var total int64

	query := dao.Mdb.Model(&mdb.MerchantWithdrawal{})
	query.Count(&total)

	offset := (page - 1) * pageSize
	err := query.Order("created_at DESC").Limit(pageSize).Offset(offset).Find(&list).Error
	return list, total, err
}

// UpdateWithdrawalStatus 更新提现状态
func UpdateWithdrawalStatus(tx *gorm.DB, withdrawNo string, updates map[string]interface{}) error {
	return tx.Model(&mdb.MerchantWithdrawal{}).Where("withdraw_no = ?", withdrawNo).Updates(updates).Error
}

// AddMerchantBalance 增加商家余额
func AddMerchantBalance(tx *gorm.DB, merchantID uint64, amount float64) error {
	return tx.Model(&mdb.Merchant{}).Where("id = ?", merchantID).
		Update("balance", gorm.Expr("balance + ?", amount)).Error
}

// SubMerchantBalance 扣减商家余额
func SubMerchantBalance(tx *gorm.DB, merchantID uint64, amount float64) error {
	return tx.Model(&mdb.Merchant{}).Where("id = ? AND balance >= ?", merchantID, amount).
		Update("balance", gorm.Expr("balance - ?", amount)).Error
}

// GetMerchantBalance 获取商家余额
func GetMerchantBalance(merchantID uint64) (float64, error) {
	var balance float64
	err := dao.Mdb.Model(&mdb.Merchant{}).Where("id = ?", merchantID).Pluck("balance", &balance).Error
	return balance, err
}

// GetMerchantIDByWallet 通过钱包地址反查商家ID
func GetMerchantIDByWallet(walletToken string) (uint64, error) {
	var merchantID uint64
	err := dao.Mdb.Model(&mdb.WalletAddress{}).Where("token = ? AND status = ?", walletToken, mdb.TokenStatusEnable).
		Pluck("merchant_id", &merchantID).Error
	return merchantID, err
}
