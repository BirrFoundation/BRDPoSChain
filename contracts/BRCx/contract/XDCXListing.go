// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package contract

import (
	"strings"

	"BRDPoSChain/accounts/abi"
	"BRDPoSChain/accounts/abi/bind"
	"BRDPoSChain/common"
	"BRDPoSChain/core/types"
)

// BRCXListingABI is the input ABI used to generate the binding from.
const BRCXListingABI = "[{\"constant\":true,\"inputs\":[],\"name\":\"tokens\",\"outputs\":[{\"name\":\"\",\"type\":\"address[]\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[{\"name\":\"token\",\"type\":\"address\"}],\"name\":\"getTokenStatus\",\"outputs\":[{\"name\":\"\",\"type\":\"bool\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"name\":\"token\",\"type\":\"address\"}],\"name\":\"apply\",\"outputs\":[],\"payable\":true,\"stateMutability\":\"payable\",\"type\":\"function\"}]"

// BRCXListingBin is the compiled bytecode used for deploying new contracts.
const BRCXListingBin = `0x608060405234801561001057600080fd5b506102be806100206000396000f3006080604052600436106100565763ffffffff7c01000000000000000000000000000000000000000000000000000000006000350416639d63848a811461005b578063a3ff31b5146100c0578063c6b32f34146100f5575b600080fd5b34801561006757600080fd5b5061007061010b565b60408051602080825283518183015283519192839290830191858101910280838360005b838110156100ac578181015183820152602001610094565b505050509050019250505060405180910390f35b3480156100cc57600080fd5b506100e1600160a060020a036004351661016d565b604080519115158252519081900360200190f35b610109600160a060020a036004351661018b565b005b6060600080548060200260200160405190810160405280929190818152602001828054801561016357602002820191906000526020600020905b8154600160a060020a03168152600190910190602001808311610145575b5050505050905090565b600160a060020a031660009081526001602052604090205460ff1690565b80600160a060020a03811615156101a157600080fd5b600160a060020a03811660009081526001602081905260409091205460ff16151514156101cd57600080fd5b683635c9adc5dea0000034146101e257600080fd5b6040516068903480156108fc02916000818181858888f1935050505015801561020f573d6000803e3d6000fd5b505060008054600180820183557f290decd9548b62a8d60345a988386fc84ba6bc95484008f6362f93160ef3e563909101805473ffffffffffffffffffffffffffffffffffffffff1916600160a060020a039490941693841790556040805160208082018352838252948452919093529190209051815460ff19169015151790555600a165627a7a723058206d2dc0ce827743c25efa82f99e7830ade39d28e17f4d651573f89e0460a6626a0029`

// DeployBRCXListing deploys a new Ethereum contract, binding an instance of BRCXListing to it.
func DeployBRCXListing(auth *bind.TransactOpts, backend bind.ContractBackend) (common.Address, *types.Transaction, *BRCXListing, error) {
	parsed, err := abi.JSON(strings.NewReader(BRCXListingABI))
	if err != nil {
		return common.Address{}, nil, nil, err
	}
	address, tx, contract, err := bind.DeployContract(auth, parsed, common.FromHex(BRCXListingBin), backend)
	if err != nil {
		return common.Address{}, nil, nil, err
	}
	return address, tx, &BRCXListing{BRCXListingCaller: BRCXListingCaller{contract: contract}, BRCXListingTransactor: BRCXListingTransactor{contract: contract}, BRCXListingFilterer: BRCXListingFilterer{contract: contract}}, nil
}

// BRCXListing is an auto generated Go binding around an Ethereum contract.
type BRCXListing struct {
	BRCXListingCaller     // Read-only binding to the contract
	BRCXListingTransactor // Write-only binding to the contract
	BRCXListingFilterer   // Log filterer for contract events
}

// BRCXListingCaller is an auto generated read-only Go binding around an Ethereum contract.
type BRCXListingCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// BRCXListingTransactor is an auto generated write-only Go binding around an Ethereum contract.
type BRCXListingTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// BRCXListingFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type BRCXListingFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// BRCXListingSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type BRCXListingSession struct {
	Contract     *BRCXListing      // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// BRCXListingCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type BRCXListingCallerSession struct {
	Contract *BRCXListingCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts      // Call options to use throughout this session
}

// BRCXListingTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type BRCXListingTransactorSession struct {
	Contract     *BRCXListingTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts      // Transaction auth options to use throughout this session
}

// BRCXListingRaw is an auto generated low-level Go binding around an Ethereum contract.
type BRCXListingRaw struct {
	Contract *BRCXListing // Generic contract binding to access the raw methods on
}

// BRCXListingCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type BRCXListingCallerRaw struct {
	Contract *BRCXListingCaller // Generic read-only contract binding to access the raw methods on
}

// BRCXListingTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type BRCXListingTransactorRaw struct {
	Contract *BRCXListingTransactor // Generic write-only contract binding to access the raw methods on
}

