package log

import (
	"fmt"
	"time"
)

// AuditEvent 审计事件类型
type AuditEvent string

const (
	// 管理员相关
	EventAdminLogin         AuditEvent = "admin_login"
	EventAdminLoginFailed   AuditEvent = "admin_login_failed"
	EventAdminLogout        AuditEvent = "admin_logout"
	EventAdminCreateUser    AuditEvent = "admin_create_user"
	EventAdminUpdateUser    AuditEvent = "admin_update_user"
	EventAdminDeleteUser    AuditEvent = "admin_delete_user"

	// 授权相关
	EventAuthCreate         AuditEvent = "auth_create"
	EventAuthConfirm        AuditEvent = "auth_confirm"
	EventAuthRevoke         AuditEvent = "auth_revoke"

	// 扣款相关
	EventDeduct             AuditEvent = "deduct"
	EventDeductFailed       AuditEvent = "deduct_failed"

	// 安全相关
	EventPrivateKeyAccess   AuditEvent = "private_key_access"
	EventSignatureFailure   AuditEvent = "signature_failure"
	EventRateLimitHit       AuditEvent = "rate_limit_hit"
	EventUnauthorizedAccess AuditEvent = "unauthorized_access"

	// 数据隐私相关
	EventDataExport         AuditEvent = "data_export"
	EventDataDeletion       AuditEvent = "data_deletion"
)

// AuditLog 记录审计日志
// 参数:
//   - event: 事件类型
//   - userID: 用户ID（可以是管理员ID、授权ID等）
//   - ip: 客户端IP地址
//   - details: 事件详情描述
func AuditLog(event AuditEvent, userID interface{}, ip, details string) {
	timestamp := time.Now().Unix()

	// 写入结构化日志（zap）
	Sugar.Infow("AUDIT",
		"event", event,
		"user_id", userID,
		"ip", ip,
		"details", details,
		"timestamp", timestamp,
	)

	// 注意：Redis写入功能已移除以避免循环依赖
	// 如需Redis或数据库审计日志，请在middleware/audit_logger.go中实现
}

// MaskSensitiveData 脱敏敏感数据
// 参数:
//   - s: 要脱敏的字符串
//   - showLen: 首尾各显示的字符数
// 返回:
//   - 脱敏后的字符串，格式: "开头****结尾"
func MaskSensitiveData(s string, showLen int) string {
	if s == "" {
		return ""
	}
	if len(s) <= showLen*2 {
		return "****"
	}
	return s[:showLen] + "****" + s[len(s)-showLen:]
}

// MaskWallet 脱敏钱包地址
// 示例: 0xabcd1234...5678efgh
func MaskWallet(wallet string) string {
	return MaskSensitiveData(wallet, 6)
}

// MaskPassword 脱敏密码
// 示例: AB****YZ
func MaskPassword(password string) string {
	return MaskSensitiveData(password, 2)
}

// MaskPrivateKey 脱敏私钥（仅显示前缀）
// 示例: 0x12****
func MaskPrivateKey(privateKey string) string {
	if len(privateKey) > 4 {
		return privateKey[:4] + "****"
	}
	return "****"
}

// QueryAuditLogs 已禁用 - 为避免循环依赖，Redis查询功能已移除
// 如需查询审计日志，请直接查询数据库中的audit_logs表
func QueryAuditLogs(event AuditEvent, limit int) ([]map[string]string, error) {
	return nil, fmt.Errorf("QueryAuditLogs is disabled to avoid import cycles")
}
