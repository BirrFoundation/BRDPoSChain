// Copyright 2016 The go-ethereum Authors
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

// Package debug interfaces Go runtime debugging facilities.
// This package is mostly glue code making these facilities available
// through the CLI and RPC subsystem. If you want to use them from Go code,
// use package runtime instead.
package debug

import (
	"errors"
	"io"
	"log/slog"
	"os"
	"os/user"
	"path/filepath"
	"runtime"
	"runtime/debug"
	"runtime/pprof"
	"strconv"
	"strings"
	"sync"
	"time"

	"BRDPoSChain/log"
)

// Handler is the global debugging handler.
var Handler = new(HandlerT)

// HandlerT implements the debugging API.
// Do not create values of this type, use the one
// in the Handler variable instead.
type HandlerT struct {
	mu        sync.Mutex
	cpuW      io.WriteCloser
	cpuFile   string
	traceW    io.WriteCloser
	traceFile string
	filePath  string
}

// Verbosity sets the log verbosity ceiling. The verbosity of individual packages
// and source files can be raised using Vmodule.
func (*HandlerT) Verbosity(level int) {
	glogger.Verbosity(slog.Level(level))
}

// Vmodule sets the log verbosity pattern. See package log for details on the
// pattern syntax.
func (*HandlerT) Vmodule(pattern string) error {
	return glogger.Vmodule(pattern)
}

// MemStats returns detailed runtime memory statistics.
func (*HandlerT) MemStats() *runtime.MemStats {
	s := new(runtime.MemStats)
	runtime.ReadMemStats(s)
	return s
}

func (h *HandlerT) PeriodicComputeProfiling() {
	ticker := time.NewTicker(60 * time.Second)
	go func() {
		for range ticker.C {
			h.computeProfiling()
		}
	}()
}

// MemStats returns detailed runtime memory statistics.
func (h *HandlerT) computeProfiling() error {
	s := new(runtime.MemStats)
	runtime.ReadMemStats(s)
	currentTime := strconv.FormatInt(time.Now().Unix(), 10)

	systemMem := float64(s.Alloc) / float64(s.HeapSys) * 100
	// Trigger the profiling if memory usage is above 75%
	log.Info("[computeProfiling] current systemMem", "mem", systemMem, "memAlloc", float64(s.Alloc), "heapSys", float64(s.HeapSys))

	if systemMem > float64(75) {
		memoryFileName := currentTime + "-memory-profile"
		err := h.WriteMemProfile(memoryFileName)
		if err != nil {
			log.Error("Fail to write mem profile when doing periodic compute check during high memory usage", "err", err)
			return err
		}
		log.Info("Successfully wrote the memory profile with name", "filename", memoryFileName)
		cpuFileName := currentTime + "-cpu-profile"
		err = h.CpuProfile(cpuFileName, 10)
		if err != nil {
			log.Error("Fail to write cpu profile when doing periodic compute check during high memory usage", "err", err)
			return err
		}
		log.Info("Successfully wrote the cpu profile with name", "filename", cpuFileName)
	}
	return nil
}

// GcStats returns GC statistics.
func (*HandlerT) GcStats() *debug.GCStats {
	s := new(debug.GCStats)
	debug.ReadGCStats(s)
	return s
}

// CpuProfile turns on CPU profiling for nsec seconds and writes
// profile data to file.
func (h *HandlerT) CpuProfile(file string, nsec uint) error {
	if err := h.StartCPUProfile(file); err != nil {
		return err
	}
	time.Sleep(time.Duration(nsec) * time.Second)
	h.StopCPUProfile()
	return nil
}

// StartCPUProfile turns on CPU profiling, writing to the given file.
func (h *HandlerT) StartCPUProfile(file string) error {
	h.mu.Lock()
	defer h.mu.Unlock()
	if h.cpuW != nil {
		return errors.New("CPU profiling already in progress")
	}

	var f *os.File
	var err error
	if h.filePath != "" {
		f, err = os.Create(filepath.Join(h.filePath, file))
	} else {
		f, err = os.Create(expandHome(file))
	}
	if err != nil {
		return err
	}
	if err := pprof.StartCPUProfile(f); err != nil {
		f.Close()
		return err
	}
	h.cpuW = f
	h.cpuFile = file
	log.Info("CPU profiling started", "dump", h.cpuFile)
	return nil
}

