// Copyright 2016 The go-ethereum Authors
// This file is part of the go-ethereum library.
//
// The go-ethereum library is free software: you can redistribute it and/or modify
// it under the terms of the GNU Lesser General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// The go-ethereum library is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.

package les

import (
	"encoding/binary"
	"math/big"
	"math/rand"
	"testing"
	"time"

	"BRDPoSChain/common"
	"BRDPoSChain/consensus/ethash"
	"BRDPoSChain/core"
	"BRDPoSChain/core/rawdb"
	"BRDPoSChain/core/txpool"
	"BRDPoSChain/core/types"
	"BRDPoSChain/crypto"
	"BRDPoSChain/eth/downloader"
	"BRDPoSChain/light"
	"BRDPoSChain/p2p"
	"BRDPoSChain/params"
	"BRDPoSChain/rlp"
	"BRDPoSChain/trie"
)

func expectResponse(r p2p.MsgReader, msgcode, reqID, bv uint64, data interface{}) error {
	type resp struct {
		ReqID, BV uint64
		Data      interface{}
	}
	return p2p.ExpectMsg(r, msgcode, resp{reqID, bv, data})
}

// Tests that block headers can be retrieved from a remote chain based on user queries.
func TestGetBlockHeadersLes1(t *testing.T) { testGetBlockHeaders(t, 1) }
func TestGetBlockHeadersLes2(t *testing.T) { testGetBlockHeaders(t, 2) }

