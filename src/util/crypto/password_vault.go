package crypto

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"crypto/subtle"
	"encoding/hex"
	"errors"

	"golang.org/x/crypto/argon2"
)

// PasswordVault 密码保险库
type PasswordVault struct {
	EncryptedPassword []byte // AES-256-GCM 加密后的密码
	Nonce             []byte // GCM nonce (12 bytes)
	Salt              []byte // Argon2id salt (16 bytes)
	CustomerWallet    string // 客户钱包地址
}

const (
	// Argon2id 参数
	argon2Time    uint32 = 1       // 迭代次数
	argon2Memory  uint32 = 64 * 1024 // 64 MB
	argon2Threads uint8  = 4       // 4 线程
	argon2KeyLen  uint32 = 32      // 32 bytes (AES-256)

	// Salt 和 Nonce 长度
	saltLength  = 16
	nonceLength = 12
)

// EncryptPassword 加密密码
// 使用 AES-256-GCM + Argon2id 密钥派生
func EncryptPassword(password, customerWallet string, masterKey []byte) (*PasswordVault, error) {
	if len(password) == 0 {
		return nil, errors.New("密码不能为空")
	}
	if len(customerWallet) == 0 {
		return nil, errors.New("钱包地址不能为空")
	}
	if len(masterKey) == 0 {
		return nil, errors.New("主密钥不能为空")
	}

	// 1. 生成随机 salt
	salt := make([]byte, saltLength)
	if _, err := rand.Read(salt); err != nil {
		return nil, err
	}

	// 2. 使用 Argon2id 派生密钥（结合 master key + wallet address）
	keyMaterial := append(masterKey, []byte(customerWallet)...)
	key := argon2.IDKey(keyMaterial, salt, argon2Time, argon2Memory, argon2Threads, argon2KeyLen)

	// 3. AES-256-GCM 加密
	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, err
	}

	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return nil, err
	}

	// 4. 生成随机 nonce
	nonce := make([]byte, gcm.NonceSize())
	if _, err := rand.Read(nonce); err != nil {
		return nil, err
	}

	// 5. 加密
	ciphertext := gcm.Seal(nil, nonce, []byte(password), nil)

	return &PasswordVault{
		EncryptedPassword: ciphertext,
		Nonce:             nonce,
		Salt:              salt,
		CustomerWallet:    customerWallet,
	}, nil
}

// DecryptPassword 解密密码
func DecryptPassword(vault *PasswordVault, masterKey []byte) (string, error) {
	if vault == nil {
		return "", errors.New("密码保险库为空")
	}
	if len(masterKey) == 0 {
		return "", errors.New("主密钥不能为空")
	}

	// 1. 重新派生密钥（必须使用相同的 salt 和 wallet）
	keyMaterial := append(masterKey, []byte(vault.CustomerWallet)...)
	key := argon2.IDKey(keyMaterial, vault.Salt, argon2Time, argon2Memory, argon2Threads, argon2KeyLen)

	// 2. AES-GCM 解密
	block, err := aes.NewCipher(key)
	if err != nil {
		return "", err
	}

	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return "", err
	}

	// 3. 解密
	plaintext, err := gcm.Open(nil, vault.Nonce, vault.EncryptedPassword, nil)
	if err != nil {
		return "", errors.New("密码解密失败")
	}

	return string(plaintext), nil
}

// VerifyPassword 验证密码（常量时间比较，防止时序攻击）
func VerifyPassword(inputPassword, storedPassword string) bool {
	return subtle.ConstantTimeCompare([]byte(inputPassword), []byte(storedPassword)) == 1
}

// GenerateMasterKey 生成主密钥（仅用于首次部署）
func GenerateMasterKey() (string, error) {
	key := make([]byte, 32) // 256 bits
	if _, err := rand.Read(key); err != nil {
		return "", err
	}
	return hex.EncodeToString(key), nil
}

// ParseMasterKey 解析主密钥（从环境变量）
func ParseMasterKey(hexKey string) ([]byte, error) {
	if len(hexKey) != 64 {
		return nil, errors.New("主密钥长度必须为64位十六进制字符串（32字节）")
	}
	return hex.DecodeString(hexKey)
}
