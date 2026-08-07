package main

import (
	"bytes"
	"encoding/binary"
	"fmt"
	"math/rand"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"time"
)

// ThermalDecayFS manages a filesystem where heat triggers data corruption
// and translates decayed file blocks into self-modifying MIDI compositions.
type ThermalDecayFS struct {
	rootDir  string
	midiDir  string
	mu       sync.Mutex
	stopChan chan struct{}
}

func main() {
	fmt.Println("=== Thermal Decay Filesystem & Heat-MIDI Generator ===")

	fs, err := NewThermalDecayFS("./decay_fs", "./midi_output")
	if err != nil {
		fmt.Printf("Initialization error: %v\n", err)
		return
	}

	// Seed filesystem with sample text files
	fs.SeedFiles()

	// Start continuous thermal decay and MIDI synthesis loop
	go fs.StartThermalEngine(1 * time.Second)

	fmt.Println("Engine running... Monitoring CPU heat and morphing decay into MIDI compositions.")

	// Run simulation cycle for demonstration
	time.Sleep(10 * time.Second)
	fs.Stop()
	fmt.Println("Simulation halted. Output available in ./decay_fs and ./midi_output.")
}

func NewThermalDecayFS(rootDir, midiDir string) (*ThermalDecayFS, error) {
	if err := os.MkdirAll(rootDir, 0755); err != nil {
		return nil, err
	}
	if err := os.MkdirAll(midiDir, 0755); err != nil {
		return nil, err
	}
	return &ThermalDecayFS{
		rootDir:  rootDir,
		midiDir:  midiDir,
		stopChan: make(chan struct{}),
	}, nil
}

// SeedFiles initializes structured files into the simulated storage space.
func (fs *ThermalDecayFS) SeedFiles() {
	sampleTexts := []string{
		"The quick brown fox jumps over the lazy dog. System operating at baseline temperature.",
		"Memory structures remain coherent. Data preservation protocol actively monitoring CPU thermal output.",
		"Entropy increases in isolated thermal zones. Binary arrays begin phase transition into audio harmonics.",
	}
	for i, text := range sampleTexts {
		filename := filepath.Join(fs.rootDir, fmt.Sprintf("document_%d.txt", i+1))
		os.WriteFile(filename, []byte(text), 0644)
	}
}

// StartThermalEngine periodically samples CPU temperature, mutates stored files, and updates MIDI compositions.
func (fs *ThermalDecayFS) StartThermalEngine(interval time.Duration) {
	ticker := time.NewTicker(interval)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			fs.mu.Lock()
			temp := fs.readCPUTemperature()
			fs.decayAndSynthesize(temp)
			fs.mu.Unlock()
		case <-fs.stopChan:
			return
		}
	}
}

func (fs *ThermalDecayFS) Stop() {
	close(fs.stopChan)
}

// readCPUTemperature checks Linux hardware thermal zones or simulates dynamic heat curves.
func (fs *ThermalDecayFS) readCPUTemperature() float64 {
	// Attempt reading thermal zone on Linux systems
	data, err := os.ReadFile("/sys/class/thermal/thermal_zone0/temp")
	if err == nil {
		raw := strings.TrimSpace(string(data))
		if val, err := strconv.ParseFloat(raw, 64); err == nil {
			if val > 1000 {
				val /= 1000.0 // Convert millidegrees to Celsius
			}
			return val
		}
	}
	// Fallback dynamic heat simulation (cycles between 40°C and 85°C)
	baseTemp := 45.0
	heatSpike := float64(time.Now().Unix()%15) * 2.5
	noise := (rand.Float64() - 0.5) * 4.0
	return baseTemp + heatSpike + noise
}

