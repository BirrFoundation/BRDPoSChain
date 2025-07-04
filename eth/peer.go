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

package eth

import (
	"errors"
	"fmt"
	"math/big"
	"sync"
	"time"

	"BRDPoSChain/common"
	"BRDPoSChain/core/types"
	"BRDPoSChain/p2p"
	"BRDPoSChain/rlp"
	mapset "github.com/deckarep/golang-set/v2"
)

var (
	errClosed            = errors.New("peer set is closed")
	errAlreadyRegistered = errors.New("peer is already registered")
	errNotRegistered     = errors.New("peer is not registered")
)

const (
	maxKnownTxs        = 32768  // Maximum transactions hashes to keep in the known list (prevent DOS)
	maxKnownOrderTxs   = 32768  // Maximum transactions hashes to keep in the known list (prevent DOS)
	maxKnownLendingTxs = 32768  // Maximum transactions hashes to keep in the known list (prevent DOS)
	maxKnownBlocks     = 1024   // Maximum block hashes to keep in the known list (prevent DOS)
	maxKnownVote       = 131072 // Maximum transactions hashes to keep in the known list (prevent DOS)
	maxKnownTimeout    = 131072 // Maximum transactions hashes to keep in the known list (prevent DOS)
	maxKnownSyncInfo   = 131072 // Maximum transactions hashes to keep in the known list (prevent DOS)
	handshakeTimeout   = 5 * time.Second
)

// PeerInfo represents a short summary of the Ethereum sub-protocol metadata known
// about a connected peer.
type PeerInfo struct {
	Version    int      `json:"version"`    // Ethereum protocol version negotiated
	Difficulty *big.Int `json:"difficulty"` // Total difficulty of the peer's blockchain
	Head       string   `json:"head"`       // SHA3 hash of the peer's best owned block
}

type peer struct {
	id string

	*p2p.Peer
	rw     p2p.MsgReadWriter
	pairRw p2p.MsgReadWriter

	version  int         // Protocol version negotiated
	forkDrop *time.Timer // Timed connection dropper if forks aren't validated in time

	head common.Hash
	td   *big.Int
	lock sync.RWMutex

	knownTxs    mapset.Set[common.Hash] // Set of transaction hashes known to be known by this peer
	knownBlocks mapset.Set[common.Hash] // Set of block hashes known to be known by this peer

	knownOrderTxs   mapset.Set[common.Hash] // Set of order transaction hashes known to be known by this peer
	knownLendingTxs mapset.Set[common.Hash] // Set of lending transaction hashes known to be known by this peer

	knownVote     mapset.Set[common.Hash] // Set of BFT Vote known to be known by this peer
	knownTimeout  mapset.Set[common.Hash] // Set of BFT timeout known to be known by this peer
	knownSyncInfo mapset.Set[common.Hash] // Set of BFT Sync Info known to be known by this peer
}

func newPeer(version int, p *p2p.Peer, rw p2p.MsgReadWriter) *peer {
	id := p.ID()

	return &peer{
		Peer:            p,
		rw:              rw,
		version:         version,
		id:              fmt.Sprintf("%x", id[:8]),
		knownTxs:        mapset.NewSet[common.Hash](),
		knownBlocks:     mapset.NewSet[common.Hash](),
		knownOrderTxs:   mapset.NewSet[common.Hash](),
		knownLendingTxs: mapset.NewSet[common.Hash](),

		knownVote:     mapset.NewSet[common.Hash](),
		knownTimeout:  mapset.NewSet[common.Hash](),
		knownSyncInfo: mapset.NewSet[common.Hash](),
	}
}

// Info gathers and returns a collection of metadata known about a peer.
func (p *peer) Info() *PeerInfo {
	hash, td := p.Head()

	return &PeerInfo{
		Version:    p.version,
		Difficulty: td,
		Head:       hash.Hex(),
	}
}

// Head retrieves a copy of the current head hash and total difficulty of the
// peer.
func (p *peer) Head() (hash common.Hash, td *big.Int) {
	p.lock.RLock()
	defer p.lock.RUnlock()

	copy(hash[:], p.head[:])
	return hash, new(big.Int).Set(p.td)
}

