package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"go/ast"
	"go/format"
	"go/parser"
	"go/token"
	"io"
	"log"
	"net/http"
	"os"
	"os/exec"
	"strings"
	"time"
)

// Comment represents an incoming public blog comment.
type Comment struct {
	ID   string `json:"id"`
	Body string `json:"body"`
}

// Sentiment classifies how a comment warps control flow.
type Sentiment int

const (
	Neutral Sentiment = iota
	Positive
	Negative
)

const (
	sourceFile   = "main.go"
	seenFile     = ".seen_comments.json"
	defaultFeed  = "[https://jsonplaceholder.typicode.com/comments?_limit=5](https://jsonplaceholder.typicode.com/comments?_limit=5)"
	pollInterval = 15 * time.Second
)

// scoreSentiment uses a lightweight lexicon to gauge comment mood.
func scoreSentiment(text string) Sentiment {
	lower := strings.ToLower(text)
	posWords := []string{"love", "great", "awesome", "brilliant", "nice", "good", "helpful", "yes"}
	negWords := []string{"hate", "bad", "terrible", "wrong", "awful", "stupid", "boring", "no"}

	score := 0
	for _, w := range posWords {
		if strings.Contains(lower, w) {
			score++
		}
	}
	for _, w := range negWords {
		if strings.Contains(lower, w) {
			score--
		}
	}
	if score > 0 {
		return Positive
	}
	if score < 0 {
		return Negative
	}
	return Neutral
}

// loadSeen reads previously processed comment IDs from disk.
func loadSeen() map[string]bool {
	seen := make(map[string]bool)
	data, err := os.ReadFile(seenFile)
	if err != nil {
		return seen
	}
	_ = json.Unmarshal(data, &seen)
	return seen
}

// saveSeen persists processed comment IDs to disk.
func saveSeen(seen map[string]bool) {
	data, err := json.MarshalIndent(seen, "", "  ")
	if err == nil {
		_ = os.WriteFile(seenFile, data, 0644)
	}
}

// fetchComments pulls comments from a public JSON endpoint.
func fetchComments(feedURL string) ([]Comment, error) {
	client := &http.Client{Timeout: 8 * time.Second}
	resp, err := client.Get(feedURL)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("unexpected status %d", resp.StatusCode)
	}
	raw, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	// Support array of objects with id & body (or text/comment fields).
	var items []map[string]any
	if err := json.Unmarshal(raw, &items); err != nil {
		return nil, err
	}
	out := make([]Comment, 0, len(items))
	for i, item := range items {
		id := fmt.Sprint(item["id"])
		if id == "" || id == "<nil>" {
			id = fmt.Sprintf("idx-%d", i)
		}
		body := ""
		for _, key := range []string{"body", "text", "comment", "content"} {
			if v, ok := item[key].(string); ok && v != "" {
				body = v
				break
			}
		}
		out = append(out, Comment{ID: id, Body: body})
	}
	return out, nil
}

