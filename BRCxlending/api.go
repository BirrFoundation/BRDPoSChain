package BRCxlending

import (
	"context"
	"errors"
	"sync"
	"time"
)

// List of errors
var (
	ErrOrderNonceTooLow  = errors.New("OrderNonce too low")
	ErrOrderNonceTooHigh = errors.New("OrderNonce too high")
)

// PublicBRCXLendingAPI provides the BRCX RPC service that can be
// use publicly without security implications.
type PublicBRCXLendingAPI struct {
	t        *Lending
	mu       sync.Mutex
	lastUsed map[string]time.Time // keeps track when a filter was polled for the last time.

}

// NewPublicBRCXLendingAPI create a new RPC BRCX service.
func NewPublicBRCXLendingAPI(t *Lending) *PublicBRCXLendingAPI {
	api := &PublicBRCXLendingAPI{
		t:        t,
		lastUsed: make(map[string]time.Time),
	}
	return api
}

// Version returns the Lending sub-protocol version.
func (api *PublicBRCXLendingAPI) Version(ctx context.Context) string {
	return ProtocolVersionStr
}
