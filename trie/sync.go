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

package trie

import (
	"errors"
	"fmt"

	"BRDPoSChain/common"
	"BRDPoSChain/common/prque"
	"BRDPoSChain/ethdb"
)

// ErrNotRequested is returned by the trie sync when it's requested to process a
// Node it did not request.
var ErrNotRequested = errors.New("not requested")

// ErrAlreadyProcessed is returned by the trie sync when it's requested to process a
// Node it already processed previously.
var ErrAlreadyProcessed = errors.New("already processed")

// request represents a scheduled or already in-flight state retrieval request.
type request struct {
	hash common.Hash // Hash of the Node data content to retrieve
	data []byte      // Data content of the Node, cached until all subtrees complete
	raw  bool        // Whether this is a raw entry (code) or a trie Node

	parents []*request // Parent state nodes referencing this entry (notify all upon completion)
	depth   int        // Depth level within the trie the Node is located to prioritise DFS
	deps    int        // Number of dependencies before allowed to commit this Node

	callback LeafCallback // Callback to invoke if a leaf Node it reached on this branch
}

// SyncResult is a simple list to return missing nodes along with their request
// hashes.
type SyncResult struct {
	Hash common.Hash // Hash of the originally unknown trie Node
	Data []byte      // Data content of the retrieved Node
}

// syncMemBatch is an in-memory buffer of successfully downloaded but not yet
// persisted data items.
type syncMemBatch struct {
	batch map[common.Hash][]byte // In-memory membatch of recently completed items
}

// newSyncMemBatch allocates a new memory-buffer for not-yet persisted trie nodes.
func newSyncMemBatch() *syncMemBatch {
	return &syncMemBatch{
		batch: make(map[common.Hash][]byte),
	}
}

// Sync is the main state trie synchronisation scheduler, which provides yet
// unknown trie hashes to retrieve, accepts Node data associated with said hashes
// and reconstructs the trie step by step until all is done.
type Sync struct {
	database ethdb.KeyValueReader     // Persistent database to check for existing entries
	membatch *syncMemBatch            // Memory buffer to avoid frequent database writes
	requests map[common.Hash]*request // Pending requests pertaining to a key hash
	queue    *prque.Prque[int64, any] // Priority queue with the pending requests
	bloom    *SyncBloom               // Bloom filter for fast Node existence checks
}

// NewSync creates a new trie data download scheduler.
func NewSync(root common.Hash, database ethdb.KeyValueReader, callback LeafCallback, bloom *SyncBloom) *Sync {
	ts := &Sync{
		database: database,
		membatch: newSyncMemBatch(),
		requests: make(map[common.Hash]*request),
		queue:    prque.New[int64, any](nil), // Ugh, can contain both string and hash, whyyy
		bloom:    bloom,
	}
	ts.AddSubTrie(root, 0, common.Hash{}, callback)
	return ts
}

// AddSubTrie registers a new trie to the sync code, rooted at the designated parent.
func (s *Sync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callback LeafCallback) {
	// Short circuit if the trie is empty or already known
	if root == emptyRoot {
		return
	}
	if _, ok := s.membatch.batch[root]; ok {
		return
	}
	if s.bloom.Contains(root[:]) {
		// Bloom filter says this might be a duplicate, double check
		blob, _ := s.database.Get(root[:])
		if local, err := decodeNode(root[:], blob); local != nil && err == nil {
			return
		}
		// False positive, bump fault meter
		bloomFaultMeter.Mark(1)
	}
	// Assemble the new sub-trie sync request
	req := &request{
		hash:     root,
		depth:    depth,
		callback: callback,
	}
	// If this sub-trie has a designated parent, link them together
	if parent != (common.Hash{}) {
		ancestor := s.requests[parent]
		if ancestor == nil {
			panic(fmt.Sprintf("sub-trie ancestor not found: %x", parent))
		}
		ancestor.deps++
		req.parents = append(req.parents, ancestor)
	}
	s.schedule(req)
}

// AddRawEntry schedules the direct retrieval of a state entry that should not be
// interpreted as a trie Node, but rather accepted and stored into the database
// as is. This method's goal is to support misc state metadata retrievals (e.g.
// contract code).
func (s *Sync) AddRawEntry(hash common.Hash, depth int, parent common.Hash) {
	// Short circuit if the entry is empty or already known
	if hash == emptyState {
		return
	}
	if _, ok := s.membatch.batch[hash]; ok {
		return
	}
	if s.bloom.Contains(hash[:]) {
		// Bloom filter says this might be a duplicate, double check
		if ok, _ := s.database.Has(hash[:]); ok {
			return
		}
		// False positive, bump fault meter
		bloomFaultMeter.Mark(1)
	}
	// Assemble the new sub-trie sync request
	req := &request{
		hash:  hash,
		raw:   true,
		depth: depth,
	}
	// If this sub-trie has a designated parent, link them together
	if parent != (common.Hash{}) {
		ancestor := s.requests[parent]
		if ancestor == nil {
			panic(fmt.Sprintf("raw-entry ancestor not found: %x", parent))
		}
		ancestor.deps++
		req.parents = append(req.parents, ancestor)
	}
	s.schedule(req)
}