func testGetBlockHeaders(t *testing.T, protocol int) {
	db := rawdb.NewMemoryDatabase()
	pm := newTestProtocolManagerMust(t, false, downloader.MaxHashFetch+15, nil, nil, nil, db)
	bc := pm.blockchain.(*core.BlockChain)
	peer, _ := newTestPeer(t, "peer", protocol, pm, true)
	defer peer.close()

	// Create a "random" unknown hash for testing
	var unknown common.Hash
	for i := range unknown {
		unknown[i] = byte(i)
	}
	// Create a batch of tests for various scenarios
	limit := uint64(MaxHeaderFetch)
	tests := []struct {
		query  *getBlockHeadersData // The query to execute for header retrieval
		expect []common.Hash        // The hashes of the block whose headers are expected
	}{
		// A single random block should be retrievable by hash and number too
		{
			&getBlockHeadersData{Origin: hashOrNumber{Hash: bc.GetBlockByNumber(limit / 2).Hash()}, Amount: 1},
			[]common.Hash{bc.GetBlockByNumber(limit / 2).Hash()},
		}, {
			&getBlockHeadersData{Origin: hashOrNumber{Number: limit / 2}, Amount: 1},
			[]common.Hash{bc.GetBlockByNumber(limit / 2).Hash()},
		},
		// Multiple headers should be retrievable in both directions
		{
			&getBlockHeadersData{Origin: hashOrNumber{Number: limit / 2}, Amount: 3},
			[]common.Hash{
				bc.GetBlockByNumber(limit / 2).Hash(),
				bc.GetBlockByNumber(limit/2 + 1).Hash(),
				bc.GetBlockByNumber(limit/2 + 2).Hash(),
			},
		}, {
			&getBlockHeadersData{Origin: hashOrNumber{Number: limit / 2}, Amount: 3, Reverse: true},
			[]common.Hash{
				bc.GetBlockByNumber(limit / 2).Hash(),
				bc.GetBlockByNumber(limit/2 - 1).Hash(),
				bc.GetBlockByNumber(limit/2 - 2).Hash(),
			},
		},
		// Multiple headers with skip lists should be retrievable
		{
			&getBlockHeadersData{Origin: hashOrNumber{Number: limit / 2}, Skip: 3, Amount: 3},
			[]common.Hash{
				bc.GetBlockByNumber(limit / 2).Hash(),
				bc.GetBlockByNumber(limit/2 + 4).Hash(),
				bc.GetBlockByNumber(limit/2 + 8).Hash(),
			},
		}, {
			&getBlockHeadersData{Origin: hashOrNumber{Number: limit / 2}, Skip: 3, Amount: 3, Reverse: true},
			[]common.Hash{
				bc.GetBlockByNumber(limit / 2).Hash(),
				bc.GetBlockByNumber(limit/2 - 4).Hash(),
				bc.GetBlockByNumber(limit/2 - 8).Hash(),
			},
		},
		// The chain endpoints should be retrievable
		{
			&getBlockHeadersData{Origin: hashOrNumber{Number: 0}, Amount: 1},
			[]common.Hash{bc.GetBlockByNumber(0).Hash()},
		}, {
			&getBlockHeadersData{Origin: hashOrNumber{Number: bc.CurrentBlock().NumberU64()}, Amount: 1},
			[]common.Hash{bc.CurrentBlock().Hash()},
		},
		// Ensure protocol limits are honored
		/*{
			&getBlockHeadersData{Origin: hashOrNumber{Number: bc.CurrentBlock().NumberU64() - 1}, Amount: limit + 10, Reverse: true},
			bc.GetBlockHashesFromHash(bc.CurrentBlock().Hash(), limit),
		},*/
		// Check that requesting more than available is handled gracefully
		{
			&getBlockHeadersData{Origin: hashOrNumber{Number: bc.CurrentBlock().NumberU64() - 4}, Skip: 3, Amount: 3},
			[]common.Hash{
				bc.GetBlockByNumber(bc.CurrentBlock().NumberU64() - 4).Hash(),
				bc.GetBlockByNumber(bc.CurrentBlock().NumberU64()).Hash(),
			},
		}, {
			&getBlockHeadersData{Origin: hashOrNumber{Number: 4}, Skip: 3, Amount: 3, Reverse: true},
			[]common.Hash{
				bc.GetBlockByNumber(4).Hash(),
				bc.GetBlockByNumber(0).Hash(),
			},
		},
		// Check that requesting more than available is handled gracefully, even if mid skip
		{
			&getBlockHeadersData{Origin: hashOrNumber{Number: bc.CurrentBlock().NumberU64() - 4}, Skip: 2, Amount: 3},
			[]common.Hash{
				bc.GetBlockByNumber(bc.CurrentBlock().NumberU64() - 4).Hash(),
				bc.GetBlockByNumber(bc.CurrentBlock().NumberU64() - 1).Hash(),
			},
		}, {
			&getBlockHeadersData{Origin: hashOrNumber{Number: 4}, Skip: 2, Amount: 3, Reverse: true},
			[]common.Hash{
				bc.GetBlockByNumber(4).Hash(),
				bc.GetBlockByNumber(1).Hash(),
			},
		},
		// Check that non existing headers aren't returned
		{
			&getBlockHeadersData{Origin: hashOrNumber{Hash: unknown}, Amount: 1},
			[]common.Hash{},
		}, {
			&getBlockHeadersData{Origin: hashOrNumber{Number: bc.CurrentBlock().NumberU64() + 1}, Amount: 1},
			[]common.Hash{},
		},
	}
	// Run each of the tests and verify the results against the chain
	var reqID uint64
	for i, tt := range tests {
		// Collect the headers to expect in the response
		headers := []*types.Header{}
		for _, hash := range tt.expect {
			headers = append(headers, bc.GetHeaderByHash(hash))
		}
		// Send the hash request and verify the response
		reqID++
		cost := peer.GetRequestCost(GetBlockHeadersMsg, int(tt.query.Amount))
		sendRequest(peer.app, GetBlockHeadersMsg, reqID, cost, tt.query)
		if err := expectResponse(peer.app, BlockHeadersMsg, reqID, testBufLimit, headers); err != nil {
			t.Errorf("test %d: headers mismatch: %v", i, err)
		}
	}
}

// Tests that block contents can be retrieved from a remote chain based on their hashes.
func TestGetBlockBodiesLes1(t *testing.T) { testGetBlockBodies(t, 1) }
func TestGetBlockBodiesLes2(t *testing.T) { testGetBlockBodies(t, 2) }

