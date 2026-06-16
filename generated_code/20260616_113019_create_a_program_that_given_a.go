package main

import (
	"bytes"
	"encoding/base64"
	"image"
	"image/color"
	"image/draw"
	"image/gif"
	"io"
	"log"
	"os"
	"time"
)

// Simple MIDI event representation.
type midiEvent struct {
	Delta   uint32
	Pitch   uint8
	Velocity uint8
}

// Read a variable‑length quantity.
func readVLQ(r io.Reader) (uint32, error) {
	var value uint32
	for i := 0; i < 4; i++ {
		var b [1]byte
		if _, err := r.Read(b[:]); err != nil {
			return 0, err
		}
		value = (value << 7) | uint32(b[0]&0x7F)
		if b[0]&0x80 == 0 {
			return value, nil
		}
	}
	return value, nil
}

// Parse only Note On events from a whole‑file MIDI (format 0/1).
func parseMIDI(data []byte) ([]midiEvent, error) {
	r := bytes.NewReader(data)

	// Header chunk
	var hdr [14]byte
	if _, err := io.ReadFull(r, hdr[:]); err != nil {
		return nil, err
	}
	if string(hdr[0:4]) != "MThd" {
		return nil, io.ErrUnexpectedEOF
	}
	// skip format, ntrks, division (bytes 8‑13)
	// For simplicity assume division = 480 ticks per quarter note.
	var events []midiEvent
	for {
		// Track header
		var trackHdr [8]byte
		if _, err := io.ReadFull(r, trackHdr[:]); err != nil {
			break // EOF -> done
		}
		if string(trackHdr[0:4]) != "MTrk" {
			return nil, io.ErrUnexpectedEOF
		}
		trackLen := int(trackHdr[4])<<24 | int(trackHdr[5])<<16 | int(trackHdr[6])<<8 | int(trackHdr[7])
		trackData := make([]byte, trackLen)
		if _, err := io.ReadFull(r, trackData); err != nil {
			return nil, err
		}
		trackR := bytes.NewReader(trackData)
		var lastStatus byte
		for trackR.Len() > 0 {
			delta, err := readVLQ(trackR)
			if err != nil {
				break
			}
			var status byte
			peek, err := trackR.ReadByte()
			if err != nil {
				break
			}
			if peek&0x80 != 0 { // new status byte
				status = peek
				lastStatus = status
			} else { // running status
				status = lastStatus
				trackR.UnreadByte()
			}
			if status&0xF0 == 0x90 { // Note On
				var note, vel [1]byte
				if _, err := trackR.Read(note[:]); err != nil {
					break
				}
				if _, err := trackR.Read(vel[:]); err != nil {
					break
				}
				if vel[0] > 0 {
					events = append(events, midiEvent{Delta: delta, Pitch: note[0], Velocity: vel[0]})
				}
			} else {
				// skip 2 data bytes for other channel messages, 1 for program change etc.
				switch status & 0xF0 {
				case 0x80, 0xA0, 0xB0, 0xE0:
					trackR.Seek(2, io.SeekCurrent)
				case 0xC0, 0xD0:
					trackR.Seek(1, io.SeekCurrent)
				case 0xF0:
					// SysEx or Meta: skip until end byte 0xF7 or read length.
					if status == 0xFF { // Meta event
						if _, err := trackR.ReadByte(); err != nil {
							break
						}
						len, err := readVLQ(trackR)
						if err != nil {
							break
						}
						trackR.Seek(int64(len), io.SeekCurrent)
					} else {
						// skip SysEx
						len, err := readVLQ(trackR)
						if err != nil {
							break
						}
						trackR.Seek(int64(len), io.SeekCurrent)
					}
				}
			}
		}
	}
	return events, nil
}

