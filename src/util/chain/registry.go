package chain

import (
	"github.com/assimon/luuu/config"
)

// ChainInfo 链配置信息
type ChainInfo struct {
	Name         string   // 标准名称: BSC, EVM, POLYGON, TRON
	DisplayName  string   // 显示名称
	ChainID      int64    // EVM链ID (0=TRON)
	ChainIDHex   string   // 十六进制链ID
	USDTContract string   // USDT合约地址
	Decimals     int      // USDT精度
	RpcURLs      []string // RPC节点列表
	ExplorerURL  string   // 区块浏览器地址
	NativeSymbol string   // 原生币符号
	IsTron       bool
	IsEVM        bool
}

// 已注册的链配置（启动时从config初始化）
var registry map[string]*ChainInfo

// InitRegistry 从config初始化链注册表（在config.Init()之后调用）
func InitRegistry() {
	registry = map[string]*ChainInfo{
		ChainBsc: {
			Name:         ChainBsc,
			DisplayName:  "BNB Smart Chain",
			ChainID:      56,
			ChainIDHex:   "0x38",
			USDTContract: config.GetBscUsdtContract(),
			Decimals:     config.GetBscUsdtDecimals(),
			RpcURLs:      config.GetBscRpcUrls(),
			ExplorerURL:  "https://bscscan.com",
			NativeSymbol: "BNB",
			IsTron:       false,
			IsEVM:        true,
		},
		ChainEvm: {
			Name:         ChainEvm,
			DisplayName:  "Ethereum",
			ChainID:      1,
			ChainIDHex:   "0x1",
			USDTContract: config.GetEthUsdtContract(),
			Decimals:     config.GetEthUsdtDecimals(),
			RpcURLs:      config.GetEthRpcUrls(),
			ExplorerURL:  "https://etherscan.io",
			NativeSymbol: "ETH",
			IsTron:       false,
			IsEVM:        true,
		},
		ChainPolygon: {
			Name:         ChainPolygon,
			DisplayName:  "Polygon",
			ChainID:      137,
			ChainIDHex:   "0x89",
			USDTContract: config.GetPolygonUsdtContract(),
			Decimals:     config.GetPolygonUsdtDecimals(),
			RpcURLs:      config.GetPolygonRpcUrls(),
			ExplorerURL:  "https://polygonscan.com",
			NativeSymbol: "POL",
			IsTron:       false,
			IsEVM:        true,
		},
		ChainTron: {
			Name:         ChainTron,
			DisplayName:  "TRON",
			ChainID:      0,
			ChainIDHex:   "",
			USDTContract: "TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t",
			Decimals:     6,
			RpcURLs:      []string{"https://api.trongrid.io"},
			ExplorerURL:  "https://tronscan.org",
			NativeSymbol: "TRX",
			IsTron:       true,
			IsEVM:        false,
		},
	}
}

// GetChainInfo 获取链配置信息
func GetChainInfo(chainName string) *ChainInfo {
	name := NormalizeChain(chainName)
	if registry == nil {
		return nil
	}
	return registry[name]
}

// GetAllChains 获取所有支持的链
func GetAllChains() []*ChainInfo {
	if registry == nil {
		return nil
	}
	result := make([]*ChainInfo, 0, len(registry))
	for _, info := range registry {
		result = append(result, info)
	}
	return result
}

// GetAllEVMChains 获取所有EVM链
func GetAllEVMChains() []*ChainInfo {
	result := make([]*ChainInfo, 0)
	for _, info := range registry {
		if info.IsEVM {
			result = append(result, info)
		}
	}
	return result
}

// GetChainIDByName 根据链名获取链ID
func GetChainIDByName(chainName string) int64 {
	info := GetChainInfo(chainName)
	if info == nil {
		return 0
	}
	return info.ChainID
}

// GetContractByChain 根据链名获取USDT合约地址
func GetContractByChain(chainName string) string {
	info := GetChainInfo(chainName)
	if info == nil {
		return ""
	}
	return info.USDTContract
}

// GetDecimalsByChain 根据链名获取USDT精度
func GetDecimalsByChain(chainName string) int {
	info := GetChainInfo(chainName)
	if info == nil {
		return 6
	}
	return info.Decimals
}

// GetRpcURLsByChain 根据链名获取RPC URL列表
func GetRpcURLsByChain(chainName string) []string {
	info := GetChainInfo(chainName)
	if info == nil {
		return nil
	}
	return info.RpcURLs
}
