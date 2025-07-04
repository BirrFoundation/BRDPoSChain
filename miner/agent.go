// Copyright 2015 The go-ethereum Authors
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

package miner

import (
	"sync"

	"sync/atomic"

	"BRDPoSChain/consensus"
	"BRDPoSChain/log"
)

type CpuAgent struct {
	mu sync.Mutex

	workCh        chan *Work
	stop          chan struct{}
	quitCurrentOp chan struct{}
	returnCh      chan<- *Result

	chain  consensus.ChainReader
	engine consensus.Engine

	isMining int32 // isMining indicates whether the agent is currently mining
}

func NewCpuAgent(chain consensus.ChainReader, engine consensus.Engine) *CpuAgent {
	miner := &CpuAgent{
		chain:  chain,
		engine: engine,
		stop:   make(chan struct{}, 1),
		workCh: make(chan *Work, 1),
	}
	return miner
}

func (ca *CpuAgent) Work() chan<- *Work            { return ca.workCh }
func (ca *CpuAgent) SetReturnCh(ch chan<- *Result) { ca.returnCh = ch }

func (ca *CpuAgent) Stop() {
	if !atomic.CompareAndSwapInt32(&ca.isMining, 1, 0) {
		return // agent already stopped
	}
	ca.stop <- struct{}{}
done:
	// Empty work channel
	for {
		select {
		case <-ca.workCh:
		default:
			break done
		}
	}
}

func (ca *CpuAgent) Start() {
	if !atomic.CompareAndSwapInt32(&ca.isMining, 0, 1) {
		return // agent already started
	}
	go ca.update()
}

func (ca *CpuAgent) update() {
out:
	for {
		select {
		case work := <-ca.workCh:
			ca.mu.Lock()
			if ca.quitCurrentOp != nil {
				close(ca.quitCurrentOp)
			}
			ca.quitCurrentOp = make(chan struct{})
			go ca.mine(work, ca.quitCurrentOp)
			ca.mu.Unlock()
		case <-ca.stop:
			ca.mu.Lock()
			if ca.quitCurrentOp != nil {
				close(ca.quitCurrentOp)
				ca.quitCurrentOp = nil
			}
			ca.mu.Unlock()
			break out
		}
	}
}

func (ca *CpuAgent) mine(work *Work, stop <-chan struct{}) {
	if result, err := ca.engine.Seal(ca.chain, work.Block, stop); result != nil {
		log.Info("Successfully sealed new block", "number", result.Number(), "hash", result.Hash())
		ca.returnCh <- &Result{work, result}
	} else {
		if err != nil {
			log.Warn("Block sealing failed", "err", err)
		}
		ca.returnCh <- nil
	}
}

func (ca *CpuAgent) GetHashRate() int64 {
	if pow, ok := ca.engine.(consensus.PoW); ok {
		return int64(pow.Hashrate())
	}
	return 0
}