// SetHead updates the head hash and total difficulty of the peer.
func (p *peer) SetHead(hash common.Hash, td *big.Int) {
	p.lock.Lock()
	defer p.lock.Unlock()

	copy(p.head[:], hash[:])
	p.td.Set(td)
}

// MarkBlock marks a block as known for the peer, ensuring that the block will
// never be propagated to this particular peer.
func (p *peer) MarkBlock(hash common.Hash) {
	// If we reached the memory allowance, drop a previously known block hash
	for p.knownBlocks.Cardinality() >= maxKnownBlocks {
		p.knownBlocks.Pop()
	}
	p.knownBlocks.Add(hash)
}

// MarkTransaction marks a transaction as known for the peer, ensuring that it
// will never be propagated to this particular peer.
func (p *peer) MarkTransaction(hash common.Hash) {
	// If we reached the memory allowance, drop a previously known transaction hash
	for p.knownTxs.Cardinality() >= maxKnownTxs {
		p.knownTxs.Pop()
	}
	p.knownTxs.Add(hash)
}

// OrderMarkTransaction marks a order transaction as known for the peer, ensuring that it
// will never be propagated to this particular peer.
func (p *peer) MarkOrderTransaction(hash common.Hash) {
	// If we reached the memory allowance, drop a previously known transaction hash
	for p.knownOrderTxs.Cardinality() >= maxKnownOrderTxs {
		p.knownOrderTxs.Pop()
	}
	p.knownOrderTxs.Add(hash)
}

// MarkLendingTransaction marks a lending transaction as known for the peer, ensuring that it
// will never be propagated to this particular peer.
func (p *peer) MarkLendingTransaction(hash common.Hash) {
	// If we reached the memory allowance, drop a previously known transaction hash
	for p.knownLendingTxs.Cardinality() >= maxKnownLendingTxs {
		p.knownLendingTxs.Pop()
	}
	p.knownLendingTxs.Add(hash)
}

// MarkVote marks a vote as known for the peer, ensuring that it
// will never be propagated to this particular peer.
func (p *peer) MarkVote(hash common.Hash) {
	// If we reached the memory allowance, drop a previously known transaction hash
	for p.knownVote.Cardinality() >= maxKnownVote {
		p.knownVote.Pop()
	}
	p.knownVote.Add(hash)
}

// MarkTimeout marks a timeout as known for the peer, ensuring that it
// will never be propagated to this particular peer.
func (p *peer) MarkTimeout(hash common.Hash) {
	// If we reached the memory allowance, drop a previously known transaction hash
	for p.knownTimeout.Cardinality() >= maxKnownTimeout {
		p.knownTimeout.Pop()
	}
	p.knownTimeout.Add(hash)
}

// MarkSyncInfo marks a syncInfo as known for the peer, ensuring that it
// will never be propagated to this particular peer.
func (p *peer) MarkSyncInfo(hash common.Hash) {
	// If we reached the memory allowance, drop a previously known transaction hash
	for p.knownSyncInfo.Cardinality() >= maxKnownSyncInfo {
		p.knownSyncInfo.Pop()
	}
	p.knownSyncInfo.Add(hash)
}

// SendTransactions sends transactions to the peer and includes the hashes
// in its transaction hash set for future reference.
func (p *peer) SendTransactions(txs types.Transactions) error {
	for p.knownTxs.Cardinality() >= maxKnownTxs {
		p.knownTxs.Pop()
	}
	for _, tx := range txs {
		p.knownTxs.Add(tx.Hash())
	}
	return p2p.Send(p.rw, TxMsg, txs)
}

// SendTransactions sends transactions to the peer and includes the hashes
// in its transaction hash set for future reference.
func (p *peer) SendOrderTransactions(txs types.OrderTransactions) error {
	for p.knownOrderTxs.Cardinality() >= maxKnownOrderTxs {
		p.knownOrderTxs.Pop()
	}

	for _, tx := range txs {
		p.knownOrderTxs.Add(tx.Hash())
	}
	return p2p.Send(p.rw, OrderTxMsg, txs)
}

// SendTransactions sends transactions to the peer and includes the hashes
// in its transaction hash set for future reference.
func (p *peer) SendLendingTransactions(txs types.LendingTransactions) error {
	for p.knownLendingTxs.Cardinality() >= maxKnownLendingTxs {
		p.knownLendingTxs.Pop()
	}

	for _, tx := range txs {
		p.knownLendingTxs.Add(tx.Hash())
	}
	return p2p.Send(p.rw, LendingTxMsg, txs)
}

