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
	"fmt"
	"os"
	"testing"

	"BRDPoSChain/internal/cmdtest"

	"github.com/docker/docker/pkg/reexec"
)

type testBRC struct {
	*cmdtest.TestCmd

	// template variables for expect
	Datadir   string
	Etherbase string
}

func init() {
	// Run the app if we've been exec'd as "BRC-test" in runGeth.
	reexec.Register("BRC-test", func() {
		if err := app.Run(os.Args); err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		os.Exit(0)
	})
}

func TestMain(m *testing.M) {
	// check if we have been reexec'd
	if reexec.Init() {
		return
	}
	os.Exit(m.Run())
}

// spawns BRC with the given command line args. If the args don't set --datadir, the
// child g gets a temporary data directory.
func runBRC(t *testing.T, args ...string) *testBRC {
	tt := &testBRC{}
	tt.TestCmd = cmdtest.NewTestCmd(t, tt)
	for i, arg := range args {
		switch arg {
		case "--datadir":
			if i < len(args)-1 {
				tt.Datadir = args[i+1]
			}
		case "--miner-etherbase":
			if i < len(args)-1 {
				tt.Etherbase = args[i+1]
			}
		}
	}
	if tt.Datadir == "" {
		// The temporary datadir will be removed automatically if something fails below.
		tt.Datadir = t.TempDir()
		tt.Cleanup = func() { os.RemoveAll(tt.Datadir) }
		args = append([]string{"--datadir", tt.Datadir}, args...)
	}

	// Boot "BRC". This actually runs the test binary but the TestMain
	// function will prevent any tests from running.
	tt.Run("BRC-test", args...)

	return tt
}
