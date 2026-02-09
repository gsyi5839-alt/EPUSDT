package crypto

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"encoding/base64"
	"errors"
	"io"
)

// EncryptAES256GCM 使用 AES-256-GCM 加密数据
// 参数:
//   - plaintext: 要加密的明文数据
//   - key: 32字节的加密密钥
// 返回:
//   - 加密后的 base64 编码字符串（包含 nonce + ciphertext + tag）
func EncryptAES256GCM(plaintext, key []byte) (string, error) {
	if len(key) != 32 {
		return "", errors.New("密钥长度必须为32字节")
	}

	block, err := aes.NewCipher(key)
	if err != nil {
		return "", err
	}

	aesGCM, err := cipher.NewGCM(block)
	if err != nil {
		return "", err
	}

	// 生成随机 nonce（12字节）
	nonce := make([]byte, aesGCM.NonceSize())
	if _, err := io.ReadFull(rand.Reader, nonce); err != nil {
		return "", err
	}

	// 加密（nonce + ciphertext + tag）
	ciphertext := aesGCM.Seal(nonce, nonce, plaintext, nil)
	return base64.StdEncoding.EncodeToString(ciphertext), nil
}

// DecryptAES256GCM 解密 AES-256-GCM 数据
// 参数:
//   - ciphertext: base64 编码的加密数据
//   - key: 32字节的解密密钥
// 返回:
//   - 解密后的明文数据
func DecryptAES256GCM(ciphertext string, key []byte) ([]byte, error) {
	if len(key) != 32 {
		return nil, errors.New("密钥长度必须为32字节")
	}

	data, err := base64.StdEncoding.DecodeString(ciphertext)
	if err != nil {
		return nil, err
	}

	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, err
	}

	aesGCM, err := cipher.NewGCM(block)
	if err != nil {
		return nil, err
	}

	nonceSize := aesGCM.NonceSize()
	if len(data) < nonceSize {
		return nil, errors.New("密文格式错误")
	}

	nonce, ciphertextBytes := data[:nonceSize], data[nonceSize:]
	plaintext, err := aesGCM.Open(nil, nonce, ciphertextBytes, nil)
	if err != nil {
		return nil, errors.New("解密失败：密钥错误或数据已损坏")
	}

	return plaintext, nil
}

// GenerateAESKey 生成32字节随机密钥
func GenerateAESKey() ([]byte, error) {
	key := make([]byte, 32)
	_, err := rand.Read(key)
	return key, err
}