// SendNewBlockHashes announces the availability of a number of blocks through
// a hash notification.
func (p *peer) SendNewBlockHashes(hashes []common.Hash, numbers []uint64) error {
	for p.knownBlocks.Cardinality() >= maxKnownBlocks {
		p.knownBlocks.Pop()
	}

	for _, hash := range hashes {
		p.knownBlocks.Add(hash)
	}
	request := make(newBlockHashesData, len(hashes))
	for i := 0; i < len(hashes); i++ {
		request[i].Hash = hashes[i]
		request[i].Number = numbers[i]
	}
	return p2p.Send(p.rw, NewBlockHashesMsg, request)
}

// SendNewBlock propagates an entire block to a remote peer.
func (p *peer) SendNewBlock(block *types.Block, td *big.Int) error {
	for p.knownBlocks.Cardinality() >= maxKnownBlocks {
		p.knownBlocks.Pop()
	}

	p.knownBlocks.Add(block.Hash())
	if p.pairRw != nil {
		return p2p.Send(p.pairRw, NewBlockMsg, []interface{}{block, td})
	} else {
		return p2p.Send(p.rw, NewBlockMsg, []interface{}{block, td})
	}
}

// SendBlockHeaders sends a batch of block headers to the remote peer.
func (p *peer) SendBlockHeaders(headers []*types.Header) error {
	if p.pairRw != nil {
		return p2p.Send(p.pairRw, BlockHeadersMsg, headers)
	} else {
		return p2p.Send(p.rw, BlockHeadersMsg, headers)
	}
}

// SendBlockBodies sends a batch of block contents to the remote peer.
func (p *peer) SendBlockBodies(bodies []*blockBody) error {
	if p.pairRw != nil {
		return p2p.Send(p.pairRw, BlockBodiesMsg, blockBodiesData(bodies))
	} else {
		return p2p.Send(p.rw, BlockBodiesMsg, blockBodiesData(bodies))
	}
}

// SendBlockBodiesRLP sends a batch of block contents to the remote peer from
// an already RLP encoded format.
func (p *peer) SendBlockBodiesRLP(bodies []rlp.RawValue) error {
	if p.pairRw != nil {
		return p2p.Send(p.pairRw, BlockBodiesMsg, bodies)
	} else {
		return p2p.Send(p.rw, BlockBodiesMsg, bodies)
	}
}

// SendNodeDataRLP sends a batch of arbitrary internal data, corresponding to the
// hashes requested.
func (p *peer) SendNodeData(data [][]byte) error {
	if p.pairRw != nil {
		return p2p.Send(p.pairRw, NodeDataMsg, data)
	} else {
		return p2p.Send(p.rw, NodeDataMsg, data)
	}
}

// SendReceiptsRLP sends a batch of transaction receipts, corresponding to the
// ones requested from an already RLP encoded format.
func (p *peer) SendReceiptsRLP(receipts []rlp.RawValue) error {
	if p.pairRw != nil {
		return p2p.Send(p.pairRw, ReceiptsMsg, receipts)
	} else {
		return p2p.Send(p.rw, ReceiptsMsg, receipts)
	}
}

func (p *peer) SendVote(vote *types.Vote) error {
	for p.knownVote.Cardinality() >= maxKnownVote {
		p.knownVote.Pop()
	}

	p.knownVote.Add(vote.Hash())
	if p.pairRw != nil {
		return p2p.Send(p.pairRw, VoteMsg, vote)
	} else {
		return p2p.Send(p.rw, VoteMsg, vote)
	}
}

/*
func (p *peer) AsyncSendVote() {

}
*/
func (p *peer) SendTimeout(timeout *types.Timeout) error {
	for p.knownTimeout.Cardinality() >= maxKnownTimeout {
		p.knownTimeout.Pop()
	}

	p.knownTimeout.Add(timeout.Hash())
	if p.pairRw != nil {
		return p2p.Send(p.pairRw, TimeoutMsg, timeout)
	} else {
		return p2p.Send(p.rw, TimeoutMsg, timeout)
	}
}

