package BRCx

import (
	"math/big"
	"strings"

	BRDPoSChain "BRDPoSChain"
	"BRDPoSChain/accounts/abi"
	"BRDPoSChain/common"
	"BRDPoSChain/consensus"
	"BRDPoSChain/contracts/BRCx/contract"
	"BRDPoSChain/core"
	"BRDPoSChain/core/state"
	"BRDPoSChain/log"
)

// GetTokenAbi return token abi
func GetTokenAbi() (*abi.ABI, error) {
	contractABI, err := abi.JSON(strings.NewReader(contract.TRC21ABI))
	if err != nil {
		return nil, err
	}
	return &contractABI, nil
}

// RunContract run smart contract
func RunContract(chain consensus.ChainContext, statedb *state.StateDB, contractAddr common.Address, abi *abi.ABI, method string, args ...interface{}) (interface{}, error) {
	input, err := abi.Pack(method)
	if err != nil {
		return nil, err
	}
	fakeCaller := common.HexToAddress("0x0000000000000000000000000000000000000001")
	msg := BRDPoSChain.CallMsg{To: &contractAddr, Data: input, From: fakeCaller}
	result, err := core.CallContractWithState(msg, chain, statedb)
	if err != nil {
		return nil, err
	}
	var unpackResult interface{}
	err = abi.UnpackIntoInterface(&unpackResult, method, result)
	if err != nil {
		return nil, err
	}
	return unpackResult, nil
}

func (BRCx *BRCX) GetTokenDecimal(chain consensus.ChainContext, statedb *state.StateDB, tokenAddr common.Address) (*big.Int, error) {
	if tokenDecimal, ok := BRCx.tokenDecimalCache.Get(tokenAddr); ok && tokenDecimal != nil {
		return tokenDecimal, nil
	}
	if tokenAddr == common.BRCNativeAddressBinary {
		BRCx.tokenDecimalCache.Add(tokenAddr, common.BasePrice)
		return common.BasePrice, nil
	}
	var decimals uint8
	defer func() {
		log.Debug("GetTokenDecimal from ", "relayerSMC", common.RelayerRegistrationSMC, "tokenAddr", tokenAddr.Hex(), "decimals", decimals)
	}()
	contractABI, err := GetTokenAbi()
	if err != nil {
		return nil, err
	}
	stateCopy := statedb.Copy()
	result, err := RunContract(chain, stateCopy, tokenAddr, contractABI, "decimals")
	if err != nil {
		return nil, err
	}
	decimals = result.(uint8)

	tokenDecimal := new(big.Int).SetUint64(0).Exp(big.NewInt(10), big.NewInt(int64(decimals)), nil)
	BRCx.tokenDecimalCache.Add(tokenAddr, tokenDecimal)
	return tokenDecimal, nil
}

// FIXME: using in unit tests only
func (BRCx *BRCX) SetTokenDecimal(token common.Address, decimal *big.Int) {
	BRCx.tokenDecimalCache.Add(token, decimal)
}
