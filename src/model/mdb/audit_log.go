package mdb

import "time"

// AuditLog 安全审计日志
type AuditLog struct {
	ID             uint64 `gorm:"primaryKey;autoIncrement" json:"id"`
	EventType      string `gorm:"type:varchar(50);index;not null" json:"event_type"`        // 事件类型
	AuthNo         string `gorm:"type:varchar(50);index" json:"auth_no"`                    // 授权编号
	CustomerWallet string `gorm:"type:varchar(100);index" json:"customer_wallet"`           // 客户钱包
	OperatorID     string `gorm:"type:varchar(50)" json:"operator_id"`                      // 操作员
	IPAddress      string `gorm:"type:varchar(50)" json:"ip_address"`                       // IP 地址
	UserAgent      string `gorm:"type:varchar(255)" json:"user_agent"`                      // 客户端信息
	RequestData    string `gorm:"type:text" json:"request_data"`                            // 请求数据（脱敏）
	ResponseStatus int    `gorm:"type:int" json:"response_status"`                          // 响应状态码
	ErrorMessage   string `gorm:"type:varchar(500)" json:"error_message"`                   // 错误信息
	Timestamp      int64  `gorm:"index;not null" json:"timestamp"`                          // 时间戳
	TxHash         string `gorm:"type:varchar(128)" json:"tx_hash"`                         // 交易哈希
	CreatedAt      time.Time `gorm:"autoCreateTime" json:"created_at"`
}

func (a *AuditLog) TableName() string {
	return "audit_logs"
}

// 审计事件类型常量
const (
	EventAuthCreate     = "auth.create"     // 创建授权
	EventAuthConfirm    = "auth.confirm"    // 确认授权
	EventAuthRevoke     = "auth.revoke"     // 撤销授权
	EventAuthExpire     = "auth.expire"     // 授权过期
	EventAuthRenew      = "auth.renew"      // 授权续期
	EventDeductRequest  = "deduct.request"  // 扣款请求
	EventDeductSuccess  = "deduct.success"  // 扣款成功
	EventDeductFailed   = "deduct.failed"   // 扣款失败
	EventPasswordVerify = "password.verify" // 密码验证成功
	EventPasswordFailed = "password.failed" // 密码验证失败
	EventAllowanceCheck = "allowance.check" // 授权额度检查
	EventGasOptimize    = "gas.optimize"    // Gas费优化
)
