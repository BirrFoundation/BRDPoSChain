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

package testing

import (
	"errors"
	"fmt"
	"sync"
	"time"

	"BRDPoSChain/log"
	"BRDPoSChain/p2p"
	"BRDPoSChain/p2p/discover"
	"BRDPoSChain/p2p/simulations/adapters"
)

var errTimedOut = errors.New("timed out")

// ProtocolSession is a quasi simulation of a pivot node running
// a service and a number of dummy peers that can send (trigger) or
// receive (expect) messages
type ProtocolSession struct {
	Server  *p2p.Server
	IDs     []discover.NodeID
	adapter *adapters.SimAdapter
	events  chan *p2p.PeerEvent
}

// Exchange is the basic units of protocol tests
// the triggers and expects in the arrays are run immediately and asynchronously
// thus one cannot have multiple expects for the SAME peer with DIFFERENT message types
// because it's unpredictable which expect will receive which message
// (with expect #1 and #2, messages might be sent #2 and #1, and both expects will complain about wrong message code)
// an exchange is defined on a session
type Exchange struct {
	Label    string
	Triggers []Trigger
	Expects  []Expect
	Timeout  time.Duration
}

// Trigger is part of the exchange, incoming message for the pivot node
// sent by a peer
type Trigger struct {
	Msg     interface{}     // type of message to be sent
	Code    uint64          // code of message is given
	Peer    discover.NodeID // the peer to send the message to
	Timeout time.Duration   // timeout duration for the sending
}

// Expect is part of an exchange, outgoing message from the pivot node
// received by a peer
type Expect struct {
	Msg     interface{}     // type of message to expect
	Code    uint64          // code of message is now given
	Peer    discover.NodeID // the peer that expects the message
	Timeout time.Duration   // timeout duration for receiving
}

// Disconnect represents a disconnect event, used and checked by TestDisconnected
type Disconnect struct {
	Peer  discover.NodeID // discconnected peer
	Error error           // disconnect reason
}

// trigger sends messages from peers
func (ps *ProtocolSession) trigger(trig Trigger) error {
	simNode, ok := ps.adapter.GetNode(trig.Peer)
	if !ok {
		return fmt.Errorf("trigger: peer %v does not exist (1- %v)", trig.Peer, len(ps.IDs))
	}
	mockNode, ok := simNode.Services()[0].(*mockNode)
	if !ok {
		return fmt.Errorf("trigger: peer %v is not a mock", trig.Peer)
	}

	errc := make(chan error)

	go func() {
		errc <- mockNode.Trigger(&trig)
	}()

	t := trig.Timeout
	if t == time.Duration(0) {
		t = 1000 * time.Millisecond
	}
	select {
	case err := <-errc:
		return err
	case <-time.After(t):
		return fmt.Errorf("timout expecting %v to send to peer %v", trig.Msg, trig.Peer)
	}
}

// expect checks an expectation of a message sent out by the pivot node
func (ps *ProtocolSession) expect(exps []Expect) error {
	// construct a map of expectations for each node
	peerExpects := make(map[discover.NodeID][]Expect)
	for _, exp := range exps {
		if exp.Msg == nil {
			return errors.New("no message to expect")
		}
		peerExpects[exp.Peer] = append(peerExpects[exp.Peer], exp)
	}

	// construct a map of mockNodes for each node
	mockNodes := make(map[discover.NodeID]*mockNode)
	for nodeID := range peerExpects {
		simNode, ok := ps.adapter.GetNode(nodeID)
		if !ok {
			return fmt.Errorf("trigger: peer %v does not exist (1- %v)", nodeID, len(ps.IDs))
		}
		mockNode, ok := simNode.Services()[0].(*mockNode)
		if !ok {
			return fmt.Errorf("trigger: peer %v is not a mock", nodeID)
		}
		mockNodes[nodeID] = mockNode
	}

	// done chanell cancels all created goroutines when function returns
	done := make(chan struct{})
	defer close(done)
	// errc catches the first error from
	errc := make(chan error)

	wg := &sync.WaitGroup{}
	wg.Add(len(mockNodes))
	for nodeID, mockNode := range mockNodes {
		nodeID := nodeID
		mockNode := mockNode
		go func() {
			defer wg.Done()

			// Sum all Expect timeouts to give the maximum
			// time for all expectations to finish.
			// mockNode.Expect checks all received messages against
			// a list of expected messages and timeout for each
			// of them can not be checked separately.
			var t time.Duration
			for _, exp := range peerExpects[nodeID] {
				if exp.Timeout == time.Duration(0) {
					t += 2000 * time.Millisecond
				} else {
					t += exp.Timeout
				}
			}
			alarm := time.NewTimer(t)
			defer alarm.Stop()

			// expectErrc is used to check if error returned
			// from mockNode.Expect is not nil and to send it to
			// errc only in that case.
			// done channel will be closed when function
			expectErrc := make(chan error)
			go func() {
				select {
				case expectErrc <- mockNode.Expect(peerExpects[nodeID]...):
				case <-done:
				case <-alarm.C:
				}
			}()

			select {
			case err := <-expectErrc:
				if err != nil {
					select {
					case errc <- err:
					case <-done:
					case <-alarm.C:
						errc <- errTimedOut
					}
				}
			case <-done:
			case <-alarm.C:
				errc <- errTimedOut
			}

		}()
	}

	go func() {
		wg.Wait()
		// close errc when all goroutines finish to return nill err from errc
		close(errc)
	}()

	return <-errc
}

// TestExchanges tests a series of exchanges against the session
func (ps *ProtocolSession) TestExchanges(exchanges ...Exchange) error {
	for i, e := range exchanges {
		if err := ps.testExchange(e); err != nil {
			return fmt.Errorf("exchange #%d %q: %v", i, e.Label, err)
		}
		log.Trace(fmt.Sprintf("exchange #%d %q: run successfully", i, e.Label))
	}
	return nil
}

// testExchange tests a single Exchange.
// Default timeout value is 2 seconds.
func (ps *ProtocolSession) testExchange(e Exchange) error {
	errc := make(chan error)
	done := make(chan struct{})
	defer close(done)

	go func() {
		for _, trig := range e.Triggers {
			err := ps.trigger(trig)
			if err != nil {
				errc <- err
				return
			}
		}

		select {
		case errc <- ps.expect(e.Expects):
		case <-done:
		}
	}()

	// time out globally or finish when all expectations satisfied
	t := e.Timeout
	if t == 0 {
		t = 2000 * time.Millisecond
	}
	alarm := time.NewTimer(t)
	select {
	case err := <-errc:
		return err
	case <-alarm.C:
		return errTimedOut
	}
}

// TestDisconnected tests the disconnections given as arguments
// the disconnect structs describe what disconnect error is expected on which peer
func (ps *ProtocolSession) TestDisconnected(disconnects ...*Disconnect) error {
	expects := make(map[discover.NodeID]error)
	for _, disconnect := range disconnects {
		expects[disconnect.Peer] = disconnect.Error
	}

	timeout := time.After(time.Second)
	for len(expects) > 0 {
		select {
		case event := <-ps.events:
			if event.Type != p2p.PeerEventTypeDrop {
				continue
			}
			expectErr, ok := expects[event.Peer]
			if !ok {
				continue
			}

			if !(expectErr == nil && event.Error == "" || expectErr != nil && expectErr.Error() == event.Error) {
				return fmt.Errorf("unexpected error on peer %v. expected '%v', got '%v'", event.Peer, expectErr, event.Error)
			}
			delete(expects, event.Peer)
		case <-timeout:
			return errors.New("timed out waiting for peers to disconnect")
		}
	}
	return nil
}