/*
func (p *peer) AsyncSendTimeout() {

}
*/
func (p *peer) SendSyncInfo(syncInfo *types.SyncInfo) error {
	for p.knownSyncInfo.Cardinality() >= maxKnownSyncInfo {
		p.knownSyncInfo.Pop()
	}

	p.knownSyncInfo.Add(syncInfo.Hash())
	if p.pairRw != nil {
		return p2p.Send(p.pairRw, SyncInfoMsg, syncInfo)
	} else {
		return p2p.Send(p.rw, SyncInfoMsg, syncInfo)
	}
}

/*
func (p *peer) AsyncSendSyncInfo() {

}
*/

// RequestOneHeader is a wrapper around the header query functions to fetch a
// single header. It is used solely by the fetcher.
func (p *peer) RequestOneHeader(hash common.Hash) error {
	p.Log().Debug("Fetching single header", "hash", hash)
	if p.pairRw != nil {
		return p2p.Send(p.pairRw, GetBlockHeadersMsg, &getBlockHeadersData{Origin: hashOrNumber{Hash: hash}, Amount: uint64(1), Skip: uint64(0), Reverse: false})
	} else {
		return p2p.Send(p.rw, GetBlockHeadersMsg, &getBlockHeadersData{Origin: hashOrNumber{Hash: hash}, Amount: uint64(1), Skip: uint64(0), Reverse: false})
	}
}

// RequestHeadersByHash fetches a batch of blocks' headers corresponding to the
// specified header query, based on the hash of an origin block.
func (p *peer) RequestHeadersByHash(origin common.Hash, amount int, skip int, reverse bool) error {
	p.Log().Debug("Fetching batch of headers", "count", amount, "fromhash", origin, "skip", skip, "reverse", reverse)
	if p.pairRw != nil {
		return p2p.Send(p.pairRw, GetBlockHeadersMsg, &getBlockHeadersData{Origin: hashOrNumber{Hash: origin}, Amount: uint64(amount), Skip: uint64(skip), Reverse: reverse})
	} else {
		return p2p.Send(p.rw, GetBlockHeadersMsg, &getBlockHeadersData{Origin: hashOrNumber{Hash: origin}, Amount: uint64(amount), Skip: uint64(skip), Reverse: reverse})
	}
}

// RequestHeadersByNumber fetches a batch of blocks' headers corresponding to the
// specified header query, based on the number of an origin block.
func (p *peer) RequestHeadersByNumber(origin uint64, amount int, skip int, reverse bool) error {
	p.Log().Debug("Fetching batch of headers", "count", amount, "fromnum", origin, "skip", skip, "reverse", reverse)
	if p.pairRw != nil {
		return p2p.Send(p.pairRw, GetBlockHeadersMsg, &getBlockHeadersData{Origin: hashOrNumber{Number: origin}, Amount: uint64(amount), Skip: uint64(skip), Reverse: reverse})
	} else {
		return p2p.Send(p.rw, GetBlockHeadersMsg, &getBlockHeadersData{Origin: hashOrNumber{Number: origin}, Amount: uint64(amount), Skip: uint64(skip), Reverse: reverse})
	}
}

// RequestBodies fetches a batch of blocks' bodies corresponding to the hashes
// specified.
func (p *peer) RequestBodies(hashes []common.Hash) error {
	p.Log().Debug("Fetching batch of block bodies", "count", len(hashes))
	if p.pairRw != nil {
		return p2p.Send(p.pairRw, GetBlockBodiesMsg, hashes)
	} else {
		return p2p.Send(p.rw, GetBlockBodiesMsg, hashes)
	}
}

// RequestNodeData fetches a batch of arbitrary data from a node's known state
// data, corresponding to the specified hashes.
func (p *peer) RequestNodeData(hashes []common.Hash) error {
	p.Log().Debug("Fetching batch of state data", "count", len(hashes))
	if p.pairRw != nil {
		return p2p.Send(p.pairRw, GetNodeDataMsg, hashes)
	} else {
		return p2p.Send(p.rw, GetNodeDataMsg, hashes)
	}
}

