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

package p2p

import (
	"bytes"
	"errors"
	"fmt"
	"io"
	"sync/atomic"
	"time"

	"BRDPoSChain/event"
	"BRDPoSChain/p2p/discover"
	"BRDPoSChain/rlp"
)

// Msg defines the structure of a p2p message.
//
// Note that a Msg can only be sent once since the Payload reader is
// consumed during sending. It is not possible to create a Msg and
// send it any number of times. If you want to reuse an encoded
// structure, encode the payload into a byte array and create a
// separate Msg with a bytes.Reader as Payload for each send.
type Msg struct {
	Code       uint64
	Size       uint32 // size of the paylod
	Payload    io.Reader
	ReceivedAt time.Time
}

// Decode parses the RLP content of a message into
// the given value, which must be a pointer.
//
// For the decoding rules, please see package rlp.
func (m Msg) Decode(val interface{}) error {
	s := rlp.NewStream(m.Payload, uint64(m.Size))
	if err := s.Decode(val); err != nil {
		return newPeerError(errInvalidMsg, "(code %x) (size %d) %v", m.Code, m.Size, err)
	}
	return nil
}

func (m Msg) String() string {
	return fmt.Sprintf("msg #%v (%v bytes)", m.Code, m.Size)
}

// Discard reads any remaining payload data into a black hole.
func (m Msg) Discard() error {
	_, err := io.Copy(io.Discard, m.Payload)
	return err
}

type MsgReader interface {
	ReadMsg() (Msg, error)
}

type MsgWriter interface {
	// WriteMsg sends a message. It will block until the message's
	// Payload has been consumed by the other end.
	//
	// Note that messages can be sent only once because their
	// payload reader is drained.
	WriteMsg(Msg) error
}

// MsgReadWriter provides reading and writing of encoded messages.
// Implementations should ensure that ReadMsg and WriteMsg can be
// called simultaneously from multiple goroutines.
type MsgReadWriter interface {
	MsgReader
	MsgWriter
}

// Send writes an RLP-encoded message with the given code.
// data should encode as an RLP list.
func Send(w MsgWriter, msgcode uint64, data interface{}) error {
	size, r, err := rlp.EncodeToReader(data)
	if err != nil {
		return err
	}
	return w.WriteMsg(Msg{Code: msgcode, Size: uint32(size), Payload: r})
}

// SendItems writes an RLP with the given code and data elements.
// For a call such as:
//
//	SendItems(w, code, e1, e2, e3)
//
// the message payload will be an RLP list containing the items:
//
//	[e1, e2, e3]
func SendItems(w MsgWriter, msgcode uint64, elems ...interface{}) error {
	return Send(w, msgcode, elems)
}

// eofSignal wraps a reader with eof signaling. the eof channel is
// closed when the wrapped reader returns an error or when count bytes
// have been read.
type eofSignal struct {
	wrapped io.Reader
	count   uint32 // number of bytes left
	eof     chan<- struct{}
}

// note: when using eofSignal to detect whether a message payload
// has been read, Read might not be called for zero sized messages.
func (s *eofSignal) Read(buf []byte) (int, error) {
	if s.count == 0 {
		if s.eof != nil {
			s.eof <- struct{}{}
			s.eof = nil
		}
		return 0, io.EOF
	}

	max := len(buf)
	if int(s.count) < len(buf) {
		max = int(s.count)
	}
	n, err := s.wrapped.Read(buf[:max])
	s.count -= uint32(n)
	if (err != nil || s.count == 0) && s.eof != nil {
		s.eof <- struct{}{} // tell Peer that msg has been consumed
		s.eof = nil
	}
	return n, err
}

// MsgPipe creates a message pipe. Reads on one end are matched
// with writes on the other. The pipe is full-duplex, both ends
// implement MsgReadWriter.
func MsgPipe() (*MsgPipeRW, *MsgPipeRW) {
	var (
		c1, c2  = make(chan Msg), make(chan Msg)
		closing = make(chan struct{})
		closed  = new(int32)
		rw1     = &MsgPipeRW{c1, c2, closing, closed}
		rw2     = &MsgPipeRW{c2, c1, closing, closed}
	)
	return rw1, rw2
}

// ErrPipeClosed is returned from pipe operations after the
// pipe has been closed.
var ErrPipeClosed = errors.New("p2p: read or write on closed message pipe")

// MsgPipeRW is an endpoint of a MsgReadWriter pipe.
type MsgPipeRW struct {
	w       chan<- Msg
	r       <-chan Msg
	closing chan struct{}
	closed  *int32
}

