// Copyright (c) 2018 BRDPoSChain
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Lesser General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with this program. If not, see <http://www.gnu.org/licenses/>.

package core

import (
	"fmt"
	"math/big"
	"math/rand"
	"strings"

	ethereum "BRDPoSChain"
	"BRDPoSChain/accounts/abi"
	"BRDPoSChain/common"
	"BRDPoSChain/consensus"
	"BRDPoSChain/contracts/BRCx/contract"
	"BRDPoSChain/core/state"
	"BRDPoSChain/core/types"
	"BRDPoSChain/core/vm"
	"BRDPoSChain/log"
)

const (
	balanceOfFunction  = "balanceOf"
	minFeeFunction     = "minFee"
	getDecimalFunction = "decimals"
)

// callMsg implements core.Message to allow passing it as a transaction simulator.
type callMsg struct {
	ethereum.CallMsg
}

func (m callMsg) From() common.Address         { return m.CallMsg.From }
func (m callMsg) Nonce() uint64                { return 0 }
func (m callMsg) IsFake() bool                 { return true }
func (m callMsg) To() *common.Address          { return m.CallMsg.To }
func (m callMsg) GasPrice() *big.Int           { return m.CallMsg.GasPrice }
func (m callMsg) GasFeeCap() *big.Int          { return m.CallMsg.GasFeeCap }
func (m callMsg) GasTipCap() *big.Int          { return m.CallMsg.GasTipCap }
func (m callMsg) Gas() uint64                  { return m.CallMsg.Gas }
func (m callMsg) Value() *big.Int              { return m.CallMsg.Value }
func (m callMsg) Data() []byte                 { return m.CallMsg.Data }
func (m callMsg) BalanceTokenFee() *big.Int    { return m.CallMsg.BalanceTokenFee }
func (m callMsg) AccessList() types.AccessList { return m.CallMsg.AccessList }

type SimulatedBackend interface {
	CallContractWithState(call ethereum.CallMsg, chain consensus.ChainContext, statedb *state.StateDB) ([]byte, error)
}

// GetTokenAbi return token abi
func GetTokenAbi(tokenAbi string) (*abi.ABI, error) {
	contractABI, err := abi.JSON(strings.NewReader(tokenAbi))
	if err != nil {
		return nil, err
	}
	return &contractABI, nil
}

