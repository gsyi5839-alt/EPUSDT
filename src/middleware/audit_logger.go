package middleware

import (
	"encoding/json"
	"regexp"
	"time"

	"github.com/assimon/luuu/model/data"
	"github.com/assimon/luuu/model/mdb"
	"github.com/labstack/echo/v4"
)

// AuditLogger 审计日志中间件配置
type AuditLogger struct {
	// 是否启用审计
	Enabled bool
	// 需要审计的路径（正则表达式）
	PathPatterns []*regexp.Regexp
}

// NewAuditLogger 创建审计日志中间件
func NewAuditLogger(enabled bool, patterns []string) *AuditLogger {
	logger := &AuditLogger{
		Enabled:      enabled,
		PathPatterns: make([]*regexp.Regexp, 0),
	}

	// 编译正则表达式
	for _, pattern := range patterns {
		if re, err := regexp.Compile(pattern); err == nil {
			logger.PathPatterns = append(logger.PathPatterns, re)
		}
	}

	return logger
}

// Middleware 返回 Echo 中间件函数
func (a *AuditLogger) Middleware() echo.MiddlewareFunc {
	return func(next echo.HandlerFunc) echo.HandlerFunc {
		return func(c echo.Context) error {
			// 如果未启用，直接跳过
			if !a.Enabled {
				return next(c)
			}

			// 检查路径是否需要审计
			if !a.shouldAudit(c.Path()) {
				return next(c)
			}

			// 记录开始时间
			start := time.Now()

			// 执行下一个处理器
			err := next(c)

			// 记录审计日志（异步）
			go a.recordLog(c, start, err)

			return err
		}
	}
}

// shouldAudit 判断是否需要审计该路径
func (a *AuditLogger) shouldAudit(path string) bool {
	// 如果没有配置模式，审计所有路径
	if len(a.PathPatterns) == 0 {
		return true
	}

	// 检查路径是否匹配任一模式
	for _, pattern := range a.PathPatterns {
		if pattern.MatchString(path) {
			return true
		}
	}

	return false
}

// recordLog 记录审计日志
func (a *AuditLogger) recordLog(c echo.Context, start time.Time, err error) {
	// 提取请求数据
	authNo := a.extractAuthNo(c)
	customerWallet := a.extractCustomerWallet(c)
	operatorID := a.extractOperatorID(c)
	eventType := a.detectEventType(c)
	requestData := a.sanitizeRequestData(c)

	// 响应状态
	responseStatus := c.Response().Status
	if err != nil && responseStatus == 0 {
		responseStatus = 500
	}

	// 错误信息
	errorMsg := ""
	if err != nil {
		errorMsg = err.Error()
	}

	// 创建审计日志
	log := &mdb.AuditLog{
		EventType:      eventType,
		AuthNo:         authNo,
		CustomerWallet: customerWallet,
		OperatorID:     operatorID,
		IPAddress:      c.RealIP(),
		UserAgent:      c.Request().UserAgent(),
		RequestData:    requestData,
		ResponseStatus: responseStatus,
		ErrorMessage:   errorMsg,
		Timestamp:      time.Now().Unix(),
	}

	// 保存到数据库（忽略错误，避免影响主流程）
	data.CreateAuditLog(log)
}

// extractAuthNo 从请求中提取授权编号
func (a *AuditLogger) extractAuthNo(c echo.Context) string {
	// 尝试从路径参数获取
	if authNo := c.Param("auth_no"); authNo != "" {
		return authNo
	}

	// 尝试从查询参数获取
	if authNo := c.QueryParam("auth_no"); authNo != "" {
		return authNo
	}

	// 尝试从请求体获取（仅支持 JSON）
	if c.Request().Header.Get("Content-Type") == "application/json" {
		var body map[string]interface{}
		if err := c.Bind(&body); err == nil {
			if authNo, ok := body["auth_no"].(string); ok {
				return authNo
			}
		}
	}

	return ""
}

// extractCustomerWallet 提取客户钱包地址
func (a *AuditLogger) extractCustomerWallet(c echo.Context) string {
	// 尝试从请求体获取
	if c.Request().Header.Get("Content-Type") == "application/json" {
		var body map[string]interface{}
		if err := c.Bind(&body); err == nil {
			if wallet, ok := body["customer_wallet"].(string); ok {
				return wallet
			}
		}
	}

	return ""
}

// extractOperatorID 提取操作员ID
func (a *AuditLogger) extractOperatorID(c echo.Context) string {
	// 尝试从请求头获取（JWT token）
	if token := c.Request().Header.Get("Authorization"); token != "" {
		// TODO: 解析 JWT 获取操作员 ID
		return "admin" // 临时返回
	}

	// 尝试从请求体获取
	if c.Request().Header.Get("Content-Type") == "application/json" {
		var body map[string]interface{}
		if err := c.Bind(&body); err == nil {
			if operatorID, ok := body["operator_id"].(string); ok {
				return operatorID
			}
		}
	}

	return ""
}

// detectEventType 检测事件类型
func (a *AuditLogger) detectEventType(c echo.Context) string {
	path := c.Path()
	method := c.Request().Method

	// 根据路径和方法判断事件类型
	switch {
	case path == "/api/v1/auth/create" && method == "POST":
		return mdb.EventAuthCreate
	case path == "/api/v1/auth/confirm" && method == "POST":
		return mdb.EventAuthConfirm
	case path == "/api/v1/auth/deduct" && method == "POST":
		return mdb.EventDeductRequest
	case path == "/api/v1/auth/revoke" && method == "POST":
		return mdb.EventAuthRevoke
	case path == "/api/v1/auth/renew" && method == "POST":
		return mdb.EventAuthRenew
	default:
		return "unknown"
	}
}

// sanitizeRequestData 脱敏请求数据
func (a *AuditLogger) sanitizeRequestData(c echo.Context) string {
	// 仅处理 JSON 请求
	if c.Request().Header.Get("Content-Type") != "application/json" {
		return ""
	}

	var body map[string]interface{}
	if err := c.Bind(&body); err != nil {
		return ""
	}

	// 脱敏敏感字段
	sensitiveFields := []string{"password", "private_key", "secret", "token"}
	for _, field := range sensitiveFields {
		if _, exists := body[field]; exists {
			body[field] = "***"
		}
	}

	// 转换为 JSON 字符串
	jsonData, _ := json.Marshal(body)
	return string(jsonData)
}

// DefaultAuditLogger 默认审计日志中间件（审计所有 /api/v1/auth 路径）
func DefaultAuditLogger() echo.MiddlewareFunc {
	logger := NewAuditLogger(true, []string{
		`^/api/v1/auth/.*`,
		`^/api/v1/wallet/.*`,
	})
	return logger.Middleware()
}
