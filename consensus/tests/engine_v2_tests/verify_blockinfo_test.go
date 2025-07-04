package engine_v2_tests

import (
	"fmt"
	"testing"

	"BRDPoSChain/consensus/BRDPoS"
	"BRDPoSChain/core/types"
	"BRDPoSChain/params"

	"github.com/stretchr/testify/assert"
)

func TestShouldVerifyBlockInfo(t *testing.T) {
	// Block 901 is the first v2 block with round of 1
	blockchain, _, currentBlock, signer, signFn, _ := PrepareBRCTestBlockChainForV2Engine(t, 901, params.TestBRDPoSMockChainConfig, nil)
	engineV2 := blockchain.Engine().(*BRDPoS.BRDPoS).EngineV2

	blockInfo := &types.BlockInfo{
		Hash:   currentBlock.Hash(),
		Round:  types.Round(1),
		Number: currentBlock.Number(),
	}
	err := engineV2.VerifyBlockInfo(blockchain, blockInfo, nil)
	assert.Nil(t, err)

	// Insert another Block, but it won't trigger commit
	blockNum := 902
	blockCoinBase := fmt.Sprintf("0x111000000000000000000000000000000%03d", blockNum)
	block902 := CreateBlock(blockchain, params.TestBRDPoSMockChainConfig, currentBlock, blockNum, 2, blockCoinBase, signer, signFn, nil, nil, "")
	err = blockchain.InsertBlock(block902)
	assert.Nil(t, err)

	blockInfo = &types.BlockInfo{
		Hash:   block902.Hash(),
		Round:  types.Round(2),
		Number: block902.Number(),
	}
	err = engineV2.VerifyBlockInfo(blockchain, blockInfo, nil)
	assert.Nil(t, err)

	blockInfo = &types.BlockInfo{
		Hash:   currentBlock.Hash(),
		Round:  types.Round(2),
		Number: currentBlock.Number(),
	}
	err = engineV2.VerifyBlockInfo(blockchain, blockInfo, nil)
	assert.NotNil(t, err)

	blockInfo = &types.BlockInfo{
		Hash:   block902.Hash(),
		Round:  types.Round(3),
		Number: block902.Number(),
	}
	err = engineV2.VerifyBlockInfo(blockchain, blockInfo, nil)
	assert.NotNil(t, err)

	blockInfo = &types.BlockInfo{
		Hash:   block902.Hash(),
		Round:  types.Round(2),
		Number: currentBlock.Number(),
	}
	err = engineV2.VerifyBlockInfo(blockchain, blockInfo, nil)
	assert.NotNil(t, err)
}
