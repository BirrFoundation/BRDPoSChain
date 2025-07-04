// Copyright 2017 The go-ethereum Authors
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

package params

import (
	"math/big"
	"reflect"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestCheckCompatible(t *testing.T) {
	type test struct {
		stored, new *ChainConfig
		head        uint64
		wantErr     *ConfigCompatError
	}
	tests := []test{
		{stored: AllEthashProtocolChanges, new: AllEthashProtocolChanges, head: 0, wantErr: nil},
		{stored: AllEthashProtocolChanges, new: AllEthashProtocolChanges, head: 100, wantErr: nil},
		{
			stored:  &ChainConfig{EIP150Block: big.NewInt(10)},
			new:     &ChainConfig{EIP150Block: big.NewInt(20)},
			head:    9,
			wantErr: nil,
		},
		{
			stored: AllEthashProtocolChanges,
			new:    &ChainConfig{HomesteadBlock: nil},
			head:   3,
			wantErr: &ConfigCompatError{
				What:         "Homestead fork block",
				StoredConfig: big.NewInt(0),
				NewConfig:    nil,
				RewindTo:     0,
			},
		},
		{
			stored: AllEthashProtocolChanges,
			new:    &ChainConfig{HomesteadBlock: big.NewInt(1)},
			head:   3,
			wantErr: &ConfigCompatError{
				What:         "Homestead fork block",
				StoredConfig: big.NewInt(0),
				NewConfig:    big.NewInt(1),
				RewindTo:     0,
			},
		},
		{
			stored: &ChainConfig{HomesteadBlock: big.NewInt(30), EIP150Block: big.NewInt(10)},
			new:    &ChainConfig{HomesteadBlock: big.NewInt(25), EIP150Block: big.NewInt(20)},
			head:   25,
			wantErr: &ConfigCompatError{
				What:         "EIP150 fork block",
				StoredConfig: big.NewInt(10),
				NewConfig:    big.NewInt(20),
				RewindTo:     9,
			},
		},
	}

	for _, test := range tests {
		err := test.stored.CheckCompatible(test.new, test.head)
		if !reflect.DeepEqual(err, test.wantErr) {
			t.Errorf("error mismatch:\nstored: %v\nnew: %v\nhead: %v\nerr: %v\nwant: %v", test.stored, test.new, test.head, err, test.wantErr)
		}
	}
}

func TestUpdateV2Config(t *testing.T) {
	TestBRDPoSMockChainConfig.BRDPoS.V2.BuildConfigIndex()
	c := TestBRDPoSMockChainConfig.BRDPoS.V2.CurrentConfig
	assert.Equal(t, 0.667, c.CertThreshold)

	TestBRDPoSMockChainConfig.BRDPoS.V2.UpdateConfig(10)
	c = TestBRDPoSMockChainConfig.BRDPoS.V2.CurrentConfig
	assert.Equal(t, float64(0.667), c.CertThreshold)

	TestBRDPoSMockChainConfig.BRDPoS.V2.UpdateConfig(900)
	c = TestBRDPoSMockChainConfig.BRDPoS.V2.CurrentConfig
	assert.Equal(t, 4, c.TimeoutSyncThreshold)
}

func TestV2Config(t *testing.T) {
	TestBRDPoSMockChainConfig.BRDPoS.V2.BuildConfigIndex()
	c := TestBRDPoSMockChainConfig.BRDPoS.V2.Config(1)
	assert.Equal(t, 0.667, c.CertThreshold)

	c = TestBRDPoSMockChainConfig.BRDPoS.V2.Config(5)
	assert.Equal(t, 0.667, c.CertThreshold)

	c = TestBRDPoSMockChainConfig.BRDPoS.V2.Config(10)
	assert.Equal(t, 0.667, c.CertThreshold)

	c = TestBRDPoSMockChainConfig.BRDPoS.V2.Config(11)
	assert.Equal(t, float64(0.667), c.CertThreshold)
}

func TestBuildConfigIndex(t *testing.T) {
	TestBRDPoSMockChainConfig.BRDPoS.V2.BuildConfigIndex()
	index := TestBRDPoSMockChainConfig.BRDPoS.V2.ConfigIndex()
	expected := []uint64{900, 10, 0}
	assert.Equal(t, expected, index)
}

// Test switch epoch is switchblock divide into epoch per block
func TestSwitchEpoch(t *testing.T) {
	config := BRCMainnetChainConfig.BRDPoS
	epoch := config.Epoch
	assert.Equal(t, config.V2.SwitchEpoch, config.V2.SwitchBlock.Uint64()/epoch)

	config = TestnetChainConfig.BRDPoS
	epoch = config.Epoch
	assert.Equal(t, config.V2.SwitchEpoch, config.V2.SwitchBlock.Uint64()/epoch)

	config = DevnetChainConfig.BRDPoS
	epoch = config.Epoch
	assert.Equal(t, config.V2.SwitchEpoch, config.V2.SwitchBlock.Uint64()/epoch)

	config = TestBRDPoSMockChainConfig.BRDPoS
	epoch = config.Epoch
	assert.Equal(t, config.V2.SwitchEpoch, config.V2.SwitchBlock.Uint64()/epoch)
}