func testGetBlockBodies(t *testing.T, protocol int) {
	db := rawdb.NewMemoryDatabase()
	pm := newTestProtocolManagerMust(t, false, downloader.MaxBlockFetch+15, nil, nil, nil, db)
	bc := pm.blockchain.(*core.BlockChain)
	peer, _ := newTestPeer(t, "peer", protocol, pm, true)
	defer peer.close()

	// Create a batch of tests for various scenarios
	limit := MaxBodyFetch
	tests := []struct {
		random    int           // Number of blocks to fetch randomly from the chain
		explicit  []common.Hash // Explicitly requested blocks
		available []bool        // Availability of explicitly requested blocks
		expected  int           // Total number of existing blocks to expect
	}{
		{1, nil, nil, 1},         // A single random block should be retrievable
		{10, nil, nil, 10},       // Multiple random blocks should be retrievable
		{limit, nil, nil, limit}, // The maximum possible blocks should be retrievable
		//{limit + 1, nil, nil, limit},                                  // No more than the possible block count should be returned
		{0, []common.Hash{bc.Genesis().Hash()}, []bool{true}, 1},      // The genesis block should be retrievable
		{0, []common.Hash{bc.CurrentBlock().Hash()}, []bool{true}, 1}, // The chains head block should be retrievable
		{0, []common.Hash{{}}, []bool{false}, 0},                      // A non existent block should not be returned

		// Existing and non-existing blocks interleaved should not cause problems
		{0, []common.Hash{
			{},
			bc.GetBlockByNumber(1).Hash(),
			{},
			bc.GetBlockByNumber(10).Hash(),
			{},
			bc.GetBlockByNumber(100).Hash(),
			{},
		}, []bool{false, true, false, true, false, true, false}, 3},
	}
	// Run each of the tests and verify the results against the chain
	var reqID uint64
	for i, tt := range tests {
		// Collect the hashes to request, and the response to expect
		hashes, seen := []common.Hash{}, make(map[int64]bool)
		bodies := []*types.Body{}

		for j := 0; j < tt.random; j++ {
			for {
				num := rand.Int63n(int64(bc.CurrentBlock().NumberU64()))
				if !seen[num] {
					seen[num] = true

					block := bc.GetBlockByNumber(uint64(num))
					hashes = append(hashes, block.Hash())
					if len(bodies) < tt.expected {
						bodies = append(bodies, &types.Body{Transactions: block.Transactions(), Uncles: block.Uncles()})
					}
					break
				}
			}
		}
		for j, hash := range tt.explicit {
			hashes = append(hashes, hash)
			if tt.available[j] && len(bodies) < tt.expected {
				block := bc.GetBlockByHash(hash)
				bodies = append(bodies, &types.Body{Transactions: block.Transactions(), Uncles: block.Uncles()})
			}
		}
		reqID++
		// Send the hash request and verify the response
		cost := peer.GetRequestCost(GetBlockBodiesMsg, len(hashes))
		sendRequest(peer.app, GetBlockBodiesMsg, reqID, cost, hashes)
		if err := expectResponse(peer.app, BlockBodiesMsg, reqID, testBufLimit, bodies); err != nil {
			t.Errorf("test %d: bodies mismatch: %v", i, err)
		}
	}
}

// Tests that the contract codes can be retrieved based on account addresses.
func TestGetCodeLes1(t *testing.T) { testGetCode(t, 1) }
func TestGetCodeLes2(t *testing.T) { testGetCode(t, 2) }

func testGetCode(t *testing.T, protocol int) {
	// Assemble the test environment
	db := rawdb.NewMemoryDatabase()
	pm := newTestProtocolManagerMust(t, false, 4, testChainGen, nil, nil, db)
	bc := pm.blockchain.(*core.BlockChain)
	peer, _ := newTestPeer(t, "peer", protocol, pm, true)
	defer peer.close()

	var codereqs []*CodeReq
	var codes [][]byte

	for i := uint64(0); i <= bc.CurrentBlock().NumberU64(); i++ {
		header := bc.GetHeaderByNumber(i)
		req := &CodeReq{
			BHash:  header.Hash(),
			AccKey: crypto.Keccak256(testContractAddr[:]),
		}
		codereqs = append(codereqs, req)
		if i >= testContractDeployed {
			codes = append(codes, testContractCodeDeployed)
		}
	}

	cost := peer.GetRequestCost(GetCodeMsg, len(codereqs))
	sendRequest(peer.app, GetCodeMsg, 42, cost, codereqs)
	if err := expectResponse(peer.app, CodeMsg, 42, testBufLimit, codes); err != nil {
		t.Errorf("codes mismatch: %v", err)
	}
}

// Tests that the transaction receipts can be retrieved based on hashes.
func TestGetReceiptLes1(t *testing.T) { testGetReceipt(t, 1) }
func TestGetReceiptLes2(t *testing.T) { testGetReceipt(t, 2) }

