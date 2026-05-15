package main

import (
	"fmt"
	"math/rand"
	"strings"
	"time"
	"unicode"
)

type ChordType int

const (
	Major7 ChordType = iota
	Minor7
	Dominant7
	Diminished7
	HalfDiminished
	MinorMajor7
	Aug7
	Sus4
	Major6
)

type Syllable struct {
	Text       string
	Stressed   bool
	VowelLong  bool
	IsBreak    bool
}

type Chord struct {
	Root       string
	Type       ChordType
	Duration   float64
	SyllableRef string
}

type JazzProgression struct {
	Chords    []Chord
	Tempo     int
	TimeSig   string
}

var chordSymbols = map[ChordType]string{
	Major7:        "maj7",
	Minor7:        "m7",
	Dominant7:     "7",
	Diminished7:   "dim7",
	HalfDiminished: "m7b5",
	MinorMajor7:   "mMaj7",
	Aug7:          "aug7",
	Sus4:          "sus4",
	Major6:        "6",
}

var noteCycle = []string{"C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"}

var longVowels = map[rune]bool{'a': true, 'e': true, 'i': true, 'o': true, 'u': true, 'y': true}
var vowelSeqs = []string{"aa", "ee", "ii", "oo", "uu", "ai", "ea", "ou", "ow", "ay", "ey", "oy"}

func isVowel(r rune) bool {
	return longVowels[r]
}

func hasLongVowel(syll string string) bool {
	lower := strings.ToLower(syll)
	for _, vs := range vowelSeqs {
		if strings.Contains(lower, vs) {
			return true
		}
	}
	vowelCount := 0
	for _, ch := range lower {
		if isVowel(ch) {
			vowelCount++
		}
	}
	return vowelCount >= 2
}

func countSyllables(word string) int {
	word = strings.ToLower(word)
	if len(word) == 0 {
		return 0
	}
	count := 0
	prevVowel := false
	for _, ch := range word {
		vowel := isVowel(ch)
		if vowel && !prevVowel {
			count++
		}
		prevVowel = vowel
	}
	if strings.HasSuffix(word, "e") && count > 1 {
		count--
	}
	if count == 0 {
		count = 1
	}
	return count
}

func determineStress(syllIdx int, totalSyls int, wordStartIdx int, wordLen int) bool {
	if wordLen == 1 {
		return true
	}
	if syllIdx == 0 && totalSyls > 1 {
		return false
	}
	if syllIdx == totalSyls-1 && totalSyls > 1 {
		return true
	}
	return (syllIdx+wordStartIdx)%2 == 0
}

func parsePoem(text string) []Syllable {
	words := strings.Fields(text)
	syllables := []Syllable{}
	globalIdx := 0
	
	for wi, word := range words {
		cleanWord := strings.TrimFunc(word, func(r rune) bool {
			return !unicode.IsLetter(r)
		})
		if len(cleanWord) == 0 {
			continue
		}
		
		sylCount := countSyllables(cleanWord)
		wordSylls := splitIntoSyllables(cleanWord, sylCount)
		
		for si, syl := range wordSylls {
			stressed := determineStress(si, len(wordSylls), globalIdx, len(wordSylls))
			longVowel := hasLongVowel(syl)
			
			syllables = append(syllables, Syllable{
				Text:      syl,
				Stressed:  stressed,
				VowelLong: longVowel,
			})
			globalIdx++
		}
		
		if wi < len(words)-1 {
			syllables = append(syllables, Syllable{Text: " | ", IsBreak: true})
		}
	}
	
	return syllables
}

func splitIntoSyllables(word string, count int) []string {
	if count == 1 {
		return []string{word}
	}
	
	vowelIndices := []int{}
	for i, ch := range strings.ToLower(word) {
		if isVowel(ch) {
			vowelIndices = append(vowelIndices, i)
		}
	}
	
	if len(vowelIndices) == 0 || count > len(vowelIndices) {
		result := []string{}
		for i := 0; i < count; i++ {
			result = append(result, fmt.Sprintf("%s%d", word, i))
		}
		return result
	}
	
	syls := []string{}
	chunkSize := len(vowelIndices) / count
	if chunkSize == 0 {
		chunkSize = 1
	}
	
	for i := 0; i < count; i++ {
		start := i * chunkSize
		end := start + chunkSize
		if i == count-1 {
			end = len(vowelIndices)
		}
		
		charStart := 0
		charEnd := len(word)
		if start < len(vowelIndices) {
			charStart = vowelIndices[start]
		}
		if end < len(vowelIndices) {
			charEnd = vowelIndices[end]
		}
		
		s := word[charStart:charEnd]
		if len(s) == 0 {
			s = word
		}
		syls = append(syls, s)
	}
	
	return syls
}