// mutateSource bends the AST of sourceFile based on a comment's sentiment.
func mutateSource(comment Comment, s Sentiment) error {
	fset := token.NewFileSet()
	node, err := parser.ParseFile(fset, sourceFile, nil, parser.ParseComments)
	if err != nil {
		return err
	}

	// Find baroqueRitual function and twist its body with absurd control flow.
	for _, decl := range node.Decls {
		fn, ok := decl.(*ast.FuncDecl)
		if !ok || fn.Name.Name != "baroqueRitual" || fn.Body == nil {
			continue
		}

		// Unique counter derived from comment ID length and existing statement count.
		tag := fmt.Sprintf("spiral_%d_%d", len(fn.Body.List), len(comment.ID))

		var wrapped ast.Stmt
		switch s {
		case Positive:
			// Positive sentiment inflates a celebratory nested loop + switch.
			wrapped = &ast.ForStmt{
				Init: &ast.AssignStmt{
					Lhs: []ast.Expr{ast.NewIdent("joy")},
					Tok: token.DEFINE,
					Rhs: []ast.Expr{&ast.BasicLit{Kind: token.INT, Value: "0"}},
				},
				Cond: &ast.BinaryExpr{
					X:  ast.NewIdent("joy"),
					Op: token.LSS,
					Y:  &ast.BasicLit{Kind: token.INT, Value: "2"},
				},
				Post: &ast.IncDecStmt{
					X:   ast.NewIdent("joy"),
					Tok: token.INC,
				},
				Body: &ast.BlockStmt{
					List: []ast.Stmt{
						&ast.SwitchStmt{
							Tag: ast.NewIdent("joy"),
							Body: &ast.BlockStmt{
								List: []ast.Stmt{
									&ast.CaseClause{
										List: []ast.Expr{&ast.BasicLit{Kind: token.INT, Value: "0"}},
										Body: []ast.Stmt{
											&ast.ExprStmt{
												X: &ast.CallExpr{
													Fun: ast.NewIdent("println"),
													Args: []ast.Expr{
														&ast.BasicLit{Kind: token.STRING, Value: fmt.Sprintf(`"☀️  [%s] ascending loop: %s"`, tag, escapeGoString(comment.ID))},
													},
												},
											},
										},
									},
									&ast.CaseClause{
										Body: []ast.Stmt{
											&ast.BranchStmt{Tok: token.FALLTHROUGH},
										},
									},
									&ast.CaseClause{
										Body: []ast.Stmt{
											&ast.ExprStmt{
												X: &ast.CallExpr{
													Fun: ast.NewIdent("println"),
													Args: []ast.Expr{
														&ast.BasicLit{Kind: token.STRING, Value: fmt.Sprintf(`"✨ [%s] radiant cascade"`, tag)},
													},
												},
											},
										},
									},
								},
							},
						},
					},
				},
			}

		case Negative:
			// Negative sentiment knots control flow with a labeled goto detour.
			detourLabel := "detour_" + tag
			afterLabel := "reconcile_" + tag
			wrapped = &ast.BlockStmt{
				List: []ast.Stmt{
					&ast.BranchStmt{Tok: token.GOTO, Label: ast.NewIdent(detourLabel)},
					&ast.LabeledStmt{
						Label: ast.NewIdent(afterLabel),
						Stmt: &ast.ExprStmt{
							X: &ast.CallExpr{
								Fun: ast.NewIdent("println"),
								Args: []ast.Expr{
									&ast.BasicLit{Kind: token.STRING, Value: fmt.Sprintf(`"🌩️  [%s] emerged from spiteful detour"`, tag)},
								},
							},
						},
					},
					&ast.BranchStmt{Tok: token.GOTO, Label: ast.NewIdent("end_" + tag)},
					&ast.LabeledStmt{
						Label: ast.NewIdent(detourLabel),
						Stmt: &ast.IfStmt{
							Cond: &ast.BinaryExpr{
								X:  &ast.BasicLit{Kind: token.INT, Value: "1"},
								Op: token.EQL,
								Y:  &ast.BasicLit{Kind: token.INT, Value: "1"},
							},
							Body: &ast.BlockStmt{
								List: []ast.Stmt{
									&ast.ExprStmt{
										X: &ast.CallExpr{
											Fun: ast.NewIdent("println"),
											Args: []ast.Expr{
												&ast.BasicLit{Kind: token.STRING, Value: fmt.Sprintf(`"⚡ [%s] contrarian jump on comment %s"`, tag, escapeGoString(comment.ID))},
											},
										},
									},
									&ast.BranchStmt{Tok: token.GOTO, Label: ast.NewIdent(afterLabel)},
								},
							},
						},
					},
					&ast.LabeledStmt{
						Label: ast.NewIdent("end_" + tag),
						Stmt:  &ast.EmptyStmt{Semicolon: token.NoPos},
					},
				},
			}

		default:
			// Neutral sentiment adds an enigmatic self-referential condition.
			wrapped = &ast.IfStmt{
				Init: &ast.AssignStmt{
					Lhs: []ast.Expr{ast.NewIdent("riddle")},
					Tok: token.DEFINE,
					Rhs: []ast.Expr{
						&ast.BinaryExpr{
							X:  &ast.BasicLit{Kind: token.INT, Value: fmt.Sprintf("%d", len(comment.Body)+1)},
							Op: token.REM,
							Y:  &ast.BasicLit{Kind: token.INT, Value: "2"},
						},
					},
				},
				Cond: &ast.BinaryExpr{
					X:  ast.NewIdent("riddle"),
					Op: token.EQL,
					Y:  &ast.BasicLit{Kind: token.INT, Value: "0"},
				},
				Body: &ast.BlockStmt{
					List: []ast.Stmt{
						&ast.ExprStmt{
							X: &ast.CallExpr{
								Fun: ast.NewIdent("println"),
								Args: []ast.Expr{
									&ast.BasicLit{Kind: token.STRING, Value: fmt.Sprintf(`"🌫️  [%s] even-length riddle on comment %s"`, tag, escapeGoString(comment.ID))},
								},
							},
						},
					},
				},
				Else: &ast.BlockStmt{
					List: []ast.Stmt{
						&ast.ExprStmt{
							X: &ast.CallExpr{
								Fun: ast.NewIdent("println"),
								Args: []ast.Expr{
									&ast.BasicLit{Kind: token.STRING, Value: fmt.Sprintf(`"🌀 [%s] odd-length riddle on comment %s"`, tag, escapeGoString(comment.ID))},
								},
							},
						},
					},
				},
			}
		}

		fn.Body.List = append(fn.Body.List, wrapped)
	}

	var buf bytes.Buffer
	if err := format.Node(&buf, fset, node); err != nil {
		return err
	}
	if err := os.WriteFile(sourceFile, buf.Bytes(), 0644); err != nil {
		return err
	}

	// Recompile in-place if running from source directory.
	if _, err := os.Stat(sourceFile); err == nil {
		cmd := exec.Command("go", "build", "-o", "mutating_blog_flow", sourceFile)
		_ = cmd.Run()
	}
	return nil
}

func escapeGoString(s string) string {
	s = strings.ReplaceAll(s, `\`, `\\`)
	s = strings.ReplaceAll(s, `"`, `\"`)
	return s
}

// baroqueRitual is the living control-flow sculpture mutated by stranger comments.
func baroqueRitual() {
	println("🏛️  Entering baroque control flow...")
}

func main() {
	feedURL := os.Getenv("COMMENTS_URL")
	if feedURL == "" {
		feedURL = defaultFeed
	}

	seen := loadSeen()
	log.Printf("Watching public comments at %s (every %s)", feedURL, pollInterval)

	for {
		baroqueRitual()

		comments, err := fetchComments(feedURL)
		if err != nil {
			log.Printf("Poll error: %v", err)
		} else {
			mutated := false
			for _, c := range comments {
				if seen[c.ID] {
					continue
				}
				seen[c.ID] = true
				s := scoreSentiment(c.Body)
				log.Printf("New comment [%s] (sentiment=%d): mutating %s", c.ID, s, sourceFile)
				if err := mutateSource(c, s); err != nil {
					log.Printf("Mutation failed: %v", err)
				} else {
					mutated = true
				}
			}
			if mutated {
				saveSeen(seen)
			}
		}

		time.Sleep(pollInterval)
	}
}