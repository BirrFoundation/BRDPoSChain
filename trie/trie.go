// Copyright 2014 The go-ethereum Authors
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

// Package trie implements Merkle Patricia Tries.
package trie

import (
	"bytes"
	"fmt"
	"sync"

	"BRDPoSChain/common"
	"BRDPoSChain/crypto"
	"BRDPoSChain/log"
)

var (
	// TODO(daniel):
	// 1. remove file core/types/derive_sha.go, Ref: #21502
	// 2. then replace emptyRoot, emptyState with types.EmptyRootHash, types.EmptyCodeHash, Ref: #26718

	// emptyRoot is the known root hash of an empty trie.
	emptyRoot = common.HexToHash("56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421")

	// emptyState is the known hash of an empty state trie entry.
	emptyState = crypto.Keccak256Hash(nil)
)

// LeafCallback is a callback type invoked when a trie operation reaches a leaf
// Node. It's used by state sync and commit to allow handling external references
// between account and storage tries.
type LeafCallback func(leaf []byte, parent common.Hash) error

// Trie is a Merkle Patricia Trie.
// The zero value is an empty trie with no database.
// Use New to create a trie that sits on top of a database.
//
// Trie is not safe for concurrent use.
type Trie struct {
	Db   *Database
	root Node
	// Keep track of the number leafs which have been inserted since the last
	// hashing operation. This number will not directly map to the number of
	// actually unhashed nodes
	unhashed int
}

// newFlag returns the Cache flag value for a newly created Node.
func (t *Trie) newFlag() NodeFlag {
	return NodeFlag{dirty: true}
}

// New creates a trie with an existing root Node from Db.
//
// If root is the zero hash or the sha3 hash of an empty string, the
// trie is initially empty and does not require a database. Otherwise,
// New will panic if Db is nil and returns a MissingNodeError if root does
// not exist in the database. Accessing the trie loads nodes from Db on demand.
func New(root common.Hash, db *Database) (*Trie, error) {
	if db == nil {
		panic("trie.New called without a database")
	}
	trie := &Trie{
		Db: db,
	}
	if root != (common.Hash{}) && root != emptyRoot {
		rootnode, err := trie.resolveHash(root[:], nil)
		if err != nil {
			return nil, err
		}
		trie.root = rootnode
	}
	return trie, nil
}

// NodeIterator returns an iterator that returns nodes of the trie. Iteration starts at
// the key after the given start key.
func (t *Trie) NodeIterator(start []byte) NodeIterator {
	return newNodeIterator(t, start)
}

// Get returns the value for key stored in the trie.
// The value bytes must not be modified by the caller.
func (t *Trie) Get(key []byte) []byte {
	res, err := t.TryGet(key)
	if err != nil {
		log.Error(fmt.Sprintf("Unhandled trie error: %v", err))
	}
	return res
}

// TryGet returns the value for key stored in the trie.
// The value bytes must not be modified by the caller.
// If a Node was not found in the database, a MissingNodeError is returned.
func (t *Trie) TryGet(key []byte) ([]byte, error) {
	key = keybytesToHex(key)
	value, newroot, didResolve, err := t.tryGet(t.root, key, 0)
	if err == nil && didResolve {
		t.root = newroot
	}
	return value, err
}

func (t *Trie) tryGet(origNode Node, key []byte, pos int) (value []byte, newnode Node, didResolve bool, err error) {
	switch n := (origNode).(type) {
	case nil:
		return nil, nil, false, nil
	case ValueNode:
		return n, n, false, nil
	case *ShortNode:
		if len(key)-pos < len(n.Key) || !bytes.Equal(n.Key, key[pos:pos+len(n.Key)]) {
			// key not found in trie
			return nil, n, false, nil
		}
		value, newnode, didResolve, err = t.tryGet(n.Val, key, pos+len(n.Key))
		if err == nil && didResolve {
			n = n.copy()
			n.Val = newnode
		}
		return value, n, didResolve, err
	case *FullNode:
		value, newnode, didResolve, err = t.tryGet(n.Children[key[pos]], key, pos+1)
		if err == nil && didResolve {
			n = n.copy()
			n.Children[key[pos]] = newnode
		}
		return value, n, didResolve, err
	case HashNode:
		child, err := t.resolveHash(n, key[:pos])
		if err != nil {
			return nil, n, true, err
		}
		value, newnode, _, err := t.tryGet(child, key, pos)
		return value, newnode, true, err
	default:
		panic(fmt.Sprintf("%T: invalid Node: %v", origNode, origNode))
	}
}

