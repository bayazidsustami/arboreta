package main

import (
	"bytes"
	"encoding/binary"
	"encoding/base64"
	"flag"
	"fmt"
	"image"
	_ "image/jpeg"
	_ "image/png"
	"io"
	"io/ioutil"
	"log"
	"math"
	"os"
	"strings"
)

// simple struct to hold our bundle
type bundle struct {
	Image []byte // original PNG/JPEG bytes
	Poem  string // generated poem
	SVG   []byte // typographic SVG
}

// encode packs the bundle into a reversible binary format:
// [4-byte image length][image][4-byte poem length][poem][4-byte svg length][svg]
func encode(b *bundle) []byte {
	buf := new(bytes.Buffer)
	binary.Write(buf, binary.BigEndian, uint32(len(b.Image)))
	buf.Write(b.Image)
	binary.Write(buf, binary.BigEndian, uint32(len(b.Poem)))
	buf.WriteString(b.Poem)
	binary.Write(buf, binary.BigEndian, uint32(len(b.SVG)))
	buf.Write(b.SVG)
	return buf.Bytes()
}

// decode reverses encode.
func decode(data []byte) (*bundle, error) {
	r := bytes.NewReader(data)
	var imgLen, poemLen, svgLen uint32
	if err := binary.Read(r, binary.BigEndian, &imgLen); err != nil {
		return nil, err
	}
	img := make([]byte, imgLen)
	if _, err := io.ReadFull(r, img); err != nil {
		return nil, err
	}
	if err := binary.Read(r, binary.BigEndian, &poemLen); err != nil {
		return nil, err
	}
	poemBytes := make([]byte, poemLen)
	if _, err := io.ReadFull(r, poemBytes); err != nil {
		return nil, err
	}
	if err := binary.Read(r, binary.BigEndian, &svgLen); err != nil {
		return nil, err
	}
	svg := make([]byte, svgLen)
	if _, err := io.ReadFull(r, svg); err != nil {
		return nil, err
	}
	return &bundle{
		Image: img,
		Poem:  string(poemBytes),
		SVG:   svg,
	}, nil
}

// dominantPalette extracts up to three dominant colors using a brute‑force histogram.
func dominantPalette(img image.Image) []color {
	bounds := img.Bounds()
	hist := make(map[color]int)
	for y := bounds.Min.Y; y < bounds.Max.Y; y++ {
		for x := bounds.Min.X; x < bounds.Max.X; x++ {
			r, g, b, _ := img.At(x, y).RGBA()
			c := color{uint8(r >> 8), uint8(g >> 8), uint8(b >> 8)}
			hist[c]++
		}
	}
	// simple selection of top three
	type pair struct {
		c color
		n int
	}
	var list []pair
	for k, v := range hist {
		list = append(list, pair{k, v})
	}
	// sort descending
	for i := 0; i < len(list); i++ {
		for j := i + 1; j < len(list); j++ {
			if list[j].n > list[i].n {
				list[i], list[j] = list[j], list[i]
			}
		}
	}
	var res []color
	for i := 0; i < len(list) && i < 3; i++ {
		res = append(res, list[i].c)
	}
	return res
}

// tiny color representation
type color struct {
	r, g, b uint8
}

// poemFromPalette creates a 4‑line rhyme where each line ends with a word derived from a hue.
func poemFromPalette(p []color) string {
	words := []string{"sky", "dawn", "gleam", "shade"}
	lines := make([]string, 4)
	for i := 0; i < 4; i++ {
		h := hueFromColor(p[i%len(p)])
		adj := adjectiveFromHue(h)
		lines[i] = fmt.Sprintf("The %s %s", adj, words[i%len(words)])
	}
	// simple AABB scheme
	return strings.Join([]string{lines[0], lines[1], lines[2], lines[3]}, "\n")
}

