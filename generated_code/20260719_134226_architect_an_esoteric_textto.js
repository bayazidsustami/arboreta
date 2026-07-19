// Esoteric Text-to-Music Engine: Transpiles an AST into a Generative Gregorian Chant
// Syntactic errors produce dissonant clusters; successful compilation resolves to an Amen cadence.

class EsotericChantEngine {
    constructor() {
        // Initialize Web Audio API if available (browser environment)
        this.AudioContext = window.AudioContext || window.webkitAudioContext;
        this.ctx = this.AudioContext ? new this.AudioContext() : null;
        
        // Dorian Mode Scale Degrees (D Gregorian Chant fundamental)
        this.scale = [146.83, 164.81, 174.61, 196.00, 220.00, 246.94, 261.63, 293.66]; // D3 to D4
        this.drone = 73.42; // D2 Drone
    }

    // Micro-lexer and parser to generate a basic AST from code
    parse(code) {
        const tokens = [];
        const regex = /\s*(=>|{|}|\(|\)|;|[a-zA-Z_]\w*|[0-9]+)\s*/g;
        let match;
        let lastIndex = 0;

        while ((match = regex.exec(code)) !== null) {
            if (match.index !== lastIndex) {
                throw new SyntaxError(`Unexpected token near character ${lastIndex}`);
            }
            tokens.push(match[1]);
            lastIndex = regex.lastIndex;
        }
        if (lastIndex < code.length && /\S/.test(code.slice(lastIndex))) {
            throw new SyntaxError(`Lexical error at end of input`);
        }

        // Recursive descent parsing into a simple AST
        let tokenIdx = 0;
        const parseBlock = () => {
            const node = { type: 'Block', body: [] };
            while (tokenIdx < tokens.length && tokens[tokenIdx] !== '}') {
                node.body.push(parseStatement());
            }
            return node;
        };

        const parseStatement = () => {
            const token = tokens[tokenIdx++];
            if (!token) throw new SyntaxError("Unexpected end of file");

            if (token === '{') {
                const block = parseBlock();
                if (tokens[tokenIdx++] !== '}') throw new SyntaxError("Expected closing brace '}'");
                return block;
            }
            if (tokens[tokenIdx] === '=>') {
                tokenIdx++; // consume '=>'
                const body = parseStatement();
                return { type: 'ArrowFunction', id: token, body };
            }
            if (tokens[tokenIdx] === ';') {
                tokenIdx++; // consume ';'
                return { type: 'Identifier', name: token };
            }
            return { type: 'Expression', value: token };
        };

        const ast = parseBlock();
        if (tokenIdx < tokens.length) throw new SyntaxError("Extraneous tokens after parsing");
        return ast;
    }

    // Synthesis helper creating a vocalistic, organic organum timbre
    createVoice(freq, type = 'triangle', detune = 0) {
        if (!this.ctx) return null;
        
        const osc = this.ctx.createOscillator();
        const gain = this.ctx.createGain();
        const filter = this.ctx.createBiquadFilter();

        osc.type = type;
        osc.frequency.value = freq;
        osc.detune.value = detune;

        // Formant filtering to simulate Gregorian vocalization
        filter.type = 'lowpass';
        filter.frequency.value = freq * 3;
        filter.Q.value = 4;

        osc.connect(filter);
        filter.connect(gain);
        gain.connect(this.ctx.destination);

        return { osc, gain };
    }

    // Schedule a sound event with smooth envelope structures
    playTone(freq, start, duration, type = 'triangle', detune = 0, volume = 0.15) {
        const voice = this.createVoice(freq, type, detune);
        if (!voice) return;

        voice.osc.start(start);
        
        // Gentle vocal-like attack and decay curves
        voice.gain.gain.setValueAtTime(0, start);
        voice.gain.gain.linearRampToValueAtTime(volume, start + 0.2);
        voice.gain.gain.setValueAtTime(volume, start + duration - 0.3);
        voice.gain.gain.exponentialRampToValueAtTime(0.0001, start + duration);

        voice.osc.stop(start + duration);
    }

