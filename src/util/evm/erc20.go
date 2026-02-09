package evm

import (
	"strings"

	"github.com/ethereum/go-ethereum/accounts/abi"
)

const erc20ABIJson = `[
  {
    "constant": true,
    "inputs": [
      {"name": "owner", "type": "address"},
      {"name": "spender", "type": "address"}
    ],
    "name": "allowance",
    "outputs": [{"name": "", "type": "uint256"}],
    "type": "function"
  },
  {
    "constant": false,
    "inputs": [
      {"name": "from", "type": "address"},
      {"name": "to", "type": "address"},
      {"name": "value", "type": "uint256"}
    ],
    "name": "transferFrom",
    "outputs": [{"name": "", "type": "bool"}],
    "type": "function"
  }
]`

func mustParseErc20Abi() abi.ABI {
	parsed, err := abi.JSON(strings.NewReader(erc20ABIJson))
	if err != nil {
		panic(err)
	}
	return parsed
}
