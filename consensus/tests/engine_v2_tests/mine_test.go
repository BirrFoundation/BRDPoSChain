package engine_v2_tests

import (
	"fmt"
	"math/big"
	"testing"
	"time"

	"BRDPoSChain/common"
	"BRDPoSChain/consensus"
	"BRDPoSChain/consensus/BRDPoS"
	"BRDPoSChain/consensus/BRDPoS/utils"
	"BRDPoSChain/core/types"
	"BRDPoSChain/params"

	"github.com/stretchr/testify/assert"
)

func TestYourTurnInitialV2(t *testing.T) {
	config := params.TestBRDPoSMockChainConfig
	blockchain, _, parentBlock, signer, signFn, _ := PrepareBRCTestBlockChainForV2Engine(t, int(config.BRDPoS.Epoch)-1, config, nil)
	minePeriod := config.BRDPoS.V2.CurrentConfig.MinePeriod
	adaptor := blockchain.Engine().(*BRDPoS.BRDPoS)

	// Insert block 900
	t.Logf("Inserting block with propose at 900...")
	blockCoinbaseA := "0xaaa0000000000000000000000000000000000900"
	//Get from block validator error message
	merkleRoot := "35999dded35e8db12de7e6c1471eb9670c162eec616ecebbaf4fddd4676fb930"
	header := &types.Header{
		Root:       common.HexToHash(merkleRoot),
		Number:     big.NewInt(int64(900)),
		ParentHash: parentBlock.Hash(),
		Coinbase:   common.HexToAddress(blockCoinbaseA),
		Extra:      common.Hex2Bytes("d7830100018358444388676f312e31352e38856c696e757800000000000000000278c350152e15fa6ffc712a5a73d704ce73e2e103d9e17ae3ff2c6712e44e25b09ac5ee91f6c9ff065551f0dcac6f00cae11192d462db709be3758ccef312ee5eea8d7bad5374c6a652150515d744508b61c1a4deb4e4e7bf057e4e3824c11fd2569bcb77a52905cda63b5a58507910bed335e4c9d87ae0ecdfafd400"),
	}
	block900, err := createBlockFromHeader(blockchain, header, nil, signer, signFn, config)
	if err != nil {
		t.Fatal(err)
	}
	err = blockchain.InsertBlock(block900)
	assert.Nil(t, err)
	time.Sleep(time.Duration(minePeriod) * time.Second)

	// YourTurn is called before mine first v2 block
	b, err := adaptor.YourTurn(blockchain, block900.Header(), common.HexToAddress("brc0278C350152e15fa6FFC712a5A73D704Ce73E2E1"))
	assert.Nil(t, err)
	assert.False(t, b)
	b, err = adaptor.YourTurn(blockchain, block900.Header(), common.HexToAddress("brc03d9e17Ae3fF2c6712E44e25B09Ac5ee91f6c9ff"))
	assert.Nil(t, err)
	// round=1, so masternode[1] has YourTurn = True
	assert.True(t, b)
	assert.Equal(t, adaptor.EngineV2.GetCurrentRoundFaker(), types.Round(1))

	snap, err := adaptor.EngineV2.GetSnapshot(blockchain, block900.Header())
	assert.Nil(t, err)
	assert.NotNil(t, snap)
	masterNodes := adaptor.EngineV1.GetMasternodesFromCheckpointHeader(block900.Header())
	for i := 0; i < len(masterNodes); i++ {
		assert.Equal(t, masterNodes[i], snap.NextEpochCandidates[i])
	}
}

func TestShouldMineOncePerRound(t *testing.T) {
	config := params.TestBRDPoSMockChainConfig
	blockchain, _, block910, signer, _, _ := PrepareBRCTestBlockChainForV2Engine(t, 910, config, nil)
	adaptor := blockchain.Engine().(*BRDPoS.BRDPoS)
	minePeriod := config.BRDPoS.V2.CurrentConfig.MinePeriod

	// Make sure we seal the parentBlock 910
	_, err := adaptor.Seal(blockchain, block910, nil)
	assert.Nil(t, err)
	time.Sleep(time.Duration(minePeriod) * time.Second)
	b, err := adaptor.YourTurn(blockchain, block910.Header(), signer)
	assert.False(t, b)
	assert.Equal(t, utils.ErrAlreadyMined, err)
}