// decayAndSynthesize corrupts filesystem blocks according to CPU heat and converts data into MIDI notes.
func (fs *ThermalDecayFS) decayAndSynthesize(temp float64) {
	files, err := os.ReadDir(fs.rootDir)
	if err != nil || len(files) == 0 {
		return
	}

	// Calculate decay likelihood based on thermal state (hotter CPU = faster corruption)
	corruptionProbability := (temp - 30.0) / 100.0
	if corruptionProbability < 0.05 {
		corruptionProbability = 0.05
	} else if corruptionProbability > 0.9 {
		corruptionProbability = 0.9
	}

	var totalCorruptedBytes []byte

	for _, file := range files {
		if file.IsDir() {
			continue
		}
		path := filepath.Join(fs.rootDir, file.Name())
		data, err := os.ReadFile(path)
		if err != nil {
			continue
		}

		// Mutate bytes directly based on thermal severity
		mutated := false
		for i := 0; i < len(data); i++ {
			if rand.Float64() < corruptionProbability*0.1 {
				data[i] ^= byte(int(temp) & 0xFF) // Thermal XOR shift corruption
				mutated = true
			}
		}

		if mutated {
			os.WriteFile(path, data, 0644)
		}
		totalCorruptedBytes = append(totalCorruptedBytes, data...)
	}

	// Synthesize a self-modifying MIDI file representing the current thermal composition
	midiData := fs.generateMIDI(temp, totalCorruptedBytes)
	midiPath := filepath.Join(fs.midiDir, fmt.Sprintf("heat_composition_%dC.mid", int(temp)))
	os.WriteFile(midiPath, midiData, 0644)

	fmt.Printf("[Temp: %.1f°C] Corruption Factor: %.2f | Composition Saved: %s\n",
		temp, corruptionProbability, filepath.Base(midiPath))
}

// generateMIDI builds a valid Standard MIDI File (SMF Format 0) from decayed raw data.
func (fs *ThermalDecayFS) generateMIDI(temp float64, rawData []byte) []byte {
	var trackBytes bytes.Buffer

	// Dynamic BPM based on temperature (Hotter CPU = Faster tempo)
	bpm := 60.0 + (temp-30.0)*3.5
	if bpm < 40 {
		bpm = 40
	}
	usPerQuarter := uint32(60000000 / bpm)

	// Meta Event: Set Tempo
	trackBytes.Write([]byte{0x00, 0xFF, 0x51, 0x03})
	trackBytes.Write([]byte{
		byte(usPerQuarter >> 16),
		byte(usPerQuarter >> 8),
		byte(usPerQuarter),
	})

	// Pentatonic scale pitch map derived from mutated bytes
	scale := []byte{60, 62, 64, 67, 69, 72, 74, 76, 79, 81} // C Major Pentatonic

	// Convert file byte arrays into dynamic MIDI Note On / Note Off events
	var prevDelta byte = 0x00
	for i, b := range rawData {
		if i > 64 { // Restrict single track length
			break
		}
		pitchIndex := (int(b) + int(temp)) % len(scale)
		pitch := scale[pitchIndex]

		// Dynamic note velocity influenced by heat intensity
		velocity := byte(40 + (int(temp) % 80))

		// Note On event
		trackBytes.WriteByte(prevDelta)
		trackBytes.Write([]byte{0x90, pitch, velocity})

		// Note Off event after duration calculated from raw byte payload
		durationDelta := byte(0x20 + (b % 0x30))
		trackBytes.WriteByte(durationDelta)
		trackBytes.Write([]byte{0x80, pitch, 0x00})
	}

	// End of Track Meta Event
	trackBytes.Write([]byte{0x00, 0xFF, 0x2F, 0x00})

	// Construct MIDI File Header & Payload
	var midiBuffer bytes.Buffer

	// MThd Header Chunk
	midiBuffer.WriteString("MThd")
	binary.Write(&midiBuffer, binary.BigEndian, uint32(6))  // Length
	binary.Write(&midiBuffer, binary.BigEndian, uint16(0))  // Format 0
	binary.Write(&midiBuffer, binary.BigEndian, uint16(1))  // Single track
	binary.Write(&midiBuffer, binary.BigEndian, uint16(96)) // Division (ticks per quarter)

	// MTrk Track Chunk
	midiBuffer.WriteString("MTrk")
	binary.Write(&midiBuffer, binary.BigEndian, uint32(trackBytes.Len()))
	midiBuffer.Write(trackBytes.Bytes())

	return midiBuffer.Bytes()
}