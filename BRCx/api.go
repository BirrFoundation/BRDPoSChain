package BRCx

import (
	"context"
	"errors"
	"sync"
	"time"
)

const (
	LimitThresholdOrderNonceInQueue = 100
)

// List of errors
var (
	ErrNoTopics          = errors.New("missing topic(s)")
	ErrOrderNonceTooLow  = errors.New("OrderNonce too low")
	ErrOrderNonceTooHigh = errors.New("OrderNonce too high")
)

// PublicBRCXAPI provides the BRCX RPC service that can be
// use publicly without security implications.
type PublicBRCXAPI struct {
	t        *BRCX
	mu       sync.Mutex
	lastUsed map[string]time.Time // keeps track when a filter was polled for the last time.

}

// NewPublicBRCXAPI create a new RPC BRCX service.
func NewPublicBRCXAPI(t *BRCX) *PublicBRCXAPI {
	api := &PublicBRCXAPI{
		t:        t,
		lastUsed: make(map[string]time.Time),
	}
	return api
}

// Version returns the BRCX sub-protocol version.
func (api *PublicBRCXAPI) Version(ctx context.Context) string {
	return ProtocolVersionStr
}
