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

package tradingstate

import (
	"io"
	"math/big"

	"BRDPoSChain/common"
	"BRDPoSChain/rlp"
)

// stateObject represents an Ethereum orderId which is being modified.
//
// The usage pattern is as follows:
// First you need to obtain a state object.
// tradingExchangeObject values can be accessed and modified through the object.
// Finally, call CommitAskTrie to write the modified storage trie into a database.
type stateOrderItem struct {
	orderBook common.Hash
	orderId   common.Hash
	data      OrderItem
	onDirty   func(orderId common.Hash) // Callback method to mark a state object newly dirty
}

// empty returns whether the orderId is considered empty.
func (s *stateOrderItem) empty() bool {
	return s.data.Quantity == nil || s.data.Quantity.Cmp(Zero) == 0
}

// newObject creates a state object.
func newStateOrderItem(orderBook common.Hash, orderId common.Hash, data OrderItem, onDirty func(orderId common.Hash)) *stateOrderItem {
	return &stateOrderItem{
		orderBook: orderBook,
		orderId:   orderId,
		data:      data,
		onDirty:   onDirty,
	}
}

// EncodeRLP implements rlp.Encoder.
func (s *stateOrderItem) EncodeRLP(w io.Writer) error {
	return rlp.Encode(w, s.data)
}

func (s *stateOrderItem) deepCopy(onDirty func(orderId common.Hash)) *stateOrderItem {
	stateOrderList := newStateOrderItem(s.orderBook, s.orderId, s.data, onDirty)
	return stateOrderList
}

func (s *stateOrderItem) setVolume(volume *big.Int) {
	s.data.Quantity = volume
	if s.onDirty != nil {
		s.onDirty(s.orderId)
		s.onDirty = nil
	}
}

func (s *stateOrderItem) Quantity() *big.Int {
	return s.data.Quantity
}