func testGetReceipt(t *testing.T, protocol int) {
	// Assemble the test environment
	db := rawdb.NewMemoryDatabase()
	pm := newTestProtocolManagerMust(t, false, 4, testChainGen, nil, nil, db)
	bc := pm.blockchain.(*core.BlockChain)
	peer, _ := newTestPeer(t, "peer", protocol, pm, true)
	defer peer.close()

	// Collect the hashes to request, and the response to expect
	hashes, receipts := []common.Hash{}, []types.Receipts{}
	for i := uint64(0); i <= bc.CurrentBlock().NumberU64(); i++ {
		block := bc.GetBlockByNumber(i)

		hashes = append(hashes, block.Hash())
		receipts = append(receipts, rawdb.ReadRawReceipts(db, block.Hash(), block.NumberU64()))
	}
	// Send the hash request and verify the response
	cost := peer.GetRequestCost(GetReceiptsMsg, len(hashes))
	sendRequest(peer.app, GetReceiptsMsg, 42, cost, hashes)
	if err := expectResponse(peer.app, ReceiptsMsg, 42, testBufLimit, receipts); err != nil {
		t.Errorf("receipts mismatch: %v", err)
	}
}

// Tests that trie merkle proofs can be retrieved
func TestGetProofsLes1(t *testing.T) { testGetProofs(t, 1) }
func TestGetProofsLes2(t *testing.T) { testGetProofs(t, 2) }

func testGetProofs(t *testing.T, protocol int) {
	// Assemble the test environment
	db := rawdb.NewMemoryDatabase()
	pm := newTestProtocolManagerMust(t, false, 4, testChainGen, nil, nil, db)
	bc := pm.blockchain.(*core.BlockChain)
	peer, _ := newTestPeer(t, "peer", protocol, pm, true)
	defer peer.close()

	var (
		proofreqs []ProofReq
		proofsV1  [][]rlp.RawValue
	)
	proofsV2 := light.NewNodeSet()

	accounts := []common.Address{testBankAddress, acc1Addr, acc2Addr, {}}
	for i := uint64(0); i <= bc.CurrentBlock().NumberU64(); i++ {
		header := bc.GetHeaderByNumber(i)
		root := header.Root
		trie, _ := trie.New(root, trie.NewDatabase(db))

		for _, acc := range accounts {
			req := ProofReq{
				BHash: header.Hash(),
				Key:   crypto.Keccak256(acc[:]),
			}
			proofreqs = append(proofreqs, req)

			switch protocol {
			case 1:
				var proof light.NodeList
				trie.Prove(crypto.Keccak256(acc[:]), 0, &proof)
				proofsV1 = append(proofsV1, proof)
			case 2:
				trie.Prove(crypto.Keccak256(acc[:]), 0, proofsV2)
			}
		}
	}
	// Send the proof request and verify the response
	switch protocol {
	case 1:
		cost := peer.GetRequestCost(GetProofsV1Msg, len(proofreqs))
		sendRequest(peer.app, GetProofsV1Msg, 42, cost, proofreqs)
		if err := expectResponse(peer.app, ProofsV1Msg, 42, testBufLimit, proofsV1); err != nil {
			t.Errorf("proofs mismatch: %v", err)
		}
	case 2:
		cost := peer.GetRequestCost(GetProofsV2Msg, len(proofreqs))
		sendRequest(peer.app, GetProofsV2Msg, 42, cost, proofreqs)
		if err := expectResponse(peer.app, ProofsV2Msg, 42, testBufLimit, proofsV2.NodeList()); err != nil {
			t.Errorf("proofs mismatch: %v", err)
		}
	}
}

// Tests that CHT proofs can be correctly retrieved.
func TestGetCHTProofsLes1(t *testing.T) { testGetCHTProofs(t, 1) }
func TestGetCHTProofsLes2(t *testing.T) { testGetCHTProofs(t, 2) }

