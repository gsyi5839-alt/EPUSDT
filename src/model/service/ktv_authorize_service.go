package service

import (
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"math/big"
	"math/rand"
	"sync"
	"time"

	"github.com/assimon/luuu/config"
	"github.com/assimon/luuu/model/dao"
	"github.com/assimon/luuu/model/data"
	"github.com/assimon/luuu/model/mdb"
	"github.com/assimon/luuu/telegram"
	"github.com/assimon/luuu/util/chain"
	"github.com/assimon/luuu/util/evm"
	"github.com/assimon/luuu/util/http_client"
	"github.com/assimon/luuu/util/log"
	"github.com/assimon/luuu/util/math"
	"github.com/assimon/luuu/util/tron"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/shopspring/decimal"
)

var authLock sync.Mutex

// USDT TRC20 合约地址
const USDT_CONTRACT = "TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t"

// CreateAuthorization 创建授权请求
func CreateAuthorization(amountUsdt float64, tableNo, customerName, remark, chainName string) (*AuthorizationResponse, error) {
	authLock.Lock()
	defer authLock.Unlock()

	chainName = chain.NormalizeChain(chainName)
	if chainName == "" {
		chainName = chain.ChainTron
	}
	if !chain.IsSupported(chainName) {
		return nil, errors.New("不支持的链")
	}

	// 获取商家钱包
	wallets, err := data.GetAvailableWalletAddressByChain(chainName)
	if err != nil || len(wallets) == 0 {
		return nil, errors.New("无可用收款钱包")
	}
	wallets = filterWalletsWithPrivateKey(chainName, wallets)
	if len(wallets) == 0 {
		return nil, errors.New("无可用收款钱包（缺少私钥配置）")
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
		Chain:          chainName,
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
		Chain:          chainName,
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

// ConfirmAuthorizationAuto 自动确认授权（基于 allowance 校验）
func ConfirmAuthorizationAuto(authNo, customerWallet string) (*AuthorizationAutoStatus, error) {
	auth, err := data.GetAuthorizeByNo(authNo)
	if err != nil {
		return nil, errors.New("授权记录不存在")
	}

	if time.Now().Unix() > auth.ExpireTime {
		return nil, errors.New("授权已过期")
	}

	if auth.Status == mdb.AuthorizeStatusActive {
		return &AuthorizationAutoStatus{
			Status:         "active",
			AuthorizedUsdt: auth.AuthorizedUsdt,
			AllowanceUsdt:  auth.AuthorizedUsdt,
		}, nil
	}

	if chain.IsTronChain(auth.Chain) {
		if !tron.IsValidTronAddress(customerWallet) {
			return nil, errors.New("客户钱包地址无效")
		}
		allowance, err := getTrc20Allowance(customerWallet, auth.MerchantWallet)
		if err != nil {
			return nil, err
		}

		if allowance < auth.AuthorizedUsdt {
			return &AuthorizationAutoStatus{
				Status:         "pending",
				AuthorizedUsdt: auth.AuthorizedUsdt,
				AllowanceUsdt:  allowance,
			}, nil
		}

		// 更新授权状态
		auth.CustomerWallet = customerWallet
		auth.Status = mdb.AuthorizeStatusActive
		auth.AuthorizeTime = time.Now().Unix()
		if err := dao.Mdb.Save(auth).Error; err != nil {
			return nil, err
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

		return &AuthorizationAutoStatus{
			Status:         "active",
			AuthorizedUsdt: auth.AuthorizedUsdt,
			AllowanceUsdt:  allowance,
		}, nil
	}

	if !chain.IsEvmChain(auth.Chain) {
		return nil, errors.New("不支持的链")
	}

	allowance, err := evm.GetAllowance(auth.Chain, customerWallet, auth.MerchantWallet)
	if err != nil {
		return nil, err
	}

	if allowance < auth.AuthorizedUsdt {
		return &AuthorizationAutoStatus{
			Status:         "pending",
			AuthorizedUsdt: auth.AuthorizedUsdt,
			AllowanceUsdt:  allowance,
		}, nil
	}

	// 更新授权状态
	auth.CustomerWallet = customerWallet
	auth.Status = mdb.AuthorizeStatusActive
	auth.AuthorizeTime = time.Now().Unix()
	if err := dao.Mdb.Save(auth).Error; err != nil {
		return nil, err
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

	return &AuthorizationAutoStatus{
		Status:         "active",
		AuthorizedUsdt: auth.AuthorizedUsdt,
		AllowanceUsdt:  allowance,
	}, nil
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
	if chain.IsEvmChain(auth.Chain) {
		executeEvmTransferFrom(auth, deduct)
		return
	}
	// 注意：这里需要商家私钥来签名交易
	// 由于安全原因，私钥应该存储在安全的地方

	privateKey := config.GetMerchantPrivateKeyForWallet(auth.MerchantWallet)
	if privateKey == "" {
		data.UpdateDeductionFailed(deduct.DeductNo, "商家私钥未配置")
		return
	}

	// 资金转入公司钱包（中转）
	companyWallet := config.GetCompanyWallet()
	targetWallet := companyWallet
	if targetWallet == "" {
		targetWallet = auth.MerchantWallet
	}

	// 调用波场 API 执行 transferFrom
	txHash, err := tronTransferFrom(
		privateKey,
		auth.CustomerWallet,
		targetWallet,
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
	// 累加商家余额
	merchantID, _ := data.GetMerchantIDByWallet(auth.MerchantWallet)
	if merchantID > 0 {
		_ = data.AddMerchantBalance(tx, merchantID, deduct.AmountUsdt)
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

func executeEvmTransferFrom(auth *mdb.KtvAuthorize, deduct *mdb.KtvDeduction) {
	privateKey := config.GetMerchantPrivateKeyForWallet(auth.MerchantWallet)
	if privateKey == "" {
		data.UpdateDeductionFailed(deduct.DeductNo, "商家私钥未配置")
		return
	}

	// 资金转入公司钱包（中转）
	companyWallet := config.GetCompanyWallet()
	evmTarget := companyWallet
	if evmTarget == "" {
		evmTarget = auth.MerchantWallet
	}

	txHash, err := evm.TransferFrom(auth.Chain, privateKey, auth.CustomerWallet, evmTarget, deduct.AmountUsdt)
	if err != nil {
		data.UpdateDeductionFailed(deduct.DeductNo, err.Error())
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

	tx := dao.Mdb.Begin()
	if err := data.UpdateDeductionSuccess(tx, deduct.DeductNo, txHash); err != nil {
		tx.Rollback()
		return
	}
	if err := data.UpdateAuthorizeUsed(tx, uint64(auth.ID), deduct.AmountUsdt); err != nil {
		tx.Rollback()
		return
	}
	// 累加商家余额
	merchantID, _ := data.GetMerchantIDByWallet(auth.MerchantWallet)
	if merchantID > 0 {
		_ = data.AddMerchantBalance(tx, merchantID, deduct.AmountUsdt)
	}
	tx.Commit()

	if auth.RemainingUsdt-deduct.AmountUsdt <= 0.01 {
		data.UpdateAuthorizeDepleted(uint64(auth.ID))
	}

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

func filterWalletsWithPrivateKey(chainName string, wallets []mdb.WalletAddress) []mdb.WalletAddress {
	chainName = chain.NormalizeChain(chainName)
	if !chain.IsTronChain(chainName) && !chain.IsEvmChain(chainName) {
		return wallets
	}
	if len(config.GetMerchantPrivateKeyForWallet("")) > 0 && !config.HasMerchantPrivateKeyMap() {
		return wallets
	}
	var out []mdb.WalletAddress
	for _, w := range wallets {
		if config.GetMerchantPrivateKeyForWallet(w.Token) != "" {
			out = append(out, w)
		}
	}
	return out
}

// tronTransferFrom 调用波场 transferFrom
// 安全修复: 私钥仅在本地签名，不再发送到第三方 API
func tronTransferFrom(privateKeyHex, from, to string, amount float64) (string, error) {
	client := http_client.GetHttpClient()

	// 将 USDT 金额转换为最小单位（6位小数）
	amountSun := int64(amount * 1e6)

	// 1. 构建 transferFrom 参数
	// function transferFrom(address from, address to, uint256 value)
	// selector: 0x23b872dd

	fromHex, err := tron.AddressToHex(from)
	if err != nil {
		return "", err
	}
	toHex, err := tron.AddressToHex(to)
	if err != nil {
		return "", err
	}
	valueHex := fmt.Sprintf("%064x", amountSun)

	parameter := fromHex + toHex + valueHex

	// 2. 调用 triggersmartcontract（仅构建未签名交易，不发送私钥）
	triggerBody := map[string]interface{}{
		"owner_address":     to, // 商家地址（有授权的地址）
		"contract_address":  USDT_CONTRACT,
		"function_selector": "transferFrom(address,address,uint256)",
		"parameter":         parameter,
		"fee_limit":         30000000, // 30 TRX
		"call_value":        0,
		"visible":           true,
	}

	var resp map[string]interface{}
	_, err = client.R().
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

	// 4. 本地签名交易（安全: 私钥不离开本地）
	txID, signature, err := tronLocalSign(transaction, privateKeyHex)
	if err != nil {
		return "", fmt.Errorf("本地签名失败: %v", err)
	}

	// 将签名添加到交易中
	transaction["signature"] = []string{signature}

	// 5. 广播已签名交易
	var broadcastResp map[string]interface{}
	_, err = client.R().
		SetBody(transaction).
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

	return txID, nil
}

// tronLocalSign 在本地对 TRON 交易进行签名
// 使用 secp256k1 + SHA256 完成签名，私钥不离开本地内存
func tronLocalSign(transaction map[string]interface{}, privateKeyHex string) (string, string, error) {
	// 获取交易的 txID（即 raw_data 的 SHA256 哈希）
	txID, ok := transaction["txID"].(string)
	if !ok || txID == "" {
		return "", "", errors.New("交易缺少 txID")
	}

	// 将 txID（hex）解码为字节
	txIDBytes, err := hex.DecodeString(txID)
	if err != nil {
		return "", "", fmt.Errorf("txID 解码失败: %v", err)
	}

	// 解析私钥
	privKey, err := crypto.HexToECDSA(privateKeyHex)
	if err != nil {
		return "", "", fmt.Errorf("私钥格式错误: %v", err)
	}

	// 使用 secp256k1 对 txID 哈希签名（TRON 使用 SHA256，txID 已经是 SHA256 哈希）
	// go-ethereum 的 crypto.Sign 对数据进行签名（数据应为32字节哈希）
	sig, err := crypto.Sign(txIDBytes, privKey)
	if err != nil {
		return "", "", fmt.Errorf("签名失败: %v", err)
	}

	// 记录签名成功（不记录任何敏感信息）
	log.Sugar.Infof("[tron] 交易本地签名成功, txID=%s", txID)

	return txID, hex.EncodeToString(sig), nil
}

// tronLocalSignRawData 备用方案: 从 raw_data_hex 计算 txID 并签名
// 用于验证 txID 的正确性
func tronLocalSignRawData(rawDataHex string, privateKeyHex string) (string, string, error) {
	rawBytes, err := hex.DecodeString(rawDataHex)
	if err != nil {
		return "", "", fmt.Errorf("raw_data_hex 解码失败: %v", err)
	}

	// TRON txID = SHA256(raw_data)
	hash := sha256.Sum256(rawBytes)
	txID := hex.EncodeToString(hash[:])

	privKey, err := crypto.HexToECDSA(privateKeyHex)
	if err != nil {
		return "", "", fmt.Errorf("私钥格式错误: %v", err)
	}

	sig, err := crypto.Sign(hash[:], privKey)
	if err != nil {
		return "", "", fmt.Errorf("签名失败: %v", err)
	}

	return txID, hex.EncodeToString(sig), nil
}

func getTrc20Allowance(owner, spender string) (float64, error) {
	ownerHex, err := tron.AddressToHex(owner)
	if err != nil {
		return 0, err
	}
	spenderHex, err := tron.AddressToHex(spender)
	if err != nil {
		return 0, err
	}

	parameter := ownerHex + spenderHex
	triggerBody := map[string]interface{}{
		"owner_address":     owner,
		"contract_address":  USDT_CONTRACT,
		"function_selector": "allowance(address,address)",
		"parameter":         parameter,
		"call_value":        0,
		"visible":           true,
	}

	client := http_client.GetHttpClient()
	var resp map[string]interface{}
	_, err = client.R().
		SetBody(triggerBody).
		SetResult(&resp).
		Post("https://api.trongrid.io/wallet/triggersmartcontract")
	if err != nil {
		return 0, fmt.Errorf("查询授权失败: %v", err)
	}

	if result, ok := resp["result"].(map[string]interface{}); ok {
		if result["result"] == false {
			if msg, ok := result["message"].(string); ok {
				decoded, _ := hex.DecodeString(msg)
				return 0, fmt.Errorf("查询授权失败: %s", string(decoded))
			}
		}
	}

	constantResult, ok := resp["constant_result"].([]interface{})
	if !ok || len(constantResult) == 0 {
		return 0, errors.New("查询授权失败: 无结果")
	}

	hexStr, ok := constantResult[0].(string)
	if !ok || hexStr == "" {
		return 0, errors.New("查询授权失败: 结果格式错误")
	}

	val := new(big.Int)
	val.SetString(hexStr, 16)
	amountSun := val.Int64()
	return float64(amountSun) / 1e6, nil
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
	Password       string  `json:"password,omitempty"`
	AmountUsdt     float64 `json:"amount_usdt"`
	MerchantWallet string  `json:"merchant_wallet"`
	ExpireTime     int64   `json:"expire_time"`
	AuthUrl        string  `json:"auth_url"`
	Chain          string  `json:"chain"`
	QRCodeContent  string  `json:"qr_code_content,omitempty"`  // 二维码内容（可选）
	QRCodeFormat   string  `json:"qr_code_format,omitempty"`   // 二维码格式（可选）
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

type AuthorizationAutoStatus struct {
	Status         string  `json:"status"`
	AuthorizedUsdt float64 `json:"authorized_usdt"`
	AllowanceUsdt  float64 `json:"allowance_usdt"`
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
