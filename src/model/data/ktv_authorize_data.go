package data

import (
	"github.com/assimon/luuu/model/dao"
	"github.com/assimon/luuu/model/mdb"
	"gorm.io/gorm"
)

// CreateAuthorize 创建授权记录
func CreateAuthorize(auth *mdb.KtvAuthorize) error {
	return dao.Mdb.Create(auth).Error
}

// GetAuthorizeByNo 通过授权编号获取
func GetAuthorizeByNo(authNo string) (*mdb.KtvAuthorize, error) {
	auth := new(mdb.KtvAuthorize)
	err := dao.Mdb.Model(auth).Where("auth_no = ?", authNo).First(auth).Error
	return auth, err
}

// GetAuthorizeByPassword 通过密码获取授权
func GetAuthorizeByPassword(password string) (*mdb.KtvAuthorize, error) {
	auth := new(mdb.KtvAuthorize)
	err := dao.Mdb.Model(auth).Where("password = ? AND status = ?", password, mdb.AuthorizeStatusActive).First(auth).Error
	return auth, err
}

// GetAuthorizeByWallet 通过钱包地址获取有效授权
func GetAuthorizeByWallet(wallet string) (*mdb.KtvAuthorize, error) {
	auth := new(mdb.KtvAuthorize)
	err := dao.Mdb.Model(auth).
		Where("customer_wallet = ? AND status = ?", wallet, mdb.AuthorizeStatusActive).
		First(auth).Error
	return auth, err
}

// UpdateAuthorizeActive 激活授权
func UpdateAuthorizeActive(authNo, txHash string, authorizeTime int64) error {
	return dao.Mdb.Model(&mdb.KtvAuthorize{}).Where("auth_no = ?", authNo).
		Updates(map[string]interface{}{
			"status":         mdb.AuthorizeStatusActive,
			"tx_hash":        txHash,
			"authorize_time": authorizeTime,
		}).Error
}

// UpdateAuthorizeUsed 更新已使用额度
func UpdateAuthorizeUsed(tx *gorm.DB, authID uint64, usedAmount float64) error {
	return tx.Model(&mdb.KtvAuthorize{}).Where("id = ?", authID).
		Updates(map[string]interface{}{
			"used_usdt":      gorm.Expr("used_usdt + ?", usedAmount),
			"remaining_usdt": gorm.Expr("remaining_usdt - ?", usedAmount),
		}).Error
}

// UpdateAuthorizeDepleted 标记额度已用尽
func UpdateAuthorizeDepleted(authID uint64) error {
	return dao.Mdb.Model(&mdb.KtvAuthorize{}).Where("id = ?", authID).
		Update("status", mdb.AuthorizeStatusDepleted).Error
}

// GetActiveAuthorizes 获取所有有效授权
func GetActiveAuthorizes() ([]mdb.KtvAuthorize, error) {
	var auths []mdb.KtvAuthorize
	err := dao.Mdb.Model(&mdb.KtvAuthorize{}).
		Where("status = ?", mdb.AuthorizeStatusActive).
		Order("created_at DESC").
		Find(&auths).Error
	return auths, err
}

// CreateDeduction 创建扣款记录
func CreateDeduction(deduct *mdb.KtvDeduction) error {
	return dao.Mdb.Create(deduct).Error
}

// GetDeductionByNo 通过扣款单号获取
func GetDeductionByNo(deductNo string) (*mdb.KtvDeduction, error) {
	deduct := new(mdb.KtvDeduction)
	err := dao.Mdb.Model(deduct).Where("deduct_no = ?", deductNo).First(deduct).Error
	return deduct, err
}

// UpdateDeductionSuccess 更新扣款成功
func UpdateDeductionSuccess(tx *gorm.DB, deductNo, txHash string) error {
	return tx.Model(&mdb.KtvDeduction{}).Where("deduct_no = ?", deductNo).
		Updates(map[string]interface{}{
			"status":  2,
			"tx_hash": txHash,
		}).Error
}

// UpdateDeductionFailed 更新扣款失败
func UpdateDeductionFailed(deductNo, reason string) error {
	return dao.Mdb.Model(&mdb.KtvDeduction{}).Where("deduct_no = ?", deductNo).
		Updates(map[string]interface{}{
			"status":      3,
			"fail_reason": reason,
		}).Error
}

// GetDeductionsByAuth 获取某授权的扣款记录
func GetDeductionsByAuth(authID uint64) ([]mdb.KtvDeduction, error) {
	var deducts []mdb.KtvDeduction
	err := dao.Mdb.Model(&mdb.KtvDeduction{}).
		Where("auth_id = ?", authID).
		Order("created_at DESC").
		Find(&deducts).Error
	return deducts, err
}

// GetDeductionsByPassword 通过密码获取扣款记录
func GetDeductionsByPassword(password string) ([]mdb.KtvDeduction, error) {
	var deducts []mdb.KtvDeduction
	err := dao.Mdb.Model(&mdb.KtvDeduction{}).
		Where("password = ?", password).
		Order("created_at DESC").
		Find(&deducts).Error
	return deducts, err
}

// UpdateAuthorizeStatus 更新授权状态
func UpdateAuthorizeStatus(authID uint64, status int) error {
	return dao.Mdb.Model(&mdb.KtvAuthorize{}).Where("id = ?", authID).
		Update("status", status).Error
}

// GetPendingAuthorizes 获取所有待确认的授权
func GetPendingAuthorizes() ([]mdb.KtvAuthorize, error) {
	var auths []mdb.KtvAuthorize
	err := dao.Mdb.Model(&mdb.KtvAuthorize{}).
		Where("status = ?", mdb.AuthorizeStatusPending).
		Order("created_at DESC").
		Find(&auths).Error
	return auths, err
}
