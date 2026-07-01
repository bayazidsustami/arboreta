package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"os"

	"github.com/go-midi/midi"
	"github.com/go-midi/midi/smf"
)

type Note struct {
	Tick     uint64  `json:"t"` // position in ticks
	Pitch    uint8   `json:"p"` // MIDI note number
	Velocity uint8   `json:"v"` // 0-127
	Duration uint64  `json:"d"` // length in ticks
}

// extract notes from a SMF file (type 0/1)
func extractNotes(r *smf.Reader) ([]Note, uint64) {
	var notes []Note
	var ppq uint64 = 480 // default, will be overwritten
	for {
		track, err := r.Next()
		if err != nil {
			break
		}
		if track.Header.DeltaFormat != 0 && track.Header.DeltaFormat != 1 {
			continue
		}
		if ppq == 0 {
			ppq = uint64(track.Header.TimeDivision)
		}
		absTick := uint64(0)
		// map of pending note‑on events to compute duration
		pending := make(map[uint8]uint64)
		for _, ev := range track.Events {
			absTick += uint64(ev.Delta)
			switch msg := ev.Message.(type) {
			case *smf.NoteOn:
				if msg.Velocity > 0 {
					pending[msg.Key] = absTick
				} else {
					if start, ok := pending[msg.Key]; ok {
						notes = append(notes, Note{
							Tick:     start,
							Pitch:    msg.Key,
							Velocity: msg.Velocity,
							Duration: absTick - start,
						})
						delete(pending, msg.Key)
					}
				}
			case *smf.NoteOff:
				if start, ok := pending[msg.Key]; ok {
					notes = append(notes, Note{
						Tick:     start,
						Pitch:    msg.Key,
						Velocity: 0,
						Duration: absTick - start,
					})
					delete(pending, msg.Key)
				}
			}
		}
	}
	return notes, ppq
}

// generate a tiny HTML/JS app embedding the note data
func makeHTML(notes []Note, ppq uint64) string {
	notesJSON, _ := json.Marshal(notes)
	return fmt.Sprintf(`<!DOCTYPE html>
<html lang="en"><head><meta charset="UTF-8"><title>MIDI‑CA Kaleidoscope</title>
<style>body{margin:0;overflow:hidden;background:#000}</style></head>
<body><canvas id="c"></canvas>
<script>
const notes = %s;
const ppq = %d;
const canvas = document.getElementById('c');
const ctx = canvas.getContext('2d');
let W, H, cells, next;
function init(){
    W = canvas.width = window.innerWidth;
    H = canvas.height = window.innerHeight;
    const cols = Math.floor(W/4), rows = Math.floor(H/4);
    cells = new Uint8Array(cols*rows);
    next  = new Uint8Array(cols*rows);
    // random seed
    for(let i=0;i<cells.length;i++) cells[i]=Math.random()>0.5?1:0;
}
function getNoteAt(tick){
    // simple linear search – enough for demo
    for(let n of notes){
        if(tick>=n.t && tick< n.t+n.d) return n;
    }
    return null;
}
function step(time){
    const tick = Math.floor(time/ (1000/60) * (ppq/480)); // rough sync
    const n = getNoteAt(tick);
    const pitch = n? n.p : 60;
    const vel   = n? n.v : 64;
    const density = notes.filter(x=> Math.abs(x.t-tick)<ppq).length;
    const cols = Math.floor(W/4), rows = Math.floor(H/4);
    for(let y=0;y<rows;y++){
        for(let x=0;x<cols;x++){
            const i = y*cols+x;
            let sum=0;
            // Moore neighbourhood
            for(let dy=-1;dy<=1;dy++){
                for(let dx=-1;dx<=1;dx++){
                    if(dx===0 && dy===0) continue;
                    const nx = (x+dx+cols)%cols;
                    const ny = (y+dy+rows)%rows;
                    sum += cells[ny*cols+nx];
                }
            }
            // music‑driven rule
            const rule = (sum + (pitch%8) + Math.floor(vel/32) + density)%2;
            next[i]= rule;
        }
    }
    // swap buffers
    [cells,next]=[next,cells];
    // render
    const img = ctx.createImageData(cols,rows);
    for(let i=0;i<cells.length;i++){
        const v = cells[i];
        const hue = (pitch*4+ i)%360;
        const sat = 80+v*20;
        const lgt = 30+v*40;
        const a = 0.4+v*0.6;
        const col = hsl2rgb(hue,sat,lgt);
        img.data[i*4+0]=col[0];
        img.data[i*4+1]=col[1];
        img.data[i*4+2]=col[2];
        img.data[i*4+3]=a*255;
    }
    // draw scaled
    ctx.putImageData(img,0,0);
    ctx.imageSmoothingEnabled=false;
    ctx.drawImage(canvas,0,0,W,H);
    requestAnimationFrame(step);
}
function hsl2rgb(h,s,l){
    s/=100; l/=100;
    const k=n=> (n+h/30)%12;
    const a = s*Math.min(l,1-l);
    const f=n=> l - a*Math.max(-1,Math.min(k(n)-3,Math.min(9-k(n),1)));
    return [Math.round(255*f(0)),Math.round(255*f(8)),Math.round(255*f(4))];
}
window.addEventListener('resize',init);
init();
requestAnimationFrame(step);
</script></body></html>`, notesJSON, ppq)
}

func main() {
	flag.Usage = func() {
		fmt.Fprintf(flag.CommandLine.Output(), "Usage: %s <midi-file>\n", os.Args[0])
	}
	flag.Parse()
	if flag.NArg() != 1 {
		flag.Usage()
		os.Exit(1)
	}
	data, err := ioutil.ReadFile(flag.Arg(0))
	if err != nil {
		log.Fatal(err)
	}
	reader, err := smf.NewReader(data)
	if err != nil {
		log.Fatal(err)
	}
	notes, ppq := extractNotes(reader)
	html := makeHTML(notes, ppq)
	if err := ioutil.WriteFile("out.html", []byte(html), 0644); err != nil {
		log.Fatal(err)
	}
	fmt.Println("Generated out.html – open it in a browser.")
}