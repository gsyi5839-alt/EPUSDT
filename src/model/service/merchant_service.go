package service

import (
	"crypto/md5"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"time"

	"github.com/assimon/luuu/config"
	"github.com/assimon/luuu/model/data"
	"github.com/assimon/luuu/model/mdb"
	"github.com/golang-jwt/jwt/v5"
	"golang.org/x/crypto/bcrypt"
)

// JWT密钥（商家独立）
const merchantJWTSecret = "epusdt_merchant_jwt_secret_key_2026"

// MerchantClaims JWT声明
type MerchantClaims struct {
	MerchantID uint64 `json:"merchant_id"`
	Username   string `json:"username"`
	jwt.RegisteredClaims
}

// MerchantRegisterRequest 商家注册请求
type MerchantRegisterRequest struct {
	Username     string `json:"username" validate:"required"`
	Password     string `json:"password" validate:"required"`
	Email        string `json:"email"`
	MerchantName string `json:"merchant_name" validate:"required"`
	WalletToken  string `json:"wallet_token" validate:"required"`
}

// MerchantLoginRequest 商家登录请求
type MerchantLoginRequest struct {
	Username string `json:"username" validate:"required"`
	Password string `json:"password" validate:"required"`
}

// MerchantRegister 商家注册
func MerchantRegister(req *MerchantRegisterRequest) (*mdb.Merchant, string, error) {
	// 手动验证长度
	if len(req.Username) < 3 || len(req.Username) > 32 {
		return nil, "", errors.New("用户名长度必须在3-32个字符之间")
	}
	if len(req.Password) < 6 {
		return nil, "", errors.New("密码长度不能少于6个字符")
	}

	// 检查用户名是否已存在
	existMerchant, _ := data.GetMerchantByUsername(req.Username)
	if existMerchant != nil && existMerchant.ID > 0 {
		return nil, "", errors.New("用户名已存在")
	}

	// 密码加密
	passwordHash, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		return nil, "", err
	}

	// 生成API Token
	apiToken := generateMerchantApiToken()

	// 创建商家
	merchant := &mdb.Merchant{
		Username:     req.Username,
		PasswordHash: string(passwordHash),
		Email:        req.Email,
		MerchantName: req.MerchantName,
		WalletToken:  req.WalletToken,
		Status:       1,
		ApiToken:     apiToken,
		UsdtRate:     config.GetUsdtRate(), // 使用系统默认汇率
		Balance:      0,
		LastLoginAt:  time.Now().Unix(),
	}

	if err := data.CreateMerchant(merchant); err != nil {
		return nil, "", err
	}

	// 生成JWT Token
	token, err := generateMerchantJWT(merchant.ID, merchant.Username)
	if err != nil {
		return nil, "", err
	}

	return merchant, token, nil
}

// MerchantLogin 商家登录
func MerchantLogin(req *MerchantLoginRequest) (*mdb.Merchant, string, error) {
	// 获取商家
	merchant, err := data.GetMerchantByUsername(req.Username)
	if err != nil {
		return nil, "", errors.New("用户名或密码错误")
	}

	// 检查状态
	if merchant.Status != 1 {
		return nil, "", errors.New("账号已被禁用")
	}

	// 验证密码
	if err := bcrypt.CompareHashAndPassword([]byte(merchant.PasswordHash), []byte(req.Password)); err != nil {
		return nil, "", errors.New("用户名或密码错误")
	}

	// 更新最后登录时间
	data.UpdateMerchantLastLogin(merchant.ID, time.Now().Unix())

	// 生成JWT Token
	token, err := generateMerchantJWT(merchant.ID, merchant.Username)
	if err != nil {
		return nil, "", err
	}

	return merchant, token, nil
}

// GetMerchantProfile 获取商家信息
func GetMerchantProfile(merchantID uint64) (*mdb.Merchant, error) {
	return data.GetMerchantByID(merchantID)
}

