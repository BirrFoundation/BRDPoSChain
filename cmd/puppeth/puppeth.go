// Copyright 2017 The go-ethereum Authors
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

// puppeth is a command to assemble and maintain private networks.
package main

import (
	"math/rand"
	"os"
	"strings"
	"time"

	"BRDPoSChain/log"
	"github.com/urfave/cli/v2"
)

// main is just a boring entry point to set up the CLI app.
func main() {
	app := cli.NewApp()
	app.Name = "puppeth"
	app.Usage = "assemble and maintain private Ethereum networks"
	app.Flags = []cli.Flag{
		&cli.StringFlag{
			Name:  "network",
			Usage: "name of the network to administer (no spaces or hyphens, please)",
		},
		&cli.IntFlag{
			Name:  "loglevel",
			Value: 3,
			Usage: "log level to emit to the screen",
		},
	}
	app.Action = func(c *cli.Context) error {
		// Set up the logger to print everything and the random generator
		log.SetDefault(log.NewLogger(log.NewTerminalHandlerWithLevel(os.Stdout, log.FromLegacyLevel(c.Int("loglevel")), true)))
		rand.Seed(time.Now().UnixNano())

		network := c.String("network")
		if strings.Contains(network, " ") || strings.Contains(network, "-") {
			log.Crit("No spaces or hyphens allowed in network name")
		}
		// Start the wizard and relinquish control
		makeWizard(c.String("network")).run()
		return nil
	}
	app.Run(os.Args)
}