// RequestReceipts fetches a batch of transaction receipts from a remote node.
func (p *peer) RequestReceipts(hashes []common.Hash) error {
	p.Log().Debug("Fetching batch of receipts", "count", len(hashes))
	if p.pairRw != nil {
		return p2p.Send(p.pairRw, GetReceiptsMsg, hashes)
	} else {
		return p2p.Send(p.rw, GetReceiptsMsg, hashes)
	}
}

// Handshake executes the eth protocol handshake, negotiating version number,
// network IDs, difficulties, head and genesis blocks.
func (p *peer) Handshake(network uint64, td *big.Int, head common.Hash, genesis common.Hash) error {
	// Send out own handshake in a new thread
	errc := make(chan error, 2)
	var status statusData // safe to read after two values have been received from errc

	go func() {
		errc <- p2p.Send(p.rw, StatusMsg, &statusData{
			ProtocolVersion: uint32(p.version),
			NetworkId:       network,
			TD:              td,
			CurrentBlock:    head,
			GenesisBlock:    genesis,
		})
	}()
	go func() {
		errc <- p.readStatus(network, &status, genesis)
	}()
	timeout := time.NewTimer(handshakeTimeout)
	defer timeout.Stop()
	for i := 0; i < 2; i++ {
		select {
		case err := <-errc:
			if err != nil {
				return err
			}
		case <-timeout.C:
			return p2p.DiscReadTimeout
		}
	}
	p.td, p.head = status.TD, status.CurrentBlock
	return nil
}

func (p *peer) readStatus(network uint64, status *statusData, genesis common.Hash) (err error) {
	msg, err := p.rw.ReadMsg()
	if err != nil {
		return err
	}
	if msg.Code != StatusMsg {
		return errResp(ErrNoStatusMsg, "first msg has code %x (!= %x)", msg.Code, StatusMsg)
	}
	if msg.Size > ProtocolMaxMsgSize {
		return errResp(ErrMsgTooLarge, "%v > %v", msg.Size, ProtocolMaxMsgSize)
	}
	// Decode the handshake and make sure everything matches
	if err := msg.Decode(&status); err != nil {
		return errResp(ErrDecode, "msg %v: %v", msg, err)
	}
	if status.GenesisBlock != genesis {
		return errResp(ErrGenesisBlockMismatch, "%x (!= %x)", status.GenesisBlock[:8], genesis[:8])
	}
	if status.NetworkId != network {
		return errResp(ErrNetworkIdMismatch, "%d (!= %d)", status.NetworkId, network)
	}
	if int(status.ProtocolVersion) != p.version {
		return errResp(ErrProtocolVersionMismatch, "%d (!= %d)", status.ProtocolVersion, p.version)
	}
	return nil
}

// String implements fmt.Stringer.
func (p *peer) String() string {
	return fmt.Sprintf("Peer %s [%s]", p.id,
		fmt.Sprintf("eth/%2d", p.version),
	)
}

// peerSet represents the collection of active peers currently participating in
// the Ethereum sub-protocol.
type peerSet struct {
	peers  map[string]*peer
	lock   sync.RWMutex
	closed bool
}

// newPeerSet creates a new peer set to track the active participants.
func newPeerSet() *peerSet {
	return &peerSet{
		peers: make(map[string]*peer),
	}
}

// Register injects a new peer into the working set, or returns an error if the
// peer is already known.
func (ps *peerSet) Register(p *peer) error {
	ps.lock.Lock()
	defer ps.lock.Unlock()

	if ps.closed {
		return errClosed
	}
	if existPeer, ok := ps.peers[p.id]; ok {
		if existPeer.pairRw != nil {
			return errAlreadyRegistered
		}
		existPeer.PairPeer = p.Peer
		existPeer.pairRw = p.rw
		p.PairPeer = existPeer.Peer
		return p2p.ErrAddPairPeer
	}
	ps.peers[p.id] = p
	return nil
}

// Unregister removes a remote peer from the active set, disabling any further
// actions to/from that particular entity.
func (ps *peerSet) Unregister(id string) error {
	ps.lock.Lock()
	defer ps.lock.Unlock()

	if _, ok := ps.peers[id]; !ok {
		return errNotRegistered
	}
	delete(ps.peers, id)
	return nil
}

// Peer retrieves the registered peer with the given id.
func (ps *peerSet) Peer(id string) *peer {
	ps.lock.RLock()
	defer ps.lock.RUnlock()

	return ps.peers[id]
}

