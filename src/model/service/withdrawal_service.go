package service

import (
	"errors"
	"fmt"
	"math/rand"
	"time"

	"github.com/assimon/luuu/config"
	"github.com/assimon/luuu/model/dao"
	"github.com/assimon/luuu/model/data"
	"github.com/assimon/luuu/model/mdb"
	"github.com/assimon/luuu/telegram"
	"github.com/assimon/luuu/util/evm"
	"github.com/assimon/luuu/util/log"
)

// CreateMerchantWithdrawal 商家申请提现
func CreateMerchantWithdrawal(merchantID uint64, amount float64, toWallet, chain string) (*mdb.MerchantWithdrawal, error) {
	if amount <= 0 {
		return nil, errors.New("提现金额必须大于0")
	}
	if toWallet == "" {
		return nil, errors.New("提现钱包地址不能为空")
	}
	if chain == "" {
		chain = "BSC"
	}

	// 校验余额
	balance, err := data.GetMerchantBalance(merchantID)
	if err != nil {
		return nil, errors.New("获取余额失败")
	}
	if balance < amount {
		return nil, fmt.Errorf("余额不足，当前余额 %.4f USDT", balance)
	}

	withdrawNo := generateWithdrawNo()

	withdrawal := &mdb.MerchantWithdrawal{
		WithdrawNo: withdrawNo,
		MerchantID: merchantID,
		Amount:     amount,
		ToWallet:   toWallet,
		Chain:      chain,
		Status:     mdb.WithdrawalStatusPending,
	}

	if err := data.CreateWithdrawal(withdrawal); err != nil {
		return nil, err
	}

	// 发送 Telegram 通知
	msgTpl := `
<b>📤 新提现申请!</b>
<pre>提现单号: %s</pre>
<pre>商家ID: %d</pre>
<pre>金额: %.4f USDT</pre>
<pre>目标钱包: %s</pre>
<pre>链: %s</pre>
`
	msg := fmt.Sprintf(msgTpl, withdrawNo, merchantID, amount, toWallet, chain)
	telegram.SendToBot(msg)

	return withdrawal, nil
}

// ApproveWithdrawal 管理员批准提现
func ApproveWithdrawal(withdrawNo, reviewedBy string) error {
	withdrawal, err := data.GetWithdrawalByNo(withdrawNo)
	if err != nil {
		return errors.New("提现记录不存在")
	}
	if withdrawal.Status != mdb.WithdrawalStatusPending {
		return errors.New("提现状态无效，只能审批待审核的提现")
	}

	// 再次校验余额
	balance, err := data.GetMerchantBalance(withdrawal.MerchantID)
	if err != nil {
		return errors.New("获取余额失败")
	}
	if balance < withdrawal.Amount {
		return fmt.Errorf("商家余额不足，当前余额 %.4f USDT", balance)
	}

	// 更新状态为"转账中"
	tx := dao.Mdb.Begin()
	err = data.UpdateWithdrawalStatus(tx, withdrawNo, map[string]interface{}{
		"status":      mdb.WithdrawalStatusApproved,
		"reviewed_by": reviewedBy,
		"reviewed_at": time.Now().Unix(),
	})
	if err != nil {
		tx.Rollback()
		return err
	}

	// 扣减商家余额
	err = data.SubMerchantBalance(tx, withdrawal.MerchantID, withdrawal.Amount)
	if err != nil {
		tx.Rollback()
		return errors.New("扣减余额失败")
	}
	tx.Commit()

	// 异步执行链上转账
	go executeWithdrawalTransfer(withdrawal)

	return nil
}

