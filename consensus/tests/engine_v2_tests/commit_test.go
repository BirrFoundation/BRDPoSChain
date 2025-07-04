package engine_v2_tests

import (
	"strings"
	"testing"

	"BRDPoSChain/consensus/BRDPoS"
	"BRDPoSChain/consensus/BRDPoS/utils"
	"BRDPoSChain/core/types"
	"BRDPoSChain/params"

	"github.com/stretchr/testify/assert"
)

func TestNormalReorgWhenNotInvolveCommittedBlock(t *testing.T) {
	// create 3 forking blockss, so the committed block is not in the forking numbers
	var numOfForks = new(int)
	*numOfForks = 3
	blockchain, _, currentBlock, signer, signFn, forkedBlock := PrepareBRCTestBlockChainForV2Engine(t, 906, params.TestBRDPoSMockChainConfig, &ForkedBlockOptions{numOfForkedBlocks: numOfForks})
	engineV2 := blockchain.Engine().(*BRDPoS.BRDPoS).EngineV2

	var extraField types.ExtraFields_v2
	err := utils.DecodeBytesExtraFields(currentBlock.Extra(), &extraField)
	if err != nil {
		t.Fatal("Fail to decode extra data", err)
	}
	engineV2.ProcessQCFaker(blockchain, extraField.QuorumCert)
	assert.Equal(t, uint64(903), engineV2.GetLatestCommittedBlockInfo().Number.Uint64())
	blockCoinBase := "0x111000000000000000000000000000000123"
	newBlock := CreateBlock(blockchain, params.TestBRDPoSMockChainConfig, forkedBlock, int(forkedBlock.NumberU64())+1, int64(extraField.Round)+10, blockCoinBase, signer, signFn, nil, nil, forkedBlock.Header().Root.Hex())
	err = blockchain.InsertBlock(newBlock)
	assert.Nil(t, err)
}

func TestShouldNotReorgCommittedBlock(t *testing.T) {
	// create 4 forking blocks, so the committed block is in the forking numbers
	var numOfForks = new(int)
	*numOfForks = 4
	blockchain, _, currentBlock, signer, signFn, forkedBlock := PrepareBRCTestBlockChainForV2Engine(t, 906, params.TestBRDPoSMockChainConfig, &ForkedBlockOptions{numOfForkedBlocks: numOfForks})
	engineV2 := blockchain.Engine().(*BRDPoS.BRDPoS).EngineV2

	var extraField types.ExtraFields_v2
	err := utils.DecodeBytesExtraFields(currentBlock.Extra(), &extraField)
	if err != nil {
		t.Fatal("Fail to decode extra data", err)
	}
	engineV2.ProcessQCFaker(blockchain, extraField.QuorumCert)
	assert.Equal(t, uint64(903), engineV2.GetLatestCommittedBlockInfo().Number.Uint64())
	blockCoinBase := "0x111000000000000000000000000000000123"
	newBlock := CreateBlock(blockchain, params.TestBRDPoSMockChainConfig, forkedBlock, int(forkedBlock.NumberU64())+1, int64(extraField.Round)+10, blockCoinBase, signer, signFn, nil, nil, forkedBlock.Header().Root.Hex())
	err = blockchain.InsertBlock(newBlock)
	assert.NotNil(t, err)
	assert.True(t, strings.Contains(err.Error(), "reorg"))
	assert.True(t, strings.Contains(err.Error(), "attack"))
}
