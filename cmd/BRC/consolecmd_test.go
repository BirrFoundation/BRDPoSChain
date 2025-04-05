// Copyright 2016 The go-ethereum Authors
// This file is part of go-ethereum.
//
// go-ethereum is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// go-ethereum is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with go-ethereum. If not, see <http://www.gnu.org/licenses/>.

package main

import (
	"crypto/rand"
	"math/big"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
	"testing"
	"time"

	"BRDPoSChain/params"
)

const (
	ipcAPIs  = "BRCx:1.0 BRCxlending:1.0 BRDPoS:1.0 admin:1.0 debug:1.0 eth:1.0 miner:1.0 net:1.0 personal:1.0 rpc:1.0 txpool:1.0 web3:1.0"
	httpAPIs = "eth:1.0 net:1.0 rpc:1.0 web3:1.0"
)

// Tests that a node embedded within a console can be started up properly and
// then terminated by closing the input stream.
func TestConsoleWelcome(t *testing.T) {
	coinbase := "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182"
	datadir := t.TempDir()

	// Start a BRC console, make sure it's cleaned up and terminate the console
	BRC := runBRC(t,
		"console", "--datadir", datadir, "--BRCx-datadir", datadir+"/BRCx",
		"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none",
		"--miner-etherbase", coinbase)

	// Gather all the infos the welcome message needs to contain
	BRC.SetTemplateFunc("goos", func() string { return runtime.GOOS })
	BRC.SetTemplateFunc("goarch", func() string { return runtime.GOARCH })
	BRC.SetTemplateFunc("gover", runtime.Version)
	BRC.SetTemplateFunc("BRCver", func() string { return params.Version })
	BRC.SetTemplateFunc("niltime", func() string {
		return time.Unix(1559211559, 0).Format("Mon Jan 02 2006 15:04:05 GMT-0700 (MST)")
	})
	BRC.SetTemplateFunc("apis", func() string { return ipcAPIs })

	// Verify the actual welcome message to the required template
	BRC.Expect(`
Welcome to the BRC JavaScript console!

instance: BRC/v{{BRCver}}/{{goos}}-{{goarch}}/{{gover}}
coinbase: {{.Etherbase}}
at block: 0 ({{niltime}})
 datadir: {{.Datadir}}
 modules: {{apis}}

> {{.InputLine "exit"}}
`)
	BRC.ExpectExit()
}

// Tests that a console can be attached to a running node via various means.
func TestIPCAttachWelcome(t *testing.T) {
	// Configure the instance for IPC attachement
	coinbase := "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182"
	datadir := t.TempDir()
	var ipc string
	if runtime.GOOS == "windows" {
		ipc = `\\.\pipe\BRC` + strconv.Itoa(trulyRandInt(100000, 999999))
	} else {
		ipc = filepath.Join(datadir, "BRC.ipc")
	}
	BRC := runBRC(t,
		"--datadir", datadir, "--BRCx-datadir", datadir+"/BRCx",
		"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none",
		"--miner-etherbase", coinbase, "--ipcpath", ipc)

	time.Sleep(2 * time.Second) // Simple way to wait for the RPC endpoint to open
	testAttachWelcome(t, BRC, "ipc:"+ipc, ipcAPIs)

	BRC.Interrupt()
	BRC.ExpectExit()
}

func TestHTTPAttachWelcome(t *testing.T) {
	coinbase := "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182"
	port := strconv.Itoa(trulyRandInt(1024, 65536)) // Yeah, sometimes this will fail, sorry :P
	datadir := t.TempDir()
	BRC := runBRC(t,
		"--datadir", datadir, "--BRCx-datadir", datadir+"/BRCx",
		"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none",
		"--miner-etherbase", coinbase, "--http", "--http-port", port, "--http-api", "eth,net,rpc,web3")

	time.Sleep(2 * time.Second) // Simple way to wait for the RPC endpoint to open
	testAttachWelcome(t, BRC, "http://localhost:"+port, httpAPIs)

	BRC.Interrupt()
	BRC.ExpectExit()
}

func TestWSAttachWelcome(t *testing.T) {
	coinbase := "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182"
	port := strconv.Itoa(trulyRandInt(1024, 65536)) // Yeah, sometimes this will fail, sorry :P
	datadir := t.TempDir()
	BRC := runBRC(t,
		"--datadir", datadir, "--BRCx-datadir", datadir+"/BRCx",
		"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none",
		"--miner-etherbase", coinbase, "--ws", "--ws-port", port, "--ws-api", "eth,net,rpc,web3")

	time.Sleep(2 * time.Second) // Simple way to wait for the RPC endpoint to open
	testAttachWelcome(t, BRC, "ws://localhost:"+port, httpAPIs)

	BRC.Interrupt()
	BRC.ExpectExit()
}

func testAttachWelcome(t *testing.T, BRC *testBRC, endpoint, apis string) {
	// Attach to a running BRC note and terminate immediately
	attach := runBRC(t, "attach", endpoint)
	defer attach.ExpectExit()
	attach.CloseStdin()

	// Gather all the infos the welcome message needs to contain
	attach.SetTemplateFunc("goos", func() string { return runtime.GOOS })
	attach.SetTemplateFunc("goarch", func() string { return runtime.GOARCH })
	attach.SetTemplateFunc("gover", runtime.Version)
	attach.SetTemplateFunc("BRCver", func() string { return params.Version })
	attach.SetTemplateFunc("etherbase", func() string { return BRC.Etherbase })
	attach.SetTemplateFunc("niltime", func() string {
		return time.Unix(1559211559, 0).Format("Mon Jan 02 2006 15:04:05 GMT-0700 (MST)")
	})
	attach.SetTemplateFunc("ipc", func() bool { return strings.HasPrefix(endpoint, "ipc") })
	attach.SetTemplateFunc("datadir", func() string { return BRC.Datadir })
	attach.SetTemplateFunc("apis", func() string { return apis })

	// Verify the actual welcome message to the required template
	attach.Expect(`
Welcome to the BRC JavaScript console!

instance: BRC/v{{BRCver}}/{{goos}}-{{goarch}}/{{gover}}
coinbase: {{etherbase}}
at block: 0 ({{niltime}}){{if ipc}}
 datadir: {{datadir}}{{end}}
 modules: {{apis}}

> {{.InputLine "exit" }}
`)
	attach.ExpectExit()
}

// trulyRandInt generates a crypto random integer used by the console tests to
// not clash network ports with other tests running cocurrently.
func trulyRandInt(lo, hi int) int {
	num, _ := rand.Int(rand.Reader, big.NewInt(int64(hi-lo)))
	return int(num.Int64()) + lo
}
