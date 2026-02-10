package config

import (
	"fmt"
	"net/url"
	"os"
	"strings"
	"time"

	"github.com/spf13/viper"
)

var (
	AppDebug    bool
	MysqlDns    string
	RuntimePath string
	LogSavePath string
	StaticPath  string
	TgBotToken  string
	TgProxy     string
	TgManage    int64
	UsdtRate    float64
	BscRpcUrls  []string
	EthRpcUrls  []string
	PolygonRpcUrls []string
	BscScanApiKey  string
	EthUsdtContract string
	BscUsdtContract string
	PolygonUsdtContract string
	EthUsdtDecimals int
	BscUsdtDecimals int
	PolygonUsdtDecimals int
	MerchantPrivateKeyMap map[string]string
	AdminJwtSecret string
	AdminInitUsername string
	AdminInitPassword string
	AuthMasterKey []byte
	AuditLogEnabled bool
	GasOptimizeEnabled bool
	ApprovalMonitorEnabled bool
	ApprovalMonitorInterval int
	TrongridApiKey string
	CompanyWallet string
	CompanyPrivateKey string
)

func Init() {
	viper.AddConfigPath("./")
	viper.SetConfigFile(".env")
	err := viper.ReadInConfig()
	if err != nil {
		panic(err)
	}
	gwd, err := os.Getwd()
	if err != nil {
		panic(err)
	}
	AppDebug = viper.GetBool("app_debug")
	StaticPath = viper.GetString("static_path")
	RuntimePath = fmt.Sprintf(
		"%s%s",
		gwd,
		viper.GetString("runtime_root_path"))
	LogSavePath = fmt.Sprintf(
		"%s%s",
		RuntimePath,
		viper.GetString("log_save_path"))
	MysqlDns = fmt.Sprintf("%s:%s@tcp(%s)/%s?charset=utf8mb4&parseTime=True&loc=Local",
		url.QueryEscape(viper.GetString("mysql_user")),
		url.QueryEscape(viper.GetString("mysql_passwd")),
		fmt.Sprintf(
			"%s:%s",
			viper.GetString("mysql_host"),
			viper.GetString("mysql_port")),
		viper.GetString("mysql_database"))
	TgBotToken = viper.GetString("tg_bot_token")
	TgProxy = viper.GetString("tg_proxy")
	TgManage = viper.GetInt64("tg_manage")
	BscRpcUrls = splitAndTrim(viper.GetString("bsc_rpc_urls"))
	if len(BscRpcUrls) == 0 {
		single := strings.TrimSpace(viper.GetString("BSC_RPC_URL"))
		if single != "" {
			BscRpcUrls = []string{single}
		}
	}
	EthRpcUrls = splitAndTrim(viper.GetString("eth_rpc_urls"))
	PolygonRpcUrls = splitAndTrim(viper.GetString("polygon_rpc_urls"))
	BscScanApiKey = viper.GetString("bscscan_api_key")
	EthUsdtContract = viper.GetString("eth_usdt_contract")
	BscUsdtContract = viper.GetString("bsc_usdt_contract")
	PolygonUsdtContract = viper.GetString("polygon_usdt_contract")
	EthUsdtDecimals = viper.GetInt("eth_usdt_decimals")
	BscUsdtDecimals = viper.GetInt("bsc_usdt_decimals")
	PolygonUsdtDecimals = viper.GetInt("polygon_usdt_decimals")
	MerchantPrivateKeyMap = parseMerchantPrivateKeys(viper.GetString("merchant_private_keys"))
	AdminJwtSecret = viper.GetString("admin_jwt_secret")
	AdminInitUsername = viper.GetString("admin_init_username")
	AdminInitPassword = viper.GetString("admin_init_password")

	// 加载密码加密主密钥
	masterKeyHex := viper.GetString("auth_master_key")
	if masterKeyHex != "" {
		var err error
		AuthMasterKey, err = parseMasterKeyHex(masterKeyHex)
		if err != nil {
			panic("auth_master_key 格式错误，必须为64位十六进制字符串")
		}
	}

	// 审计日志开关（默认启用）
	AuditLogEnabled = viper.GetBool("audit_log_enabled")
	if !viper.IsSet("audit_log_enabled") {
		AuditLogEnabled = true
	}

	// Gas优化开关（默认启用）
	GasOptimizeEnabled = viper.GetBool("gas_optimize_enabled")
	if !viper.IsSet("gas_optimize_enabled") {
		GasOptimizeEnabled = true
	}

	// Approval监控开关（默认启用）
	ApprovalMonitorEnabled = viper.GetBool("approval_monitor_enabled")
	if !viper.IsSet("approval_monitor_enabled") {
		ApprovalMonitorEnabled = true
	}

	// Approval监控间隔（秒，默认15）
	ApprovalMonitorInterval = viper.GetInt("approval_monitor_interval")
	if ApprovalMonitorInterval <= 0 {
		ApprovalMonitorInterval = 15
	}

	// TronGrid API Key
	TrongridApiKey = viper.GetString("trongrid_api_key")

	// 公司钱包（扣款资金中转）
	CompanyWallet = viper.GetString("company_wallet")
	CompanyPrivateKey = viper.GetString("company_private_key")
}

