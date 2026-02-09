package tron

import (
	"crypto/sha256"
	"encoding/hex"
	"errors"

	"github.com/btcsuite/btcutil/base58"
)

// IsValidTronAddress 校验 Tron Base58Check 地址是否合法
func IsValidTronAddress(addr string) bool {
	if len(addr) < 26 || len(addr) > 35 || addr[0] != 'T' {
		return false
	}

	decoded := base58.Decode(addr)
	if len(decoded) != 25 {
		return false
	}

	// TRON 主网地址必须以 0x41 开头
	if decoded[0] != 0x41 {
		return false
	}

	payload := decoded[:21]
	checksum := decoded[21:]

	hash := sha256.Sum256(payload)
	hash2 := sha256.Sum256(hash[:])

	return string(checksum) == string(hash2[:4])
}

// AddressToHex 将 Tron Base58Check 地址转换为 32 字节参数 hex
func AddressToHex(address string) (string, error) {
	if !IsValidTronAddress(address) {
		return "", errors.New("invalid tron address")
	}

	decoded := base58.Decode(address)
	if len(decoded) != 25 {
		return "", errors.New("invalid tron address length")
	}

	// 去掉前缀 0x41，取 20 字节地址
	raw := decoded[1:21]
	return leftPadHex(hex.EncodeToString(raw), 64), nil
}

func leftPadHex(hexStr string, length int) string {
	for len(hexStr) < length {
		hexStr = "0" + hexStr
	}
	return hexStr
}
