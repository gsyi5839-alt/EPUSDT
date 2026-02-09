package data

import (
	"github.com/assimon/luuu/model/dao"
	"github.com/assimon/luuu/model/mdb"
)

// CreateMerchant 创建商家
func CreateMerchant(merchant *mdb.Merchant) error {
	return dao.Mdb.Create(merchant).Error
}

// GetMerchantByUsername 通过用户名获取商家
func GetMerchantByUsername(username string) (*mdb.Merchant, error) {
	merchant := new(mdb.Merchant)
	err := dao.Mdb.Model(merchant).Where("username = ?", username).First(merchant).Error
	return merchant, err
}

// GetMerchantByID 通过ID获取商家
func GetMerchantByID(id uint64) (*mdb.Merchant, error) {
	merchant := new(mdb.Merchant)
	err := dao.Mdb.Model(merchant).Where("id = ?", id).First(merchant).Error
	return merchant, err
}

// GetMerchantByApiToken 通过API Token获取商家
func GetMerchantByApiToken(apiToken string) (*mdb.Merchant, error) {
	merchant := new(mdb.Merchant)
	err := dao.Mdb.Model(merchant).Where("api_token = ?", apiToken).First(merchant).Error
	return merchant, err
}

// UpdateMerchantLastLogin 更新商家最后登录时间
func UpdateMerchantLastLogin(id uint64, timestamp int64) error {
	return dao.Mdb.Model(&mdb.Merchant{}).Where("id = ?", id).Update("last_login_at", timestamp).Error
}

// UpdateMerchant 更新商家信息
func UpdateMerchant(merchant *mdb.Merchant) error {
	return dao.Mdb.Save(merchant).Error
}

// ListMerchants 列出所有商家
func ListMerchants(limit int) ([]mdb.Merchant, error) {
	var merchants []mdb.Merchant
	err := dao.Mdb.Model(&mdb.Merchant{}).Order("id DESC").Limit(limit).Find(&merchants).Error
	return merchants, err
}

// UpdateMerchantStatus 更新商家状态（封禁/解封）
func UpdateMerchantStatus(id uint64, status int) error {
	return dao.Mdb.Model(&mdb.Merchant{}).Where("id = ?", id).Update("status", status).Error
}

// GetAuthorizesByMerchant 获取商家的所有授权记录
func GetAuthorizesByMerchant(merchantWallet string, page, pageSize int, status int) ([]mdb.KtvAuthorize, int64, error) {
	var auths []mdb.KtvAuthorize
	var total int64

	query := dao.Mdb.Model(&mdb.KtvAuthorize{}).Where("merchant_wallet = ?", merchantWallet)

	if status > 0 {
		query = query.Where("status = ?", status)
	}

	// 获取总数
	query.Count(&total)

	// 分页查询
	offset := (page - 1) * pageSize
	err := query.Order("created_at DESC").Limit(pageSize).Offset(offset).Find(&auths).Error

	return auths, total, err
}

// GetDeductionsByMerchant 获取商家的所有扣款记录
func GetDeductionsByMerchant(merchantWallet string, page, pageSize int, status int, startTime, endTime int64) ([]mdb.KtvDeduction, int64, error) {
	var deducts []mdb.KtvDeduction
	var total int64

	// 先通过merchant_wallet查找所有授权的auth_id
	var authIDs []uint64
	dao.Mdb.Model(&mdb.KtvAuthorize{}).Where("merchant_wallet = ?", merchantWallet).Pluck("id", &authIDs)

	if len(authIDs) == 0 {
		return deducts, 0, nil
	}

	query := dao.Mdb.Model(&mdb.KtvDeduction{}).Where("auth_id IN ?", authIDs)

	if status > 0 {
		query = query.Where("status = ?", status)
	}

	if startTime > 0 {
		query = query.Where("deduct_time >= ?", startTime)
	}

	if endTime > 0 {
		query = query.Where("deduct_time <= ?", endTime)
	}

	// 获取总数
	query.Count(&total)

	// 分页查询
	offset := (page - 1) * pageSize
	err := query.Order("deduct_time DESC").Limit(pageSize).Offset(offset).Find(&deducts).Error

	return deducts, total, err
}

