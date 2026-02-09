package service

import (
	"errors"
	"fmt"
	"math/big"
	"math/rand"
	"time"

	"github.com/assimon/luuu/config"
	"github.com/assimon/luuu/model/data"
	"github.com/assimon/luuu/model/mdb"
	"github.com/assimon/luuu/util/chain"
)

// QRCodeFormat 二维码格式类型
type QRCodeFormat string

const (
	QRCodeFormatEIP681        QRCodeFormat = "eip681"        // EIP-681标准（EVM链）
	QRCodeFormatWeb           QRCodeFormat = "web"           // 网页跳转（TRON链）
	QRCodeFormatWalletConnect QRCodeFormat = "walletconnect" // WalletConnect（备选）
)

// AuthorizationQRCode 授权二维码数据
type AuthorizationQRCode struct {
	Format      QRCodeFormat `json:"format"`       // 二维码格式
	Content     string       `json:"content"`      // 二维码内容
	ChainID     int64        `json:"chain_id"`     // 链ID
	ChainName   string       `json:"chain_name"`   // 链名称
	AuthNo      string       `json:"auth_no"`      // 授权编号
	DisplayURL  string       `json:"display_url"`  // 展示URL（用于网页显示）
	Description string       `json:"description"`  // 使用说明
}

// GenerateAuthorizationQRCode 生成授权二维码
func GenerateAuthorizationQRCode(
	authNo string,
	chainName string,
	merchantWallet string,
	amountUsdt float64,
) (*AuthorizationQRCode, error) {

	chainName = chain.NormalizeChain(chainName)

	// EVM链：使用EIP-681标准
	if chain.IsEvmChain(chainName) {
		return generateEIP681QRCode(authNo, chainName, merchantWallet, amountUsdt)
	}

	// TRON链：使用网页跳转
	if chain.IsTronChain(chainName) {
		return generateTronWebQRCode(authNo, merchantWallet, amountUsdt)
	}

	return nil, errors.New("不支持的链")
}

// generateEIP681QRCode 生成EIP-681格式二维码（EVM链）
func generateEIP681QRCode(
	authNo string,
	chainName string,
	merchantWallet string,
	amountUsdt float64,
) (*AuthorizationQRCode, error) {

	// 获取链配置
	var chainID int64
	var tokenAddress string
	var decimals int

	switch chain.NormalizeChain(chainName) {
	case chain.ChainBsc:
		chainID = 56
		tokenAddress = config.GetBscUsdtContract()
		decimals = config.GetBscUsdtDecimals()
	case chain.ChainEvm:
		chainID = 1
		tokenAddress = config.GetEthUsdtContract()
		decimals = config.GetEthUsdtDecimals()
	case chain.ChainPolygon:
		chainID = 137
		tokenAddress = config.GetPolygonUsdtContract()
		decimals = config.GetPolygonUsdtDecimals()
	default:
		return nil, errors.New("不支持的EVM链")
	}

	if tokenAddress == "" {
		return nil, errors.New("USDT合约地址未配置")
	}

	// 转换金额为最小单位
	amountWei := new(big.Float).Mul(
		big.NewFloat(amountUsdt),
		new(big.Float).SetInt(new(big.Int).Exp(big.NewInt(10), big.NewInt(int64(decimals)), nil)),
	)
	amountInt, _ := amountWei.Int(nil)

	// EIP-681格式
	// ethereum:<contract>@<chainId>/approve?address=<spender>&uint256=<amount>
	qrContent := fmt.Sprintf(
		"ethereum:%s@%d/approve?address=%s&uint256=%s",
		tokenAddress,
		chainID,
		merchantWallet,
		amountInt.String(),
	)

	// 生成展示URL（备用方案：如果钱包不支持EIP-681，引导到网页）
	displayURL := fmt.Sprintf("%s/auth/evm/%s", config.GetAppUri(), authNo)

	description := fmt.Sprintf(
		"请使用支持EIP-681的钱包扫描（MetaMask、Trust Wallet、imToken等）。\n"+
			"如果扫描后无反应，请访问：%s",
		displayURL,
	)

	return &AuthorizationQRCode{
		Format:      QRCodeFormatEIP681,
		Content:     qrContent,
		ChainID:     chainID,
		ChainName:   chainName,
		AuthNo:      authNo,
		DisplayURL:  displayURL,
		Description: description,
	}, nil
}

// generateTronWebQRCode 生成TRON网页跳转二维码
func generateTronWebQRCode(
	authNo string,
	merchantWallet string,
	amountUsdt float64,
) (*AuthorizationQRCode, error) {

	// 生成授权页面URL
	baseURL := config.GetAppUri()
	qrContent := fmt.Sprintf("%s/auth/trc20/%s", baseURL, authNo)

	description := "请使用TronLink、Trust Wallet等TRON钱包扫描二维码，" +
		"或在移动设备浏览器中打开此链接完成授权。"

	return &AuthorizationQRCode{
		Format:      QRCodeFormatWeb,
		Content:     qrContent,
		ChainID:     0, // TRON没有EVM ChainID
		ChainName:   chain.ChainTron,
		AuthNo:      authNo,
		DisplayURL:  qrContent,
		Description: description,
	}, nil
}

// CreateAuthorizationWithQRCode 创建授权并生成二维码
func CreateAuthorizationWithQRCode(
	amountUsdt float64,
	tableNo string,
	customerName string,
	remark string,
	chainName string,
) (*AuthorizationResponse, *AuthorizationQRCode, error) {

	chainName = chain.NormalizeChain(chainName)
	if chainName == "" {
		chainName = chain.ChainTron
	}

	if !chain.IsSupported(chainName) {
		return nil, nil, errors.New("不支持的链")
	}

	// 获取商家钱包
	wallets, err := data.GetAvailableWalletAddressByChain(chainName)
	if err != nil || len(wallets) == 0 {
		return nil, nil, errors.New("无可用收款钱包")
	}

	// 如果是需要私钥的链，过滤有私钥配置的钱包
	if chain.IsTronChain(chainName) || chain.IsEvmChain(chainName) {
		wallets = filterWalletsWithPrivateKey(chainName, wallets)
		if len(wallets) == 0 {
			return nil, nil, errors.New("无可用收款钱包（缺少私钥配置）")
		}
	}

	wallet := wallets[rand.Intn(len(wallets))]

	// 生成授权编号
	authNo := generateAuthNo()
	expireTime := time.Now().Add(24 * time.Hour).Unix()

	// 创建授权记录
	auth := &mdb.KtvAuthorize{
		AuthNo:         authNo,
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
		return nil, nil, err
	}

	// 生成二维码
	qrCode, err := GenerateAuthorizationQRCode(authNo, chainName, wallet.Token, amountUsdt)
	if err != nil {
		return nil, nil, err
	}

	// 构建响应
	response := &AuthorizationResponse{
		AuthNo:         authNo,
		AmountUsdt:     amountUsdt,
		MerchantWallet: wallet.Token,
		ExpireTime:     expireTime,
		AuthUrl:        qrCode.DisplayURL,
		Chain:          chainName,
		QRCodeContent:  qrCode.Content,
		QRCodeFormat:   string(qrCode.Format),
	}

	return response, qrCode, nil
}