// Generate a simple kaleidoscopic pattern based on pitch/velocity.
func makeFrame(pitch uint8, vel uint8) *image.Paletted {
	const size = 200
	rect := image.Rect(0, 0, size, size)
	img := image.NewPaletted(rect, palette())
	// background
	bg := color.RGBA{0, 0, 0, 255}
	draw.Draw(img, rect, &image.Uniform{bg}, image.Point{}, draw.Src)

	// draw radial lines
	n := int(pitch%12 + 3) // number of symmetries
	col := color.RGBA{R: vel, G: 255 - vel, B: uint8(255 - pitch), A: 255}
	center := size / 2
	for i := 0; i < n; i++ {
		angle := float64(i) * 2 * 3.14159265 / float64(n)
		x := center + int(float64(center)*float64(pitch%128)/128*0.7*float64(i%2+1)*float64(i%3+1))
		y := center + int(float64(center)*float64(pitch%128)/128*0.7*float64(i%5+1))
		// simple line: set pixels along a straight line from center to (x,y)
		dx := x - center
		dy := y - center
		steps := max(abs(dx), abs(dy))
		for s := 0; s <= steps; s++ {
			px := center + dx*s/steps
			py := center + dy*s/steps
			if px >= 0 && px < size && py >= 0 && py < size {
				img.SetColorIndex(px, py, uint8(col.R%256))
			}
		}
		// mirror
		mx := size - x
		my := size - y
		dx = mx - center
		dy = my - center
		steps = max(abs(dx), abs(dy))
		for s := 0; s <= steps; s++ {
			px := center + dx*s/steps
			py := center + dy*s/steps
			if px >= 0 && px < size && py >= 0 && py < size {
				img.SetColorIndex(px, py, uint8(col.G%256))
			}
		}
	}
	return img
}

// Simple palette (256 grayscale)
func palette() []color.Color {
	p := make([]color.Color, 256)
	for i := 0; i < 256; i++ {
		p[i] = color.RGBA{uint8(i), uint8(i), uint8(i), 255}
	}
	return p
}

func abs(x int) int {
	if x < 0 {
		return -x
	}
	return x
}
func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}

// Assemble GIF with comment extension containing a Lua script.
func makeGIF(events []midiEvent, midiData []byte) ([]byte, error) {
	out := &bytes.Buffer{}
	g := gif.GIF{}
	// default delay (in 1/100th sec)
	const baseDelay = 5

	for _, ev := range events {
		frame := makeFrame(ev.Pitch, ev.Velocity)
		g.Image = append(g.Image, frame)
		// simplistic timing: delta scaled to baseDelay
		delay := baseDelay + int(ev.Delta/120) // arbitrary scaling
		if delay < 1 {
			delay = 1
		}
		g.Delay = append(g.Delay, delay)
	}
	// Lua script to reconstruct MIDI from Base64 stored in a comment.
	lua := "local b=require('mime').unb64;local f=io.open('reconstructed.mid','wb');f:write(b[[%s]]);f:close()"
	encoded := base64.StdEncoding.EncodeToString(midiData)
	script := fmt.Sprintf(lua, encoded)

	// Append GIF comment extension.
	// Extension introducer 0x21, comment label 0xFE.
	// Split script into sub‑blocks of max 255 bytes.
	commentData := []byte(script)
	var commentBlock bytes.Buffer
	commentBlock.WriteByte(0x21) // extension introducer
	commentBlock.WriteByte(0xFE) // comment label
	for len(commentData) > 0 {
		n := len(commentData)
		if n > 255 {
			n = 255
		}
		commentBlock.WriteByte(byte(n))
		commentBlock.Write(commentData[:n])
		commentData = commentData[n:]
	}
	commentBlock.WriteByte(0x00) // block terminator

	// Encode GIF header+image data.
	if err := gif.EncodeAll(out, &g); err != nil {
		return nil, err
	}
	// Insert comment block just before trailer (0x3B).
	data := out.Bytes()
	idx := bytes.LastIndexByte(data, 0x3B)
	if idx == -1 {
		return nil, fmt.Errorf("invalid GIF")
	}
	final := append([]byte{}, data[:idx]...)
	final = append(final, commentBlock.Bytes()...)
	final = append(final, data[idx:]...)
	return final, nil
}

func main() {
	if len(os.Args) < 2 {
		log.Fatalf("usage: %s <midifile>", os.Args[0])
	}
	midiPath := os.Args[1]
	midiData, err := os.ReadFile(midiPath)
	if err != nil {
		log.Fatal(err)
	}
	events, err := parseMIDI(midiData)
	if err != nil {
		log.Fatal(err)
	}
	if len(events) == 0 {
		log.Fatal("no note on events found")
	}
	gifData, err := makeGIF(events, midiData)
	if err != nil {
		log.Fatal(err)
	}
	// output GIF to file next to input
	outPath := midiPath + ".gif"
	if err := os.WriteFile(outPath, gifData, 0644); err != nil {
		log.Fatal(err)
	}
	// simple progress indicator
	log.Printf("generated %s with %d frames", outPath, len(events))
}