func (t *Trie) TryGetBestLeftKeyAndValue() ([]byte, []byte, error) {
	key, value, newroot, didResolve, err := t.tryGetBestLeftKeyAndValue(t.root, []byte{})
	if err == nil && didResolve {
		t.root = newroot
	}
	return hexToKeybytes(key), value, err
}

func (t *Trie) tryGetBestLeftKeyAndValue(origNode Node, prefix []byte) (key []byte, value []byte, newnode Node, didResolve bool, err error) {
	switch n := (origNode).(type) {
	case nil:
		return nil, nil, nil, false, nil
	case *ShortNode:
		switch v := n.Val.(type) {
		case ValueNode:
			return append(prefix, n.Key...), v, n, false, nil
		default:
		}
		key, value, newnode, didResolve, err = t.tryGetBestLeftKeyAndValue(n.Val, append(prefix, n.Key...))
		if err == nil && didResolve {
			n = n.copy()
			n.Val = newnode
		}
		return key, value, n, didResolve, err
	case *FullNode:
		for i := 0; i < len(n.Children); i++ {
			if n.Children[i] == nil {
				continue
			}
			key, value, newnode, didResolve, err = t.tryGetBestLeftKeyAndValue(n.Children[i], append(prefix, byte(i)))
			if err == nil && didResolve {
				n = n.copy()
				n.Children[i] = newnode
			}
			return key, value, n, didResolve, err
		}
	case HashNode:
		child, err := t.resolveHash(n, nil)
		if err != nil {
			return nil, nil, n, true, err
		}
		key, value, newnode, _, err := t.tryGetBestLeftKeyAndValue(child, prefix)
		return key, value, newnode, true, err
	default:
		return nil, nil, nil, false, fmt.Errorf("%T: invalid Node: %v", origNode, origNode)
	}
	return nil, nil, nil, false, fmt.Errorf("%T: invalid Node: %v", origNode, origNode)
}

func (t *Trie) TryGetAllLeftKeyAndValue(limit []byte) ([][]byte, [][]byte, error) {
	limit = keybytesToHex(limit)
	length := len(limit) - 1
	limit = limit[0:length]
	dataKeys, values, newroot, didResolve, err := t.tryGetAllLeftKeyAndValue(t.root, []byte{}, limit)
	if err == nil && didResolve {
		t.root = newroot
	}
	keys := [][]byte{}
	for _, data := range dataKeys {
		keys = append(keys, hexToKeybytes(data))
	}
	return keys, values, err
}
func (t *Trie) tryGetAllLeftKeyAndValue(origNode Node, prefix []byte, limit []byte) (keys [][]byte, values [][]byte, newnode Node, didResolve bool, err error) {
	switch n := (origNode).(type) {
	case nil:
		return nil, nil, nil, false, nil
	case ValueNode:
		key := make([]byte, len(prefix))
		copy(key, prefix)
		if bytes.Compare(key, limit) < 0 {
			keys = append(keys, key)
			values = append(values, n)
		}
		return keys, values, n, false, nil
	case *ShortNode:
		keys, values, newnode, didResolve, err := t.tryGetAllLeftKeyAndValue(n.Val, append(prefix, n.Key...), limit)
		if err == nil && didResolve {
			n = n.copy()
			n.Val = newnode
		}
		return keys, values, n, didResolve, err
	case *FullNode:
		for i := len(n.Children) - 1; i >= 0; i-- {
			if n.Children[i] == nil {
				continue
			}
			newPrefix := append(prefix, byte(i))
			if bytes.Compare(newPrefix, limit) > 0 {
				continue
			}
			allKeys, allValues, newnode, didResolve, err := t.tryGetAllLeftKeyAndValue(n.Children[i], newPrefix, limit)
			if err != nil {
				return nil, nil, n, false, err
			}
			if didResolve {
				n = n.copy()
				n.Children[i] = newnode
			}
			keys = append(keys, allKeys...)
			values = append(values, allValues...)
		}
		return keys, values, n, didResolve, err
	case HashNode:
		child, err := t.resolveHash(n, nil)
		if err != nil {
			return nil, nil, n, true, err
		}
		keys, values, newnode, _, err := t.tryGetAllLeftKeyAndValue(child, prefix, limit)
		return keys, values, newnode, true, err
	default:
		return nil, nil, nil, false, fmt.Errorf("%T: invalid Node: %v", origNode, origNode)
	}
	return nil, nil, nil, false, fmt.Errorf("%T: invalid Node: %v", origNode, origNode)
}
func (t *Trie) TryGetBestRightKeyAndValue() ([]byte, []byte, error) {
	key, value, newroot, didResolve, err := t.tryGetBestRightKeyAndValue(t.root, []byte{})
	if err == nil && didResolve {
		t.root = newroot
	}
	return hexToKeybytes(key), value, err
}

