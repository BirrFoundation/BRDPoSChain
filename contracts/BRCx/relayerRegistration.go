package BRCx

import (
	"math/big"

	"BRDPoSChain/accounts/abi/bind"
	"BRDPoSChain/common"
	"BRDPoSChain/contracts/BRCx/contract"
)

type RelayerRegistration struct {
	*contract.RelayerRegistrationSession
	contractBackend bind.ContractBackend
}

func NewRelayerRegistration(transactOpts *bind.TransactOpts, contractAddr common.Address, contractBackend bind.ContractBackend) (*RelayerRegistration, error) {
	smartContract, err := contract.NewRelayerRegistration(contractAddr, contractBackend)
	if err != nil {
		return nil, err
	}

	return &RelayerRegistration{
		&contract.RelayerRegistrationSession{
			Contract:     smartContract,
			TransactOpts: *transactOpts,
		},
		contractBackend,
	}, nil
}

func DeployRelayerRegistration(transactOpts *bind.TransactOpts, contractBackend bind.ContractBackend, BRCxListing common.Address, maxRelayers *big.Int, maxTokenList *big.Int, minDeposit *big.Int) (common.Address, *RelayerRegistration, error) {
	contractAddr, _, _, err := contract.DeployRelayerRegistration(transactOpts, contractBackend, BRCxListing, maxRelayers, maxTokenList, minDeposit)
	if err != nil {
		return contractAddr, nil, err
	}
	smartContract, err := NewRelayerRegistration(transactOpts, contractAddr, contractBackend)
	if err != nil {
		return contractAddr, nil, err
	}

	return contractAddr, smartContract, nil
}