func testGetCHTProofs(t *testing.T, protocol int) {
	// Figure out the client's CHT frequency
	frequency := uint64(light.CHTFrequencyClient)
	if protocol == 1 {
		frequency = uint64(light.CHTFrequencyServer)
	}
	// Assemble the test environment
	db := rawdb.NewMemoryDatabase()
	pm := newTestProtocolManagerMust(t, false, int(frequency)+light.HelperTrieProcessConfirmations, testChainGen, nil, nil, db)
	bc := pm.blockchain.(*core.BlockChain)
	peer, _ := newTestPeer(t, "peer", protocol, pm, true)
	defer peer.close()

	// Wait a while for the CHT indexer to process the new headers
	time.Sleep(100 * time.Millisecond * time.Duration(frequency/light.CHTFrequencyServer)) // Chain indexer throttling
	time.Sleep(250 * time.Millisecond)                                                     // CI tester slack

	// Assemble the proofs from the different protocols
	header := bc.GetHeaderByNumber(frequency)
	rlp, _ := rlp.EncodeToBytes(header)

	key := make([]byte, 8)
	binary.BigEndian.PutUint64(key, frequency)

	proofsV1 := []ChtResp{{
		Header: header,
	}}
	proofsV2 := HelperTrieResps{
		AuxData: [][]byte{rlp},
	}
	switch protocol {
	case 1:
		root := light.GetChtRoot(db, 0, bc.GetHeaderByNumber(frequency-1).Hash())
		trie, _ := trie.New(root, trie.NewDatabase(rawdb.NewTable(db, light.ChtTablePrefix)))

		var proof light.NodeList
		trie.Prove(key, 0, &proof)
		proofsV1[0].Proof = proof

	case 2:
		root := light.GetChtV2Root(db, 0, bc.GetHeaderByNumber(frequency-1).Hash())
		trie, _ := trie.New(root, trie.NewDatabase(rawdb.NewTable(db, light.ChtTablePrefix)))
		trie.Prove(key, 0, &proofsV2.Proofs)
	}
	// Assemble the requests for the different protocols
	requestsV1 := []ChtReq{{
		ChtNum:   1,
		BlockNum: frequency,
	}}
	requestsV2 := []HelperTrieReq{{
		Type:    htCanonical,
		TrieIdx: 0,
		Key:     key,
		AuxReq:  auxHeader,
	}}
	// Send the proof request and verify the response
	switch protocol {
	case 1:
		cost := peer.GetRequestCost(GetHeaderProofsMsg, len(requestsV1))
		sendRequest(peer.app, GetHeaderProofsMsg, 42, cost, requestsV1)
		if err := expectResponse(peer.app, HeaderProofsMsg, 42, testBufLimit, proofsV1); err != nil {
			t.Errorf("proofs mismatch: %v", err)
		}
	case 2:
		cost := peer.GetRequestCost(GetHelperTrieProofsMsg, len(requestsV2))
		sendRequest(peer.app, GetHelperTrieProofsMsg, 42, cost, requestsV2)
		if err := expectResponse(peer.app, HelperTrieProofsMsg, 42, testBufLimit, proofsV2); err != nil {
			t.Errorf("proofs mismatch: %v", err)
		}
	}
}

// Tests that bloombits proofs can be correctly retrieved.
func TestGetBloombitsProofs(t *testing.T) {
	// Assemble the test environment
	db := rawdb.NewMemoryDatabase()
	pm := newTestProtocolManagerMust(t, false, light.BloomTrieFrequency+256, testChainGen, nil, nil, db)
	bc := pm.blockchain.(*core.BlockChain)
	peer, _ := newTestPeer(t, "peer", 2, pm, true)
	defer peer.close()

	// Wait a while for the bloombits indexer to process the new headers
	time.Sleep(100 * time.Millisecond * time.Duration(light.BloomTrieFrequency/4096)) // Chain indexer throttling
	time.Sleep(250 * time.Millisecond)                                                // CI tester slack

	// Request and verify each bit of the bloom bits proofs
	for bit := 0; bit < 2048; bit++ {
		// Assemble therequest and proofs for the bloombits
		key := make([]byte, 10)

		binary.BigEndian.PutUint16(key[:2], uint16(bit))
		binary.BigEndian.PutUint64(key[2:], uint64(light.BloomTrieFrequency))

		requests := []HelperTrieReq{{
			Type:    htBloomBits,
			TrieIdx: 0,
			Key:     key,
		}}
		var proofs HelperTrieResps

		root := light.GetBloomTrieRoot(db, 0, bc.GetHeaderByNumber(light.BloomTrieFrequency-1).Hash())
		trie, _ := trie.New(root, trie.NewDatabase(rawdb.NewTable(db, light.BloomTrieTablePrefix)))
		trie.Prove(key, 0, &proofs.Proofs)

		// Send the proof request and verify the response
		cost := peer.GetRequestCost(GetHelperTrieProofsMsg, len(requests))
		sendRequest(peer.app, GetHelperTrieProofsMsg, 42, cost, requests)
		if err := expectResponse(peer.app, HelperTrieProofsMsg, 42, testBufLimit, proofs); err != nil {
			t.Errorf("bit %d: proofs mismatch: %v", bit, err)
		}
	}
}