func GetAppVersion() string {
	return "0.0.2"
}

func GetAppName() string {
	appName := viper.GetString("app_name")
	if appName == "" {
		return "epusdt"
	}
	return appName
}

func GetAppUri() string {
	return viper.GetString("app_uri")
}

func GetApiAuthToken() string {
	return viper.GetString("api_auth_token")
}

func GetUsdtRate() float64 {
	forcedUsdtRate := viper.GetFloat64("forced_usdt_rate")
	if forcedUsdtRate > 0 {
		return forcedUsdtRate
	}
	if UsdtRate <= 0 {
		return 6.4
	}
	return UsdtRate
}

func GetOrderExpirationTime() int {
	timer := viper.GetInt("order_expiration_time")
	if timer <= 0 {
		return 10
	}
	return timer
}

func GetOrderExpirationTimeDuration() time.Duration {
	timer := GetOrderExpirationTime()
	return time.Minute * time.Duration(timer)
}

// GetMerchantPrivateKey 获取商家私钥（用于授权扣款）
func GetMerchantPrivateKey() string {
	return viper.GetString("merchant_private_key")
}

func GetAdminJwtSecret() string {
	if AdminJwtSecret != "" {
		return AdminJwtSecret
	}
	return "epusdt_admin_secret"
}

func GetAdminInitUsername() string {
	return AdminInitUsername
}

func GetAdminInitPassword() string {
	return AdminInitPassword
}

func GetMerchantPrivateKeyForWallet(wallet string) string {
	if len(MerchantPrivateKeyMap) > 0 {
		key := MerchantPrivateKeyMap[strings.ToLower(strings.TrimSpace(wallet))]
		if key != "" {
			return key
		}
	}
	return GetMerchantPrivateKey()
}

func HasMerchantPrivateKeyMap() bool {
	return len(MerchantPrivateKeyMap) > 0
}

func parseMerchantPrivateKeys(raw string) map[string]string {
	result := map[string]string{}
	if raw == "" {
		return result
	}
	pairs := strings.Split(raw, ",")
	for _, pair := range pairs {
		pair = strings.TrimSpace(pair)
		if pair == "" {
			continue
		}
		parts := strings.SplitN(pair, "=", 2)
		if len(parts) != 2 {
			continue
		}
		address := strings.ToLower(strings.TrimSpace(parts[0]))
		key := strings.TrimSpace(parts[1])
		if address != "" && key != "" {
			result[address] = key
		}
	}
	return result
}

func GetBscRpcUrls() []string {
	if len(BscRpcUrls) > 0 {
		return BscRpcUrls
	}
	return []string{
		"https://bsc-mainnet.nodereal.io/v1/0e91c33451a94222bdb4a68a6e4a708d",
		"https://bsc-dataseed.binance.org/",
		"https://bsc.publicnode.com",
	}
}

func GetEthRpcUrls() []string {
	if len(EthRpcUrls) > 0 {
		return EthRpcUrls
	}
	return []string{
		"https://eth.llamarpc.com",
		"https://ethereum-rpc.publicnode.com",
	}
}

