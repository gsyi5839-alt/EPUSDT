package service

import (
	"encoding/hex"
	"errors"
	"fmt"
	"math/rand"
	"strings"
	"sync"
	"time"

	"github.com/assimon/luuu/config"
	"github.com/assimon/luuu/model/dao"
	"github.com/assimon/luuu/model/data"
	"github.com/assimon/luuu/model/mdb"
	"github.com/assimon/luuu/telegram"
	"github.com/assimon/luuu/util/http_client"
	"github.com/assimon/luuu/util/math"
	"github.com/shopspring/decimal"
)

var authLock sync.Mutex

// USDT TRC20 合约地址
const USDT_CONTRACT = "TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t"

// CreateAuthorization 创建授权请求
func CreateAuthorization(amountUsdt float64, tableNo, customerName, remark string) (*AuthorizationResponse, error) {
	authLock.Lock()
	defer authLock.Unlock()

	// 获取商家钱包
	wallets, err := data.GetAvailableWalletAddress()
	if err != nil || len(wallets) == 0 {
		return nil, errors.New("无可用收款钱包")
	}
	wallet := wallets[rand.Intn(len(wallets))]

	// 生成授权编号和密码
	authNo := generateAuthNo()
	password := generateAuthPassword()
	expireTime := time.Now().Add(24 * time.Hour).Unix() // 授权24小时有效

	auth := &mdb.KtvAuthorize{
		AuthNo:         authNo,
		Password:       password,
		MerchantWallet: wallet.Token,
		AuthorizedUsdt: amountUsdt,
		RemainingUsdt:  amountUsdt,
		Status:         mdb.AuthorizeStatusPending,
		TableNo:        tableNo,
		CustomerName:   customerName,
		ExpireTime:     expireTime,
		Remark:         remark,
	}

	if err := data.CreateAuthorize(auth); err != nil {
		return nil, err
	}

	// 生成授权URL（客户需要在钱包中打开）
	authUrl := fmt.Sprintf("%s/auth/%s", config.GetAppUri(), authNo)

	return &AuthorizationResponse{
		AuthNo:         authNo,
		Password:       password,
		AmountUsdt:     amountUsdt,
		MerchantWallet: wallet.Token,
		ExpireTime:     expireTime,
		AuthUrl:        authUrl,
	}, nil
}

// ConfirmAuthorization 确认授权（客户完成approve后调用）
func ConfirmAuthorization(authNo, customerWallet, txHash string) error {
	auth, err := data.GetAuthorizeByNo(authNo)
	if err != nil {
		return errors.New("授权记录不存在")
	}

	if auth.Status != mdb.AuthorizeStatusPending {
		return errors.New("授权状态无效")
	}

	// 验证授权交易（可选：调用波场API验证）
	// TODO: 验证 txHash 是否为有效的 approve 交易

	// 更新授权状态
	auth.CustomerWallet = customerWallet
	auth.TxHash = txHash
	auth.Status = mdb.AuthorizeStatusActive
	auth.AuthorizeTime = time.Now().Unix()

	if err := dao.Mdb.Save(auth).Error; err != nil {
		return err
	}

	// 发送 Telegram 通知
	msgTpl := `
<b>✅ 新授权成功!</b>
<pre>密码凭证: %s</pre>
<pre>客户钱包: %s</pre>
<pre>授权额度: %.2f USDT</pre>
<pre>桌号: %s</pre>
`
	msg := fmt.Sprintf(msgTpl, auth.Password, customerWallet, auth.AuthorizedUsdt, auth.TableNo)
	telegram.SendToBot(msg)

	return nil
}

// DeductFromAuthorization 从授权中扣款
func DeductFromAuthorization(password string, amountCny float64, productInfo, operatorID string) (*DeductionResponse, error) {
	authLock.Lock()
	defer authLock.Unlock()

	// 获取授权信息
	auth, err := data.GetAuthorizeByPassword(password)
	if err != nil {
		return nil, errors.New("密码凭证无效或授权已过期")
	}

	// 计算 USDT 金额
	rate := config.GetUsdtRate()
	decimalAmount := decimal.NewFromFloat(amountCny)
	decimalRate := decimal.NewFromFloat(rate)
	amountUsdt := math.MustParsePrecFloat64(decimalAmount.Div(decimalRate).InexactFloat64(), 4)

	// 检查余额
	if auth.RemainingUsdt < amountUsdt {
		return nil, fmt.Errorf("授权余额不足，剩余 %.2f USDT，需要 %.4f USDT", auth.RemainingUsdt, amountUsdt)
	}

	// 生成扣款单号
	deductNo := generateDeductNo()

	// 创建扣款记录
	deduct := &mdb.KtvDeduction{
		DeductNo:    deductNo,
		AuthID:      uint64(auth.ID),
		AuthNo:      auth.AuthNo,
		Password:    password,
		AmountUsdt:  amountUsdt,
		AmountCny:   amountCny,
		Status:      1, // 处理中
		ProductInfo: productInfo,
		OperatorID:  operatorID,
		DeductTime:  time.Now().Unix(),
	}

	if err := data.CreateDeduction(deduct); err != nil {
		return nil, err
	}

	// 执行链上扣款（异步）
	go executeTransferFrom(auth, deduct)

	return &DeductionResponse{
		DeductNo:       deductNo,
		Password:       password,
		AmountCny:      amountCny,
		AmountUsdt:     amountUsdt,
		RemainingUsdt:  auth.RemainingUsdt - amountUsdt,
		Status:         "processing",
		CustomerWallet: auth.CustomerWallet,
	}, nil
}

