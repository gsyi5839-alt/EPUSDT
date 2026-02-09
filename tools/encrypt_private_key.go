package main

import (
	"encoding/hex"
	"fmt"
	"os"

	"github.com/assimon/luuu/util/crypto"
)

func main() {
	if len(os.Args) < 2 {
		printUsage()
		os.Exit(1)
	}

	command := os.Args[1]

	switch command {
	case "generate-key":
		generateKey()
	case "encrypt":
		if len(os.Args) < 4 {
			printUsage()
			os.Exit(1)
		}
		encrypt(os.Args[2], os.Args[3])
	case "decrypt":
		if len(os.Args) < 4 {
			printUsage()
			os.Exit(1)
		}
		decrypt(os.Args[2], os.Args[3])
	default:
		printUsage()
		os.Exit(1)
	}
}

func printUsage() {
	fmt.Println("EPUSDT 私钥加密工具")
	fmt.Println("")
	fmt.Println("用法:")
	fmt.Println("  1. 生成主密钥:")
	fmt.Println("     go run tools/encrypt_private_key.go generate-key")
	fmt.Println("")
	fmt.Println("  2. 加密私钥:")
	fmt.Println("     go run tools/encrypt_private_key.go encrypt <master_key_hex> <private_key>")
	fmt.Println("     示例: go run tools/encrypt_private_key.go encrypt abc123...def456 0x1234567890abcdef...")
	fmt.Println("")
	fmt.Println("  3. 解密私钥（验证）:")
	fmt.Println("     go run tools/encrypt_private_key.go decrypt <master_key_hex> <encrypted_key>")
}

func generateKey() {
	key, err := crypto.GenerateAESKey()
	if err != nil {
		fmt.Printf("错误: 生成密钥失败: %v\n", err)
		os.Exit(1)
	}

	keyHex := hex.EncodeToString(key)
	fmt.Println("====== 新主加密密钥 ======")
	fmt.Println(keyHex)
	fmt.Println("")
	fmt.Println("请将以下配置添加到 .env 文件:")
	fmt.Printf("master_encryption_key=%s\n", keyHex)
	fmt.Println("")
	fmt.Println("⚠️  警告: 请妥善保管此密钥，丢失后无法恢复加密的私钥")
}

func encrypt(masterKeyHex, privateKey string) {
	masterKey, err := hex.DecodeString(masterKeyHex)
	if err != nil || len(masterKey) != 32 {
		fmt.Println("错误: master_key 必须是64位hex字符串（32字节）")
		fmt.Println("请使用 'generate-key' 命令生成新密钥")
		os.Exit(1)
	}

	encrypted, err := crypto.EncryptAES256GCM([]byte(privateKey), masterKey)
	if err != nil {
		fmt.Printf("加密失败: %v\n", err)
		os.Exit(1)
	}

	fmt.Println("====== 加密成功 ======")
	fmt.Println("加密后的私钥:")
	fmt.Println(encrypted)
	fmt.Println("")
	fmt.Println("请将以下配置添加到 .env 文件:")
	fmt.Printf("merchant_private_key_encrypted=%s\n", encrypted)
	fmt.Println("")
	fmt.Println("⚠️  请删除 .env 中的明文私钥配置: merchant_private_key")
}

func decrypt(masterKeyHex, encryptedKey string) {
	masterKey, err := hex.DecodeString(masterKeyHex)
	if err != nil || len(masterKey) != 32 {
		fmt.Println("错误: master_key 必须是64位hex字符串（32字节）")
		os.Exit(1)
	}

	plaintext, err := crypto.DecryptAES256GCM(encryptedKey, masterKey)
	if err != nil {
		fmt.Printf("解密失败: %v\n", err)
		os.Exit(1)
	}

	fmt.Println("====== 解密成功 ======")
	fmt.Println("私钥:")
	fmt.Println(string(plaintext))
}