func mapToChord(syll Syllable, rootIdx int) Chord {
	baseChord := Chord{
		Root:       noteCycle[rootIdx%12],
		Duration:   1.0,
		SyllableRef: syll.Text,
	}
	
	if syll.IsBreak {
		baseChord.Duration = 0.5
		baseChord.Type = Minor7
		return baseChord
	}
	
	switch {
	case syll.Stressed && syll.VowelLong:
		baseChord.Type = Major7
	case syll.Stressed && !syll.VowelLong:
		baseChord.Type = Dominant7
	case !syll.Stressed && syll.VowelLong:
		baseChord.Type = Minor7
	case !syll.Stressed && !syll.VowelLong:
		baseChord.Type = HalfDiminished
	default:
		baseChord.Type = Minor7
	}
	
	return baseChord
}

func generateProgression(syllables []Syllable, keyRoot int) JazzProgression {
	rand.Seed(time.Now().UnixNano())
	
	chords := []Chord{}
	rootIdx := keyRoot
	
	for i, syll := range syllables {
		if syll.IsBreak {
			chords = append(chords, Chord{
				Root:      noteCycle[(rootIdx+7)%12],
				Type:      Minor7,
				Duration: 0.5,
			})
			continue
		}
		
		interval := 0
		if i > 0 && !syllables[i-1].IsBreak {
			prevStressed := syllables[i-1].Stressed
			currStressed := syll.Stressed
			
			if currStressed && !prevStressed {
				interval = 5
			} else if !currStressed && prevStressed {
				interval = 3
			} else if currStressed && prevStressed {
				interval = 7
			} else {
				interval = 2
			}
		}
		
		rootIdx += interval
		chord := mapToChord(syll, rootIdx)
		chords = append(chords, chord)
	}
	
	return JazzProgression{
		Chords:  chords,
		Tempo:   120,
		TimeSig: "4/4",
	}
}

func (jp JazzProgression) String() string {
	var b strings.Builder
	b.WriteString("🎷 JAZZ POEM CHORD PROGRESSION 🎷\n")
	b.WriteString("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
	b.WriteString(fmt.Sprintf("Tempo: %d BPM | Time: %s\n\n", jp.Tempo, jp.TimeSig))
	
	for i, chord := range jp.Chords {
		symbol := chordSymbols[chord.Type]
		chordStr := fmt.Sprintf("%s%s", chord.Root, symbol)
		
		bar := (i / 4) + 1
		beat := (i % 4) + 1
		
		stressMark := "  "
		if !chord.SyllableRef.IsBreak && chord.SyllableRef.Stressed {
			stressMark = "◆"
		} else if chord.SyllableRef == " | " {
			stressMark = "|"
		}
		
		b.WriteString(fmt.Sprintf("Bar %d Beat %d: [%s] %-8s (duration: %.1f) \"%s\"\n", 
			bar, beat, stressMark, chordStr, chord.Duration, chord.SyllableRef))
	}
	
	b.WriteString("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
	b.WriteString("Chord Progression (simplified):\n")
	
	prevRoot := ""
	prevType := ChordType(-1)
	for _, chord := range jp.Chords {
		if chord.SyllableRef == " | " {
			b.WriteString(" | ")
			continue
		}
		symbol := chordSymbols[chord.Type]
		if chord.Root == prevRoot && chord.Type == prevType {
			continue
		}
		b.WriteString(fmt.Sprintf("%s%s ", chord.Root, symbol))
		prevRoot = chord.Root
		prevType = chord.Type
	}
	
	b.WriteString("\n")
	return b.String()
}

func main() {
	poem := `Twilight whispers through the trees
Soft and slow the evening breeze
Notes of jazz in darkness play
Dreams drift gently far away`

	fmt.Println("📜 INPUT POEM:")
	fmt.Println(poem)
	fmt.Println()
	
	syllables := parsePoem(poem)
	
	fmt.Println("🔍 SYLLABLE ANALYSIS:")
	for i, syl := range syllables {
		if syl.IsBreak {
			fmt.Printf("%d: [BREAK]\n", i)
			continue
		}
		stress := "unstressed"
		if syl.Stressed {
			stress = "STRESSED"
		}
		vowelLen := "short"
		if syl.VowelLong {
			vowelLen = "LONG"
		}
		fmt.Printf("%d: \"%s\" → %s, %s vowel\n", i, syl.Text, stress, vowelLen)
	}
	fmt.Println()
	
	keyRoot := 0
	progression := generateProgression(syllables, keyRoot)
	
	fmt.Println(progression)
	
	fmt.Println("🎵 PLAYING INSTRUCTIONS:")
	fmt.Println("• Stressed syllables (◆) land on beat 1 of their bar")
	fmt.Println("• Use swing feel (dotted eighth-sixteenth)")
	fmt.Println("• Let chords ring according to their duration")
	fmt.Println("• Breathe during the breaks (|)")
}