// hue approximation
func hueFromColor(c color) float64 {
	r, g, b := float64(c.r)/255, float64(c.g)/255, float64(c.b)/255
	max := math.Max(r, math.Max(g, b))
	min := math.Min(r, math.Min(g, b))
	if max == min {
		return 0
	}
	var h float64
	switch max {
	case r:
		h = (g-b)/ (max-min)
	case g:
		h = 2 + (b-r)/(max-min)
	case b:
		h = 4 + (r-g)/(max-min)
	}
	h *= 60
	if h < 0 {
		h += 360
	}
	return h
}

// map hue to an adjective
func adjectiveFromHue(h float64) string {
	switch {
	case h < 60:
		return "brisk"
	case h < 120:
		return "soft"
	case h < 180:
		return "cool"
	case h < 240:
		return "deep"
	case h < 300:
		return "warm"
	default:
		return "bright"
	}
}

// generateSVG creates an SVG where each glyph is displaced by the average intensity of its column.
func generateSVG(poem string, img image.Image) []byte {
	lines := strings.Split(poem, "\n")
	w, h := 400, 100+len(lines)*30
	svg := fmt.Sprintf(`<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d">`, w, h)
	y := 30
	for _, line := range lines {
		shift := columnShift(line, img)
		svg += fmt.Sprintf(`<text x="%d" y="%d" font-family="serif" font-size="20" transform="translate(%f,0)">%s</text>`,
			20, y, shift, line)
		y += 30
	}
	svg += `</svg>`
	return []byte(svg)
}

// columnShift returns a small horizontal offset based on average brightness of corresponding image column.
func columnShift(txt string, img image.Image) float64 {
	bounds := img.Bounds()
	col := int(float64(bounds.Dx()) * (float64(len(txt)) / 400.0))
	if col >= bounds.Dx() {
		col = bounds.Dx() - 1
	}
	var sum int
	for y := bounds.Min.Y; y < bounds.Max.Y; y++ {
		r, g, b, _ := img.At(col, y).RGBA()
		sum += int((r + g + b) >> 8)
	}
	avg := sum / bounds.Dy()
	return (float64(avg) - 128) / 50.0 // modest shift
}

// helper to read whole file
func readAll(path string) ([]byte, error) {
	return ioutil.ReadFile(path)
}

// helper to write file
func writeAll(path string, data []byte) error {
	return ioutil.WriteFile(path, data, 0644)
}

func main() {
	encodeFlag := flag.Bool("encode", false, "encode image to bundle")
	decodeFlag := flag.Bool("decode", false, "decode bundle to files")
	in := flag.String("in", "", "input file")
	out := flag.String("out", "", "output prefix")
	flag.Parse()

	if *encodeFlag {
		if *in == "" {
			log.Fatal("input image required")
		}
		imgBytes, err := readAll(*in)
		if err != nil {
			log.Fatal(err)
		}
		img, _, err := image.Decode(bytes.NewReader(imgBytes))
		if err != nil {
			log.Fatal(err)
		}
		palette := dominantPalette(img)
		poem := poemFromPalette(palette)
		svg := generateSVG(poem, img)

		b := &bundle{Image: imgBytes, Poem: poem, SVG: svg}
		outData := encode(b)

		if *out == "" {
			os.Stdout.Write(outData)
		} else {
			if err := writeAll(*out, outData); err != nil {
				log.Fatal(err)
			}
		}
		return
	}

	if *decodeFlag {
		if *in == "" {
			log.Fatal("input bundle required")
		}
		data, err := readAll(*in)
		if err != nil {
			log.Fatal(err)
		}
		b, err := decode(data)
		if err != nil {
			log.Fatal(err)
		}
		prefix := *out
		if prefix == "" {
			prefix = "out"
		}
		if err := writeAll(prefix+"_image.png", b.Image); err != nil {
			log.Fatal(err)
		}
		if err := writeAll(prefix+"_poem.txt", []byte(b.Poem)); err != nil {
			log.Fatal(err)
		}
		if err := writeAll(prefix+"_poem.svg", b.SVG); err != nil {
			log.Fatal(err)
		}
		// also display base64 for compactness
		fmt.Println(base64.StdEncoding.EncodeToString(data))
		return
	}

	log.Fatal("specify -encode or -decode")
}