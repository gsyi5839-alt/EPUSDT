package main

import (
	"fmt"
	"log"
	"os"

	"github.com/assimon/luuu/config"
	"github.com/assimon/luuu/model/dao"
	"github.com/assimon/luuu/model/mdb"
	"github.com/assimon/luuu/util/crypto"
)

// 密码加密迁移脚本
// 用于将现有的明文密码加密存储

func main() {
	fmt.Println("========================================")
	fmt.Println("密码加密迁移工具 v1.0")
	fmt.Println("========================================")
	fmt.Println()

	// 1. 加载配置
	fmt.Println("[1/5] 加载配置...")
	if err := os.Chdir("src"); err != nil {
		log.Fatalf("切换目录失败: %v", err)
	}

	config.Init()

	// 检查主密钥
	masterKey := config.GetAuthMasterKey()
	if len(masterKey) == 0 {
		log.Fatal("❌ 错误: auth_master_key 未配置，请先在 .env 中设置主密钥")
	}
	fmt.Printf("✅ 主密钥已加载 (长度: %d bytes)\n", len(masterKey))
	fmt.Println()

	// 2. 初始化数据库
	fmt.Println("[2/5] 连接数据库...")
	switch config.GetString("db_type") {
	case "mysql":
		dao.InitMysql()
	case "postgres":
		dao.InitPostgres()
	case "sqlite":
		dao.InitSqlite()
	default:
		dao.InitMysql()
	}
	fmt.Println("✅ 数据库连接成功")
	fmt.Println()

	// 3. 查询需要加密的授权记录
	fmt.Println("[3/5] 查询需要加密的授权记录...")
	var auths []mdb.KtvAuthorize

	// 查询条件：password 不为空 且 encrypted_password 为空
	err := dao.Mdb.Where("password IS NOT NULL AND password != '' AND (encrypted_password IS NULL OR encrypted_password = '')").
		Find(&auths).Error

	if err != nil {
		log.Fatalf("❌ 查询失败: %v", err)
	}

	fmt.Printf("✅ 找到 %d 条需要加密的记录\n", len(auths))
	fmt.Println()

	if len(auths) == 0 {
		fmt.Println("🎉 没有需要迁移的数据，退出。")
		return
	}

	// 4. 确认迁移
	fmt.Printf("⚠️  将对 %d 条授权记录进行密码加密，是否继续？(y/n): ", len(auths))
	var confirm string
	fmt.Scanln(&confirm)

	if confirm != "y" && confirm != "Y" {
		fmt.Println("❌ 用户取消迁移")
		return
	}
	fmt.Println()

	// 5. 执行加密迁移
	fmt.Println("[4/5] 执行加密迁移...")
	successCount := 0
	failCount := 0

	for i, auth := range auths {
		fmt.Printf("处理 [%d/%d] AuthNo: %s ... ", i+1, len(auths), auth.AuthNo)

		// 跳过空密码
		if auth.Password == "" {
			fmt.Println("⏭️  密码为空，跳过")
			continue
		}

		// 跳过已加密的记录
		if len(auth.EncryptedPassword) > 0 {
			fmt.Println("⏭️  已加密，跳过")
			continue
		}

		// 加密密码
		vault, err := crypto.EncryptPassword(auth.Password, auth.CustomerWallet, masterKey)
		if err != nil {
			fmt.Printf("❌ 失败: %v\n", err)
			failCount++
			continue
		}

		// 更新数据库
		err = dao.Mdb.Model(&auth).Updates(map[string]interface{}{
			"encrypted_password": vault.EncryptedPassword,
			"password_nonce":     vault.Nonce,
			"password_salt":      vault.Salt,
		}).Error

		if err != nil {
			fmt.Printf("❌ 更新失败: %v\n", err)
			failCount++
			continue
		}

		fmt.Println("✅ 成功")
		successCount++
	}

	fmt.Println()

	// 6. 迁移结果
	fmt.Println("[5/5] 迁移结果:")
	fmt.Println("========================================")
	fmt.Printf("✅ 成功: %d 条\n", successCount)
	fmt.Printf("❌ 失败: %d 条\n", failCount)
	fmt.Printf("📊 总计: %d 条\n", len(auths))
	fmt.Println("========================================")
	fmt.Println()

	if failCount > 0 {
		fmt.Println("⚠️  部分记录加密失败，请检查日志并手动处理")
	} else {
		fmt.Println("🎉 所有密码加密完成！")
	}

	// 7. 验证迁移（可选）
	fmt.Println()
	fmt.Print("是否验证加密结果？(y/n): ")
	var verify string
	fmt.Scanln(&verify)

	if verify == "y" || verify == "Y" {
		fmt.Println()
		fmt.Println("验证加密结果...")

		var verifyAuths []mdb.KtvAuthorize
		dao.Mdb.Where("id IN ?", getAuthIDs(auths)).Find(&verifyAuths)

		verifySuccessCount := 0
		verifyFailCount := 0

		for _, auth := range verifyAuths {
			// 尝试解密
			vault := &crypto.PasswordVault{
				EncryptedPassword: auth.EncryptedPassword,
				Nonce:             auth.PasswordNonce,
				Salt:              auth.PasswordSalt,
				CustomerWallet:    auth.CustomerWallet,
			}

			decrypted, err := crypto.DecryptPassword(vault, masterKey)
			if err != nil {
				fmt.Printf("❌ AuthNo: %s 解密失败: %v\n", auth.AuthNo, err)
				verifyFailCount++
				continue
			}

			// 验证解密后的密码是否与原密码一致
			if !crypto.VerifyPassword(auth.Password, decrypted) {
				fmt.Printf("❌ AuthNo: %s 密码不匹配\n", auth.AuthNo)
				verifyFailCount++
				continue
			}

			verifySuccessCount++
		}

		fmt.Println()
		fmt.Println("验证结果:")
		fmt.Printf("✅ 验证成功: %d 条\n", verifySuccessCount)
		fmt.Printf("❌ 验证失败: %d 条\n", verifyFailCount)

		if verifyFailCount > 0 {
			fmt.Println("⚠️  验证失败，请检查数据完整性")
		} else {
			fmt.Println("🎉 验证通过，数据完整！")
		}
	}

	fmt.Println()
	fmt.Println("迁移完成。")
}

// getAuthIDs 获取授权ID列表
func getAuthIDs(auths []mdb.KtvAuthorize) []uint64 {
	ids := make([]uint64, len(auths))
	for i, auth := range auths {
		ids[i] = auth.ID
	}
	return ids
}

// 辅助函数：获取配置字符串
func (c *config) GetString(key string) string {
	// 这个函数需要在 config 包中实现
	// 这里仅作示例
	return ""
}