// WriteMsg sends a messsage on the pipe.
// It blocks until the receiver has consumed the message payload.
func (p *MsgPipeRW) WriteMsg(msg Msg) error {
	if atomic.LoadInt32(p.closed) == 0 {
		consumed := make(chan struct{}, 1)
		msg.Payload = &eofSignal{msg.Payload, msg.Size, consumed}
		select {
		case p.w <- msg:
			if msg.Size > 0 {
				// wait for payload read or discard
				select {
				case <-consumed:
				case <-p.closing:
				}
			}
			return nil
		case <-p.closing:
		}
	}
	return ErrPipeClosed
}

// ReadMsg returns a message sent on the other end of the pipe.
func (p *MsgPipeRW) ReadMsg() (Msg, error) {
	if atomic.LoadInt32(p.closed) == 0 {
		select {
		case msg := <-p.r:
			return msg, nil
		case <-p.closing:
		}
	}
	return Msg{}, ErrPipeClosed
}

// Close unblocks any pending ReadMsg and WriteMsg calls on both ends
// of the pipe. They will return ErrPipeClosed. Close also
// interrupts any reads from a message payload.
func (p *MsgPipeRW) Close() error {
	if atomic.AddInt32(p.closed, 1) != 1 {
		// someone else is already closing
		atomic.StoreInt32(p.closed, 1) // avoid overflow
		return nil
	}
	close(p.closing)
	return nil
}

// ExpectMsg reads a message from r and verifies that its
// code and encoded RLP content match the provided values.
// If content is nil, the payload is discarded and not verified.
func ExpectMsg(r MsgReader, code uint64, content interface{}) error {
	msg, err := r.ReadMsg()
	if err != nil {
		return err
	}
	if msg.Code != code {
		return fmt.Errorf("message code mismatch: got %d, expected %d", msg.Code, code)
	}
	if content == nil {
		return msg.Discard()
	} else {
		contentEnc, err := rlp.EncodeToBytes(content)
		if err != nil {
			panic("content encode error: " + err.Error())
		}
		if int(msg.Size) != len(contentEnc) {
			return fmt.Errorf("message size mismatch: got %d, want %d", msg.Size, len(contentEnc))
		}
		actualContent, err := io.ReadAll(msg.Payload)
		if err != nil {
			return err
		}
		if !bytes.Equal(actualContent, contentEnc) {
			return fmt.Errorf("message payload mismatch:\ngot:  %x\nwant: %x", actualContent, contentEnc)
		}
	}
	return nil
}

// msgEventer wraps a MsgReadWriter and sends events whenever a message is sent
// or received
type msgEventer struct {
	MsgReadWriter

	feed     *event.Feed
	peerID   discover.NodeID
	Protocol string
}

// newMsgEventer returns a msgEventer which sends message events to the given
// feed
func newMsgEventer(rw MsgReadWriter, feed *event.Feed, peerID discover.NodeID, proto string) *msgEventer {
	return &msgEventer{
		MsgReadWriter: rw,
		feed:          feed,
		peerID:        peerID,
		Protocol:      proto,
	}
}

// ReadMsg reads a message from the underlying MsgReadWriter and emits a
// "message received" event
func (e *msgEventer) ReadMsg() (Msg, error) {
	msg, err := e.MsgReadWriter.ReadMsg()
	if err != nil {
		return msg, err
	}
	e.feed.Send(&PeerEvent{
		Type:     PeerEventTypeMsgRecv,
		Peer:     e.peerID,
		Protocol: e.Protocol,
		MsgCode:  &msg.Code,
		MsgSize:  &msg.Size,
	})
	return msg, nil
}

// WriteMsg writes a message to the underlying MsgReadWriter and emits a
// "message sent" event
func (e *msgEventer) WriteMsg(msg Msg) error {
	err := e.MsgReadWriter.WriteMsg(msg)
	if err != nil {
		return err
	}
	e.feed.Send(&PeerEvent{
		Type:     PeerEventTypeMsgSend,
		Peer:     e.peerID,
		Protocol: e.Protocol,
		MsgCode:  &msg.Code,
		MsgSize:  &msg.Size,
	})
	return nil
}

// Close closes the underlying MsgReadWriter if it implements the io.Closer
// interface
func (e *msgEventer) Close() error {
	if v, ok := e.MsgReadWriter.(io.Closer); ok {
		return v.Close()
	}
	return nil
}
