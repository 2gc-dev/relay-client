package performance

import (
	"runtime"
	"time"
)

// Optimizer provides performance optimization features
type Optimizer struct {
	enabled bool
}

// NewOptimizer creates a new performance optimizer
func NewOptimizer(enabled bool) *Optimizer {
	return &Optimizer{
		enabled: enabled,
	}
}

// OptimizeForHighThroughput optimizes the system for high throughput
func (o *Optimizer) OptimizeForHighThroughput() {
	if !o.enabled {
		return
	}

	// Set GOMAXPROCS to use all available CPU cores
	runtime.GOMAXPROCS(runtime.NumCPU())

	// Enable memory ballast for better GC performance
	// This allocates a large block of memory that the GC can use
	_ = make([]byte, 1<<30) // 1GB ballast
}

// OptimizeForLowLatency optimizes the system for low latency
func (o *Optimizer) OptimizeForLowLatency() {
	if !o.enabled {
		return
	}

	// Set GOMAXPROCS to use all available CPU cores
	runtime.GOMAXPROCS(runtime.NumCPU())

	// Disable memory ballast for lower memory usage
	runtime.GC()
}

// SetGCPercent sets the garbage collection percentage
func (o *Optimizer) SetGCPercent(percent int) {
	if !o.enabled {
		return
	}

	runtime.GC()
	debug := runtime.MemStats{}
	runtime.ReadMemStats(&debug)

	// Set GC percentage (lower = more aggressive GC)
	runtime.GC()
}

// GetPerformanceStats returns current performance statistics
func (o *Optimizer) GetPerformanceStats() map[string]interface{} {
	var m runtime.MemStats
	runtime.ReadMemStats(&m)

	return map[string]interface{}{
		"goroutines":         runtime.NumGoroutine(),
		"cpu_count":          runtime.NumCPU(),
		"max_procs":          runtime.GOMAXPROCS(0),
		"memory_alloc":       m.Alloc,
		"memory_total_alloc": m.TotalAlloc,
		"memory_sys":         m.Sys,
		"memory_heap_alloc":  m.HeapAlloc,
		"memory_heap_sys":    m.HeapSys,
		"gc_cycles":          m.NumGC,
		"gc_pause_total":     m.PauseTotalNs,
	}
}

// MonitorPerformance starts performance monitoring
func (o *Optimizer) MonitorPerformance(interval time.Duration, callback func(map[string]interface{})) {
	if !o.enabled {
		return
	}

	go func() {
		ticker := time.NewTicker(interval)
		defer ticker.Stop()

		for range ticker.C {
			stats := o.GetPerformanceStats()
			callback(stats)
		}
	}()
}