// Missing retrieves the known missing nodes from the trie for retrieval.
func (s *Sync) Missing(max int) []common.Hash {
	var requests []common.Hash
	for !s.queue.Empty() && (max == 0 || len(requests) < max) {
		requests = append(requests, s.queue.PopItem().(common.Hash))
	}
	return requests
}

// Process injects a batch of retrieved trie nodes data, returning if something
// was committed to the database and also the index of an entry if its processing
// failed.
func (s *Sync) Process(results []SyncResult) (bool, int, error) {
	committed := false

	for i, item := range results {
		// If the item was not requested, bail out
		request := s.requests[item.Hash]
		if request == nil {
			return committed, i, ErrNotRequested
		}
		if request.data != nil {
			return committed, i, ErrAlreadyProcessed
		}
		// If the item is a raw entry request, commit directly
		if request.raw {
			request.data = item.Data
			s.commit(request)
			committed = true
			continue
		}
		// Decode the Node data content and update the request
		node, err := decodeNode(item.Hash[:], item.Data)
		if err != nil {
			return committed, i, err
		}
		request.data = item.Data

		// Create and schedule a request for all the children nodes
		requests, err := s.children(request, node)
		if err != nil {
			return committed, i, err
		}
		if len(requests) == 0 && request.deps == 0 {
			s.commit(request)
			committed = true
			continue
		}
		request.deps += len(requests)
		for _, child := range requests {
			s.schedule(child)
		}
	}
	return committed, 0, nil
}

// Commit flushes the data stored in the internal membatch out to persistent
// storage, returning any occurred error.
func (s *Sync) Commit(dbw ethdb.Batch) error {
	// Dump the membatch into a database dbw
	for key, value := range s.membatch.batch {
		if err := dbw.Put(key[:], value); err != nil {
			return err
		}
		s.bloom.Add(key[:])
	}
	// Drop the membatch data and return
	s.membatch = newSyncMemBatch()
	return nil
}

// Pending returns the number of state entries currently pending for download.
func (s *Sync) Pending() int {
	return len(s.requests)
}

// schedule inserts a new state retrieval request into the fetch queue. If there
// is already a pending request for this Node, the new request will be discarded
// and only a parent reference added to the old one.
func (s *Sync) schedule(req *request) {
	// If we're already requesting this Node, add a new reference and stop
	if old, ok := s.requests[req.hash]; ok {
		old.parents = append(old.parents, req.parents...)
		return
	}
	// Schedule the request for future retrieval
	s.queue.Push(req.hash, int64(req.depth))
	s.requests[req.hash] = req
}

// children retrieves all the missing children of a state trie entry for future
// retrieval scheduling.
func (s *Sync) children(req *request, object Node) ([]*request, error) {
	// Gather all the children of the Node, irrelevant whether known or not
	type child struct {
		node  Node
		depth int
	}
	var children []child

	switch node := (object).(type) {
	case *ShortNode:
		children = []child{{
			node:  node.Val,
			depth: req.depth + len(node.Key),
		}}
	case *FullNode:
		for i := 0; i < 17; i++ {
			if node.Children[i] != nil {
				children = append(children, child{
					node:  node.Children[i],
					depth: req.depth + 1,
				})
			}
		}
	default:
		panic(fmt.Sprintf("unknown Node: %+v", node))
	}
	// Iterate over the children, and request all unknown ones
	requests := make([]*request, 0, len(children))
	for _, child := range children {
		// Notify any external watcher of a new key/value Node
		if req.callback != nil {
			if node, ok := (child.node).(ValueNode); ok {
				if err := req.callback(node, req.hash); err != nil {
					return nil, err
				}
			}
		}
		// If the child references another Node, resolve or schedule
		if node, ok := (child.node).(HashNode); ok {
			// Try to resolve the Node from the local database
			hash := common.BytesToHash(node)
			if _, ok := s.membatch.batch[hash]; ok {
				continue
			}
			if s.bloom.Contains(node) {
				// Bloom filter says this might be a duplicate, double check
				if ok, _ := s.database.Has(node); ok {
					continue
				}
				// False positive, bump fault meter
				bloomFaultMeter.Mark(1)
			}
			// Locally unknown Node, schedule for retrieval
			requests = append(requests, &request{
				hash:     hash,
				parents:  []*request{req},
				depth:    child.depth,
				callback: req.callback,
			})
		}
	}
	return requests, nil
}

// commit finalizes a retrieval request and stores it into the membatch. If any
// of the referencing parent requests complete due to this commit, they are also
// committed themselves.
func (s *Sync) commit(req *request) (err error) {
	// Write the Node content to the membatch
	s.membatch.batch[req.hash] = req.data

	delete(s.requests, req.hash)

	// Check all parents for completion
	for _, parent := range req.parents {
		parent.deps--
		if parent.deps == 0 {
			if err := s.commit(parent); err != nil {
				return err
			}
		}
	}
	return nil
}
