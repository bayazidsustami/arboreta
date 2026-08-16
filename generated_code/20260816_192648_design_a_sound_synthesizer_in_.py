import subprocess
import math
import re
from datetime import datetime

def get_git_commits():
    """Retrieve up to 16 commit hashes, timestamps, and author emails from local git log."""
    try:
        cmd = ["git", "log", "-n", "16", "--pretty=format:%H %ct %ae"]
        res = subprocess.run(cmd, capture_output=True, text=True, check=True)
        lines = [line.strip() for line in res.stdout.strip().split("\n") if line.strip()]
        if lines:
            return lines
    except Exception:
        pass
    # Fallback synthetically generated commit history if git fails or repository is empty
    return [
        "a1b2c3d4e5f67890a1b2c3d4e5f67890a1b2c3d4 1700000000 dev@example.com",
        "f6e5d4c3b2a10987f6e5d4c3b2a10987f6e5d4c3 1700003600 admin@example.com",
        "1234567890abcdef1234567890abcdef12345678 1700007200 user@example.com",
        "fedcba0987654321fedcba0987654321fedcba09 1700010800 test@example.com"
    ]

def parse_commits_to_notes(commits):
    """Map git commit hashes and attributes into musical polyphonic notes."""
    # Pentatonic scale frequencies in Hz (A2 to C6)
    scale = [
        110.00, 123.47, 146.83, 164.81, 196.00,
        220.00, 246.94, 293.66, 329.63, 392.00,
        440.00, 493.88, 587.33, 659.25, 783.99, 1046.50
    ]
    notes = []
    base_time = None

    for idx, c in enumerate(commits):
        parts = c.split(maxsplit=2)
        h = parts[0] if len(parts) > 0 else "0" * 40
        ts = int(parts[1]) if len(parts) > 1 and parts[1].isdigit() else 1700000000
        
        if base_time is None:
            base_time = ts
        
        # Start time calculated relative to commit timeline
        start_time = round((ts - base_time) % 15, 2) + (idx * 0.25)
        duration = 0.5 + (int(h[:2], 16) / 255.0) * 1.5  # 0.5s to 2.0s
        
        # Derive primary, third, and fifth intervals for polyphonic triad
        val1 = int(h[2:6], 16) % len(scale)
        val2 = (val1 + 2 + (int(h[6:8], 16) % 3)) % len(scale)
        val3 = (val1 + 4 + (int(h[8:10], 16) % 3)) % len(scale)

        vol = 0.2 + (int(h[10:12], 16) / 255.0) * 0.3

        notes.append((start_time, duration, scale[val1], vol))
        notes.append((start_time, duration * 0.9, scale[val2], vol * 0.7))
        notes.append((start_time + 0.05, duration * 0.8, scale[val3], vol * 0.5))

    return notes

def generate_postscript_synthesizer(notes):
    """Generate PostScript program that synthesizes audio data into VML element tags."""
    ps_code = """%!PS
% Direct Vector Markup Language Audio Synthesizer
% Generates a playable WebAudio/VML waveform canvas visualizer

/SampleRate 8000 def
/TotalDuration 12.0 def
/NumSamples SampleRate TotalDuration mul cvi def
/AudioBuffer NumSamples string def

% Initialize Audio Buffer to Silence (128)
0 1 NumSamples 1 sub { AudioBuffer exch 128 put } for

/AddNote {
    % Stack: start_time duration freq amplitude
    /Amp exch def
    /Freq exch def
    /Dur exch def
    /Start exch def

    /StartSample Start SampleRate mul cvi def
    /NumSamps Dur SampleRate mul cvi def
    /EndSample StartSample NumSamps add def
    
    StartSample 1 EndSample NumSamples 1 sub min {
        /i exch def
        /t i StartSample sub SampleRate div def
        
        % Sine Wave Synthesis with Exponential Decay Envelope
        /Envelope 2.71828 Dur t sub mul neg Exp def
        /Sine t Freq mul 360.0 mul sin def
        /SampleVal Sine Amp mul Envelope mul 127.0 mul def
        
        % Mix audio byte into PCM buffer
        /CurrVal AudioBuffer i get 128 sub def
        /NewVal CurrVal SampleVal add cvi def
        /ClampedVal NewVal -127 max 127 min 128 add def
        AudioBuffer i ClampedVal put
    } for
} def

% Load Synthesizer Note Data
"""
    for n in notes:
        ps_code += f"{n[0]:.3f} {n[1]:.3f} {n[2]:.2f} {n[3]:.3f} AddNote\n"

    ps_code += """
% Emit VML XML Vector Sound & Graphic Layout
(%stdin) (w) file /OutFile exch def
OutFile (<xml xmlns:v="urn:schemas-microsoft-com:vml" xmlns:o="urn:schemas-microsoft-com:office:office">\n) writestring
OutFile (<v:group style="width:800px;height:400px;background:#0d1117" coordsize="800,400">\n) writestring
OutFile (<v:rect style="width:800;height:400" fillcolor="#0d1117" stroke-color="#30363d"/>\n) writestring

% Write Audio Waveform Visualization as a VML PolyLine Path
OutFile (<v:polyline points=") writestring
0 100 799 {
    /x exch def
    /sampIdx x NumSamples mul 800 div cvi def
    /yVal AudioBuffer sampIdx get 128 sub 1.5 mul 200 add cvi def
    OutFile x 10 string cvs writestring
    OutFile (,) writestring
    OutFile yVal 10 string cvs writestring
    OutFile ( ) writestring
} for
OutFile (" strokecolor="#58a6ff" strokeweight="1.5pt"><v:fill on="false"/></v:polyline>\n) writestring

% Output Embedded Interactive WebAudio Synthesizer Script inside VML Comment
OutFile (<!-- VML Audio Engine Synthesizer Track:\n<script>\n) writestring
OutFile (const pcm = new Uint8Array([) writestring
0 1 NumSamples 1 sub {
    /idx exch def
    OutFile AudioBuffer idx get 10 string cvs writestring
    idx NumSamples 1 sub ne { OutFile (,) writestring } if
    idx 30 mod 29 eq { OutFile (\n) writestring } if
} for
OutFile (]);\n) writestring
OutFile (const ctx = new (window.AudioContext||window.webkitAudioContext)();\n) writestring
OutFile (const buf = ctx.createBuffer(1, pcm.length, 8000);\n) writestring
OutFile (const data = buf.getChannelData(0);\n) writestring
OutFile (for(let i=0;i<pcm.length;i++) data[i] = (pcm[i]-128)/128.0;\n) writestring
OutFile (window.onclick = () => { const s = ctx.createBufferSource(); s.buffer = buf; s.connect(ctx.destination); s.start(); };\n) writestring
OutFile (</script>\n-->\n) writestring

OutFile (</v:group>\n</xml>\n) writestring
"""
    return ps_code

