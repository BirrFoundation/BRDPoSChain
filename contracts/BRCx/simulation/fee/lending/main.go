package main

import (
	"BRDPoSChain/contracts/BRCx/simulation"
	"context"
	"fmt"
	"math/big"
	"os"
	"strconv"
	"time"

	"BRDPoSChain/accounts/abi/bind"
	"BRDPoSChain/common"
	"BRDPoSChain/contracts/BRCx"
	"BRDPoSChain/crypto"
	"BRDPoSChain/ethclient"
)

func main() {
	client, err := ethclient.Dial(simulation.RpcEndpoint)
	if err != nil {
		fmt.Println(err, client)
	}

	MainKey, _ := crypto.HexToECDSA(os.Getenv("OWNER_KEY"))
	MainAddr := crypto.PubkeyToAddress(MainKey.PublicKey)
	coinbase := common.HexToAddress(os.Getenv("RELAYER_COINBASE"))
	fee, _ := strconv.Atoi(os.Getenv("FEE"))

	nonce, _ := client.NonceAt(context.Background(), MainAddr, nil)
	auth := bind.NewKeyedTransactor(MainKey)
	auth.Value = big.NewInt(0)      // in wei
	auth.GasLimit = uint64(4000000) // in units
	auth.GasPrice = big.NewInt(250000000000000)

	auth.Nonce = big.NewInt(int64(nonce))

	lendContract, _ := BRCx.NewLendingRelayerRegistration(auth, common.HexToAddress("0x4d7eA2cE949216D6b120f3AA10164173615A2b6C"), client)

	tx, err := lendContract.UpdateFee(coinbase, uint16(fee))
	if err != nil {
		fmt.Println("UpdateFee: failed!", err)
	}

	time.Sleep(5 * time.Second)
	r, err := client.TransactionReceipt(context.Background(), tx.Hash())
	if err != nil {
		fmt.Println("UpdateFee: Get receipt failed", err)
	}
	fmt.Println("UpdateFee: Done receipt status", r.Status)

}