func TestUpdateMasterNodes(t *testing.T) {
	config := params.TestBRDPoSMockChainConfig
	blockchain, _, currentBlock, signer, signFn, _ := PrepareBRCTestBlockChainForV2Engine(t, int(config.BRDPoS.Epoch+config.BRDPoS.Gap)-1, config, nil)
	adaptor := blockchain.Engine().(*BRDPoS.BRDPoS)
	x := adaptor.EngineV2
	snap, err := x.GetSnapshot(blockchain, currentBlock.Header())

	assert.Nil(t, err)
	assert.Equal(t, 450, int(snap.Number))

	// Insert block 1350
	t.Logf("Inserting block with propose at 1350...")
	blockCoinbaseA := "0xaaa0000000000000000000000000000000001350"
	// NOTE: voterAddr never exist in the Masternode list, but all acc1,2,3 already does
	tx, err := voteTX(37117, 0, voterAddr.String())
	if err != nil {
		t.Fatal(err)
	}
	//Get from block validator error message
	merkleRoot := "ef9198eb14b003774a505033f6cdcea2d357cbf7a7e7b004d8034d4e2a9770ee"
	header := &types.Header{
		Root:       common.HexToHash(merkleRoot),
		Number:     big.NewInt(int64(1350)),
		ParentHash: currentBlock.Hash(),
		Coinbase:   common.HexToAddress(blockCoinbaseA),
	}

	header.Extra = generateV2Extra(450, currentBlock, signer, signFn, nil)

	parentBlock, err := createBlockFromHeader(blockchain, header, []*types.Transaction{tx}, signer, signFn, config)
	assert.Nil(t, err)
	err = blockchain.InsertBlock(parentBlock)
	assert.Nil(t, err)
	// 1350 is a gap block, need to update the snapshot
	err = blockchain.UpdateM1()
	assert.Nil(t, err)
	t.Logf("Inserting block from 1351 to 1800...")
	for i := 1351; i <= 1800; i++ {
		blockCoinbase := fmt.Sprintf("0xaaa000000000000000000000000000000000%4d", i)
		//Get from block validator error message
		header = &types.Header{
			Root:       common.HexToHash(merkleRoot),
			Number:     big.NewInt(int64(i)),
			ParentHash: parentBlock.Hash(),
			Coinbase:   common.HexToAddress(blockCoinbase),
		}

		header.Extra = generateV2Extra(int64(i), currentBlock, signer, signFn, nil)

		block, err := createBlockFromHeader(blockchain, header, nil, signer, signFn, config)
		if err != nil {
			t.Fatal(err)
		}
		err = blockchain.InsertBlock(block)
		assert.Nil(t, err)
		parentBlock = block
	}

	snap, err = x.GetSnapshot(blockchain, parentBlock.Header())

	assert.Nil(t, err)
	assert.True(t, snap.IsCandidates(voterAddr))
	assert.Equal(t, int(snap.Number), 1350)
}

func TestPrepareFail(t *testing.T) {
	config := params.TestBRDPoSMockChainConfig
	blockchain, _, currentBlock, signer, _, _ := PrepareBRCTestBlockChainForV2Engine(t, int(config.BRDPoS.Epoch), config, nil)
	adaptor := blockchain.Engine().(*BRDPoS.BRDPoS)

	tstamp := time.Now().Unix()

	notReadyToProposeHeader := &types.Header{
		ParentHash: currentBlock.Hash(),
		Number:     big.NewInt(int64(901)),
		GasLimit:   params.TargetGasLimit,
		Time:       big.NewInt(tstamp),
		Coinbase:   signer,
	}

	err := adaptor.Prepare(blockchain, notReadyToProposeHeader)
	assert.Equal(t, consensus.ErrNotReadyToPropose, err)

	notReadyToMine := &types.Header{
		ParentHash: currentBlock.Hash(),
		Number:     big.NewInt(int64(901)),
		GasLimit:   params.TargetGasLimit,
		Time:       big.NewInt(tstamp),
		Coinbase:   signer,
	}
	// trigger initial which will set the highestQC
	_, err = adaptor.YourTurn(blockchain, currentBlock.Header(), signer)
	assert.Nil(t, err)
	err = adaptor.Prepare(blockchain, notReadyToMine)
	assert.Equal(t, consensus.ErrNotReadyToMine, err)

	adaptor.EngineV2.SetNewRoundFaker(blockchain, types.Round(4), false)
	header901WithoutCoinbase := &types.Header{
		ParentHash: currentBlock.Hash(),
		Number:     big.NewInt(int64(901)),
		GasLimit:   params.TargetGasLimit,
		Time:       big.NewInt(tstamp),
	}

	err = adaptor.Prepare(blockchain, header901WithoutCoinbase)
	assert.Equal(t, consensus.ErrCoinbaseMismatch, err)
}