// NewBRCXListing creates a new instance of BRCXListing, bound to a specific deployed contract.
func NewBRCXListing(address common.Address, backend bind.ContractBackend) (*BRCXListing, error) {
	contract, err := bindBRCXListing(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &BRCXListing{BRCXListingCaller: BRCXListingCaller{contract: contract}, BRCXListingTransactor: BRCXListingTransactor{contract: contract}, BRCXListingFilterer: BRCXListingFilterer{contract: contract}}, nil
}

// NewBRCXListingCaller creates a new read-only instance of BRCXListing, bound to a specific deployed contract.
func NewBRCXListingCaller(address common.Address, caller bind.ContractCaller) (*BRCXListingCaller, error) {
	contract, err := bindBRCXListing(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &BRCXListingCaller{contract: contract}, nil
}

// NewBRCXListingTransactor creates a new write-only instance of BRCXListing, bound to a specific deployed contract.
func NewBRCXListingTransactor(address common.Address, transactor bind.ContractTransactor) (*BRCXListingTransactor, error) {
	contract, err := bindBRCXListing(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &BRCXListingTransactor{contract: contract}, nil
}

// NewBRCXListingFilterer creates a new log filterer instance of BRCXListing, bound to a specific deployed contract.
func NewBRCXListingFilterer(address common.Address, filterer bind.ContractFilterer) (*BRCXListingFilterer, error) {
	contract, err := bindBRCXListing(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &BRCXListingFilterer{contract: contract}, nil
}

// bindBRCXListing binds a generic wrapper to an already deployed contract.
func bindBRCXListing(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := abi.JSON(strings.NewReader(BRCXListingABI))
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_BRCXListing *BRCXListingRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _BRCXListing.Contract.BRCXListingCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_BRCXListing *BRCXListingRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _BRCXListing.Contract.BRCXListingTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_BRCXListing *BRCXListingRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _BRCXListing.Contract.BRCXListingTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_BRCXListing *BRCXListingCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _BRCXListing.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_BRCXListing *BRCXListingTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _BRCXListing.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_BRCXListing *BRCXListingTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _BRCXListing.Contract.contract.Transact(opts, method, params...)
}

// GetTokenStatus is a free data retrieval call binding the contract method 0xa3ff31b5.
//
// Solidity: function getTokenStatus(token address) constant returns(bool)
func (_BRCXListing *BRCXListingCaller) GetTokenStatus(opts *bind.CallOpts, token common.Address) (bool, error) {
	var (
		ret0 = new(bool)
	)
	out := &[]interface{}{
		ret0,
	}
	err := _BRCXListing.contract.Call(opts, out, "getTokenStatus", token)
	return *ret0, err
}

// GetTokenStatus is a free data retrieval call binding the contract method 0xa3ff31b5.
//
// Solidity: function getTokenStatus(token address) constant returns(bool)
func (_BRCXListing *BRCXListingSession) GetTokenStatus(token common.Address) (bool, error) {
	return _BRCXListing.Contract.GetTokenStatus(&_BRCXListing.CallOpts, token)
}

// GetTokenStatus is a free data retrieval call binding the contract method 0xa3ff31b5.
//
// Solidity: function getTokenStatus(token address) constant returns(bool)
func (_BRCXListing *BRCXListingCallerSession) GetTokenStatus(token common.Address) (bool, error) {
	return _BRCXListing.Contract.GetTokenStatus(&_BRCXListing.CallOpts, token)
}

// Tokens is a free data retrieval call binding the contract method 0x9d63848a.
//
// Solidity: function tokens() constant returns(address[])
func (_BRCXListing *BRCXListingCaller) Tokens(opts *bind.CallOpts) ([]common.Address, error) {
	var (
		ret0 = new([]common.Address)
	)
	out := &[]interface{}{
		ret0,
	}
	err := _BRCXListing.contract.Call(opts, out, "tokens")
	return *ret0, err
}

// Tokens is a free data retrieval call binding the contract method 0x9d63848a.
//
// Solidity: function tokens() constant returns(address[])
func (_BRCXListing *BRCXListingSession) Tokens() ([]common.Address, error) {
	return _BRCXListing.Contract.Tokens(&_BRCXListing.CallOpts)
}

// Tokens is a free data retrieval call binding the contract method 0x9d63848a.
//
// Solidity: function tokens() constant returns(address[])
func (_BRCXListing *BRCXListingCallerSession) Tokens() ([]common.Address, error) {
	return _BRCXListing.Contract.Tokens(&_BRCXListing.CallOpts)
}

// Apply is a paid mutator transaction binding the contract method 0xc6b32f34.
//
// Solidity: function apply(token address) returns()
func (_BRCXListing *BRCXListingTransactor) Apply(opts *bind.TransactOpts, token common.Address) (*types.Transaction, error) {
	return _BRCXListing.contract.Transact(opts, "apply", token)
}

// Apply is a paid mutator transaction binding the contract method 0xc6b32f34.
//
// Solidity: function apply(token address) returns()
func (_BRCXListing *BRCXListingSession) Apply(token common.Address) (*types.Transaction, error) {
	return _BRCXListing.Contract.Apply(&_BRCXListing.TransactOpts, token)
}

// Apply is a paid mutator transaction binding the contract method 0xc6b32f34.
//
// Solidity: function apply(token address) returns()
func (_BRCXListing *BRCXListingTransactorSession) Apply(token common.Address) (*types.Transaction, error) {
	return _BRCXListing.Contract.Apply(&_BRCXListing.TransactOpts, token)
}
