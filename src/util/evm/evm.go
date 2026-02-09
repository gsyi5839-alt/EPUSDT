package evm

import (
	"context"
	"errors"
	"math/big"
	"strings"
	"sync"
	"time"

	"github.com/assimon/luuu/config"
	"github.com/assimon/luuu/util/chain"
	"github.com/shopspring/decimal"

	"github.com/ethereum/go-ethereum"
	// 区块链合约绑定和ABI处理 - 为未来的合约交互功能保留
	_ "github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethclient"
)

type chainConfig struct {
	Name         string
	ChainID      int64
	RpcUrls      []string
	TokenAddress string
	Decimals     int
}

var (
	erc20ABI       = mustParseErc20Abi()
	rrLock         sync.Mutex
	rrIndexByChain = map[string]int{}
)

func GetAllowance(chainName, owner, spender string) (float64, error) {
	cfg, err := getChainConfig(chainName)
	if err != nil {
		return 0, err
	}
	client, err := dial(cfg)
	if err != nil {
		return 0, err
	}
	defer client.Close()

	ownerAddr := common.HexToAddress(owner)
	spenderAddr := common.HexToAddress(spender)
	contractAddr := common.HexToAddress(cfg.TokenAddress)

	data, err := erc20ABI.Pack("allowance", ownerAddr, spenderAddr)
	if err != nil {
		return 0, err
	}

	ctx, cancel := context.WithTimeout(context.Background(), 8*time.Second)
	defer cancel()

	msg := ethereum.CallMsg{
		To:   &contractAddr,
		Data: data,
	}
	output, err := client.CallContract(ctx, msg, nil)
	if err != nil {
		return 0, err
	}

	results, err := erc20ABI.Unpack("allowance", output)
	if err != nil || len(results) == 0 {
		return 0, errors.New("allowance解析失败")
	}

	val, ok := results[0].(*big.Int)
	if !ok {
		return 0, errors.New("allowance类型错误")
	}

	return ToDecimalAmount(val, cfg.Decimals), nil
}

func TransferFrom(chainName, privateKeyHex, from, to string, amount float64) (string, error) {
	cfg, err := getChainConfig(chainName)
	if err != nil {
		return "", err
	}
	client, err := dial(cfg)
	if err != nil {
		return "", err
	}
	defer client.Close()

	privateKey, err := crypto.HexToECDSA(strings.TrimPrefix(privateKeyHex, "0x"))
	if err != nil {
		return "", errors.New("私钥格式错误")
	}

	fromAddr := common.HexToAddress(from)
	toAddr := common.HexToAddress(to)
	contractAddr := common.HexToAddress(cfg.TokenAddress)
	spenderAddr := crypto.PubkeyToAddress(privateKey.PublicKey)

	if spenderAddr != toAddr {
		return "", errors.New("私钥地址与商家收款地址不一致")
	}

	value := fromDecimalAmount(amount, cfg.Decimals)
	data, err := erc20ABI.Pack("transferFrom", fromAddr, toAddr, value)
	if err != nil {
		return "", err
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	nonce, err := client.PendingNonceAt(ctx, spenderAddr)
	if err != nil {
		return "", err
	}

	// Gas 优化：使用优化后的 Gas 估算器
	estimator := NewGasEstimator(client, cfg.ChainID)

	// Gas Limit 估算（添加 20% 缓冲）
	callMsg := ethereum.CallMsg{
		From: spenderAddr,
		To:   &contractAddr,
		Data: data,
	}
	gasLimit, err := client.EstimateGas(ctx, callMsg)
	if err != nil {
		return "", err
	}
	gasLimit = gasLimit + gasLimit/5

	// 尝试使用 EIP-1559（Ethereum/Polygon）
	maxFee, maxPriorityFee, err := estimator.EstimateEIP1559Fees()
	if err == nil && maxFee != nil {
		// 使用 EIP-1559 动态费用
		tx := types.NewTx(&types.DynamicFeeTx{
			ChainID:   big.NewInt(cfg.ChainID),
			Nonce:     nonce,
			To:        &contractAddr,
			Value:     big.NewInt(0),
			Gas:       gasLimit,
			GasFeeCap: maxFee,
			GasTipCap: maxPriorityFee,
			Data:      data,
		})

		signer := types.LatestSignerForChainID(big.NewInt(cfg.ChainID))
		signedTx, err := types.SignTx(tx, signer, privateKey)
		if err != nil {
			return "", err
		}

		if err := client.SendTransaction(ctx, signedTx); err != nil {
			return "", err
		}

		return signedTx.Hash().Hex(), nil
	}

	// 使用传统 Gas Price（BSC 或旧链）
	gasPrice, err := estimator.EstimateOptimalGasPrice()
	if err != nil {
		return "", err
	}

	tx := types.NewTx(&types.LegacyTx{
		Nonce:    nonce,
		To:       &contractAddr,
		Value:    big.NewInt(0),
		Gas:      gasLimit,
		GasPrice: gasPrice,
		Data:     data,
	})

	signer := types.LatestSignerForChainID(big.NewInt(cfg.ChainID))
	signedTx, err := types.SignTx(tx, signer, privateKey)
	if err != nil {
		return "", err
	}

	if err := client.SendTransaction(ctx, signedTx); err != nil {
		return "", err
	}

	return signedTx.Hash().Hex(), nil
}

func getChainConfig(chainName string) (*chainConfig, error) {
	chainName = chain.NormalizeChain(chainName)
	switch chainName {
	case chain.ChainEvm:
		return &chainConfig{
			Name:         "ETH",
			ChainID:      1,
			RpcUrls:      config.GetEthRpcUrls(),
			TokenAddress: config.GetEthUsdtContract(),
			Decimals:     config.GetEthUsdtDecimals(),
		}, nil
	case chain.ChainBsc:
		return &chainConfig{
			Name:         "BSC",
			ChainID:      56,
			RpcUrls:      config.GetBscRpcUrls(),
			TokenAddress: config.GetBscUsdtContract(),
			Decimals:     config.GetBscUsdtDecimals(),
		}, nil
	case chain.ChainPolygon:
		return &chainConfig{
			Name:         "POLYGON",
			ChainID:      137,
			RpcUrls:      config.GetPolygonRpcUrls(),
			TokenAddress: config.GetPolygonUsdtContract(),
			Decimals:     config.GetPolygonUsdtDecimals(),
		}, nil
	default:
		return nil, errors.New("不支持的链")
	}
}

func dial(cfg *chainConfig) (*ethclient.Client, error) {
	if len(cfg.RpcUrls) == 0 {
		return nil, errors.New("未配置RPC节点")
	}
	rpcUrl := pickRpcUrl(cfg.Name, cfg.RpcUrls)
	return ethclient.Dial(rpcUrl)
}

func pickRpcUrl(chainName string, urls []string) string {
	rrLock.Lock()
	defer rrLock.Unlock()

	idx := rrIndexByChain[chainName]
	if idx < 0 || idx >= len(urls) {
		idx = 0
	}
	chosen := urls[idx]
	rrIndexByChain[chainName] = (idx + 1) % len(urls)
	return chosen
}

func ToDecimalAmount(val *big.Int, decimals int) float64 {
	if val == nil {
		return 0
	}
	d := decimal.NewFromBigInt(val, 0)
	scale := decimal.NewFromInt(1).Shift(int32(decimals))
	return d.Div(scale).InexactFloat64()
}

func fromDecimalAmount(amount float64, decimals int) *big.Int {
	d := decimal.NewFromFloat(amount)
	scale := decimal.NewFromInt(1).Shift(int32(decimals))
	val := d.Mul(scale).BigInt()
	return val
}