func TestPrepareHappyPath(t *testing.T) {
	config := params.TestBRDPoSMockChainConfig
	blockchain, _, currentBlock, signer, _, _ := PrepareBRCTestBlockChainForV2Engine(t, int(config.BRDPoS.Epoch), config, nil)
	adaptor := blockchain.Engine().(*BRDPoS.BRDPoS)
	// trigger initial
	_, err := adaptor.YourTurn(blockchain, currentBlock.Header(), signer)
	assert.Nil(t, err)

	tstamp := time.Now().Unix()

	header901 := &types.Header{
		ParentHash: currentBlock.Hash(),
		Number:     big.NewInt(int64(901)),
		GasLimit:   params.TargetGasLimit,
		Time:       big.NewInt(tstamp),
		Coinbase:   signer,
	}

	adaptor.EngineV2.SetNewRoundFaker(blockchain, types.Round(4), false)
	err = adaptor.Prepare(blockchain, header901)
	assert.Nil(t, err)

	snap, err := adaptor.EngineV2.GetSnapshot(blockchain, currentBlock.Header())
	if err != nil {
		t.Fatal(err)
	}

	validators := []byte{}
	for _, v := range snap.NextEpochCandidates {
		validators = append(validators, v[:]...)
	}
	assert.Equal(t, validators, header901.Validators)

	var decodedExtraField types.ExtraFields_v2
	err = utils.DecodeBytesExtraFields(header901.Extra, &decodedExtraField)
	assert.Nil(t, err)
	assert.Equal(t, types.Round(4), decodedExtraField.Round)
	assert.Equal(t, types.Round(0), decodedExtraField.QuorumCert.ProposedBlockInfo.Round)
}

func TestPrepareDifferentMasternode(t *testing.T) {
	config := params.TestBRDPoSMockChainConfig
	blockchain, _, currentBlock, _, _, _ := PrepareBRCTestBlockChainForV2Engine(t, 1799, config, nil)
	adaptor := blockchain.Engine().(*BRDPoS.BRDPoS)
	// trigger initial
	adaptor.EngineV2.SetNewRoundFaker(blockchain, types.Round(919), false)
	myturn, err := adaptor.YourTurn(blockchain, currentBlock.Header(), acc1Addr)
	assert.Nil(t, err)
	assert.True(t, myturn)
}

// test if we have 128 candidates, then snapshot will store all of them, and when preparing (and verifying) candidates is truncated to MaxMasternodes
func TestUpdateMultipleMasterNodes(t *testing.T) {
	config := params.TestBRDPoSMockChainConfig
	blockchain, _, currentBlock, signer, signFn := PrepareBRCTestBlockChainWith128Candidates(t, int(config.BRDPoS.Epoch+config.BRDPoS.Gap)-1, config)
	adaptor := blockchain.Engine().(*BRDPoS.BRDPoS)
	x := adaptor.EngineV2
	// Insert block 1350
	t.Logf("Inserting block with propose at 1350...")
	blockCoinbaseA := "0xaaa0000000000000000000000000000000001350"
	//Get from block validator error message
	merkleRoot := "b345a8560bd51926803dd17677c9f0751193914a851a4ec13063d6bf50220b53"
	parentBlock := CreateBlock(blockchain, config, currentBlock, 1350, 450, blockCoinbaseA, signer, signFn, nil, nil, merkleRoot)
	err := blockchain.InsertBlock(parentBlock)
	assert.Nil(t, err)
	// 1350 is a gap block, need to update the snapshot
	err = blockchain.UpdateM1()
	assert.Nil(t, err)
	// but we wait until 1800 to test the snapshot

	t.Logf("Inserting block from 1351 to 1800...")
	for i := 1351; i <= 1800; i++ {
		blockCoinbase := fmt.Sprintf("0xaaa000000000000000000000000000000000%4d", i)
		block := CreateBlock(blockchain, config, parentBlock, i, int64(i-900), blockCoinbase, signer, signFn, nil, nil, merkleRoot)
		err = blockchain.InsertBlock(block)
		assert.Nil(t, err)
		if i < 1800 {
			parentBlock = block
		}
		if i == 1800 {
			snap, err := x.GetSnapshot(blockchain, block.Header())

			assert.Nil(t, err)
			assert.Equal(t, 1350, int(snap.Number))
			assert.Equal(t, 128, len(snap.NextEpochCandidates)) // 128 is all masternode candidates, not limited by MaxMasternodes
		}
	}

	tstamp := time.Now().Unix()

	header1800 := &types.Header{
		ParentHash: parentBlock.Hash(),
		Number:     big.NewInt(int64(1800)),
		GasLimit:   params.TargetGasLimit,
		Time:       big.NewInt(tstamp),
		Coinbase:   voterAddr,
	}

	adaptor.EngineV2.SetNewRoundFaker(blockchain, types.Round(900), false)
	blockInfo := &types.BlockInfo{Hash: parentBlock.Hash(), Round: types.Round(900 - 1), Number: parentBlock.Number()}
	signature := []byte{1, 2, 3, 4, 5, 6, 7, 8}
	signatures := []types.Signature{signature}
	quorumCert := &types.QuorumCert{ProposedBlockInfo: blockInfo, Signatures: signatures, GapNumber: 1350}
	adaptor.EngineV2.ProcessQCFaker(blockchain, quorumCert)
	adaptor.EngineV2.AuthorizeFaker(voterAddr)
	err = adaptor.Prepare(blockchain, header1800)
	assert.Nil(t, err)
	assert.Equal(t, blockchain.Config().BRDPoS.V2.Config(900).MaxMasternodes, len(header1800.Validators)/common.AddressLength)
	assert.Equal(t, 0, len(header1800.Penalties)/common.AddressLength)
}
