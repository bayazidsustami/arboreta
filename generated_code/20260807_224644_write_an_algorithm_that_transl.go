package main

import (
	"fmt"
	"strings"
)

// CommitType categorizes git commits for translating into textile features.
type CommitType int

const (
	StandardCommit CommitType = iota
	BranchSplit
	MergeConflict
)

// Commit represents a single node in a Git history graph.
type Commit struct {
	Hash     string
	Author   string
	Message  string
	Type     CommitType
	Branch   string
	Children int
}

// Colorway maps git branch identifiers to yarn colors.
var Colorways = map[string]string{
	"main":    "Crimson Red",
	"feature": "Nordic Blue",
	"bugfix":  "Mustard Yellow",
	"hotfix":  "Forest Green",
	"release": "Snow White",
}

// SweaterPattern encapsulates printable instructions for a 3D-knitted garment.
type SweaterPattern struct {
	Title     string
	Gauge     string
	ColorMap  map[string]string
	FrontBody []string
	BackBody  []string
	Sleeves   []string
}

// GenerateSweaterPattern converts commit history into row-by-row knitting instructions.
func GenerateSweaterPattern(history []Commit) SweaterPattern {
	pattern := SweaterPattern{
		Title:    "Git-Integrated 3D Seamless Pullover Pattern",
		Gauge:    "20 sts x 26 rows = 4 inches in Stockinette Stitch",
		ColorMap: make(map[string]string),
	}

	currentColor := Colorways["main"]
	pattern.ColorMap["main"] = currentColor
	totalStitches := 80 // Base stitch count for body tube in 3D circular knitting

	pattern.FrontBody = append(pattern.FrontBody, "--- BODY (Knit seamlessly in the round from Hem to Underarm) ---")
	pattern.FrontBody = append(pattern.FrontBody, fmt.Sprintf("Cast on %d stitches using Tubular Cast-On with %s.", totalStitches, currentColor))

	for i, commit := range history {
		rowNum := i + 1

		// Branch splits trigger a colorway transition in the pattern
		if commit.Type == BranchSplit {
			if color, exists := Colorways[commit.Branch]; exists {
				currentColor = color
				pattern.ColorMap[commit.Branch] = color
				pattern.FrontBody = append(pattern.FrontBody,
					fmt.Sprintf("[Row %02d - Commit %s] BRANCH SPLIT (%s): Transition yarn color to '%s'. Knit %d sts.",
						rowNum, commit.Hash[:7], commit.Branch, currentColor, totalStitches))
				continue
			}
		}

		// Merge conflicts manifest as deliberate drop-stitch mesh eyelets
		if commit.Type == MergeConflict {
			pattern.FrontBody = append(pattern.FrontBody,
				fmt.Sprintf("[Row %02d - Commit %s] MERGE CONFLICT: *K2tog, yo, DROP 1 STITCH deliberately* (lacework mesh feature), knit to end. (Stitch count: %d)",
					rowNum, commit.Hash[:7], totalStitches-1))
			totalStitches--
			continue
		}

		// Standard commits form default texture rows
		stitchPattern := "Knit all stitches (Stockinette)"
		if commit.Children > 1 {
			stitchPattern = "K2, P2 ribbing accent row (Multiple commit children)"
		}
		pattern.FrontBody = append(pattern.FrontBody,
			fmt.Sprintf("[Row %02d - Commit %s] (%s) Yarn [%s]: %s.",
				rowNum, commit.Hash[:7], commit.Branch, currentColor, stitchPattern))
	}

	// Sleeve instructions incorporating branch complexity
	pattern.Sleeves = append(pattern.Sleeves, "--- SLEEVES (Knit 2 alike in the round) ---")
	pattern.Sleeves = append(pattern.Sleeves, "Cast on 40 sts. Work 15 rows in 1x1 Ribbing.")
	pattern.Sleeves = append(pattern.Sleeves, "Increase 1 st each side every 6th row while maintaining commit sequence colors.")

	return pattern
}

// PrintRenderedSweater outputs the pattern layout and ASCII visualization.
func PrintRenderedSweater(p SweaterPattern) {
	fmt.Println(strings.Repeat("=", 70))
	fmt.Printf("   3D KNITTING PATTERN GENERATOR: %s\n", p.Title)
	fmt.Println(strings.Repeat("=", 70))
	fmt.Printf("Gauge: %s\n\n", p.Gauge)

	fmt.Println("COLORWAY PALETTE:")
	for branch, color := range p.ColorMap {
		fmt.Printf("  • Branch '%s' -> %s\n", branch, color)
	}
	fmt.Println()

	fmt.Println("PRINTABLE ROW-BY-ROW KNITTING INSTRUCTIONS:")
	for _, row := range p.FrontBody {
		fmt.Println("  ", row)
	}

	fmt.Println()
	for _, row := range p.Sleeves {
		fmt.Println("  ", row)
	}

	fmt.Println(strings.Repeat("=", 70))
	fmt.Println("3D GARMENT STRUCTURE DIAGRAM (Drop Stitches 'M' & Color Bands '|||'):")
	fmt.Println(strings.Repeat("=", 70))
	fmt.Println(`
         /===============\
        /  .---.   .---.  \
       /  /     \ /     \  \
      |  |   M   |   M   |  |     M = Merge Conflict Drop-Stitches
      |  |   |   |   |   |  |     ||| = Colorway Branch Transitions
     /====\  |   |   |  /====\
    /      \ |===|===| /      \
   /   /\   \|   |   |/   /\   \
  /   /  \   \   |   /   /  \   \
 /___/    \___\_____/___/    \___\
  |||      |||||||||||||      |||
	`)
}

func main() {
	// Simulated git commit sequence with branch splits and conflicts
	gitHistory := []Commit{
		{Hash: "a1b2c3d4", Author: "Dev", Message: "Initial commit", Type: StandardCommit, Branch: "main"},
		{Hash: "b2c3d4e5", Author: "Dev", Message: "Add core modules", Type: StandardCommit, Branch: "main"},
		{Hash: "c3d4e5f6", Author: "Dev", Message: "Create feature branch", Type: BranchSplit, Branch: "feature"},
		{Hash: "d4e5f6a1", Author: "Dev", Message: "WIP feature implementation", Type: StandardCommit, Branch: "feature"},
		{Hash: "e5f6a1b2", Author: "Dev", Message: "Attempt merge with main (conflict)", Type: MergeConflict, Branch: "feature"},
		{Hash: "f6a1b2c3", Author: "Dev", Message: "Hotfix requested on main", Type: BranchSplit, Branch: "hotfix"},
		{Hash: "a2b3c4d5", Author: "Dev", Message: "Resolve merge conflict in main", Type: MergeConflict, Branch: "main"},
		{Hash: "b3c4d5e6", Author: "Dev", Message: "Tag release v1.0", Type: BranchSplit, Branch: "release"},
	}

	pattern := GenerateSweaterPattern(gitHistory)
	PrintRenderedSweater(pattern)
}