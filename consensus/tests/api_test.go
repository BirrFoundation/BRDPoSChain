package tests

import (
	"math/big"
	"testing"

	"BRDPoSChain/accounts/abi/bind/backends"
	"BRDPoSChain/consensus/BRDPoS"
	"BRDPoSChain/core/types"
	"BRDPoSChain/crypto"
	"BRDPoSChain/params"

	"github.com/stretchr/testify/assert"
)

var (
	voterKey, _ = crypto.HexToECDSA("b71c71a67e1177ad4e901695e1b4b9ee04aefe388d1e14474d32c45c72ce7b7a")
	voterAddr   = crypto.PubkeyToAddress(voterKey.PublicKey) //brc5F74529C0338546f82389402a01c31fB52c6f434
)

func TestConfigApi(t *testing.T) {
	bc := backends.NewBRCSimulatedBackend(types.GenesisAlloc{
		voterAddr: {Balance: new(big.Int).SetUint64(10000000000)},
	}, 10000000, params.TestBRDPoSMockChainConfig)

	engine := bc.BlockChain().Engine().(*BRDPoS.BRDPoS)

	info := engine.APIs(bc.BlockChain())[0].Service.(*BRDPoS.API).NetworkInformation()

	assert.Equal(t, info.NetworkId, big.NewInt(1337))
	assert.Equal(t, info.ConsensusConfigs.V2.CurrentConfig.MaxMasternodes, 18)
	assert.Equal(t, info.ConsensusConfigs.V2.CurrentConfig.CertThreshold, 0.667)
	assert.Equal(t, info.ConsensusConfigs.V2.CurrentConfig.MinePeriod, 2)
	assert.Equal(t, info.ConsensusConfigs.V2.CurrentConfig.TimeoutSyncThreshold, 2)
}