// GetMerchantStats 获取商家统计数据
func GetMerchantStats(merchantWallet string, startTime, endTime int64) (map[string]interface{}, error) {
	// 获取授权的auth_id列表
	var authIDs []uint64
	dao.Mdb.Model(&mdb.KtvAuthorize{}).Where("merchant_wallet = ?", merchantWallet).Pluck("id", &authIDs)

	stats := make(map[string]interface{})

	if len(authIDs) == 0 {
		stats["total_amount_usdt"] = 0.0
		stats["total_amount_cny"] = 0.0
		stats["total_count"] = 0
		stats["success_count"] = 0
		stats["failed_count"] = 0
		return stats, nil
	}

	// 统计扣款数据
	type Result struct {
		TotalAmountUsdt float64
		TotalAmountCny  float64
		TotalCount      int64
		SuccessCount    int64
		FailedCount     int64
	}

	var result Result
	query := dao.Mdb.Model(&mdb.KtvDeduction{}).Where("auth_id IN ?", authIDs)

	if startTime > 0 {
		query = query.Where("deduct_time >= ?", startTime)
	}

	if endTime > 0 {
		query = query.Where("deduct_time <= ?", endTime)
	}

	query.Select("SUM(amount_usdt) as total_amount_usdt, SUM(amount_cny) as total_amount_cny, COUNT(*) as total_count").Scan(&result)

	// 成功数量
	dao.Mdb.Model(&mdb.KtvDeduction{}).Where("auth_id IN ? AND status = 2", authIDs).
		Where("deduct_time >= ? AND deduct_time <= ?", startTime, endTime).
		Count(&result.SuccessCount)

	// 失败数量
	dao.Mdb.Model(&mdb.KtvDeduction{}).Where("auth_id IN ? AND status = 3", authIDs).
		Where("deduct_time >= ? AND deduct_time <= ?", startTime, endTime).
		Count(&result.FailedCount)

	stats["total_amount_usdt"] = result.TotalAmountUsdt
	stats["total_amount_cny"] = result.TotalAmountCny
	stats["total_count"] = result.TotalCount
	stats["success_count"] = result.SuccessCount
	stats["failed_count"] = result.FailedCount

	return stats, nil
}

// GetMerchantChartData 获取商家图表数据（按日期统计）
func GetMerchantChartData(merchantWallet string, startTime, endTime int64) ([]map[string]interface{}, error) {
	// 获取授权的auth_id列表
	var authIDs []uint64
	dao.Mdb.Model(&mdb.KtvAuthorize{}).Where("merchant_wallet = ?", merchantWallet).Pluck("id", &authIDs)

	var chartData []map[string]interface{}

	if len(authIDs) == 0 {
		return chartData, nil
	}

	// 按日期分组统计
	type DailyStats struct {
		Date        string  `json:"date"`
		AmountUsdt  float64 `json:"amount_usdt"`
		AmountCny   float64 `json:"amount_cny"`
		Count       int64   `json:"count"`
	}

	var dailyStats []DailyStats
	err := dao.Mdb.Model(&mdb.KtvDeduction{}).
		Select("DATE(FROM_UNIXTIME(deduct_time)) as date, SUM(amount_usdt) as amount_usdt, SUM(amount_cny) as amount_cny, COUNT(*) as count").
		Where("auth_id IN ? AND status = 2", authIDs).
		Where("deduct_time >= ? AND deduct_time <= ?", startTime, endTime).
		Group("date").
		Order("date ASC").
		Scan(&dailyStats).Error

	if err != nil {
		return nil, err
	}

	for _, stat := range dailyStats {
		chartData = append(chartData, map[string]interface{}{
			"date":        stat.Date,
			"amount_usdt": stat.AmountUsdt,
			"amount_cny":  stat.AmountCny,
			"count":       stat.Count,
		})
	}

	return chartData, nil
}

// ========== 商家钱包管理 ==========

// GetWalletsByMerchantID 获取商家的钱包列表
func GetWalletsByMerchantID(merchantID uint64) ([]mdb.WalletAddress, error) {
	var wallets []mdb.WalletAddress
	err := dao.Mdb.Where("merchant_id = ?", merchantID).Order("id DESC").Find(&wallets).Error
	return wallets, err
}

// AddMerchantWallet 添加商家钱包
func AddMerchantWallet(wallet *mdb.WalletAddress) error {
	return dao.Mdb.Create(wallet).Error
}

// DeleteMerchantWallet 删除商家钱包（必须属于该商家）
func DeleteMerchantWallet(merchantID uint64, walletID uint64) error {
	return dao.Mdb.Where("id = ? AND merchant_id = ?", walletID, merchantID).Delete(&mdb.WalletAddress{}).Error
}

// UpdateMerchantWalletStatus 更新商家钱包状态
func UpdateMerchantWalletStatus(merchantID uint64, walletID uint64, status int64) error {
	return dao.Mdb.Model(&mdb.WalletAddress{}).Where("id = ? AND merchant_id = ?", walletID, merchantID).Update("status", status).Error
}