func (t *Trie) tryGetBestRightKeyAndValue(origNode Node, prefix []byte) (key []byte, value []byte, newnode Node, didResolve bool, err error) {
	switch n := (origNode).(type) {
	case nil:
		return nil, nil, nil, false, nil
	case *ShortNode:
		switch v := n.Val.(type) {
		case ValueNode:
			return append(prefix, n.Key...), v, n, false, nil
		default:
		}
		key, value, newnode, didResolve, err = t.tryGetBestRightKeyAndValue(n.Val, append(prefix, n.Key...))
		if err == nil && didResolve {
			n = n.copy()
			n.Val = newnode
		}
		return key, value, n, didResolve, err
	case *FullNode:
		for i := len(n.Children) - 1; i >= 0; i-- {
			if n.Children[i] == nil {
				continue
			}
			key, value, newnode, didResolve, err = t.tryGetBestRightKeyAndValue(n.Children[i], append(prefix, byte(i)))
			if err == nil && didResolve {
				n = n.copy()
				n.Children[i] = newnode
			}
			return key, value, n, didResolve, err
		}
	case HashNode:
		child, err := t.resolveHash(n, nil)
		if err != nil {
			return nil, nil, n, true, err
		}
		key, value, newnode, _, err := t.tryGetBestRightKeyAndValue(child, prefix)
		return key, value, newnode, true, err
	default:
		return nil, nil, nil, false, fmt.Errorf("%T: invalid Node: %v", origNode, origNode)
	}
	return nil, nil, nil, false, fmt.Errorf("%T: invalid Node: %v", origNode, origNode)
}

// Update associates key with value in the trie. Subsequent calls to
// Get will return value. If value has length zero, any existing value
// is deleted from the trie and calls to Get will return nil.
//
// The value bytes must not be modified by the caller while they are
// stored in the trie.
func (t *Trie) Update(key, value []byte) {
	if err := t.TryUpdate(key, value); err != nil {
		log.Error(fmt.Sprintf("Unhandled trie error: %v", err))
	}
}

// TryUpdate associates key with value in the trie. Subsequent calls to
// Get will return value. If value has length zero, any existing value
// is deleted from the trie and calls to Get will return nil.
//
// The value bytes must not be modified by the caller while they are
// stored in the trie.
//
// If a Node was not found in the database, a MissingNodeError is returned.
func (t *Trie) TryUpdate(key, value []byte) error {
	t.unhashed++
	k := keybytesToHex(key)
	if len(value) != 0 {
		_, n, err := t.insert(t.root, nil, k, ValueNode(value))
		if err != nil {
			return err
		}
		t.root = n
	} else {
		_, n, err := t.delete(t.root, nil, k)
		if err != nil {
			return err
		}
		t.root = n
	}
	return nil
}

