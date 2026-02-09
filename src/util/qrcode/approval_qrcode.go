package qrcode

import (
	"encoding/base64"
	"fmt"
	"math/big"

	"github.com/assimon/luuu/config"
	"github.com/assimon/luuu/util/chain"
	"github.com/skip2/go-qrcode"
)

// QRCodeData 二维码数据
type QRCodeData struct {
	Format      string `json:"format"`        // "eip681", "tron_web", "plain"
	URI         string `json:"uri"`           // 编码进QR码的内容
	FallbackURL string `json:"fallback_url"`  // Web回退URL
	ImageBase64 string `json:"image_base64"`  // Base64 PNG图片
	Description string `json:"description"`   // 用户引导说明
}

// GenerateApprovalQRCode 生成授权二维码（兼容主流钱包App）
func GenerateApprovalQRCode(chainName, merchantWallet string, amountUsdt float64, authNo string) (*QRCodeData, error) {
	chainName = chain.NormalizeChain(chainName)
	info := chain.GetChainInfo(chainName)
	if info == nil {
		return nil, fmt.Errorf("不支持的链: %s", chainName)
	}

	var qrData *QRCodeData
	var err error

	if info.IsEVM {
		qrData, err = generateEVMApprovalQR(info, merchantWallet, amountUsdt)
	} else if info.IsTron {
		qrData, err = generateTronApprovalQR(merchantWallet, amountUsdt, authNo)
	} else {
		return nil, fmt.Errorf("不支持的链: %s", chainName)
	}

	if err != nil {
		return nil, err
	}

	// 生成二维码图片（PNG，256x256）
	qrCode, err := qrcode.Encode(qrData.URI, qrcode.Medium, 256)
	if err != nil {
		return nil, fmt.Errorf("生成二维码失败: %v", err)
	}
	qrData.ImageBase64 = base64.StdEncoding.EncodeToString(qrCode)

	return qrData, nil
}

// generateEVMApprovalQR 生成 EIP-681 格式二维码
// 兼容: MetaMask, Trust Wallet, imToken, TokenPocket, Coinbase Wallet
// 格式: ethereum:<contract>@<chainId>/approve?address=<spender>&uint256=<amount>
func generateEVMApprovalQR(info *chain.ChainInfo, merchantWallet string, amountUsdt float64) (*QRCodeData, error) {
	// 使用 big.Int 精确计算金额，避免浮点误差
	amountWei := UsdtToWei(amountUsdt, info.Decimals)

	// 构建 EIP-681 URI
	uri := fmt.Sprintf("ethereum:%s@%d/approve?address=%s&uint256=%s",
		info.USDTContract,
		info.ChainID,
		merchantWallet,
		amountWei.String(),
	)

	return &QRCodeData{
		Format:      "eip681",
		URI:         uri,
		FallbackURL: "",
		Description: fmt.Sprintf("请使用钱包App扫描此二维码，授权 %.4f USDT (%s链)", amountUsdt, info.DisplayName),
	}, nil
}

// generateTronApprovalQR 生成 TRON 授权二维码
// TronLink不支持EIP-681，使用Web页面引导客户在TronLink内置浏览器中完成授权
func generateTronApprovalQR(merchantWallet string, amountUsdt float64, authNo string) (*QRCodeData, error) {
	appURI := config.GetAppUri()
	if appURI == "" {
		return nil, fmt.Errorf("未配置 app_uri，无法生成TRON授权二维码")
	}

	// QR码内容为授权页面URL，客户在TronLink浏览器中打开即可触发approve
	uri := fmt.Sprintf("%s/auth/tron/%s", appURI, authNo)

	return &QRCodeData{
		Format:      "tron_web",
		URI:         uri,
		FallbackURL: uri,
		Description: fmt.Sprintf("请使用TronLink扫描此二维码，授权 %.4f USDT (TRON链)", amountUsdt),
	}, nil
}

// UsdtToWei 将 USDT 金额转换为链上最小单位（精确计算）
func UsdtToWei(amountUsdt float64, decimals int) *big.Int {
	// 将浮点数转为字符串避免精度丢失
	// 先乘以一个大数来保留小数精度，再用big.Int运算
	multiplier := new(big.Int).Exp(big.NewInt(10), big.NewInt(int64(decimals)), nil)

	// 用 big.Float 做中间计算
	amountFloat := new(big.Float).SetFloat64(amountUsdt)
	multiplierFloat := new(big.Float).SetInt(multiplier)
	result := new(big.Float).Mul(amountFloat, multiplierFloat)

	// 截断为整数
	amountWei, _ := result.Int(new(big.Int))
	return amountWei
}

// WeiToUsdt 将链上最小单位转换为 USDT 金额
func WeiToUsdt(amountWei *big.Int, decimals int) float64 {
	divisor := new(big.Int).Exp(big.NewInt(10), big.NewInt(int64(decimals)), nil)
	result := new(big.Float).Quo(
		new(big.Float).SetInt(amountWei),
		new(big.Float).SetInt(divisor),
	)
	f, _ := result.Float64()
	return f
}

// GenerateQRCodeImage 生成纯二维码图片（返回base64编码的PNG）
func GenerateQRCodeImage(content string, size int) (string, error) {
	if size <= 0 {
		size = 256
	}
	qrCode, err := qrcode.Encode(content, qrcode.Medium, size)
	if err != nil {
		return "", err
	}
	return base64.StdEncoding.EncodeToString(qrCode), nil
}
