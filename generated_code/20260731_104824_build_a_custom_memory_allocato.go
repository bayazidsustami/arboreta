package main

import (
	"fmt"
	"math/bits"
	"unsafe"
)

// Target ASCII/Bitmap Art: 8x8 Heart pattern
// 0 = Free block / Zero byte
// 1 = Allocated block / Pattern byte
var heartPattern = [8][8]byte{
	{0, 1, 1, 0, 0, 1, 1, 0},
	{1, 1, 1, 1, 1, 1, 1, 1},
	{1, 1, 1, 1, 1, 1, 1, 1},
	{1, 1, 1, 1, 1, 1, 1, 1},
	{0, 1, 1, 1, 1, 1, 1, 0},
	{0, 0, 1, 1, 1, 1, 0, 0},
	{0, 0, 0, 1, 1, 0, 0, 0},
	{0, 0, 0, 0, 0, 0, 0, 0},
}

const (
	BlockSize = 8  // Each pixel pixel corresponds to 8 bytes in memory
	Rows      = 8  // 8 rows of pixels
	Cols      = 8  // 8 columns of pixels
	HeapSize  = Rows * Cols * BlockSize
	FillByte  = 0xAA // Distinct byte pattern for allocated memory (0xAA)
)

// CanvasAllocator manages a contiguous arena, deliberately fragmenting it
// to sculpt visual bitmap art directly into memory.
type CanvasAllocator struct {
	arena []byte
}

func NewCanvasAllocator() *CanvasAllocator {
	return &CanvasAllocator{
		arena: make([]byte, HeapSize),
	}
}

// Sculpt applies the bitmap pattern by allocating active blocks for '1's
// and leaving holes/zeroes for '0's.
func (a *CanvasAllocator) Sculpt(pattern [8][8]byte) {
	for row := 0; row < Rows; row++ {
		for col := 0; col < Cols; col++ {
			offset := (row*Cols + col) * BlockSize
			if pattern[row][col] == 1 {
				// Allocate and fill block
				for i := 0; i < BlockSize; i++ {
					a.arena[offset+i] = FillByte
				}
			} else {
				// Deliberately leave a fragmented empty hole (zeroed memory)
				for i := 0; i < BlockSize; i++ {
					a.arena[offset+i] = 0x00
				}
			}
		}
	}
}

// HexDump prints raw memory dump along with visually highlighted bitmap art
func (a *CanvasAllocator) HexDump() {
	ptr := uintptr(unsafe.Pointer(&a.arena[0]))
	fmt.Printf("=== Memory Heap Allocation Dump (Address: 0x%X) ===\n\n", ptr)

	for row := 0; row < Rows; row++ {
		// Print Row Memory Base Address
		rowAddr := ptr + uintptr(row*Cols*BlockSize)
		fmt.Printf("0x%08X  ", rowAddr)

		// Render hexadecimal block bytes for this row
		for col := 0; col < Cols; col++ {
			offset := (row*Cols + col) * BlockSize
			isAllocated := a.arena[offset] == FillByte

			if isAllocated {
				fmt.Printf("\033[31m%02X%02X\033[0m ", FillByte, FillByte) // Red for allocated pixels
			} else {
				fmt.Printf("\033[90m0000\033[0m ") // Dim grey for fragmented holes
			}
		}

		// Render side-by-side visual bitmap preview
		fmt.Print(" | ")
		for col := 0; col < Cols; col++ {
			offset := (row*Cols + col) * BlockSize
			if a.arena[offset] == FillByte {
				fmt.Print("\033[31m██\033[0m")
			} else {
				fmt.Print("  ")
			}
		}
		fmt.Println()
	}
	fmt.Println()
}

func main() {
	allocator := NewCanvasAllocator()

	fmt.Println("Shaping heap memory layout...")
	allocator.Sculpt(heartPattern)

	// Dump sculpted heap showing both raw byte fragments and visual art
	allocator.HexDump()

	_ = bits.OnesCount(0) // Keep standard library imports clean
}