func (t *Trie) insert(n Node, prefix, key []byte, value Node) (bool, Node, error) {
	if len(key) == 0 {
		if v, ok := n.(ValueNode); ok {
			return !bytes.Equal(v, value.(ValueNode)), value, nil
		}
		return true, value, nil
	}
	switch n := n.(type) {
	case *ShortNode:
		matchlen := prefixLen(key, n.Key)
		// If the whole key matches, keep this short Node as is
		// and only update the value.
		if matchlen == len(n.Key) {
			dirty, nn, err := t.insert(n.Val, append(prefix, key[:matchlen]...), key[matchlen:], value)
			if !dirty || err != nil {
				return false, n, err
			}
			return true, &ShortNode{n.Key, nn, t.newFlag()}, nil
		}
		// Otherwise branch out at the index where they differ.
		branch := &FullNode{flags: t.newFlag()}
		var err error
		_, branch.Children[n.Key[matchlen]], err = t.insert(nil, append(prefix, n.Key[:matchlen+1]...), n.Key[matchlen+1:], n.Val)
		if err != nil {
			return false, nil, err
		}
		_, branch.Children[key[matchlen]], err = t.insert(nil, append(prefix, key[:matchlen+1]...), key[matchlen+1:], value)
		if err != nil {
			return false, nil, err
		}
		// Replace this ShortNode with the branch if it occurs at index 0.
		if matchlen == 0 {
			return true, branch, nil
		}
		// Otherwise, replace it with a short Node leading up to the branch.
		return true, &ShortNode{key[:matchlen], branch, t.newFlag()}, nil

	case *FullNode:
		dirty, nn, err := t.insert(n.Children[key[0]], append(prefix, key[0]), key[1:], value)
		if !dirty || err != nil {
			return false, n, err
		}
		n = n.copy()
		n.flags = t.newFlag()
		n.Children[key[0]] = nn
		return true, n, nil

	case nil:
		return true, &ShortNode{key, value, t.newFlag()}, nil

	case HashNode:
		// We've hit a part of the trie that isn't loaded yet. Load
		// the Node and insert into it. This leaves all child nodes on
		// the path to the value in the trie.
		rn, err := t.resolveHash(n, prefix)
		if err != nil {
			return false, nil, err
		}
		dirty, nn, err := t.insert(rn, prefix, key, value)
		if !dirty || err != nil {
			return false, rn, err
		}
		return true, nn, nil

	default:
		panic(fmt.Sprintf("%T: invalid Node: %v", n, n))
	}
}

// Delete removes any existing value for key from the trie.
func (t *Trie) Delete(key []byte) {
	if err := t.TryDelete(key); err != nil {
		log.Error(fmt.Sprintf("Unhandled trie error: %v", err))
	}
}

// TryDelete removes any existing value for key from the trie.
// If a Node was not found in the database, a MissingNodeError is returned.
func (t *Trie) TryDelete(key []byte) error {
	t.unhashed++
	k := keybytesToHex(key)
	_, n, err := t.delete(t.root, nil, k)
	if err != nil {
		return err
	}
	t.root = n
	return nil
}

// delete returns the new root of the trie with key deleted.
// It reduces the trie to minimal form by simplifying
// nodes on the way up after deleting recursively.
func (t *Trie) delete(n Node, prefix, key []byte) (bool, Node, error) {
	switch n := n.(type) {
	case *ShortNode:
		matchlen := prefixLen(key, n.Key)
		if matchlen < len(n.Key) {
			return false, n, nil // don't replace n on mismatch
		}
		if matchlen == len(key) {
			return true, nil, nil // remove n entirely for whole matches
		}
		// The key is longer than n.Key. Remove the remaining suffix
		// from the subtrie. Child can never be nil here since the
		// subtrie must contain at least two other values with keys
		// longer than n.Key.
		dirty, child, err := t.delete(n.Val, append(prefix, key[:len(n.Key)]...), key[len(n.Key):])
		if !dirty || err != nil {
			return false, n, err
		}
		switch child := child.(type) {
		case *ShortNode:
			// Deleting from the subtrie reduced it to another
			// short Node. Merge the nodes to avoid creating a
			// ShortNode{..., ShortNode{...}}. Use concat (which
			// always creates a new slice) instead of append to
			// avoid modifying n.Key since it might be shared with
			// other nodes.
			return true, &ShortNode{concat(n.Key, child.Key...), child.Val, t.newFlag()}, nil
		default:
			return true, &ShortNode{n.Key, child, t.newFlag()}, nil
		}

	case *FullNode:
		dirty, nn, err := t.delete(n.Children[key[0]], append(prefix, key[0]), key[1:])
		if !dirty || err != nil {
			return false, n, err
		}
		n = n.copy()
		n.flags = t.newFlag()
		n.Children[key[0]] = nn

		// Check how many non-nil entries are left after deleting and
		// reduce the full Node to a short Node if only one entry is
		// left. Since n must've contained at least two children
		// before deletion (otherwise it would not be a full Node) n
		// can never be reduced to nil.
		//
		// When the loop is done, pos contains the index of the single
		// value that is left in n or -2 if n contains at least two
		// values.
		pos := -1
		for i, cld := range &n.Children {
			if cld != nil {
				if pos == -1 {
					pos = i
				} else {
					pos = -2
					break
				}
			}
		}
		if pos >= 0 {
			if pos != 16 {
				// If the remaining entry is a short Node, it replaces
				// n and its key gets the missing nibble tacked to the
				// front. This avoids creating an invalid
				// ShortNode{..., ShortNode{...}}.  Since the entry
				// might not be loaded yet, resolve it just for this
				// check.
				cnode, err := t.resolve(n.Children[pos], prefix)
				if err != nil {
					return false, nil, err
				}
				if cnode, ok := cnode.(*ShortNode); ok {
					k := append([]byte{byte(pos)}, cnode.Key...)
					return true, &ShortNode{k, cnode.Val, t.newFlag()}, nil
				}
			}
			// Otherwise, n is replaced by a one-nibble short Node
			// containing the child.
			return true, &ShortNode{[]byte{byte(pos)}, n.Children[pos], t.newFlag()}, nil
		}
		// n still contains at least two values and cannot be reduced.
		return true, n, nil

	case ValueNode:
		return true, nil, nil

	case nil:
		return false, nil, nil

	case HashNode:
		// We've hit a part of the trie that isn't loaded yet. Load
		// the Node and delete from it. This leaves all child nodes on
		// the path to the value in the trie.
		rn, err := t.resolveHash(n, prefix)
		if err != nil {
			return false, nil, err
		}
		dirty, nn, err := t.delete(rn, prefix, key)
		if !dirty || err != nil {
			return false, rn, err
		}
		return true, nn, nil

	default:
		panic(fmt.Sprintf("%T: invalid Node: %v (%v)", n, n, key))
	}
}