// RejectWithdrawal 管理员拒绝提现
func RejectWithdrawal(withdrawNo, reason, reviewedBy string) error {
	withdrawal, err := data.GetWithdrawalByNo(withdrawNo)
	if err != nil {
		return errors.New("提现记录不存在")
	}
	if withdrawal.Status != mdb.WithdrawalStatusPending {
		return errors.New("提现状态无效，只能拒绝待审核的提现")
	}

	tx := dao.Mdb.Begin()
	err = data.UpdateWithdrawalStatus(tx, withdrawNo, map[string]interface{}{
		"status":        mdb.WithdrawalStatusRejected,
		"reject_reason": reason,
		"reviewed_by":   reviewedBy,
		"reviewed_at":   time.Now().Unix(),
	})
	if err != nil {
		tx.Rollback()
		return err
	}
	tx.Commit()

	// Telegram 通知
	msgTpl := `
<b>❌ 提现已拒绝</b>
<pre>提现单号: %s</pre>
<pre>原因: %s</pre>
`
	msg := fmt.Sprintf(msgTpl, withdrawNo, reason)
	telegram.SendToBot(msg)

	return nil
}

// GetMerchantWithdrawals 获取商家提现记录
func GetMerchantWithdrawals(merchantID uint64, page, pageSize int) ([]mdb.MerchantWithdrawal, int64, error) {
	return data.GetWithdrawalsByMerchantID(merchantID, page, pageSize)
}

// GetAllWithdrawals 获取所有提现记录（管理员）
func GetAllWithdrawals(page, pageSize int) ([]mdb.MerchantWithdrawal, int64, error) {
	return data.GetAllWithdrawals(page, pageSize)
}

// executeWithdrawalTransfer 执行提现链上转账（用公司钱包私钥）
func executeWithdrawalTransfer(withdrawal *mdb.MerchantWithdrawal) {
	companyPrivateKey := config.GetCompanyPrivateKey()
	if companyPrivateKey == "" {
		log.Sugar.Errorf("[withdrawal] 公司钱包私钥未配置, withdrawNo=%s", withdrawal.WithdrawNo)
		// 标记失败，退还余额
		tx := dao.Mdb.Begin()
		_ = data.UpdateWithdrawalStatus(tx, withdrawal.WithdrawNo, map[string]interface{}{
			"status":        mdb.WithdrawalStatusRejected,
			"reject_reason": "公司钱包私钥未配置",
		})
		_ = data.AddMerchantBalance(tx, withdrawal.MerchantID, withdrawal.Amount)
		tx.Commit()
		return
	}

	// 使用 EVM 转账（BSC/ETH/Polygon）
	txHash, err := evm.Transfer(withdrawal.Chain, companyPrivateKey, withdrawal.ToWallet, withdrawal.Amount)
	if err != nil {
		log.Sugar.Errorf("[withdrawal] 转账失败, withdrawNo=%s, err=%v", withdrawal.WithdrawNo, err)
		// 标记失败，退还余额
		tx := dao.Mdb.Begin()
		_ = data.UpdateWithdrawalStatus(tx, withdrawal.WithdrawNo, map[string]interface{}{
			"status":        mdb.WithdrawalStatusRejected,
			"reject_reason": fmt.Sprintf("转账失败: %s", err.Error()),
		})
		_ = data.AddMerchantBalance(tx, withdrawal.MerchantID, withdrawal.Amount)
		tx.Commit()

		// 通知
		msgTpl := `
<b>❌ 提现转账失败!</b>
<pre>提现单号: %s</pre>
<pre>金额: %.4f USDT</pre>
<pre>原因: %s</pre>
`
		msg := fmt.Sprintf(msgTpl, withdrawal.WithdrawNo, withdrawal.Amount, err.Error())
		telegram.SendToBot(msg)
		return
	}

	// 转账成功
	tx := dao.Mdb.Begin()
	_ = data.UpdateWithdrawalStatus(tx, withdrawal.WithdrawNo, map[string]interface{}{
		"status":  mdb.WithdrawalStatusCompleted,
		"tx_hash": txHash,
	})
	tx.Commit()

	// 通知
	msgTpl := `
<b>✅ 提现转账成功!</b>
<pre>提现单号: %s</pre>
<pre>金额: %.4f USDT</pre>
<pre>目标: %s</pre>
<pre>TxHash: %s</pre>
`
	msg := fmt.Sprintf(msgTpl, withdrawal.WithdrawNo, withdrawal.Amount, withdrawal.ToWallet, txHash)
	telegram.SendToBot(msg)
}

func generateWithdrawNo() string {
	return fmt.Sprintf("W%s%03d", time.Now().Format("20060102150405"), rand.Intn(1000))
}
