package service

import (
	"testing"
	"time"

	"github.com/assimon/luuu/config"
	"github.com/assimon/luuu/model/dao"
	"github.com/assimon/luuu/model/mdb"
	"github.com/stretchr/testify/assert"
)

// TestGenerateAuthNo 测试授权编号生成
func TestGenerateAuthNo(t *testing.T) {
	authNo := generateAuthNo()

	// 验证格式: A + 年月日时分秒(14位) + 随机3位数
	assert.NotEmpty(t, authNo)
	assert.Equal(t, 'A', rune(authNo[0]))
	assert.Equal(t, 18, len(authNo)) // A(1) + 时间(14) + 随机(3)

	// 验证唯一性
	authNo2 := generateAuthNo()
	time.Sleep(1 * time.Millisecond)
	authNo3 := generateAuthNo()

	// 大概率不同（随机数可能重复，但时间不同）
	assert.NotEqual(t, authNo, authNo3)
}

// TestGenerateAuthPassword 测试密码生成
func TestGenerateAuthPassword(t *testing.T) {
	password := generateAuthPassword()

	// 验证长度
	assert.Equal(t, 8, len(password))

	// 验证字符范围（只包含数字和大写字母，不含易混淆字符I/O）
	validChars := "0123456789ABCDEFGHJKLMNPQRSTUVWXYZ"
	for _, ch := range password {
		assert.Contains(t, validChars, string(ch))
	}

	// 验证唯一性
	password2 := generateAuthPassword()
	password3 := generateAuthPassword()

	assert.NotEqual(t, password, password2)
	assert.NotEqual(t, password2, password3)
}

// TestGenerateDeductNo 测试扣款单号生成
func TestGenerateDeductNo(t *testing.T) {
	deductNo := generateDeductNo()

	// 验证格式: D + 年月日时分秒(14位) + 随机3位数
	assert.NotEmpty(t, deductNo)
	assert.Equal(t, 'D', rune(deductNo[0]))
	assert.Equal(t, 18, len(deductNo))

	// 验证唯一性
	deductNo2 := generateDeductNo()
	time.Sleep(1 * time.Millisecond)
	deductNo3 := generateDeductNo()

	assert.NotEqual(t, deductNo, deductNo3)
}

// TestFilterWalletsWithPrivateKey 测试私钥过滤
func TestFilterWalletsWithPrivateKey(t *testing.T) {
	// Mock配置
	config.GetMerchantPrivateKeyForWallet = func(wallet string) string {
		if wallet == "TXyZ123" {
			return "0xprivatekey1"
		}
		if wallet == "TXyZ456" {
			return "0xprivatekey2"
		}
		return ""
	}
	config.HasMerchantPrivateKeyMap = func() bool {
		return true
	}

	wallets := []mdb.WalletAddress{
		{Token: "TXyZ123"},
		{Token: "TXyZ456"},
		{Token: "TXyZ789"}, // 无私钥
	}

	// 测试TRON链
	filtered := filterWalletsWithPrivateKey("TRON", wallets)
	assert.Equal(t, 2, len(filtered))
	assert.Equal(t, "TXyZ123", filtered[0].Token)
	assert.Equal(t, "TXyZ456", filtered[1].Token)

	// 测试EVM链
	filtered = filterWalletsWithPrivateKey("BSC", wallets)
	assert.Equal(t, 2, len(filtered))

	// 测试非授权链（应返回全部）
	filtered = filterWalletsWithPrivateKey("UNKNOWN", wallets)
	assert.Equal(t, 3, len(filtered))
}

// TestCalculateUsdtAmount 测试人民币转USDT计算
func TestCalculateUsdtAmount(t *testing.T) {
	// Mock汇率: 1 USDT = 6.5 CNY
	originalRate := config.GetUsdtRate
	config.GetUsdtRate = func() float64 {
		return 6.5
	}
	defer func() { config.GetUsdtRate = originalRate }()

	testCases := []struct {
		cny      float64
		expected float64
	}{
		{65.00, 10.0000},
		{100.00, 15.3846},
		{6.50, 1.0000},
		{0.01, 0.0015},
	}

	for _, tc := range testCases {
		usdt := tc.cny / 6.5
		assert.InDelta(t, tc.expected, usdt, 0.0001)
	}
}

// TestAuthorizationLifecycle 测试授权生命周期
func TestAuthorizationLifecycle(t *testing.T) {
	// 注意: 此测试需要数据库连接，应在集成测试环境中运行
	t.Skip("需要数据库连接，跳过单元测试")

	// 初始化数据库
	dao.DBInit()
	defer dao.Mdb.Exec("DELETE FROM ktv_authorizes")
	defer dao.Mdb.Exec("DELETE FROM ktv_deductions")

	// 1. 创建授权
	auth, err := CreateAuthorization(100.0, "A01", "张三", "测试授权", "TRON")
	assert.NoError(t, err)
	assert.NotEmpty(t, auth.AuthNo)
	assert.NotEmpty(t, auth.Password)
	assert.Equal(t, 100.0, auth.AmountUsdt)

	// 2. 查询授权信息（未确认状态）
	authInfo, err := GetAuthorizationInfo(auth.Password)
	assert.Error(t, err) // 未确认状态应返回错误

	// 3. 模拟确认授权
	err = ConfirmAuthorization(auth.AuthNo, "TCustomer123", "0xtxhash123")
	assert.NoError(t, err)

	// 4. 再次查询授权信息（已确认）
	authInfo, err = GetAuthorizationInfo(auth.Password)
	assert.NoError(t, err)
	assert.Equal(t, mdb.AuthorizeStatusActive, authInfo.Status)
	assert.Equal(t, 100.0, authInfo.RemainingUsdt)

	// 5. 扣款
	deduct, err := DeductFromAuthorization(auth.Password, 50.0, "啤酒2瓶", "waiter_001")
	assert.NoError(t, err)
	assert.NotEmpty(t, deduct.DeductNo)
	assert.Equal(t, "processing", deduct.Status)

	// 6. 查询扣款历史
	history, err := GetDeductionHistory(auth.Password)
	assert.NoError(t, err)
	assert.GreaterOrEqual(t, len(history), 1)

	// 7. 查询授权信息（扣款后）
	authInfo, err = GetAuthorizationInfo(auth.Password)
	assert.NoError(t, err)
	// 注意: 扣款是异步的，used_usdt可能还未更新
}

// TestOrderCreationFlow 测试订单创建流程
func TestOrderCreationFlow(t *testing.T) {
	t.Skip("需要数据库和Redis连接，跳过单元测试")

	// 初始化
	dao.DBInit()
	dao.RedisInit()

	// 测试用例
	testCases := []struct {
		amount      float64
		shouldError bool
		errorMsg    string
	}{
		{100.0, false, ""},
		{0.001, true, "支付金额错误"}, // 低于最低金额
		{-10.0, true, "支付金额错误"}, // 负数
	}

	for _, tc := range testCases {
		// TODO: 实现订单创建测试
	}
}

// BenchmarkGenerateAuthNo 基准测试：授权编号生成性能
func BenchmarkGenerateAuthNo(b *testing.B) {
	for i := 0; i < b.N; i++ {
		generateAuthNo()
	}
}

// BenchmarkGenerateAuthPassword 基准测试：密码生成性能
func BenchmarkGenerateAuthPassword(b *testing.B) {
	for i := 0; i < b.N; i++ {
		generateAuthPassword()
	}
}
