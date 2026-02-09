package task

import (
	"context"
	"fmt"
	"math/big"
	"time"

	"github.com/assimon/luuu/config"
	"github.com/assimon/luuu/model/dao"
	"github.com/assimon/luuu/model/data"
	"github.com/assimon/luuu/model/mdb"
	"github.com/assimon/luuu/model/request"
	"github.com/assimon/luuu/model/service"
	"github.com/assimon/luuu/mq"
	"github.com/assimon/luuu/mq/handle"
	"github.com/assimon/luuu/telegram"
	"github.com/assimon/luuu/util/chain"
	"github.com/assimon/luuu/util/evm"
	"github.com/assimon/luuu/util/log"
	"github.com/assimon/luuu/util/math"
	"github.com/hibiken/asynq"
	"github.com/spf13/viper"

	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethclient"
)

type ListenEvmJob struct{}

func (ListenEvmJob) Run() {
	listenEvmChain(chain.ChainBsc, config.GetBscRpcUrls(), config.GetBscUsdtContract(), config.GetBscUsdtDecimals())
	listenEvmChain(chain.ChainEvm, config.GetEthRpcUrls(), config.GetEthUsdtContract(), config.GetEthUsdtDecimals())
	listenEvmChain(chain.ChainPolygon, config.GetPolygonRpcUrls(), config.GetPolygonUsdtContract(), config.GetPolygonUsdtDecimals())
}

func listenEvmChain(chainName string, rpcUrls []string, tokenContract string, decimals int) {
	if len(rpcUrls) == 0 || tokenContract == "" {
		return
	}
	if dao.Rdb == nil {
		return
	}

	wallets, err := data.GetAvailableWalletAddressByChain(chainName)
	if err != nil || len(wallets) == 0 {
		return
	}

	client, err := ethclient.Dial(rpcUrls[0])
	if err != nil {
		log.Sugar.Error(err)
		return
	}
	defer client.Close()

	ctx, cancel := context.WithTimeout(context.Background(), 8*time.Second)
	defer cancel()

	latest, err := client.BlockNumber(ctx)
	if err != nil || latest == 0 {
		return
	}

	lastBlock := getLastBlock(chainName)
	if lastBlock == 0 || lastBlock > latest {
		if latest > 200 {
			lastBlock = latest - 200
		} else {
			lastBlock = 1
		}
	}

	const maxRange uint64 = 500
	contractAddr := common.HexToAddress(tokenContract)
	transferTopic := crypto.Keccak256Hash([]byte("Transfer(address,address,uint256)"))

	blockTimeCache := map[uint64]uint64{}

	for from := lastBlock + 1; from <= latest; {
		to := from + maxRange - 1
		if to > latest {
			to = latest
		}
		for _, wallet := range wallets {
			toAddr := common.HexToAddress(wallet.Token)
			toTopic := common.BytesToHash(common.LeftPadBytes(toAddr.Bytes(), 32))
			query := ethereum.FilterQuery{
				FromBlock: big.NewInt(int64(from)),
				ToBlock:   big.NewInt(int64(to)),
				Addresses: []common.Address{contractAddr},
				Topics:    [][]common.Hash{{transferTopic}, nil, {toTopic}},
			}
			logs, err := client.FilterLogs(ctx, query)
			if err != nil {
				continue
			}
			processEvmLogs(chainName, decimals, wallet, logs, client, blockTimeCache)
		}
		from = to + 1
	}

	setLastBlock(chainName, latest)
}

func processEvmLogs(chainName string, decimals int, wallet mdb.WalletAddress, logs []types.Log, client *ethclient.Client, blockTimeCache map[uint64]uint64) {
	for _, lg := range logs {
		if len(lg.Data) == 0 || lg.TxHash.Hex() == "" {
			continue
		}
		amountInt := new(big.Int).SetBytes(lg.Data)
		amount := evm.ToDecimalAmount(amountInt, decimals)
		amount = math.MustParsePrecFloat64(amount, 2)

		tradeId, err := data.GetTradeIdByWalletAddressAndAmount(wallet.Token, amount)
		if err != nil || tradeId == "" {
			continue
		}
		order, err := data.GetOrderInfoByTradeId(tradeId)
		if err != nil || order.ID <= 0 {
			continue
		}

		blockTime := getBlockTime(client, lg.BlockNumber, blockTimeCache)
		if blockTime > 0 && order.CreatedAt.Timestamp() > int64(blockTime) {
			continue
		}

		req := &request.OrderProcessingRequest{
			Token:              wallet.Token,
			TradeId:            tradeId,
			Amount:             amount,
			BlockTransactionId: lg.TxHash.Hex(),
		}
		if err := service.OrderProcessing(req); err != nil {
			continue
		}

		orderCallbackQueue, _ := handle.NewOrderCallbackQueue(order)
		orderNoticeMaxRetry := viper.GetInt("order_notice_max_retry")
		mq.MClient.Enqueue(orderCallbackQueue, asynq.MaxRetry(orderNoticeMaxRetry),
			asynq.Retention(config.GetOrderExpirationTimeDuration()),
		)
		msgTpl := `
<b>📢📢有新的交易支付成功！</b>
<pre>链: %s</pre>
<pre>交易号：%s</pre>
<pre>订单号：%s</pre>
<pre>请求支付金额：%f cny</pre>
<pre>实际支付金额：%f usdt</pre>
<pre>钱包地址：%s</pre>
`
		msg := fmt.Sprintf(msgTpl, chainName, order.TradeId, order.OrderId, order.Amount, order.ActualAmount, order.Token)
		telegram.SendToBot(msg)
	}
}

func getLastBlock(chainName string) uint64 {
	ctx := context.Background()
	key := fmt.Sprintf("evm:last_block:%s", chainName)
	val, err := dao.Rdb.Get(ctx, key).Uint64()
	if err != nil {
		return 0
	}
	return val
}

func setLastBlock(chainName string, block uint64) {
	ctx := context.Background()
	key := fmt.Sprintf("evm:last_block:%s", chainName)
	_ = dao.Rdb.Set(ctx, key, block, 0).Err()
}

func getBlockTime(client *ethclient.Client, blockNumber uint64, cache map[uint64]uint64) uint64 {
	if t, ok := cache[blockNumber]; ok {
		return t
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	header, err := client.HeaderByNumber(ctx, big.NewInt(int64(blockNumber)))
	if err != nil {
		return 0
	}
	cache[blockNumber] = header.Time
	return header.Time
}