func TestTransactionStatusLes2(t *testing.T) {
	db := rawdb.NewMemoryDatabase()
	pm := newTestProtocolManagerMust(t, false, 0, nil, nil, nil, db)
	chain := pm.blockchain.(*core.BlockChain)
	config := txpool.DefaultConfig
	config.Journal = ""
	txPool := txpool.NewTxPool(config, params.TestChainConfig, chain)
	pm.txpool = txPool
	peer, _ := newTestPeer(t, "peer", 2, pm, true)
	defer peer.close()

	var reqID uint64

	test := func(tx *types.Transaction, send bool, expStatus txStatus) {
		reqID++
		if send {
			cost := peer.GetRequestCost(SendTxV2Msg, 1)
			sendRequest(peer.app, SendTxV2Msg, reqID, cost, types.Transactions{tx})
		} else {
			cost := peer.GetRequestCost(GetTxStatusMsg, 1)
			sendRequest(peer.app, GetTxStatusMsg, reqID, cost, []common.Hash{tx.Hash()})
		}
		if err := expectResponse(peer.app, TxStatusMsg, reqID, testBufLimit, []txStatus{expStatus}); err != nil {
			t.Errorf("transaction status mismatch")
		}
	}

	signer := types.HomesteadSigner{}

	// test error status by sending an underpriced transaction
	tx0, _ := types.SignTx(types.NewTransaction(0, acc1Addr, big.NewInt(10000), params.TxGas, nil, nil), signer, testBankKey)
	test(tx0, true, txStatus{Status: txpool.TxStatusUnknown, Error: txpool.ErrUnderpriced.Error()})

	tx1, _ := types.SignTx(types.NewTransaction(0, acc1Addr, big.NewInt(10000), params.TxGas, big.NewInt(100000000000), nil), signer, testBankKey)
	test(tx1, false, txStatus{Status: txpool.TxStatusUnknown}) // query before sending, should be unknown
	test(tx1, true, txStatus{Status: txpool.TxStatusPending})  // send valid processable tx, should return pending
	test(tx1, true, txStatus{Status: txpool.TxStatusPending})  // adding it again should not return an error

	tx2, _ := types.SignTx(types.NewTransaction(1, acc1Addr, big.NewInt(10000), params.TxGas, big.NewInt(100000000000), nil), signer, testBankKey)
	tx3, _ := types.SignTx(types.NewTransaction(2, acc1Addr, big.NewInt(10000), params.TxGas, big.NewInt(100000000000), nil), signer, testBankKey)
	// send transactions in the wrong order, tx3 should be queued
	test(tx3, true, txStatus{Status: txpool.TxStatusQueued})
	test(tx2, true, txStatus{Status: txpool.TxStatusPending})
	// query again, now tx3 should be pending too
	test(tx3, false, txStatus{Status: txpool.TxStatusPending})

	// generate and add a block with tx1 and tx2 included
	gchain, _ := core.GenerateChain(params.TestChainConfig, chain.GetBlockByNumber(0), ethash.NewFaker(), db, 1, func(i int, block *core.BlockGen) {
		block.AddTx(tx1)
		block.AddTx(tx2)
	})
	if _, err := chain.InsertChain(gchain); err != nil {
		panic(err)
	}
	// wait until TxPool processes the inserted block
	for i := 0; i < 10; i++ {
		if pending, _ := txPool.Stats(); pending == 1 {
			break
		}
		time.Sleep(100 * time.Millisecond)
	}
	if pending, _ := txPool.Stats(); pending != 1 {
		t.Fatalf("pending count mismatch: have %d, want 1", pending)
	}

	// check if their status is included now
	block1hash := rawdb.ReadCanonicalHash(db, 1)
	test(tx1, false, txStatus{Status: txpool.TxStatusIncluded, Lookup: &rawdb.LegacyTxLookupEntry{BlockHash: block1hash, BlockIndex: 1, Index: 0}})
	test(tx2, false, txStatus{Status: txpool.TxStatusIncluded, Lookup: &rawdb.LegacyTxLookupEntry{BlockHash: block1hash, BlockIndex: 1, Index: 1}})

	// create a reorg that rolls them back
	gchain, _ = core.GenerateChain(params.TestChainConfig, chain.GetBlockByNumber(0), ethash.NewFaker(), db, 2, func(i int, block *core.BlockGen) {})
	if _, err := chain.InsertChain(gchain); err != nil {
		panic(err)
	}
	// wait until TxPool processes the reorg
	for i := 0; i < 10; i++ {
		if pending, _ := txPool.Stats(); pending == 3 {
			break
		}
		time.Sleep(100 * time.Millisecond)
	}
	if pending, _ := txPool.Stats(); pending != 3 {
		t.Fatalf("pending count mismatch: have %d, want 3", pending)
	}
	// check if their status is pending again
	test(tx1, false, txStatus{Status: txpool.TxStatusPending})
	test(tx2, false, txStatus{Status: txpool.TxStatusPending})
}
