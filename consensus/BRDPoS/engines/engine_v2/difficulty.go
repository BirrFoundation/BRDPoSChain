package engine_v2

import (
	"math/big"

	"BRDPoSChain/common"
	"BRDPoSChain/consensus"
	"BRDPoSChain/core/types"
)

// TODO: what should be new difficulty
func (x *BRDPoS_v2) calcDifficulty(chain consensus.ChainReader, parent *types.Header, signer common.Address) *big.Int {
	return big.NewInt(1)
}
