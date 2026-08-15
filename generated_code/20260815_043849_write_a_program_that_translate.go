package main

import (
	"bytes"
	"context"
	"encoding/binary"
	"fmt"
	"math"
	"math/rand"
	"os"
	"os/signal"
	"runtime"
	"sync"
	"syscall"
	"time"
)

// Standard MIDI file writer for real-time streaming to a file.
type StreamMIDI struct {
	file *os.File
	mu   sync.Mutex
}

func NewStreamMIDI(filename string) (*StreamMIDI, error) {
	f, err := os.Create(filename)
	if err != nil {
		return nil, err
	}

	// MIDI Header Chunk (Format 0, 1 track, 480 ticks per quarter note)
	header := []byte{
		'M', 'T', 'h', 'd',
		0, 0, 0, 6,
		0, 0, // Format 0
		0, 1, // 1 Track
		0x01, 0xE0, // 480 PPQN
	}

	if _, err := f.Write(header); err != nil {
		f.Close()
		return nil, err
	}

	// MIDI Track Chunk Header (Placeholder for length, updated on close)
	trackHeader := []byte{'M', 'T', 'r', 'k', 0, 0, 0, 0}
	if _, err := f.Write(trackHeader); err != nil {
		f.Close()
		return nil, err
	}

	sm := &StreamMIDI{file: f}
	sm.writeTempo(500000) // 120 BPM
	return sm, nil
}

func (sm *StreamMIDI) writeVarLen(delta uint32) []byte {
	var buf []byte
	v := delta & 0x7F
	for delta >>= 7; delta > 0; delta >>= 7 {
		v <<= 8
		v |= 0x80 | (delta & 0x7F)
	}
	for {
		buf = append(buf, byte(v))
		if v&0x80 != 0 {
			v >>= 8
		} else {
			break
		}
	}
	return buf
}

func (sm *StreamMIDI) writeTempo(microsecondsPerQuarter uint32) {
	sm.mu.Lock()
	defer sm.mu.Unlock()
	data := append(sm.writeVarLen(0), 0xFF, 0x51, 0x03)
	data = append(data, byte(microsecondsPerQuarter>>16), byte(microsecondsPerQuarter>>8), byte(microsecondsPerQuarter))
	sm.file.Write(data)
}

func (sm *StreamMIDI) NoteOn(delta uint32, ch, note, vel byte) {
	sm.mu.Lock()
	defer sm.mu.Unlock()
	data := append(sm.writeVarLen(delta), 0x90|(ch&0x0F), note&0x7F, vel&0x7F)
	sm.file.Write(data)
}

func (sm *StreamMIDI) NoteOff(delta uint32, ch, note byte) {
	sm.mu.Lock()
	defer sm.mu.Unlock()
	data := append(sm.writeVarLen(delta), 0x80|(ch&0x0F), note&0x7F, 0)
	sm.file.Write(data)
}

func (sm *StreamMIDI) ProgramChange(delta uint32, ch, program byte) {
	sm.mu.Lock()
	defer sm.mu.Unlock()
	data := append(sm.writeVarLen(delta), 0xC0|(ch&0x0F), program&0x7F)
	sm.file.Write(data)
}

func (sm *StreamMIDI) Close() {
	sm.mu.Lock()
	defer sm.mu.Unlock()

	// End of Track Meta Event
	eot := append(sm.writeVarLen(0), 0xFF, 0x2F, 0x00)
	sm.file.Write(eot)

	// Calculate and rewrite total track length
	stat, err := sm.file.Stat()
	if err == nil {
		trackLen := uint32(stat.Size() - 14 - 8) // minus header (14) and track header (8)
		buf := make([]byte, 4)
		binary.BigEndian.PutUint32(buf, trackLen)
		sm.file.WriteAt(buf, 18)
	}
	sm.file.Close()
}

// Memory Sonifier tracks system memory & maps it to scales/harmony.
type Sonifier struct {
	midi         *StreamMIDI
	scales       [][]byte
	scaleIdx     int
	lastGCCount  uint32
	activeNotes  map[byte]bool
}

func NewSonifier(midi *StreamMIDI) *Sonifier {
	// Musical Scales for Harmonic Shifts
	scales := [][]byte{
		{60, 62, 64, 65, 67, 69, 71, 72}, // C Major (Calm)
		{60, 62, 63, 65, 67, 68, 70, 72}, // C Natural Minor
		{60, 61, 64, 65, 67, 68, 71, 72}, // C Double Harmonic (Dramatic)
		{60, 63, 65, 66, 67, 70, 72, 75}, // C Blues
		{60, 62, 66, 68, 70, 72, 74, 76}, // C Whole Tone (Ethereal)
	}

	// Instrument Presets: 0=Piano, 19=Organ, 48=Strings, 80=Synth Lead
	midi.ProgramChange(0, 0, 0)  // Ch 0: Arpeggio
	midi.ProgramChange(0, 1, 48) // Ch 1: Bass / Pad
	midi.ProgramChange(0, 2, 80) // Ch 2: Garbage Collection Stabs

	return &Sonifier{
		midi:        midi,
		scales:      scales,
		scaleIdx:    0,
		activeNotes: make(map[byte]bool),
	}
}

