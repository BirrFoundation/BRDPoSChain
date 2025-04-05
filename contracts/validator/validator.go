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

package validator

import (
	"math/big"

	"BRDPoSChain/accounts/abi/bind"
	"BRDPoSChain/common"
	"BRDPoSChain/contracts/validator/contract"
)

type Validator struct {
	*contract.BRCValidatorSession
	contractBackend bind.ContractBackend
}

func NewValidator(transactOpts *bind.TransactOpts, contractAddr common.Address, contractBackend bind.ContractBackend) (*Validator, error) {
	validator, err := contract.NewBRCValidator(contractAddr, contractBackend)
	if err != nil {
		return nil, err
	}

	return &Validator{
		&contract.BRCValidatorSession{
			Contract:     validator,
			TransactOpts: *transactOpts,
		},
		contractBackend,
	}, nil
}

func DeployValidator(transactOpts *bind.TransactOpts, contractBackend bind.ContractBackend, validatorAddress []common.Address, caps []*big.Int, ownerAddress common.Address) (common.Address, *Validator, error) {
	minDeposit := new(big.Int)
	minDeposit.SetString("10000000000000000000000000", 10)
	minVoterCap := new(big.Int)
	minVoterCap.SetString("25000000000000000000000", 10)
	// Deposit 50K BRC
	// Min Voter Cap 10 BRC
	// 150 masternodes
	// Candidate Delay Withdraw 30 days = 1296000 blocks
	// Voter Delay Withdraw 10 days = 432000 blocks
	validatorAddr, _, _, err := contract.DeployBRCValidator(transactOpts, contractBackend, validatorAddress, caps, ownerAddress, minDeposit, minVoterCap, big.NewInt(18), big.NewInt(1296000), big.NewInt(432000))
	if err != nil {
		return validatorAddr, nil, err
	}

	validator, err := NewValidator(transactOpts, validatorAddr, contractBackend)
	if err != nil {
		return validatorAddr, nil, err
	}

	return validatorAddr, validator, nil
}
