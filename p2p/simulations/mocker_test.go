// Copyright 2017 The go-ethereum Authors
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

// Package simulations simulates p2p networks.
// A mokcer simulates starting and stopping real nodes in a network.
package simulations

import (
	"encoding/json"
	"net/http"
	"net/url"
	"strconv"
	"sync"
	"testing"
	"time"

	"BRDPoSChain/p2p/discover"
)

func TestMocker(t *testing.T) {
	//start the simulation HTTP server
	_, s := testHTTPServer(t)
	defer s.Close()

	//create a client
	client := NewClient(s.URL)

	//start the network
	err := client.StartNetwork()
	if err != nil {
		t.Fatalf("Could not start test network: %s", err)
	}
	//stop the network to terminate
	defer func() {
		err = client.StopNetwork()
		if err != nil {
			t.Fatalf("Could not stop test network: %s", err)
		}
	}()

	//get the list of available mocker types
	resp, err := http.Get(s.URL + "/mocker")
	if err != nil {
		t.Fatalf("Could not get mocker list: %s", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		t.Fatalf("Invalid Status Code received, expected 200, got %d", resp.StatusCode)
	}

	//check the list is at least 1 in size
	var mockerlist []string
	err = json.NewDecoder(resp.Body).Decode(&mockerlist)
	if err != nil {
		t.Fatalf("Error decoding JSON mockerlist: %s", err)
	}

	if len(mockerlist) < 1 {
		t.Fatalf("No mockers available")
	}

	nodeCount := 10
	var wg sync.WaitGroup

	events := make(chan *Event, 10)
	var opts SubscribeOpts
	sub, err := client.SubscribeNetwork(events, opts)
	defer sub.Unsubscribe()

	// wait until all nodes are started and connected
	// store every node up event in a map (value is irrelevant, mimic Set datatype)
	nodemap := make(map[discover.NodeID]bool)
	nodesComplete := false
	connCount := 0
	wg.Add(1)
	go func() {
		defer wg.Done()

		for connCount < (nodeCount-1)*2 {
			select {
			case event := <-events:
				//if the event is a node Up event only
				if event.Node != nil && event.Node.Up {
					//add the correspondent node ID to the map
					nodemap[event.Node.Config.ID] = true
					//this means all nodes got a nodeUp event, so we can continue the test
					if len(nodemap) == nodeCount {
						nodesComplete = true
						//wait for 3s as the mocker will need time to connect the nodes
						//time.Sleep( 3 *time.Second)
					}
				} else if event.Conn != nil && nodesComplete {
					connCount += 1
				}
			case <-time.After(30 * time.Second):
				t.Errorf("Timeout waiting for nodes being started up!")
				return
			}
		}
	}()

	//take the last element of the mockerlist as the default mocker-type to ensure one is enabled
	mockertype := mockerlist[len(mockerlist)-1]
	//still, use hardcoded "probabilistic" one if available ;)
	for _, m := range mockerlist {
		if m == "probabilistic" {
			mockertype = m
			break
		}
	}
	//start the mocker with nodeCount number of nodes
	resp, err = http.PostForm(s.URL+"/mocker/start", url.Values{"mocker-type": {mockertype}, "node-count": {strconv.Itoa(nodeCount)}})
	if err != nil {
		t.Fatalf("Could not start mocker: %s", err)
	}
	resp.Body.Close()
	if resp.StatusCode != 200 {
		t.Fatalf("Invalid Status Code received for starting mocker, expected 200, got %d", resp.StatusCode)
	}

	wg.Wait()

	//check there are nodeCount number of nodes in the network
	nodes_info, err := client.GetNodes()
	if err != nil {
		t.Fatalf("Could not get nodes list: %s", err)
	}

	if len(nodes_info) != nodeCount {
		t.Fatalf("Expected %d number of nodes, got: %d", nodeCount, len(nodes_info))
	}

	//stop the mocker
	resp, err = http.Post(s.URL+"/mocker/stop", "", nil)
	if err != nil {
		t.Fatalf("Could not stop mocker: %s", err)
	}
	resp.Body.Close()
	if resp.StatusCode != 200 {
		t.Fatalf("Invalid Status Code received for stopping mocker, expected 200, got %d", resp.StatusCode)
	}

	//reset the network
	resp, err = http.Post(s.URL+"/reset", "", nil)
	if err != nil {
		t.Fatalf("Could not reset network: %s", err)
	}
	resp.Body.Close()

	//now the number of nodes in the network should be zero
	nodes_info, err = client.GetNodes()
	if err != nil {
		t.Fatalf("Could not get nodes list: %s", err)
	}

	if len(nodes_info) != 0 {
		t.Fatalf("Expected empty list of nodes, got: %d", len(nodes_info))
	}
}
