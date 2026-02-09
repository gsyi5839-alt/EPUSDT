package data

import (
	"github.com/assimon/luuu/model/dao"
	"github.com/assimon/luuu/model/mdb"
)

// CreateAuditLog 创建审计日志
func CreateAuditLog(log *mdb.AuditLog) error {
	return dao.Mdb.Create(log).Error
}

// GetAuditLogs 查询审计日志
func GetAuditLogs(eventType, authNo, customerWallet string, startTime, endTime int64, page, pageSize int) ([]mdb.AuditLog, int64, error) {
	var logs []mdb.AuditLog
	var total int64

	query := dao.Mdb.Model(&mdb.AuditLog{})

	// 条件过滤
	if eventType != "" {
		query = query.Where("event_type = ?", eventType)
	}
	if authNo != "" {
		query = query.Where("auth_no = ?", authNo)
	}
	if customerWallet != "" {
		query = query.Where("customer_wallet = ?", customerWallet)
	}
	if startTime > 0 {
		query = query.Where("timestamp >= ?", startTime)
	}
	if endTime > 0 {
		query = query.Where("timestamp <= ?", endTime)
	}

	// 统计总数
	err := query.Count(&total).Error
	if err != nil {
		return nil, 0, err
	}

	// 分页查询
	if page < 1 {
		page = 1
	}
	if pageSize < 1 {
		pageSize = 20
	}

	err = query.Offset((page - 1) * pageSize).
		Limit(pageSize).
		Order("timestamp DESC").
		Find(&logs).Error

	return logs, total, err
}

// GetAuditLogsByAuthNo 获取指定授权的所有日志
func GetAuditLogsByAuthNo(authNo string) ([]mdb.AuditLog, error) {
	var logs []mdb.AuditLog
	err := dao.Mdb.Model(&mdb.AuditLog{}).
		Where("auth_no = ?", authNo).
		Order("timestamp ASC").
		Find(&logs).Error
	return logs, err
}

// GetRecentFailedDeductions 获取最近失败的扣款记录
func GetRecentFailedDeductions(limit int) ([]mdb.AuditLog, error) {
	var logs []mdb.AuditLog
	err := dao.Mdb.Model(&mdb.AuditLog{}).
		Where("event_type = ?", mdb.EventDeductFailed).
		Order("timestamp DESC").
		Limit(limit).
		Find(&logs).Error
	return logs, err
}