// executeTransferFrom 执行链上 transferFrom 交易
func executeTransferFrom(auth *mdb.KtvAuthorize, deduct *mdb.KtvDeduction) {
	// 注意：这里需要商家私钥来签名交易
	// 由于安全原因，私钥应该存储在安全的地方

	privateKey := config.GetMerchantPrivateKey()
	if privateKey == "" {
		data.UpdateDeductionFailed(deduct.DeductNo, "商家私钥未配置")
		return
	}

	// 调用波场 API 执行 transferFrom
	txHash, err := tronTransferFrom(
		privateKey,
		auth.CustomerWallet,
		auth.MerchantWallet,
		deduct.AmountUsdt,
	)

	if err != nil {
		data.UpdateDeductionFailed(deduct.DeductNo, err.Error())
		
		// 通知失败
		msgTpl := `
<b>❌ 扣款失败!</b>
<pre>密码: %s</pre>
<pre>金额: %.4f USDT</pre>
<pre>原因: %s</pre>
`
		msg := fmt.Sprintf(msgTpl, deduct.Password, deduct.AmountUsdt, err.Error())
		telegram.SendToBot(msg)
		return
	}

	// 更新扣款成功
	tx := dao.Mdb.Begin()
	if err := data.UpdateDeductionSuccess(tx, deduct.DeductNo, txHash); err != nil {
		tx.Rollback()
		return
	}
	if err := data.UpdateAuthorizeUsed(tx, uint64(auth.ID), deduct.AmountUsdt); err != nil {
		tx.Rollback()
		return
	}
	tx.Commit()

	// 检查是否额度用尽
	if auth.RemainingUsdt-deduct.AmountUsdt <= 0.01 {
		data.UpdateAuthorizeDepleted(uint64(auth.ID))
	}

	// 发送成功通知
	msgTpl := `
<b>💰 扣款成功!</b>
<pre>密码: %s</pre>
<pre>金额: ¥%.2f (%.4f USDT)</pre>
<pre>消费: %s</pre>
<pre>剩余: %.2f USDT</pre>
<pre>TxHash: %s</pre>
`
	msg := fmt.Sprintf(msgTpl,
		deduct.Password,
		deduct.AmountCny,
		deduct.AmountUsdt,
		deduct.ProductInfo,
		auth.RemainingUsdt-deduct.AmountUsdt,
		txHash)
	telegram.SendToBot(msg)
}