    // Execute compilation and map the result to the auditory engine
    transpile(code) {
        console.log(`%c[Transpiling Source Code...]`, "color: #3498db; font-weight: bold;");
        
        if (this.ctx && this.ctx.state === 'suspended') {
            this.ctx.resume();
        }

        const now = this.ctx ? this.ctx.currentTime : 0;

        try {
            const ast = this.parse(code);
            console.log("%c[Compilation Successful] Generative Organum Initiated.", "color: #2ecc71; font-weight: bold;");
            
            // Map the AST topology to standard monophonic/polyphonic modal phrases
            const timeline = [];
            const traverse = (node) => {
                timeline.push(node.type);
                if (node.body && Array.isArray(node.body)) node.body.forEach(traverse);
                if (node.body && !Array.isArray(node.body)) traverse(node.body);
            };
            traverse(ast);

            let timeCursor = now + 0.5;

            // Generate parallel organum drone base
            this.playTone(this.drone, timeCursor, timeline.length * 0.8 + 3.0, 'sawtooth', 0, 0.03);
            this.playTone(this.drone * 1.5, timeCursor, timeline.length * 0.8 + 3.0, 'triangle', 5, 0.04);

            // Generate melodic structures from syntax mapping
            timeline.forEach((nodeType, index) => {
                const scaleIndex = Math.abs(nodeType.split('').reduce((acc, char) => acc + char.charCodeAt(0), 0)) % this.scale.length;
                const pitch = this.scale[scaleIndex];
                
                // Primary vox
                this.playTone(pitch, timeCursor, 0.9, 'triangle', -5, 0.12);
                // Parallel perfect fifth voice (Gregorian Organum)
                this.playTone(pitch * 1.5, timeCursor, 0.9, 'sine', 5, 0.06);
                
                timeCursor += 0.7;
            });

            // The Algorithmic Amen Cadence Resolution (Plagal Cadence: IV -> I)
            const amenStart = timeCursor + 0.4;
            const chordDuration = 1.8;

            // Subdominant (IV - G Chord structure in context)
            this.playTone(196.00, amenStart, chordDuration, 'triangle', 0, 0.15); // G3
            this.playTone(246.94, amenStart, chordDuration, 'sine', -4, 0.08);    // B3
            this.playTone(293.66, amenStart, chordDuration, 'triangle', 4, 0.08); // D4

            // Tonic Resolution (I - D minor triad root chord)
            this.playTone(147.14, amenStart + chordDuration - 0.2, chordDuration + 1, 'triangle', 0, 0.18); // D3
            this.playTone(174.61, amenStart + chordDuration - 0.2, chordDuration + 1, 'sine', -3, 0.09);    // F3
            this.playTone(220.00, amenStart + chordDuration - 0.2, chordDuration + 1, 'triangle', 3, 0.09); // A3

        } catch (error) {
            console.error(`%c[Compilation Error] Syntactic Malfunction Detected: ${error.message}`, "color: #e74c3c; font-weight: bold;");
            
            // Generate a sudden, harsh, dissonant minor/diminished cluster
            const errorTime = now + 0.1;
            const dissonanceCluster = [110.00, 116.54, 138.59, 155.56, 164.81]; // Root, m2, tritone clusters
            
            dissonanceCluster.forEach(freq => {
                this.playTone(freq, errorTime, 2.5, 'sawtooth', 15, 0.2);
            });
        }
    }
}

// Automatically instantiate and bind to structural test paradigms
const engine = new EsotericChantEngine();

// To run this engine live in-browser, execute the code context via a user gesture event:
// document.body.addEventListener('click', () => {
    
    // Sample 1: Perfect Syntactic Blueprint (Triggers Sacred Amen)
    const validCode = "{ setup => { init; } loop => { process; } }";
    engine.transpile(validCode);

    // Sample 2: Broken Syntactic Structure (Triggers Severe Dissonance)
    // setTimeout(() => {
    //     const invalidCode = "{ setup => { init;  loop => process; }";
    //     engine.transpile(invalidCode);
    // }, 6000);

// });