// Len returns if the current number of peers in the set.
func (ps *peerSet) Len() int {
	ps.lock.RLock()
	defer ps.lock.RUnlock()

	return len(ps.peers)
}

// PeersWithoutBlock retrieves a list of peers that do not have a given block in
// their set of known hashes.
func (ps *peerSet) PeersWithoutBlock(hash common.Hash) []*peer {
	ps.lock.RLock()
	defer ps.lock.RUnlock()

	list := make([]*peer, 0, len(ps.peers))
	for _, p := range ps.peers {
		if !p.knownBlocks.Contains(hash) {
			list = append(list, p)
		}
	}
	return list
}

// PeersWithoutTx retrieves a list of peers that do not have a given transaction
// in their set of known hashes.
func (ps *peerSet) PeersWithoutTx(hash common.Hash) []*peer {
	ps.lock.RLock()
	defer ps.lock.RUnlock()

	list := make([]*peer, 0, len(ps.peers))
	for _, p := range ps.peers {
		if !p.knownTxs.Contains(hash) {
			list = append(list, p)
		}
	}
	return list
}

// PeersWithoutVote retrieves a list of peers that do not have a given block in
// their set of known hashes.
func (ps *peerSet) PeersWithoutVote(hash common.Hash) []*peer {
	ps.lock.RLock()
	defer ps.lock.RUnlock()

	list := make([]*peer, 0, len(ps.peers))
	for _, p := range ps.peers {
		if !p.knownVote.Contains(hash) {
			list = append(list, p)
		}
	}
	return list
}

// PeersWithoutTimeout retrieves a list of peers that do not have a given block in
// their set of known hashes.
func (ps *peerSet) PeersWithoutTimeout(hash common.Hash) []*peer {
	ps.lock.RLock()
	defer ps.lock.RUnlock()

	list := make([]*peer, 0, len(ps.peers))
	for _, p := range ps.peers {
		if !p.knownTimeout.Contains(hash) {
			list = append(list, p)
		}
	}
	return list
}

// PeersWithoutSyncInfo retrieves a list of peers that do not have a given block in
// their set of known hashes.
func (ps *peerSet) PeersWithoutSyncInfo(hash common.Hash) []*peer {
	ps.lock.RLock()
	defer ps.lock.RUnlock()

	list := make([]*peer, 0, len(ps.peers))
	for _, p := range ps.peers {
		if !p.knownSyncInfo.Contains(hash) {
			list = append(list, p)
		}
	}
	return list
}

// PeersWithoutTx retrieves a list of peers that do not have a given transaction
// in their set of known hashes.
func (ps *peerSet) OrderPeersWithoutTx(hash common.Hash) []*peer {
	ps.lock.RLock()
	defer ps.lock.RUnlock()

	list := make([]*peer, 0, len(ps.peers))
	for _, p := range ps.peers {
		if !p.knownOrderTxs.Contains(hash) {
			list = append(list, p)
		}
	}
	return list
}

// LendingPeersWithoutTx retrieves a list of peers that do not have a given transaction
// in their set of known hashes.
func (ps *peerSet) LendingPeersWithoutTx(hash common.Hash) []*peer {
	ps.lock.RLock()
	defer ps.lock.RUnlock()

	list := make([]*peer, 0, len(ps.peers))
	for _, p := range ps.peers {
		if !p.knownLendingTxs.Contains(hash) {
			list = append(list, p)
		}
	}
	return list
}

// BestPeer retrieves the known peer with the currently highest total difficulty.
func (ps *peerSet) BestPeer() *peer {
	ps.lock.RLock()
	defer ps.lock.RUnlock()

	var (
		bestPeer *peer
		bestTd   *big.Int
	)
	for _, p := range ps.peers {
		if _, td := p.Head(); bestPeer == nil || td.Cmp(bestTd) > 0 {
			bestPeer, bestTd = p, td
		}
	}
	return bestPeer
}

// Close disconnects all peers.
// No new peers can be registered after Close has returned.
func (ps *peerSet) Close() {
	ps.lock.Lock()
	defer ps.lock.Unlock()

	for _, p := range ps.peers {
		p.Disconnect(p2p.DiscQuitting)
	}
	ps.closed = true
}