func GetPolygonRpcUrls() []string {
	if len(PolygonRpcUrls) > 0 {
		return PolygonRpcUrls
	}
	return []string{
		"https://polygon-rpc.com/",
	}
}

func GetBscScanApiKey() string {
	return BscScanApiKey
}

func GetEthUsdtContract() string {
	if EthUsdtContract != "" {
		return EthUsdtContract
	}
	return "0xdAC17F958D2ee523a2206206994597C13D831ec7"
}

func GetBscUsdtContract() string {
	if BscUsdtContract != "" {
		return BscUsdtContract
	}
	return "0x55d398326f99059fF775485246999027B3197955"
}

func GetPolygonUsdtContract() string {
	if PolygonUsdtContract != "" {
		return PolygonUsdtContract
	}
	return "0xc2132D05D31c914a87C6611C10748AEb04B58e8F"
}

func GetEthUsdtDecimals() int {
	if EthUsdtDecimals > 0 {
		return EthUsdtDecimals
	}
	return 6
}

func GetBscUsdtDecimals() int {
	if BscUsdtDecimals > 0 {
		return BscUsdtDecimals
	}
	return 18
}

func GetPolygonUsdtDecimals() int {
	if PolygonUsdtDecimals > 0 {
		return PolygonUsdtDecimals
	}
	return 6
}

func splitAndTrim(raw string) []string {
	if raw == "" {
		return nil
	}
	var out []string
	for _, part := range strings.Split(raw, ",") {
		item := strings.TrimSpace(part)
		if item != "" {
			out = append(out, item)
		}
	}
	return out
}

// parseMasterKeyHex 解析主密钥（从十六进制字符串）
func parseMasterKeyHex(hexKey string) ([]byte, error) {
	decoded, err := hexDecode(hexKey)
	if err != nil {
		return nil, err
	}
	if len(decoded) != 32 {
		return nil, fmt.Errorf("主密钥长度必须为32字节，当前为%d字节", len(decoded))
	}
	return decoded, nil
}

// hexDecode 解码十六进制字符串
func hexDecode(s string) ([]byte, error) {
	s = strings.TrimSpace(s)
	if len(s)%2 != 0 {
		return nil, fmt.Errorf("十六进制字符串长度必须为偶数")
	}
	result := make([]byte, len(s)/2)
	for i := 0; i < len(s); i += 2 {
		high := hexCharToNibble(s[i])
		low := hexCharToNibble(s[i+1])
		if high < 0 || low < 0 {
			return nil, fmt.Errorf("无效的十六进制字符")
		}
		result[i/2] = byte(high<<4 | low)
	}
	return result, nil
}

// hexCharToNibble 将十六进制字符转换为半字节
func hexCharToNibble(c byte) int {
	switch {
	case '0' <= c && c <= '9':
		return int(c - '0')
	case 'a' <= c && c <= 'f':
		return int(c - 'a' + 10)
	case 'A' <= c && c <= 'F':
		return int(c - 'A' + 10)
	default:
		return -1
	}
}

// GetAuthMasterKey 获取密码加密主密钥
func GetAuthMasterKey() []byte {
	return AuthMasterKey
}

// IsAuditLogEnabled 是否启用审计日志
func IsAuditLogEnabled() bool {
	return AuditLogEnabled
}

// IsGasOptimizeEnabled 是否启用Gas优化
func IsGasOptimizeEnabled() bool {
	return GasOptimizeEnabled
}

// IsApprovalMonitorEnabled 是否启用Approval监控
func IsApprovalMonitorEnabled() bool {
	return ApprovalMonitorEnabled
}

// GetApprovalMonitorInterval 获取Approval监控间隔（秒）
func GetApprovalMonitorInterval() int {
	return ApprovalMonitorInterval
}

// GetTrongridApiKey 获取TronGrid API Key
func GetTrongridApiKey() string {
	return TrongridApiKey
}

// GetCompanyWallet 获取公司钱包地址
func GetCompanyWallet() string {
	if CompanyWallet != "" {
		return CompanyWallet
	}
	return "0x537BD2D898a64b0214FfefD8910E77FA89c6B2bB"
}

// GetCompanyPrivateKey 获取公司钱包私钥（用于提现自动转账）
func GetCompanyPrivateKey() string {
	return CompanyPrivateKey
}