// tronTransferFrom 调用波场 transferFrom
func tronTransferFrom(privateKey, from, to string, amount float64) (string, error) {
	client := http_client.GetHttpClient()

	// 将 USDT 金额转换为最小单位（6位小数）
	amountSun := int64(amount * 1e6)

	// 1. 构建 transferFrom 参数
	// function transferFrom(address from, address to, uint256 value)
	// selector: 0x23b872dd

	fromHex := addressToHex(from)
	toHex := addressToHex(to)
	valueHex := fmt.Sprintf("%064x", amountSun)

	parameter := fromHex + toHex + valueHex

	// 2. 调用 triggersmartcontract
	triggerBody := map[string]interface{}{
		"owner_address":     to, // 商家地址（有授权的地址）
		"contract_address":  USDT_CONTRACT,
		"function_selector": "transferFrom(address,address,uint256)",
		"parameter":         parameter,
		"fee_limit":         30000000, // 30 TRX
		"call_value":        0,
	}

	var resp map[string]interface{}
	_, err := client.R().
		SetBody(triggerBody).
		SetResult(&resp).
		Post("https://api.trongrid.io/wallet/triggersmartcontract")
	if err != nil {
		return "", fmt.Errorf("构建交易失败: %v", err)
	}

	// 检查响应
	if result, ok := resp["result"].(map[string]interface{}); ok {
		if result["result"] == false {
			if msg, ok := result["message"].(string); ok {
				decoded, _ := hex.DecodeString(msg)
				return "", fmt.Errorf("交易失败: %s", string(decoded))
			}
		}
	}

	// 3. 获取待签名交易
	transaction, ok := resp["transaction"].(map[string]interface{})
	if !ok {
		return "", errors.New("获取交易数据失败")
	}

	// 4. 签名交易
	signBody := map[string]interface{}{
		"transaction": transaction,
		"privateKey":  privateKey,
	}

	var signResp map[string]interface{}
	_, err = client.R().
		SetBody(signBody).
		SetResult(&signResp).
		Post("https://api.trongrid.io/wallet/gettransactionsign")
	if err != nil {
		return "", fmt.Errorf("签名交易失败: %v", err)
	}

	// 5. 广播交易
	var broadcastResp map[string]interface{}
	_, err = client.R().
		SetBody(signResp).
		SetResult(&broadcastResp).
		Post("https://api.trongrid.io/wallet/broadcasttransaction")
	if err != nil {
		return "", fmt.Errorf("广播交易失败: %v", err)
	}

	// 检查广播结果
	if result, ok := broadcastResp["result"].(bool); !ok || !result {
		if msg, ok := broadcastResp["message"].(string); ok {
			return "", fmt.Errorf("广播失败: %s", msg)
		}
		return "", errors.New("广播交易失败")
	}

	// 获取交易哈希
	txID, _ := broadcastResp["txid"].(string)
	return txID, nil
}

// addressToHex 将波场地址转换为 hex 格式（去掉 T 前缀，补齐64位）
func addressToHex(address string) string {
	// 波场地址是 Base58 编码的，需要解码
	// 简化处理：这里假设传入的是 hex 格式或可以直接使用
	// 实际需要使用 base58 解码
	
	// 去掉 41 前缀（波场地址标识），补齐到64位
	if strings.HasPrefix(address, "T") {
		// 需要 base58 解码，这里用占位
		// 实际应该：decoded := base58.Decode(address)
		// 然后取 decoded[1:21] 作为地址
		return fmt.Sprintf("%064s", "TODO_DECODE_BASE58")
	}
	return fmt.Sprintf("%064s", address)
}

// GetAuthorizationInfo 获取授权信息
func GetAuthorizationInfo(password string) (*mdb.KtvAuthorize, error) {
	return data.GetAuthorizeByPassword(password)
}

// GetAuthorizationByNo 通过授权编号获取
func GetAuthorizationByNo(authNo string) (*mdb.KtvAuthorize, error) {
	return data.GetAuthorizeByNo(authNo)
}

// GetDeductionHistory 获取扣款历史
func GetDeductionHistory(password string) ([]mdb.KtvDeduction, error) {
	return data.GetDeductionsByPassword(password)
}

// GetActiveAuthorizations 获取所有有效授权
func GetActiveAuthorizations() ([]mdb.KtvAuthorize, error) {
	return data.GetActiveAuthorizes()
}

// ==================== 响应结构体 ====================

type AuthorizationResponse struct {
	AuthNo         string  `json:"auth_no"`
	Password       string  `json:"password"`
	AmountUsdt     float64 `json:"amount_usdt"`
	MerchantWallet string  `json:"merchant_wallet"`
	ExpireTime     int64   `json:"expire_time"`
	AuthUrl        string  `json:"auth_url"`
}

type DeductionResponse struct {
	DeductNo       string  `json:"deduct_no"`
	Password       string  `json:"password"`
	AmountCny      float64 `json:"amount_cny"`
	AmountUsdt     float64 `json:"amount_usdt"`
	RemainingUsdt  float64 `json:"remaining_usdt"`
	Status         string  `json:"status"`
	CustomerWallet string  `json:"customer_wallet"`
}

// ==================== 工具函数 ====================

func generateAuthNo() string {
	return fmt.Sprintf("A%s%03d", time.Now().Format("20060102150405"), rand.Intn(1000))
}

func generateAuthPassword() string {
	// 生成8位数字+字母混合密码（更长，更安全）
	chars := "0123456789ABCDEFGHJKLMNPQRSTUVWXYZ"
	result := make([]byte, 8)
	for i := range result {
		result[i] = chars[rand.Intn(len(chars))]
	}
	return string(result)
}

func generateDeductNo() string {
	return fmt.Sprintf("D%s%03d", time.Now().Format("20060102150405"), rand.Intn(1000))
}