// GenerateMerchantQRCode 生成授权二维码
func GenerateMerchantQRCode(merchantID uint64, amountUsdt float64, tableNo, customerName string, expireMinutes int) (*AuthorizationResponse, error) {
	// 获取商家信息
	merchant, err := data.GetMerchantByID(merchantID)
	if err != nil {
		return nil, errors.New("商家不存在")
	}

	if merchant.Status != 1 {
		return nil, errors.New("商家账号已被禁用")
	}

	// 创建授权
	return CreateAuthorization(amountUsdt, tableNo, customerName, fmt.Sprintf("商家:%s", merchant.MerchantName), "TRON")
}

// GetMerchantAuthorizations 获取商家授权列表
func GetMerchantAuthorizations(merchantID uint64, page, pageSize int, status int) ([]mdb.KtvAuthorize, int64, error) {
	// 获取商家信息
	merchant, err := data.GetMerchantByID(merchantID)
	if err != nil {
		return nil, 0, errors.New("商家不存在")
	}

	return data.GetAuthorizesByMerchant(merchant.WalletToken, page, pageSize, status)
}

// GetMerchantAuthorizationDetail 获取授权详情
func GetMerchantAuthorizationDetail(merchantID uint64, authID uint64) (*mdb.KtvAuthorize, error) {
	// 获取商家信息
	merchant, err := data.GetMerchantByID(merchantID)
	if err != nil {
		return nil, errors.New("商家不存在")
	}

	// 获取授权信息
	auth, err := data.GetAuthorizeByNo(fmt.Sprintf("%d", authID))
	if err != nil {
		return nil, errors.New("授权不存在")
	}

	// 验证授权是否属于该商家
	if auth.MerchantWallet != merchant.WalletToken {
		return nil, errors.New("无权访问该授权")
	}

	return auth, nil
}

// RevokeMerchantAuthorization 撤销授权
func RevokeMerchantAuthorization(merchantID uint64, authID uint64) error {
	// 获取商家信息
	merchant, err := data.GetMerchantByID(merchantID)
	if err != nil {
		return errors.New("商家不存在")
	}

	// 获取授权信息
	auth, err := data.GetAuthorizeByNo(fmt.Sprintf("%d", authID))
	if err != nil {
		return errors.New("授权不存在")
	}

	// 验证授权是否属于该商家
	if auth.MerchantWallet != merchant.WalletToken {
		return errors.New("无权操作该授权")
	}

	// 更新授权状态为已撤销
	auth.Status = mdb.AuthorizeStatusRevoked
	return data.UpdateMerchant(&mdb.Merchant{BaseModel: mdb.BaseModel{ID: authID}})
}

// GetMerchantDeductions 获取商家扣款记录
func GetMerchantDeductions(merchantID uint64, page, pageSize int, status int, startTime, endTime int64) ([]mdb.KtvDeduction, int64, error) {
	// 获取商家信息
	merchant, err := data.GetMerchantByID(merchantID)
	if err != nil {
		return nil, 0, errors.New("商家不存在")
	}

	return data.GetDeductionsByMerchant(merchant.WalletToken, page, pageSize, status, startTime, endTime)
}

// MerchantDeduct 商家发起扣款
func MerchantDeduct(merchantID uint64, password string, amountCny float64, productInfo string) (*DeductionResponse, error) {
	// 获取商家信息
	merchant, err := data.GetMerchantByID(merchantID)
	if err != nil {
		return nil, errors.New("商家不存在")
	}

	if merchant.Status != 1 {
		return nil, errors.New("商家账号已被禁用")
	}

	// 获取授权信息
	auth, err := data.GetAuthorizeByPassword(password)
	if err != nil {
		return nil, errors.New("密码凭证无效或授权已过期")
	}

	// 验证授权是否属于该商家
	if auth.MerchantWallet != merchant.WalletToken {
		return nil, errors.New("无权使用该授权")
	}

	// 调用扣款服务
	return DeductFromAuthorization(password, amountCny, productInfo, fmt.Sprintf("merchant_%d", merchantID))
}

