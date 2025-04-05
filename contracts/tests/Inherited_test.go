package tests

import (
	"fmt"
	"math/big"
	"os"
	"testing"

	"BRDPoSChain/accounts/abi/bind"
	"BRDPoSChain/accounts/abi/bind/backends"
	"BRDPoSChain/common"
	"BRDPoSChain/core/types"
	"BRDPoSChain/crypto"
	"BRDPoSChain/log"
	"BRDPoSChain/params"
)

var (
	mainKey, _ = crypto.HexToECDSA("b71c71a67e1177ad4e901695e1b4b9ee17ae16c6668d313eac2f96dbcda3f291")
	mainAddr   = crypto.PubkeyToAddress(mainKey.PublicKey)
)

func TestPriceFeed(t *testing.T) {
	glogger := log.NewGlogHandler(log.NewTerminalHandler(os.Stderr, false))
	glogger.Verbosity(log.LevelTrace)
	log.SetDefault(log.NewLogger(glogger))

	common.TIPBRCXCancellationFee = big.NewInt(0)
	// init genesis
	contractBackend := backends.NewBRCSimulatedBackend(
		types.GenesisAlloc{
			mainAddr: {Balance: big.NewInt(0).Mul(big.NewInt(10000000000000), big.NewInt(10000000000000))},
		},
		42000000,
		params.TestBRDPoSMockChainConfig,
	)
	transactOpts := bind.NewKeyedTransactor(mainKey)
	// deploy payer swap SMC
	addr, contract, err := DeployMyInherited(transactOpts, contractBackend)
	if err != nil {
		t.Fatal("can't deploy smart contract: ", err)
	}
	fmt.Println("addr", addr.Hex())
	tx, err := contract.Foo()
	if err != nil {
		t.Fatal("can't run function Foo() in  smart contract: ", err)
	}
	fmt.Println("tx", tx)

}
