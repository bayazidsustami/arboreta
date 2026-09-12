package main

import (
	"bytes"
	"encoding/binary"
	"fmt"
	"math"
	"math/rand"
	"os"
	"runtime"
	"sync"
	"time"
)

const (
	sampleRate = 44100
	numVoices  = 6
	twoPi      = 2 * math.Pi
)

// Voice represents a synth voice mapped to heap object characteristics.
type Voice struct {
	freq       float64
	targetFreq float64
	amp        float64
	targetAmp  float64
	pan        float64 // 0.0 (left) to 1.0 (right)
	phase      float64
}

// ReverbDelay line for simple comb filter atmospheric tails.
type DelayLine struct {
	buffer []float64
	index  int
	decay  float64
}

func main() {
	var (
		mu           sync.Mutex
		voices       = make([]*Voice, numVoices)
		reverbDecay  = 0.7
		reverbLineL  = &DelayLine{buffer: make([]float64, int(sampleRate*0.18)), decay: 0.7}
		reverbLineR  = &DelayLine{buffer: make([]float64, int(sampleRate*0.25)), decay: 0.7}
		lastNumGC    uint32
		heapKeepAlive []interface{}
	)

	for i := range voices {
		voices[i] = &Voice{freq: 110, targetFreq: 110, amp: 0, targetAmp: 0, pan: 0.5}
	}

	// Dynamic memory churn generator to create rich heap activity
	go func() {
		for {
			// Allocate objects of varying sizes and pointer depths
			count := rand.Intn(500) + 10
			for j := 0; j < count; j++ {
				depth := rand.Intn(4) + 1
				node := buildPointerTree(depth, rand.Intn(2048)+64)
				heapKeepAlive = append(heapKeepAlive, node)
			}
			if len(heapKeepAlive) > 3000 {
				heapKeepAlive = heapKeepAlive[1500:] // Trigger garbage collection sweep
			}
			time.Sleep(time.Duration(rand.Intn(80)+20) * time.Millisecond)
		}
	}()

	// Heap Sampler & Mapping Engine
	go func() {
		var m runtime.MemStats
		for {
			runtime.ReadMemStats(&m)

			mu.Lock()
			// 1. Map total heap objects & pointer addresses to voice frequencies
			baseFreq := 110.0 + math.Mod(float64(m.HeapAlloc)/1024.0, 440.0)
			for i, v := range voices {
				// Address space simulation/ptr depth via allocation stats
				harmonic := float64(i+1) * 0.75
				addressOffset := float64((m.HeapObjects+uint64(i*1337))%1200) / 100.0
				v.targetFreq = baseFreq*harmonic + addressOffset*12.0
				v.targetAmp = (0.15 / float64(i+1)) * (0.5 + 0.5*math.Sin(float64(m.Lookups)+float64(i)))
				v.pan = math.Mod(float64(m.HeapObjects*(uint64(i)+1))/17.0, 1.0)
			}

			// 2. Map GC Pauses and Activity to Reverb Tail and Intensity
			if m.NumGC > lastNumGC {
				lastPause := m.PauseNs[(m.NumGC+255)%256]
				// Longer GC pause expands reverb decay space
				reverbDecay = math.Min(0.95, 0.5+(float64(lastPause)/1e7))
				reverbLineL.decay = reverbDecay
				reverbLineR.decay = reverbDecay

				// Trigger high-frequency resonance on GC event
				voices[numVoices-1].targetFreq = 880.0 + float64(lastPause%1000)
				voices[numVoices-1].targetAmp = 0.4
				lastNumGC = m.NumGC
			}
			mu.Unlock()

			fmt.Fprintf(os.Stderr, "\r[Heap Synth] Alloc: %d KB | Objects: %d | GC Cycles: %d | Reverb Tail: %.2f",
				m.HeapAlloc/1024, m.HeapObjects, m.NumGC, reverbDecay)

			time.Sleep(30 * time.Millisecond)
		}
	}()

	// PCM Audio Streamer (Outputs raw 16-bit Stereo PCM to stdout)
	// Pipe into a player: `go run main.go | ffplay -f s16le -ar 44100 -ac 2 -i pipe:0`
	// Or `aplay -f cd` on Linux
	buf := new(bytes.Buffer)
	ticker := time.NewTicker(time.Second / 60)
	defer ticker.Stop()

	for range ticker.C {
		buf.Reset()
		samplesToRender := sampleRate / 60

		for s := 0; s < samplesToRender; s++ {
			var leftAccum, rightAccum float64

			mu.Lock()
			for _, v := range voices {
				// Smooth frequency/amplitude transitions for atmospheric textures
				v.freq += (v.targetFreq - v.freq) * 0.005
				v.amp += (v.targetAmp - v.amp) * 0.005

				v.phase += v.freq / sampleRate
				if v.phase >= 1.0 {
					v.phase -= 1.0
				}

				// Soft sine-sine phase modulation synthesis
				sample := math.Sin(twoPi*v.phase + 0.2*math.Sin(twoPi*v.phase*1.5)) * v.amp
				leftAccum += sample * (1.0 - v.pan)
				rightAccum += sample * v.pan
			}
			mu.Unlock()

			// Apply stereo comb-filtering for dynamic reverb tails
			outL := processDelay(reverbLineL, leftAccum)
			outR := processDelay(reverbLineR, rightAccum)

			// Soft clipping to prevent distortion
			outL = math.Tanh(outL) * 32767.0
			outR = math.Tanh(outR) * 32767.0

			binary.Write(buf, binary.LittleEndian, int16(outL))
			binary.Write(buf, binary.LittleEndian, int16(outR))
		}

		os.Stdout.Write(buf.Bytes())
	}
}

// Simple pointer structure to simulate varying heap graph depths
type PointerNode struct {
	Data []byte
	Next *PointerNode
}

func buildPointerTree(depth int, chunkSize int) *PointerNode {
	if depth <= 0 {
		return &PointerNode{Data: make([]byte, chunkSize)}
	}
	return &PointerNode{
		Data: make([]byte, chunkSize),
		Next: buildPointerTree(depth-1, chunkSize),
	}
}

func processDelay(d *DelayLine, input float64) float64 {
	delayed := d.buffer[d.index]
	output := input + delayed*d.decay
	d.buffer[d.index] = output
	d.index = (d.index + 1) % len(d.buffer)
	return output
}