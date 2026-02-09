package sign

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

// TestSignatureGeneration 测试签名生成
func TestSignatureGeneration(t *testing.T) {
	token := "test_api_token_123"

	// 测试用例1: 基本参数
	params := map[string]interface{}{
		"order_id":  "ORDER_001",
		"amount":    100.50,
		"timestamp": int64(1707380000),
		"nonce":     "abc123",
	}

	signature, err := Get(params, token)
	assert.NoError(t, err)
	assert.NotEmpty(t, signature)
	assert.Equal(t, 32, len(signature)) // MD5哈希长度

	// 测试用例2: 相同参数应生成相同签名
	signature2, err := Get(params, token)
	assert.NoError(t, err)
	assert.Equal(t, signature, signature2)

	// 测试用例3: 修改参数后签名不同
	params["amount"] = 200.00
	signature3, err := Get(params, token)
	assert.NoError(t, err)
	assert.NotEqual(t, signature, signature3)

	// 测试用例4: 修改token后签名不同
	params["amount"] = 100.50
	signature4, err := Get(params, "different_token")
	assert.NoError(t, err)
	assert.NotEqual(t, signature, signature4)
}

// TestSignatureWithDifferentTypes 测试不同参数类型的签名
func TestSignatureWithDifferentTypes(t *testing.T) {
	token := "test_token"

	// 测试包含不同数据类型的参数
	params := map[string]interface{}{
		"string_param": "value",
		"int_param":    123,
		"float_param":  45.67,
		"bool_param":   true,
		"timestamp":    int64(1707380000),
		"nonce":        "xyz789",
	}

	signature, err := Get(params, token)
	assert.NoError(t, err)
	assert.NotEmpty(t, signature)
}

// TestSignatureExcludesSignatureField 测试签名计算时排除signature字段
func TestSignatureExcludesSignatureField(t *testing.T) {
	token := "test_token"

	params1 := map[string]interface{}{
		"order_id":  "ORDER_001",
		"timestamp": int64(1707380000),
		"nonce":     "abc123",
	}

	params2 := map[string]interface{}{
		"order_id":  "ORDER_001",
		"timestamp": int64(1707380000),
		"nonce":     "abc123",
		"signature": "should_be_ignored",
	}

	signature1, _ := Get(params1, token)
	signature2, _ := Get(params2, token)

	// 两者应该相同，因为signature字段会被排除
	assert.Equal(t, signature1, signature2)
}

// TestSignatureParameterOrder 测试参数顺序不影响签名（字典序排序）
func TestSignatureParameterOrder(t *testing.T) {
	token := "test_token"

	// 不同顺序的参数
	params1 := map[string]interface{}{
		"z_param":   "last",
		"a_param":   "first",
		"m_param":   "middle",
		"timestamp": int64(1707380000),
		"nonce":     "abc123",
	}

	params2 := map[string]interface{}{
		"a_param":   "first",
		"m_param":   "middle",
		"z_param":   "last",
		"nonce":     "abc123",
		"timestamp": int64(1707380000),
	}

	signature1, _ := Get(params1, token)
	signature2, _ := Get(params2, token)

	// 相同参数不同顺序应生成相同签名
	assert.Equal(t, signature1, signature2)
}

// TestSignatureEmptyParams 测试空参数
func TestSignatureEmptyParams(t *testing.T) {
	token := "test_token"

	params := map[string]interface{}{}

	signature, err := Get(params, token)
	assert.NoError(t, err)
	assert.NotEmpty(t, signature)
}

// TestSignatureSpecialCharacters 测试特殊字符处理
func TestSignatureSpecialCharacters(t *testing.T) {
	token := "test_token"

	params := map[string]interface{}{
		"url":       "https://example.com/callback?param=1&other=2",
		"content":   "包含中文字符",
		"special":   "!@#$%^&*()",
		"timestamp": int64(1707380000),
		"nonce":     "abc123",
	}

	signature, err := Get(params, token)
	assert.NoError(t, err)
	assert.NotEmpty(t, signature)
	assert.Equal(t, 32, len(signature))
}

// TestSignatureVerification 测试签名验证场景
func TestSignatureVerification(t *testing.T) {
	token := "secret_token_xyz"

	// 客户端生成签名
	clientParams := map[string]interface{}{
		"order_id":     "ORDER_20260208001",
		"amount":       100.50,
		"chain":        "TRON",
		"notify_url":   "https://merchant.com/callback",
		"redirect_url": "https://merchant.com/success",
		"timestamp":    int64(1707380000),
		"nonce":        "unique_nonce_12345",
	}

	clientSignature, err := Get(clientParams, token)
	assert.NoError(t, err)

	// 服务端验证签名
	clientParams["signature"] = clientSignature
	serverSignature, err := Get(clientParams, token)
	assert.NoError(t, err)

	// 验证通过
	assert.Equal(t, clientSignature, serverSignature)

	// 篡改参数后验证失败
	clientParams["amount"] = 200.00
	tamperedSignature, err := Get(clientParams, token)
	assert.NoError(t, err)
	assert.NotEqual(t, clientSignature, tamperedSignature)
}

// TestSignatureRealWorldScenario 测试真实场景
func TestSignatureRealWorldScenario(t *testing.T) {
	// 真实API Token
	apiToken := "epusdt_prod_token_abc123"

	// 模拟创建订单请求
	createOrderParams := map[string]interface{}{
		"order_id":     "SHOP_ORDER_20260208123456",
		"amount":       299.99,
		"chain":        "BSC",
		"notify_url":   "https://shop.example.com/api/payment/callback",
		"redirect_url": "https://shop.example.com/order/success",
		"timestamp":    int64(1707398765),
		"nonce":        "f7a8b9c0d1e2f3g4h5i6",
	}

	signature, err := Get(createOrderParams, apiToken)
	assert.NoError(t, err)
	assert.NotEmpty(t, signature)

	// 验证签名可重现
	verifySignature, err := Get(createOrderParams, apiToken)
	assert.NoError(t, err)
	assert.Equal(t, signature, verifySignature)

	// 模拟扣款请求
	deductParams := map[string]interface{}{
		"password":     "AB12CD34",
		"amount_cny":   50.00,
		"product_info": "啤酒2瓶、小吃拼盘1份",
		"operator_id":  "waiter_001",
		"timestamp":    int64(1707398765),
		"nonce":        "j7k8l9m0n1o2p3q4r5s6",
	}

	deductSignature, err := Get(deductParams, apiToken)
	assert.NoError(t, err)
	assert.NotEmpty(t, deductSignature)
	assert.NotEqual(t, signature, deductSignature) // 不同请求签名不同
}

// BenchmarkSignatureGeneration 基准测试：签名生成性能
func BenchmarkSignatureGeneration(b *testing.B) {
	token := "test_token"
	params := map[string]interface{}{
		"order_id":  "ORDER_001",
		"amount":    100.50,
		"timestamp": int64(1707380000),
		"nonce":     "abc123",
	}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		Get(params, token)
	}
}

// BenchmarkSignatureWithManyParams 基准测试：多参数签名性能
func BenchmarkSignatureWithManyParams(b *testing.B) {
	token := "test_token"
	params := map[string]interface{}{
		"param_01": "value_01",
		"param_02": "value_02",
		"param_03": "value_03",
		"param_04": "value_04",
		"param_05": "value_05",
		"param_06": "value_06",
		"param_07": "value_07",
		"param_08": "value_08",
		"param_09": "value_09",
		"param_10": "value_10",
		"timestamp": int64(1707380000),
		"nonce":     "abc123",
	}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		Get(params, token)
	}
}