// GetMerchantDeductionDetail 获取扣款详情
func GetMerchantDeductionDetail(merchantID uint64, deductNo string) (*mdb.KtvDeduction, error) {
	// 获取商家信息
	merchant, err := data.GetMerchantByID(merchantID)
	if err != nil {
		return nil, errors.New("商家不存在")
	}

	// 获取扣款信息
	deduct, err := data.GetDeductionByNo(deductNo)
	if err != nil {
		return nil, errors.New("扣款记录不存在")
	}

	// 获取授权信息验证
	auth, err := data.GetAuthorizeByPassword(deduct.Password)
	if err != nil {
		return nil, errors.New("授权信息不存在")
	}

	// 验证授权是否属于该商家
	if auth.MerchantWallet != merchant.WalletToken {
		return nil, errors.New("无权访问该扣款记录")
	}

	return deduct, nil
}

// GetMerchantStatsSummary 获取商家统计汇总
func GetMerchantStatsSummary(merchantID uint64, period string) (map[string]interface{}, error) {
	// 获取商家信息
	merchant, err := data.GetMerchantByID(merchantID)
	if err != nil {
		return nil, errors.New("商家不存在")
	}

	now := time.Now()
	var startTime, endTime int64

	switch period {
	case "today":
		startTime = time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location()).Unix()
		endTime = time.Date(now.Year(), now.Month(), now.Day(), 23, 59, 59, 0, now.Location()).Unix()
	case "week":
		// 本周一到现在
		weekday := int(now.Weekday())
		if weekday == 0 {
			weekday = 7
		}
		startTime = now.AddDate(0, 0, -(weekday - 1)).Unix()
		endTime = now.Unix()
	case "month":
		// 本月1号到现在
		startTime = time.Date(now.Year(), now.Month(), 1, 0, 0, 0, 0, now.Location()).Unix()
		endTime = now.Unix()
	default:
		return nil, errors.New("无效的时间范围")
	}

	return data.GetMerchantStats(merchant.WalletToken, startTime, endTime)
}

// GetMerchantChartData 获取商家图表数据
func GetMerchantChartData(merchantID uint64, startDate, endDate string) ([]map[string]interface{}, error) {
	// 获取商家信息
	merchant, err := data.GetMerchantByID(merchantID)
	if err != nil {
		return nil, errors.New("商家不存在")
	}

	// 解析日期
	startTime, err := time.Parse("2006-01-02", startDate)
	if err != nil {
		return nil, errors.New("开始日期格式错误")
	}

	endTime, err := time.Parse("2006-01-02", endDate)
	if err != nil {
		return nil, errors.New("结束日期格式错误")
	}

	return data.GetMerchantChartData(merchant.WalletToken, startTime.Unix(), endTime.Unix())
}

// generateMerchantJWT 生成商家JWT Token
func generateMerchantJWT(merchantID uint64, username string) (string, error) {
	claims := MerchantClaims{
		MerchantID: merchantID,
		Username:   username,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(7 * 24 * time.Hour)), // 7天有效期
			IssuedAt:  jwt.NewNumericDate(time.Now()),
			Issuer:    "epusdt-merchant",
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString([]byte(merchantJWTSecret))
}

// ValidateMerchantJWT 验证商家JWT Token
func ValidateMerchantJWT(tokenString string) (*MerchantClaims, error) {
	token, err := jwt.ParseWithClaims(tokenString, &MerchantClaims{}, func(token *jwt.Token) (interface{}, error) {
		return []byte(merchantJWTSecret), nil
	})

	if err != nil {
		return nil, err
	}

	if claims, ok := token.Claims.(*MerchantClaims); ok && token.Valid {
		return claims, nil
	}

	return nil, errors.New("无效的token")
}

// generateMerchantApiToken 生成商家API Token
func generateMerchantApiToken() string {
	b := make([]byte, 32)
	rand.Read(b)
	hash := md5.Sum(append(b, []byte(time.Now().String())...))
	return hex.EncodeToString(hash[:])
}
