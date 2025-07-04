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

package blocksigner

import (
	"context"
	"math/big"
	"math/rand"
	"testing"
	"time"

	"BRDPoSChain/accounts/abi/bind"
	"BRDPoSChain/accounts/abi/bind/backends"
	"BRDPoSChain/common"
	"BRDPoSChain/common/hexutil"
	"BRDPoSChain/core/types"
	"BRDPoSChain/crypto"
	"BRDPoSChain/params"
)

var (
	key, _ = crypto.HexToECDSA("b71c71a67e1177ad4e901695e1b4b9ee17ae16c6668d313eac2f96dbcda3f291")
	addr   = crypto.PubkeyToAddress(key.PublicKey)
)

func TestBlockSigner(t *testing.T) {
	contractBackend := backends.NewBRCSimulatedBackend(types.GenesisAlloc{addr: {Balance: big.NewInt(1000000000)}}, 10000000, params.TestBRDPoSMockChainConfig)
	transactOpts := bind.NewKeyedTransactor(key)

	blockSignerAddress, blockSigner, err := DeployBlockSigner(transactOpts, contractBackend, big.NewInt(99))
	if err != nil {
		t.Fatalf("can't deploy root registry: %v", err)
	}
	contractBackend.Commit()

	d := time.Now().Add(1000 * time.Millisecond)
	ctx, cancel := context.WithDeadline(context.Background(), d)
	defer cancel()
	code, _ := contractBackend.CodeAt(ctx, blockSignerAddress, nil)
	t.Log("contract code", hexutil.Encode(code))
	f := func(key, val common.Hash) bool {
		t.Log(key.Hex(), val.Hex())
		return true
	}
	contractBackend.ForEachStorageAt(ctx, blockSignerAddress, nil, f)

	byte0 := randomHash()

	// Test sign.
	tx, err := blockSigner.Sign(big.NewInt(2), byte0)
	if err != nil {
		t.Fatalf("can't sign: %v", err)
	}
	contractBackend.Commit()
	t.Log("tx", tx)

	signers, err := blockSigner.GetSigners(byte0)
	if err != nil {
		t.Fatalf("can't get candidates: %v", err)
	}
	for _, it := range signers {
		t.Log("signer", it.String())
	}
}

// Generate random string.
func randomHash() common.Hash {
	letterBytes := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ123456789"
	var b common.Hash
	for i := range b {
		rand.Seed(time.Now().UnixNano())
		b[i] = letterBytes[rand.Intn(len(letterBytes))]
	}
	return b
}
