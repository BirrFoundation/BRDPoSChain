package BRCx

import (
	"BRDPoSChain/accounts/abi/bind"
	"BRDPoSChain/common"
	"BRDPoSChain/contracts/BRCx/contract"
)

type BRCXListing struct {
	*contract.BRCXListingSession
	contractBackend bind.ContractBackend
}

func NewMyBRCXListing(transactOpts *bind.TransactOpts, contractAddr common.Address, contractBackend bind.ContractBackend) (*BRCXListing, error) {
	smartContract, err := contract.NewBRCXListing(contractAddr, contractBackend)
	if err != nil {
		return nil, err
	}

	return &BRCXListing{
		&contract.BRCXListingSession{
			Contract:     smartContract,
			TransactOpts: *transactOpts,
		},
		contractBackend,
	}, nil
}

func DeployBRCXListing(transactOpts *bind.TransactOpts, contractBackend bind.ContractBackend) (common.Address, *BRCXListing, error) {
	contractAddr, _, _, err := contract.DeployBRCXListing(transactOpts, contractBackend)
	if err != nil {
		return contractAddr, nil, err
	}
	smartContract, err := NewMyBRCXListing(transactOpts, contractAddr, contractBackend)
	if err != nil {
		return contractAddr, nil, err
	}

	return contractAddr, smartContract, nil
}
