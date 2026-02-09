package validator

import (
	"errors"
	"html"
	"regexp"
	"strings"
)

var (
	// 字母数字和常用符号白名单
	AlphanumericRegex = regexp.MustCompile(`^[a-zA-Z0-9\s\-_]+$`)

	// 钱包地址格式验证
	EthWalletRegex  = regexp.MustCompile(`^0x[a-fA-F0-9]{40}$`)
	TronWalletRegex = regexp.MustCompile(`^T[A-Za-z1-9]{33}$`)

	// 授权密码格式（8位大写字母数字）
	AuthPasswordRegex = regexp.MustCompile(`^[A-Z0-9]{8}$`)
)

// SanitizeInput 清理用户输入，转义 HTML 特殊字符
func SanitizeInput(input string) string {
	return html.EscapeString(strings.TrimSpace(input))
}

// ValidateAlphanumeric 验证字符串是否仅包含字母数字和安全字符
func ValidateAlphanumeric(input string) error {
	if !AlphanumericRegex.MatchString(input) {
		return errors.New("仅允许字母、数字、空格、横线和下划线")
	}
	return nil
}

// ValidateWalletAddress 验证钱包地址格式
func ValidateWalletAddress(address string) error {
	if EthWalletRegex.MatchString(address) {
		return nil // EVM 地址有效
	}
	if TronWalletRegex.MatchString(address) {
		return nil // TRON 地址有效
	}
	return errors.New("钱包地址格式错误")
}

// ValidateAuthPassword 验证授权密码格式
func ValidateAuthPassword(password string) error {
	if !AuthPasswordRegex.MatchString(password) {
		return errors.New("密码格式错误，应为8位大写字母数字")
	}
	return nil
}

// ValidateLength 验证字符串长度
func ValidateLength(input string, minLen, maxLen int) error {
	length := len(input)
	if length < minLen {
		return errors.New("输入过短")
	}
	if length > maxLen {
		return errors.New("输入过长")
	}
	return nil
}

// RemoveDangerousChars 移除危险字符（额外防护）
func RemoveDangerousChars(input string) string {
	// 移除可能导致 XSS 的字符
	dangerous := []string{"<script>", "</script>", "<iframe>", "</iframe>", "javascript:", "onerror=", "onclick="}
	result := input
	for _, d := range dangerous {
		result = strings.ReplaceAll(result, d, "")
		result = strings.ReplaceAll(result, strings.ToUpper(d), "")
	}
	return result
}

// ValidateAndSanitize 验证并清理输入（一站式处理）
func ValidateAndSanitize(input string, maxLen int, alphanumericOnly bool) (string, error) {
	// 1. 去除首尾空格
	input = strings.TrimSpace(input)

	// 2. 验证长度
	if err := ValidateLength(input, 1, maxLen); err != nil {
		return "", err
	}

	// 3. 验证字符白名单
	if alphanumericOnly {
		if err := ValidateAlphanumeric(input); err != nil {
			return "", err
		}
	}

	// 4. HTML 转义
	sanitized := SanitizeInput(input)

	return sanitized, nil
}