func concat(s1 []byte, s2 ...byte) []byte {
	r := make([]byte, len(s1)+len(s2))
	copy(r, s1)
	copy(r[len(s1):], s2)
	return r
}

func (t *Trie) resolve(n Node, prefix []byte) (Node, error) {
	if n, ok := n.(HashNode); ok {
		return t.resolveHash(n, prefix)
	}
	return n, nil
}

func (t *Trie) resolveHash(n HashNode, prefix []byte) (Node, error) {
	hash := common.BytesToHash(n)
	if node := t.Db.node(hash); node != nil {
		return node, nil
	}
	return nil, &MissingNodeError{NodeHash: hash, Path: prefix}
}

// Hash returns the root hash of the trie. It does not write to the
// database and can be used even if the trie doesn't have one.
func (t *Trie) Hash() common.Hash {
	hash, cached, _ := t.hashRoot(nil)
	t.root = cached
	return common.BytesToHash(hash.(HashNode))
}

// Commit writes all nodes to the trie's memory database, tracking the internal
// and external (for account tries) references.
func (t *Trie) Commit(onleaf LeafCallback) (root common.Hash, err error) {
	if t.Db == nil {
		panic("commit called on trie with nil database")
	}
	if t.root == nil {
		return emptyRoot, nil
	}
	rootHash := t.Hash()
	h := newCommitter()
	defer returnCommitterToPool(h)
	// Do a quick check if we really need to commit, before we spin
	// up goroutines. This can happen e.g. if we load a trie for reading storage
	// values, but don't write to it.
	if !h.commitNeeded(t.root) {
		return rootHash, nil
	}
	var wg sync.WaitGroup
	if onleaf != nil {
		h.onleaf = onleaf
		h.leafCh = make(chan *leaf, leafChanSize)
		wg.Add(1)
		go func() {
			defer wg.Done()
			h.commitLoop(t.Db)
		}()
	}
	var newRoot HashNode
	newRoot, err = h.Commit(t.root, t.Db)
	if onleaf != nil {
		// The leafch is created in newCommitter if there was an onleaf callback
		// provided. The commitLoop only _reads_ from it, and the commit
		// operation was the sole writer. Therefore, it's safe to close this
		// channel here.
		close(h.leafCh)
		wg.Wait()
	}
	if err != nil {
		return common.Hash{}, err
	}
	t.root = newRoot
	return rootHash, nil
}

// hashRoot calculates the root hash of the given trie
func (t *Trie) hashRoot(db *Database) (Node, Node, error) {
	if t.root == nil {
		return HashNode(emptyRoot.Bytes()), nil, nil
	}
	// If the number of changes is below 100, we let one thread handle it
	h := newHasher(t.unhashed >= 100)
	defer returnHasherToPool(h)
	hashed, cached := h.hash(t.root, true)
	t.unhashed = 0
	return hashed, cached, nil
}
