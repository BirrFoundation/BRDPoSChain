package engine_v2_tests

import (
	"encoding/json"
	"math/big"
	"testing"

	"BRDPoSChain/common"
	"BRDPoSChain/consensus/BRDPoS"
	"BRDPoSChain/core/types"
	"BRDPoSChain/params"

	"github.com/stretchr/testify/assert"
)

func TestInitialFirstV2Block(t *testing.T) {
	blockchain, _, currentBlock, _, _, _ := PrepareBRCTestBlockChainForV2Engine(t, 900, params.TestBRDPoSMockChainConfig, nil)
	adaptor := blockchain.Engine().(*BRDPoS.BRDPoS)
	header := currentBlock.Header()

	// snapshot should not be created before initial
	snap, _ := adaptor.EngineV2.GetSnapshot(blockchain, currentBlock.Header())
	assert.Nil(t, snap)

	err := adaptor.EngineV2.Initial(blockchain, header)
	assert.Nil(t, err)

	round, _, highQC, _, _, _ := adaptor.EngineV2.GetPropertiesFaker()
	blockInfo := &types.BlockInfo{
		Hash:   header.Hash(),
		Round:  types.Round(0),
		Number: header.Number,
	}
	expectedQuorumCert := &types.QuorumCert{
		ProposedBlockInfo: blockInfo,
		Signatures:        nil,
		GapNumber:         blockchain.Config().BRDPoS.V2.SwitchBlock.Uint64() - blockchain.Config().BRDPoS.Gap,
	}
	assert.Equal(t, types.Round(1), round)
	assert.Equal(t, expectedQuorumCert, highQC)

	// Test snapshot
	snap, err = adaptor.EngineV2.GetSnapshot(blockchain, currentBlock.Header())
	assert.Nil(t, err)
	assert.Equal(t, uint64(450), snap.Number)

	// Test Running channels
	minePeriod := <-adaptor.MinePeriodCh
	assert.Equal(t, params.TestBRDPoSMockChainConfig.BRDPoS.V2.CurrentConfig.MinePeriod, minePeriod)

	t.Logf("Waiting %d secs for timeout to happen", params.TestBRDPoSMockChainConfig.BRDPoS.V2.CurrentConfig.TimeoutPeriod)
	timeoutMsg := <-adaptor.EngineV2.BroadcastCh
	assert.NotNil(t, timeoutMsg)
	assert.Equal(t, types.Round(1), timeoutMsg.(*types.Timeout).Round)
}

func TestInitialOtherV2Block(t *testing.T) {
	// insert new block with new extra fields
	blockchain, _, currentBlock, signer, signFn, _ := PrepareBRCTestBlockChainForV2Engine(t, 900, params.TestBRDPoSMockChainConfig, nil)
	adaptor := blockchain.Engine().(*BRDPoS.BRDPoS)

	blockCoinBase := "0x111000000000000000000000000000000123"
	for blockNum := 901; blockNum <= 910; blockNum++ {
		currentBlock = CreateBlock(blockchain, params.TestBRDPoSMockChainConfig, currentBlock, blockNum, int64(blockNum-900), blockCoinBase, signer, signFn, nil, nil, "")
		err := blockchain.InsertBlock(currentBlock)
		assert.Nil(t, err)
	}

	// v2
	blockInfo := &types.BlockInfo{
		Hash:   currentBlock.Header().Hash(),
		Round:  types.Round(10),
		Number: big.NewInt(910),
	}
	quorumCert := &types.QuorumCert{
		ProposedBlockInfo: blockInfo,
		Signatures:        nil, // after decode it got default value []utils.Signature{}
		GapNumber:         450,
	}
	extra := types.ExtraFields_v2{
		Round:      11,
		QuorumCert: quorumCert,
	}
	extraBytes, err := extra.EncodeToBytes()
	assert.Nil(t, err)

	header := &types.Header{
		Root:       common.HexToHash("35999dded35e8db12de7e6c1471eb9670c162eec616ecebbaf4fddd4676fb930"),
		Number:     big.NewInt(int64(911)),
		ParentHash: currentBlock.Hash(),
		Coinbase:   common.HexToAddress("0x111000000000000000000000000000000123"),
	}
	header.Extra = extraBytes

	block, err := createBlockFromHeader(blockchain, header, nil, signer, signFn, blockchain.Config())
	if err != nil {
		t.Fatal(err)
	}
	err = blockchain.InsertBlock(block)
	assert.Nil(t, err)
	// Initialise
	err = adaptor.EngineV2.Initial(blockchain, block.Header())
	assert.Nil(t, err)

	round, _, highQC, _, _, _ := adaptor.EngineV2.GetPropertiesFaker()
	expectedQuorumCert := &types.QuorumCert{
		ProposedBlockInfo: blockInfo,
		Signatures:        []types.Signature{},
		GapNumber:         blockchain.Config().BRDPoS.V2.SwitchBlock.Uint64() - blockchain.Config().BRDPoS.Gap,
	}
	assert.Equal(t, types.Round(11), round)
	assert.Equal(t, expectedQuorumCert, highQC)

	// Test snapshot
	snap, err := adaptor.EngineV2.GetSnapshot(blockchain, block.Header())
	assert.Nil(t, err)
	assert.Equal(t, uint64(450), snap.Number)
}

func TestSnapshotShouldAlreadyCreatedByUpdateM1(t *testing.T) {
	// insert new block with new extra fields
	blockchain, _, currentBlock, _, _, _ := PrepareBRCTestBlockChainForV2Engine(t, 1800, params.TestBRDPoSMockChainConfig, nil)
	adaptor := blockchain.Engine().(*BRDPoS.BRDPoS)

	snap, err := adaptor.EngineV2.GetSnapshot(blockchain, currentBlock.Header())
	assert.Nil(t, err)
	assert.Equal(t, uint64(1350), snap.Number)
}

func TestInitialWithWrongSwitchNumber(t *testing.T) {
	b, err := json.Marshal(params.TestBRDPoSMockChainConfig)
	assert.Nil(t, err)
	configString := string(b)

	var config params.ChainConfig
	err = json.Unmarshal([]byte(configString), &config)
	assert.Nil(t, err)

	blockchain, _, currentBlock, _, _, _ := PrepareBRCTestBlockChainForV2Engine(t, 800, &config, nil)
	adaptor := blockchain.Engine().(*BRDPoS.BRDPoS)
	header := currentBlock.Header()
	config.BRDPoS.V2.SwitchBlock = big.NewInt(800) // not epoch number

	err = adaptor.EngineV2.Initial(blockchain, header)
	assert.NotNil(t, err)
}