// RunContract run smart contract
func RunContract(chain consensus.ChainContext, statedb *state.StateDB, contractAddr common.Address, abi *abi.ABI, method string, args ...interface{}) (interface{}, error) {
	input, err := abi.Pack(method, args...)
	if err != nil {
		return nil, err
	}
	fakeCaller := common.HexToAddress("0x0000000000000000000000000000000000000001")
	statedb.SetBalance(fakeCaller, common.BasePrice)
	msg := ethereum.CallMsg{To: &contractAddr, Data: input, From: fakeCaller}
	result, err := CallContractWithState(msg, chain, statedb)
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

// FIXME: please use copyState for this function
// CallContractWithState executes a contract call at the given state.
func CallContractWithState(call ethereum.CallMsg, chain consensus.ChainContext, statedb *state.StateDB) ([]byte, error) {
	// Ensure message is initialized properly.
	call.GasPrice = big.NewInt(0)

	if call.Gas == 0 {
		call.Gas = 1000000
	}
	if call.Value == nil {
		call.Value = new(big.Int)
	}
	// Execute the call.
	msg := callMsg{call}
	feeCapacity := state.GetTRC21FeeCapacityFromState(statedb)
	if msg.To() != nil {
		if value, ok := feeCapacity[*msg.To()]; ok {
			msg.CallMsg.BalanceTokenFee = value
		}
	}
	txContext := NewEVMTxContext(msg)
	evmContext := NewEVMBlockContext(chain.CurrentHeader(), chain, nil)
	// Create a new environment which holds all relevant information
	// about the transaction and calling mechanisms.
	vmenv := vm.NewEVM(evmContext, txContext, statedb, nil, chain.Config(), vm.Config{})
	gaspool := new(GasPool).AddGas(1000000)
	owner := common.Address{}
	result, err := NewStateTransition(vmenv, msg, gaspool).TransitionDb(owner)
	if err != nil {
		return nil, err
	}
	return result.Return(), err
}

// make sure that balance of token is at slot 0
func ValidateBRCXApplyTransaction(chain consensus.ChainContext, blockNumber *big.Int, copyState *state.StateDB, tokenAddr common.Address) error {
	if blockNumber == nil || blockNumber.Sign() <= 0 {
		blockNumber = chain.CurrentHeader().Number
	}
	if !chain.Config().IsTIPBRCXReceiver(blockNumber) {
		return nil
	}
	contractABI, err := GetTokenAbi(contract.TRC21ABI)
	if err != nil {
		return fmt.Errorf("ValidateBRCXApplyTransaction: cannot parse ABI. Err: %v", err)
	}
	if err := ValidateBalanceSlot(chain, copyState, tokenAddr, contractABI); err != nil {
		return err
	}
	if err := ValidateTokenDecimal(chain, copyState, tokenAddr, contractABI); err != nil {
		return err
	}
	return nil
}

// make sure that balance of token is at slot 0
// make sure that minFee of token is at slot 1
func ValidateBRCZApplyTransaction(chain consensus.ChainContext, blockNumber *big.Int, copyState *state.StateDB, tokenAddr common.Address) error {
	if blockNumber == nil || blockNumber.Sign() <= 0 {
		blockNumber = chain.CurrentHeader().Number
	}
	if !chain.Config().IsTIPBRCXReceiver(blockNumber) {
		return nil
	}
	contractABI, err := GetTokenAbi(contract.TRC21ABI)
	if err != nil {
		return fmt.Errorf("ValidateBRCZApplyTransaction: cannot parse ABI. Err: %v", err)
	}
	// verify balance slot
	if err := ValidateBalanceSlot(chain, copyState, tokenAddr, contractABI); err != nil {
		return err
	}

	// validate minFee slot
	if err := ValidateMinFeeSlot(chain, copyState, tokenAddr, contractABI); err != nil {
		return err
	}
	return nil
}

func SetRandomBalance(copyState *state.StateDB, tokenAddr, addr common.Address, randomValue *big.Int) {
	slotBalanceTrc21 := state.SlotTRC21Token["balances"]
	balanceKey := state.GetLocMappingAtKey(addr.Hash(), slotBalanceTrc21)
	copyState.SetState(tokenAddr, common.BigToHash(balanceKey), common.BytesToHash(randomValue.Bytes()))
}

func ValidateBalanceSlot(chain consensus.ChainContext, copyState *state.StateDB, tokenAddr common.Address, contractABI *abi.ABI) error {
	randBalance := new(big.Int).SetInt64(int64(rand.Intn(1000000000)))
	addr := common.HexToAddress("0x0000000000000000000000000000000000000123")
	SetRandomBalance(copyState, tokenAddr, addr, randBalance)
	result, err := RunContract(chain, copyState, tokenAddr, contractABI, balanceOfFunction, addr)

	if err != nil || result == nil {
		return fmt.Errorf("cannot get balance at slot %v . Token: %s . Err: %v", state.SlotTRC21Token["balances"], tokenAddr.Hex(), err)
	}
	balance, ok := result.(*big.Int)
	if !ok {
		return fmt.Errorf("invalid balance at slot %v . Token: %s . GotBalance: %v . ResultType: %T", state.SlotTRC21Token["balances"], tokenAddr.Hex(), result, result)
	}
	if balance.Cmp(randBalance) != 0 {
		log.Debug("invalid balance slot", "balance_set_at_slot_0", randBalance, "balance_get_from_abi", balance)
		return fmt.Errorf("invalid balance slot. Token: %s", tokenAddr.Hex())
	}
	return nil
}

func ValidateMinFeeSlot(chain consensus.ChainContext, copyState *state.StateDB, tokenAddr common.Address, contractABI *abi.ABI) error {
	randomValue := new(big.Int).SetInt64(int64(rand.Intn(1000000000)))
	slotMinFeeTrc21 := state.SlotTRC21Token["minFee"]
	copyState.SetState(tokenAddr, common.BigToHash(new(big.Int).SetUint64(slotMinFeeTrc21)), common.BytesToHash(randomValue.Bytes()))

	result, err := RunContract(chain, copyState, tokenAddr, contractABI, minFeeFunction)
	if err != nil || result == nil {
		return fmt.Errorf("cannot get minFee at slot %v . Token: %s. Err: %v", state.SlotTRC21Token["minFee"], tokenAddr.Hex(), err)
	}
	minFee, ok := result.(*big.Int)
	if !ok {
		return fmt.Errorf("invalid minFee at slot %v . Token: %s . GotMinFee: %v . ResultType: %T", state.SlotTRC21Token["minFee"], tokenAddr.Hex(), result, result)
	}
	if minFee.Cmp(randomValue) != 0 {
		log.Debug("invalid minFee slot", "minFee_set_at_slot_1", randomValue, "minFee_get_from_abi", minFee)
		return fmt.Errorf("invalid minFee slot. Token: %s", tokenAddr.Hex())
	}
	return nil
}

func ValidateTokenDecimal(chain consensus.ChainContext, copyState *state.StateDB, tokenAddr common.Address, contractABI *abi.ABI) error {
	result, err := RunContract(chain, copyState, tokenAddr, contractABI, getDecimalFunction)
	if err != nil || result == nil {
		return fmt.Errorf("cannot get token decimal. Token: %s . Err: %v", tokenAddr.Hex(), err)
	}
	return nil
}
