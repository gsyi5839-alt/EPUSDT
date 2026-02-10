package dao

import (
	"sync"

	"github.com/assimon/luuu/model/mdb"
	"github.com/gookit/color"
)

var once sync.Once

// 自动建表
func MdbTableInit() {
	once.Do(func() {
		if err := Mdb.AutoMigrate(&mdb.Orders{}); err != nil {
			color.Red.Printf("[store_db] AutoMigrate DB(Orders),err=%s\n", err)
			return
		}
		if err := Mdb.AutoMigrate(&mdb.WalletAddress{}); err != nil {
			color.Red.Printf("[store_db] AutoMigrate DB(WalletAddress),err=%s\n", err)
			return
		}
		// 授权支付表
		if err := Mdb.AutoMigrate(&mdb.Authorization{}); err != nil {
			color.Red.Printf("[store_db] AutoMigrate DB(Authorization),err=%s\n", err)
			return
		}
		if err := Mdb.AutoMigrate(&mdb.Deduction{}); err != nil {
			color.Red.Printf("[store_db] AutoMigrate DB(Deduction),err=%s\n", err)
			return
		}
		// 管理系统表
		if err := Mdb.AutoMigrate(&mdb.AdminRole{}); err != nil {
			color.Red.Printf("[store_db] AutoMigrate DB(AdminRole),err=%s\n", err)
			return
		}
		if err := Mdb.AutoMigrate(&mdb.AdminUser{}); err != nil {
			color.Red.Printf("[store_db] AutoMigrate DB(AdminUser),err=%s\n", err)
			return
		}
		if err := Mdb.AutoMigrate(&mdb.CallbackLog{}); err != nil {
			color.Red.Printf("[store_db] AutoMigrate DB(CallbackLog),err=%s\n", err)
			return
		}
		// 审计日志表
		if err := Mdb.AutoMigrate(&mdb.AuditLog{}); err != nil {
			color.Red.Printf("[store_db] AutoMigrate DB(AuditLog),err=%s\n", err)
			return
		}
		// 商家表
		if err := Mdb.AutoMigrate(&mdb.Merchant{}); err != nil {
			color.Red.Printf("[store_db] AutoMigrate DB(Merchant),err=%s\n", err)
			return
		}
		// 商家提现表
		if err := Mdb.AutoMigrate(&mdb.MerchantWithdrawal{}); err != nil {
			color.Red.Printf("[store_db] AutoMigrate DB(MerchantWithdrawal),err=%s\n", err)
			return
		}
	})
}
