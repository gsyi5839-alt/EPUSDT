package chain

import (
	"errors"
	"regexp"
	"strings"

	"github.com/assimon/luuu/util/tron"
)

const (
	ChainTron    = "TRON"
	ChainEvm     = "EVM"
	ChainBsc     = "BSC"
	ChainPolygon = "POLYGON"
)

var evmAddressRe = regexp.MustCompile("^0x[0-9a-fA-F]{40}$")

func NormalizeChain(c string) string {
	switch strings.ToUpper(strings.TrimSpace(c)) {
	case "TRON", "TRC20":
		return ChainTron
	case "BSC", "BEP20":
		return ChainBsc
	case "POLYGON", "MATIC":
		return ChainPolygon
	case "EVM", "ETH", "ETHEREUM":
		return ChainEvm
	default:
		return strings.ToUpper(strings.TrimSpace(c))
	}
}

func IsSupported(c string) bool {
	switch NormalizeChain(c) {
	case ChainTron, ChainEvm, ChainBsc, ChainPolygon:
		return true
	default:
		return false
	}
}

func IsTronChain(c string) bool {
	return NormalizeChain(c) == ChainTron
}

func IsEvmChain(c string) bool {
	switch NormalizeChain(c) {
	case ChainEvm, ChainBsc, ChainPolygon:
		return true
	default:
		return false
	}
}

func ValidateAddress(chainName, address string) error {
	chainName = NormalizeChain(chainName)
	switch chainName {
	case ChainTron:
		if !tron.IsValidTronAddress(address) {
			return errors.New("TRON地址无效")
		}
		return nil
	case ChainEvm, ChainBsc, ChainPolygon:
		if !evmAddressRe.MatchString(address) {
			return errors.New("EVM地址无效")
		}
		return nil
	default:
		return errors.New("不支持的链")
	}
}