// Memory Allocation Generator to simulate varying process load
func MemoryLoadSimulator(ctx context.Context) {
	ticker := time.NewTicker(200 * time.Millisecond)
	defer ticker.Stop()

	var store [][]byte
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			// Dynamic allocation / deallocation pattern
			action := rand.Intn(10)
			if action < 7 {
				// Allocate between 500KB and 5MB
				size := rand.Intn(5*1024*1024) + 500*1024
				store = append(store, make([]byte, size))
			} else if action < 9 && len(store) > 0 {
				// Drop allocations to encourage GC
				releaseCount := rand.Intn(len(store)/2 + 1)
				store = store[releaseCount:]
			} else {
				// Force explicit GC to generate dramatic musical events
				runtime.GC()
			}
		}
	}
}

func (s *Sonifier) Run(ctx context.Context) {
	ticker := time.NewTicker(120 * time.Millisecond)
	defer ticker.Stop()

	var memStats runtime.MemStats
	var lastNote byte
	ticks := uint32(48) // Delta time (16th note at 480 PPQN)

	for {
		select {
		case <-ctx.Done():
			// Silence any playing notes on exit
			if lastNote > 0 {
				s.midi.NoteOff(ticks, 0, lastNote)
			}
			return
		case <-ticker.C:
			runtime.ReadMemStats(&memStats)

			// 1. Detect Garbage Collection Cycle for Harmonic Shift
			if memStats.NumGC > s.lastGCCount {
				s.lastGCCount = memStats.NumGC
				s.scaleIdx = (s.scaleIdx + 1) % len(s.scales)

				// Play a dramatic GC orchestral stab on Channel 2
				root := s.scales[s.scaleIdx][0] - 12
				s.midi.NoteOn(0, 2, root, 120)
				s.midi.NoteOn(0, 2, root+7, 115)
				s.midi.NoteOn(0, 2, root+12, 127)
				
				// Release stab rapidly
				go func(r byte) {
					time.Sleep(150 * time.Millisecond)
					s.midi.NoteOff(0, 2, r)
					s.midi.NoteOff(0, 2, r+7)
					s.midi.NoteOff(0, 2, r+12)
				}(root)

				fmt.Printf("[GC Cycle #%d] Harmonic shift to Scale Set %d\n", memStats.NumGC, s.scaleIdx)
			}

			// 2. Map HeapAlloc to Arpeggio Melody (Channel 0)
			currentScale := s.scales[s.scaleIdx]
			// Normalized heap size mapped across octave-extended scale
			allocMB := float64(memStats.HeapAlloc) / (1024 * 1024)
			noteIndex := int(math.Mod(allocMB*3, float64(len(currentScale)*2)))
			
			octaveShift := byte((noteIndex / len(currentScale)) * 12)
			baseNote := currentScale[noteIndex%len(currentScale)]
			pitch := baseNote + octaveShift

			// Dynamic Velocity mapped to HeapObjects count
			velocity := byte(40 + (memStats.HeapObjects % 87))

			if lastNote > 0 {
				s.midi.NoteOff(ticks, 0, lastNote)
			}
			s.midi.NoteOn(0, 0, pitch, velocity)
			lastNote = pitch

			// 3. Map System Memory (Sys) to Low Drone / Bass (Channel 1)
			bassNote := currentScale[0] - 24
			s.midi.NoteOn(0, 1, bassNote, 70)

			fmt.Printf("HeapAlloc: %6.2f MB | Objects: %6d | Playing MIDI Pitch: %d\n",
				allocMB, memStats.HeapObjects, pitch)
		}
	}
}

func main() {
	outputFile := "memory_score.mid"
	fmt.Printf("Translating live memory consumption into MIDI score...\n")
	fmt.Printf("Output File: %s (Press Ctrl+C to stop and finalize MIDI file)\n\n", outputFile)

	midiStream, err := NewStreamMIDI(outputFile)
	if err != nil {
		fmt.Printf("Failed to create MIDI file: %v\n", err)
		return
	}

	ctx, cancel := context.WithCancel(context.Background())
	sonifier := NewSonifier(midiStream)

	// Graceful shutdown handler
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)

	go MemoryLoadSimulator(ctx)
	go sonifier.Run(ctx)

	<-sigChan
	fmt.Println("\nStopping music generation and closing MIDI track...")
	cancel()

	// Wait briefly for channels to flush
	time.Sleep(300 * time.Millisecond)
	midiStream.Close()
	fmt.Println("MIDI file saved successfully!")
}