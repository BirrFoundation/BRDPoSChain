package BRDPoS

import (
	"testing"

	"BRDPoSChain/core/rawdb"
	"BRDPoSChain/params"

	"github.com/stretchr/testify/assert"
)

func TestAdaptorShouldShareDbWithV1Engine(t *testing.T) {
	database := rawdb.NewMemoryDatabase()
	config := params.TestBRDPoSMockChainConfig
	engine := New(config, database)

	assert := assert.New(t)
	assert.Equal(engine.EngineV1.GetDb(), engine.GetDb())
}
