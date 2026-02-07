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
		if err := Mdb.AutoMigrate(&mdb.KtvAuthorize{}); err != nil {
			color.Red.Printf("[store_db] AutoMigrate DB(KtvAuthorize),err=%s\n", err)
			return
		}
		if err := Mdb.AutoMigrate(&mdb.KtvDeduction{}); err != nil {
			color.Red.Printf("[store_db] AutoMigrate DB(KtvDeduction),err=%s\n", err)
			return
		}
	})
}
