package main

import (
	"fmt"
	"math"
	"math/rand"
	"os"
	"strings"
	"time"
)

// simple source embedding for self‑analysis
var source = `package main

import (
	"fmt"
	"math"
	"math/rand"
	"os"
	"strings"
	"time"
)

var source = ... // truncated for brevity
`

// low‑resolution spectrogram characters
var spectChars = []rune(" .:-=+*#%@")

// estimate syllables by counting vowel groups
func syllableCount(word string) int {
	count := 0
	prevVowel := false
	for _, r := range strings.ToLower(word) {
		isVowel := strings.ContainsRune("aeiouy", r)
		if isVowel && !prevVowel {
			count++
		}
		prevVowel = isVowel
	}
	if strings.HasSuffix(word, "e") && count > 1 {
		count--
	}
	if count == 0 {
		count = 1
	}
	return count
}

// pick a line with exactly target syllables
func pickLine(words []string, target int, rnd *rand.Rand) string {
	attempts := 0
	for attempts < 1000 {
		attempts++
		var line []string
		syl := 0
		for syl < target {
			w := words[rnd.Intn(len(words))]
			wsyl := syllableCount(w)
			if syl+wsyl > target {
				continue
			}
			line = append(line, w)
			syl += wsyl
		}
		if syl == target {
			return strings.Join(line, " ")
		}
	}
	return "" // fallback (should not happen)
}

// generate a haiku using homophones/anagrams word list
func generateHaiku(rnd *rand.Rand) []string {
	// small dictionary containing homophones/anagrams
	dict := []string{
		"sea", "see", "night", "knight", "right", "write",
		"flower", "flour", "rain", "reign", "read", "reed",
		"sole", "soul", "pair", "pear", "scent", "sent",
		"blew", "blue", "piece", "peace", "solemn", "so lemn",
		"tone", "tonne", "tale", "tail",
	}
	line1 := pickLine(dict, 5, rnd)
	line2 := pickLine(dict, 7, rnd)
	line3 := pickLine(dict, 5, rnd)
	return []string{line1, line2, line3}
}

// very small DFT for visualisation
func dft(samples []float64) []complex128 {
	n := len(samples)
	out := make([]complex128, n)
	for k := 0; k < n; k++ {
		var sum complex128
		for t := 0; t < n; t++ {
			angle := -2 * math.Pi * float64(k*t) / float64(n)
			sum += complex(samples[t], 0) * complex(math.Cos(angle), math.Sin(angle))
		}
		out[k] = sum
	}
	return out
}

// render spectrogram from magnitude slice
func renderSpectrogram(mags []float64) []string {
	height := 10
	width := len(mags)
	lines := make([]string, height)
	for i := 0; i < height; i++ {
		var sb strings.Builder
		threshold := float64(i) / float64(height)
		for _, m := range mags {
			if m > threshold {
				sb.WriteRune(spectChars[len(spectChars)-1])
			} else {
				sb.WriteRune(' ')
			}
		}
		lines[height-1-i] = sb.String()
	}
	return lines
}

// produce spectrogram of the embedded source code
func spectrogram() []string {
	// take first 64 bytes for simplicity
	n := 64
	if len(source) < n {
		n = len(source)
	}
	samples := make([]float64, n)
	for i := 0; i < n; i++ {
		samples[i] = float64(source[i])
	}
	freq := dft(samples)
	mags := make([]float64, n/2)
	max := 0.0
	for i := 0; i < n/2; i++ {
		mags[i] = cmplxAbs(freq[i])
		if mags[i] > max {
			max = mags[i]
		}
	}
	// normalise
	for i := range mags {
		mags[i] /= max
	}
	return renderSpectrogram(mags)
}

func cmplxAbs(c complex128) float64 {
	return math.Hypot(real(c), imag(c))
}

func main() {
	seed := time.Now().UnixNano()
	rnd := rand.New(rand.NewSource(seed))

	haiku := generateHaiku(rnd)
	fmt.Println("Procedural Haiku:")
	for _, line := range haiku {
		fmt.Println(line)
	}
	fmt.Println("\nSpectrogram of source (ASCII):")
	for _, line := range spectrogram() {
		fmt.Println(line)
	}
}