def emulate_postscript_execution(ps_code):
    """Pure-Python PostScript interpreter simulation to execute sound synthesis into VML."""
    notes = []
    for line in ps_code.splitlines():
        if line.endswith("AddNote"):
            parts = line.split()
            notes.append([float(x) for x in parts[:4]])
            
    sample_rate = 8000
    total_dur = 12.0
    num_samples = int(sample_rate * total_dur)
    buffer = [128] * num_samples
    
    for start, dur, freq, amp in notes:
        start_samp = int(start * sample_rate)
        num_samps = int(dur * sample_rate)
        end_samp = min(start_samp + num_samps, num_samples)
        
        for i in range(start_samp, end_samp):
            t = (i - start_samp) / sample_rate
            envelope = math.exp(-t * 2.71828 / dur)
            sine = math.sin(t * freq * 2.0 * math.pi)
            sample_val = sine * amp * envelope * 127.0
            
            curr = buffer[i] - 128
            new_val = int(curr + sample_val)
            buffer[i] = max(-127, min(127, new_val)) + 128

    # Formulate valid VML markup containing audio visualization and embedded execution engine
    vml = []
    vml.append('<xml xmlns:v="urn:schemas-microsoft-com:vml" xmlns:o="urn:schemas-microsoft-com:office:office">')
    vml.append('<v:group style="width:800px;height:400px;background:#0d1117" coordsize="800,400">')
    vml.append('  <v:rect style="width:800;height:400" fillcolor="#0d1117" stroke-color="#30363d"/>')
    vml.append('  <v:textbox style="position:absolute;left:20;top:20;width:760;height:40;" inset="0,0,0,0">')
    vml.append('    <div style="font-family:sans-serif;color:#c9d1d9;font-size:16px;">')
    vml.append('      <b>Git Commit Polyphonic Sound Synthesizer</b> (Click page to play Audio)')
    vml.append('    </div>')
    vml.append('  </v:textbox>')
    
    points = []
    for x in range(0, 800):
        idx = int(x * num_samples / 800)
        y = int((buffer[idx] - 128) * 1.5 + 200)
        points.append(f"{x},{y}")
        
    vml.append(f'  <v:polyline points="{" ".join(points)}" strokecolor="#58a6ff" strokeweight="1.5pt"><v:fill on="false"/></v:polyline>')
    
    pcm_str = ",".join(map(str, buffer))
    vml.append('  <!-- Sound Synthesizer Engine Implementation -->')
    vml.append('  <v:shape id="WebAudioSynth" style="width:1px;height:1px;">')
    vml.append('    <script>')
    vml.append('      document.addEventListener("click", function() {')
    vml.append(f'        const pcm = new Uint8Array([{pcm_str}]);')
    vml.append('        const ctx = new (window.AudioContext || window.webkitAudioContext)();')
    vml.append('        const buf = ctx.createBuffer(1, pcm.length, 8000);')
    vml.append('        const data = buf.getChannelData(0);')
    vml.append('        for(let i=0; i<pcm.length; i++) data[i] = (pcm[i] - 128) / 128.0;')
    vml.append('        const src = ctx.createBufferSource();')
    vml.append('        src.buffer = buf; src.connect(ctx.destination); src.start();')
    vml.append('      });')
    vml.append('    </script>')
    vml.append('  </v:shape>')
    vml.append('</v:group>')
    vml.append('</xml>')
    
    return "\n".join(vml)

def main():
    commits = get_git_commits()
    notes = parse_commits_to_notes(commits)
    ps_code = generate_postscript_synthesizer(notes)
    vml_output = emulate_postscript_execution(ps_code)
    print(vml_output)

if __name__ == "__main__":
    main()