// StopCPUProfile stops an ongoing CPU profile.
func (h *HandlerT) StopCPUProfile() error {
	h.mu.Lock()
	defer h.mu.Unlock()
	pprof.StopCPUProfile()
	if h.cpuW == nil {
		return errors.New("CPU profiling not in progress")
	}
	log.Info("Done writing CPU profile", "dump", h.cpuFile)
	h.cpuW.Close()
	h.cpuW = nil
	h.cpuFile = ""
	return nil
}

// GoTrace turns on tracing for nsec seconds and writes
// trace data to file.
func (h *HandlerT) GoTrace(file string, nsec uint) error {
	if err := h.StartGoTrace(file); err != nil {
		return err
	}
	time.Sleep(time.Duration(nsec) * time.Second)
	h.StopGoTrace()
	return nil
}

// BlockProfile turns on goroutine profiling for nsec seconds and writes profile data to
// file. It uses a profile rate of 1 for most accurate information. If a different rate is
// desired, set the rate and write the profile manually.
func (h *HandlerT) BlockProfile(file string, nsec uint) error {
	runtime.SetBlockProfileRate(1)
	time.Sleep(time.Duration(nsec) * time.Second)
	defer runtime.SetBlockProfileRate(0)
	return writeProfile("block", file, h.filePath)
}

// SetBlockProfileRate sets the rate of goroutine block profile data collection.
// rate 0 disables block profiling.
func (*HandlerT) SetBlockProfileRate(rate int) {
	runtime.SetBlockProfileRate(rate)
}

// WriteBlockProfile writes a goroutine blocking profile to the given file.
func (h *HandlerT) WriteBlockProfile(file string) error {
	return writeProfile("block", file, h.filePath)
}

// MutexProfile turns on mutex profiling for nsec seconds and writes profile data to file.
// It uses a profile rate of 1 for most accurate information. If a different rate is
// desired, set the rate and write the profile manually.
func (h *HandlerT) MutexProfile(file string, nsec uint) error {
	runtime.SetMutexProfileFraction(1)
	time.Sleep(time.Duration(nsec) * time.Second)
	defer runtime.SetMutexProfileFraction(0)
	return writeProfile("mutex", file, h.filePath)
}

// SetMutexProfileFraction sets the rate of mutex profiling.
func (*HandlerT) SetMutexProfileFraction(rate int) {
	runtime.SetMutexProfileFraction(rate)
}

// WriteMutexProfile writes a goroutine blocking profile to the given file.
func (h *HandlerT) WriteMutexProfile(file string) error {
	return writeProfile("mutex", file, h.filePath)
}

// WriteMemProfile writes an allocation profile to the given file.
// Note that the profiling rate cannot be set through the API,
// it must be set on the command line.
func (h *HandlerT) WriteMemProfile(file string) error {
	return writeProfile("heap", file, h.filePath)
}

// Stacks returns a printed representation of the stacks of all goroutines.
func (*HandlerT) Stacks() string {
	buf := make([]byte, 1024*1024)
	buf = buf[:runtime.Stack(buf, true)]
	return string(buf)
}

// FreeOSMemory returns unused memory to the OS.
func (*HandlerT) FreeOSMemory() {
	debug.FreeOSMemory()
}

// SetGCPercent sets the garbage collection target percentage. It returns the previous
// setting. A negative value disables GC.
func (*HandlerT) SetGCPercent(v int) int {
	return debug.SetGCPercent(v)
}

func writeProfile(name, file, path string) error {
	p := pprof.Lookup(name)
	log.Info("Writing profile records", "count", p.Count(), "type", name, "dump", file, "path", path)

	var f *os.File
	var err error
	if path != "" {
		f, err = os.Create(filepath.Join(path, file))
	} else {
		f, err = os.Create(expandHome(file))
	}
	if err != nil {
		return err
	}
	defer f.Close()
	return p.WriteTo(f, 0)
}

// expands home directory in file paths.
// ~someuser/tmp will not be expanded.
func expandHome(p string) string {
	if strings.HasPrefix(p, "~/") || strings.HasPrefix(p, "~\\") {
		home := os.Getenv("HOME")
		if home == "" {
			if usr, err := user.Current(); err == nil {
				home = usr.HomeDir
			}
		}
		if home != "" {
			p = home + p[1:]
		}
	}
	return filepath.Clean(p)
}
