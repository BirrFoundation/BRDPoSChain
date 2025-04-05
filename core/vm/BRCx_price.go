package vm

import (
	"BRDPoSChain/BRCx/tradingstate"
	"BRDPoSChain/common"
	"BRDPoSChain/log"
	"BRDPoSChain/params"
)

const BRCXPriceNumberOfBytesReturn = 32

// BRCxPrice implements a pre-compile contract to get token price in BRCx

type BRCxLastPrice struct {
	tradingStateDB *tradingstate.TradingStateDB
}
type BRCxEpochPrice struct {
	tradingStateDB *tradingstate.TradingStateDB
}

func (t *BRCxLastPrice) RequiredGas(input []byte) uint64 {
	return params.BRCXPriceGas
}

func (t *BRCxLastPrice) Run(input []byte) ([]byte, error) {
	// input includes baseTokenAddress, quoteTokenAddress
	if t.tradingStateDB != nil && len(input) == 64 {
		base := common.BytesToAddress(input[12:32]) // 20 bytes from 13-32
		quote := common.BytesToAddress(input[44:])  // 20 bytes from 45-64
		price := t.tradingStateDB.GetLastPrice(tradingstate.GetTradingOrderBookHash(base, quote))
		if price != nil {
			log.Debug("Run GetLastPrice", "base", base.Hex(), "quote", quote.Hex(), "price", price)
			return common.LeftPadBytes(price.Bytes(), BRCXPriceNumberOfBytesReturn), nil
		}
	}
	return common.LeftPadBytes([]byte{}, BRCXPriceNumberOfBytesReturn), nil
}

func (t *BRCxLastPrice) SetTradingState(tradingStateDB *tradingstate.TradingStateDB) {
	if tradingStateDB != nil {
		t.tradingStateDB = tradingStateDB.Copy()
	} else {
		t.tradingStateDB = nil
	}
}

func (t *BRCxEpochPrice) RequiredGas(input []byte) uint64 {
	return params.BRCXPriceGas
}

func (t *BRCxEpochPrice) Run(input []byte) ([]byte, error) {
	// input includes baseTokenAddress, quoteTokenAddress
	if t.tradingStateDB != nil && len(input) == 64 {
		base := common.BytesToAddress(input[12:32]) // 20 bytes from 13-32
		quote := common.BytesToAddress(input[44:])  // 20 bytes from 45-64
		price := t.tradingStateDB.GetMediumPriceBeforeEpoch(tradingstate.GetTradingOrderBookHash(base, quote))
		if price != nil {
			log.Debug("Run GetEpochPrice", "base", base.Hex(), "quote", quote.Hex(), "price", price)
			return common.LeftPadBytes(price.Bytes(), BRCXPriceNumberOfBytesReturn), nil
		}
	}
	return common.LeftPadBytes([]byte{}, BRCXPriceNumberOfBytesReturn), nil
}

func (t *BRCxEpochPrice) SetTradingState(tradingStateDB *tradingstate.TradingStateDB) {
	if tradingStateDB != nil {
		t.tradingStateDB = tradingStateDB.Copy()
	} else {
		t.tradingStateDB = nil
	}
}
