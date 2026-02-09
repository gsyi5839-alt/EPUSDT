package evm

import (
	"context"
	"math/big"
	"time"

	"github.com/assimon/luuu/util/log"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/shopspring/decimal"
)

// GasEstimator Gas 费用估算器
type GasEstimator struct {
	client  *ethclient.Client
	chainID int64
}

// NewGasEstimator 创建 Gas 估算器
func NewGasEstimator(client *ethclient.Client, chainID int64) *GasEstimator {
	return &GasEstimator{
		client:  client,
		chainID: chainID,
	}
}

// EstimateOptimalGasPrice 估算最优 Gas 价格
// 使用建议 Gas 价格和最近区块平均价格的较小值 + 5% 缓冲
func (g *GasEstimator) EstimateOptimalGasPrice() (*big.Int, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	// 1. 获取建议 Gas Price
	suggestedPrice, err := g.client.SuggestGasPrice(ctx)
	if err != nil {
		return nil, err
	}

	// 2. 获取最近区块的平均 Gas Price
	block, err := g.client.BlockByNumber(ctx, nil)
	if err != nil {
		log.Sugar.Warnf("获取最近区块失败: %v, 使用建议价格", err)
		return g.addBuffer(suggestedPrice, 5), nil
	}

	avgPrice := g.calculateAverageGasPrice(block)

	// 3. 使用较低值（节省成本）
	var optimalPrice *big.Int
	if suggestedPrice.Cmp(avgPrice) < 0 {
		optimalPrice = suggestedPrice
	} else {
		optimalPrice = avgPrice
	}

	// 4. 添加 5% 缓冲，确保交易被快速确认
	buffered := g.addBuffer(optimalPrice, 5)

	log.Sugar.Infof("[Gas优化] 建议价格: %s, 平均价格: %s, 最优价格: %s",
		formatGwei(suggestedPrice),
		formatGwei(avgPrice),
		formatGwei(buffered))

	return buffered, nil
}

// EstimateEIP1559Fees 估算 EIP-1559 动态费用（仅适用于 Ethereum/Polygon）
func (g *GasEstimator) EstimateEIP1559Fees() (*big.Int, *big.Int, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	// 获取最新区块的 BaseFee
	block, err := g.client.BlockByNumber(ctx, nil)
	if err != nil {
		return nil, nil, err
	}

	baseFee := block.BaseFee()
	if baseFee == nil {
		// 如果链不支持 EIP-1559，返回 nil
		return nil, nil, nil
	}

	// MaxPriorityFeePerGas（小费）：2 Gwei（标准）
	maxPriorityFee := big.NewInt(2e9)

	// MaxFeePerGas = BaseFee * 2 + MaxPriorityFee
	// 乘以2是为了应对BaseFee在下一个区块的波动
	maxFee := new(big.Int).Mul(baseFee, big.NewInt(2))
	maxFee.Add(maxFee, maxPriorityFee)

	log.Sugar.Infof("[EIP-1559] BaseFee: %s, MaxPriorityFee: %s, MaxFee: %s",
		formatGwei(baseFee),
		formatGwei(maxPriorityFee),
		formatGwei(maxFee))

	return maxFee, maxPriorityFee, nil
}

// calculateAverageGasPrice 计算区块中所有交易的平均 Gas Price
func (g *GasEstimator) calculateAverageGasPrice(block *types.Block) *big.Int {
	transactions := block.Transactions()
	if len(transactions) == 0 {
		return big.NewInt(0)
	}

	total := new(big.Int)
	count := 0

	for _, tx := range transactions {
		gasPrice := tx.GasPrice()
		if gasPrice != nil && gasPrice.Sign() > 0 {
			total.Add(total, gasPrice)
			count++
		}
	}

	if count == 0 {
		return big.NewInt(0)
	}

	// 返回平均值
	return new(big.Int).Div(total, big.NewInt(int64(count)))
}

// addBuffer 添加百分比缓冲
func (g *GasEstimator) addBuffer(price *big.Int, percent int) *big.Int {
	if price == nil || price.Sign() == 0 {
		return big.NewInt(0)
	}

	// price * (100 + percent) / 100
	buffered := new(big.Int).Mul(price, big.NewInt(int64(100+percent)))
	buffered.Div(buffered, big.NewInt(100))

	return buffered
}

// formatGwei 格式化为 Gwei 单位（方便日志查看）
func formatGwei(wei *big.Int) string {
	if wei == nil {
		return "0 Gwei"
	}

	// 1 Gwei = 1e9 Wei
	gwei := decimal.NewFromBigInt(wei, 0).Div(decimal.NewFromInt(1e9))
	return gwei.StringFixed(2) + " Gwei"
}

// GetOptimalGasPriceWithEIP1559 获取最优 Gas 价格（自动检测是否支持 EIP-1559）
func GetOptimalGasPriceWithEIP1559(chainName string) (*big.Int, *big.Int, *big.Int, error) {
	cfg, err := getChainConfig(chainName)
	if err != nil {
		return nil, nil, nil, err
	}

	client, err := dial(cfg)
	if err != nil {
		return nil, nil, nil, err
	}
	defer client.Close()

	estimator := NewGasEstimator(client, cfg.ChainID)

	// 尝试使用 EIP-1559
	maxFee, maxPriorityFee, err := estimator.EstimateEIP1559Fees()
	if err == nil && maxFee != nil {
		// 链支持 EIP-1559
		return nil, maxFee, maxPriorityFee, nil
	}

	// 链不支持 EIP-1559，使用传统 Gas Price
	gasPrice, err := estimator.EstimateOptimalGasPrice()
	if err != nil {
		return nil, nil, nil, err
	}

	return gasPrice, nil, nil, nil
}

// EstimateGasLimit 估算 Gas Limit（带缓冲）
func EstimateGasLimit(client *ethclient.Client, msg interface{}) (uint64, error) {
	// TODO: 实现 Gas Limit 估算
	// 当前使用固定值
	return 100000, nil
}
