import math
from dataclasses import dataclass, field
from typing import List, Optional


# --- 1. Physical Cassette Tape & Magnetic Polarity Flux ---

@dataclass
class TapeSegment:
    """Represents a physical micro-segment of magnetic tape on an unrolled spool."""
    position: int
    polarity: int  # +1 (North flux) or -1 (South flux)
    coercivity: float  # Resistance to demagnetization [0.1 .. 1.0]


def unroll_tape(raw_signal: str) -> List[TapeSegment]:
    """Convert a string stream into a spool of physical magnetic tape segments."""
    segments: List[TapeSegment] = []
    pol = 1
    for idx, ch in enumerate(raw_signal):
        # Certain characters induce magnetic flux flips; others preserve polarity
        flip = (ord(ch) ^ (idx * 7)) & 1 == 1
        if flip:
            pol *= -1
        coercivity = 0.25 + ((ord(ch) % 75) / 100.0)
        segments.append(TapeSegment(position=idx, polarity=pol, coercivity=coercivity))
    return segments


# --- 2. Mutating AST & Synth Arpeggio Generator ---

@dataclass
class ASTNode:
    """Mutable syntax tree node whose structure and pitch evolve with flux flips."""
    op: str
    value: int
    children: List["ASTNode"] = field(default_factory=list)
    harmonic_hz: float = 220.0

    def mutate_on_flip(self, flip_count: int, coercivity: float) -> str:
        """Mutate AST node state and emit a synth arpeggio note name + frequency."""
        scale_semitones = [0, 3, 5, 7, 10, 12, 15, 17, 19, 24]  # Minor pentatonic stack
        note_names = ["C", "Eb", "F", "G", "Bb"]

        # Mutate operator and value using polarity flip count and tape coercivity
        ops = ["ADD", "SUB", "SHL", "XOR", "ROT"]
        self.op = ops[(flip_count + int(coercivity * 10)) % len(ops)]
        delta = max(1, int(coercivity * 13))
        self.value = (self.value + delta * (1 if flip_count % 2 == 0 else -1)) % 256

        # Derive synth arpeggio pitch from mutated AST state
        step = scale_semitones[(self.value + flip_count) % len(scale_semitones)]
        octave_shift = int(coercivity * 2.5)
        midi_note = 48 + step + (octave_shift * 12)  # C3 base
        self.harmonic_hz = round(440.0 * (2.0 ** ((midi_note - 69) / 12.0)), 2)

        # Spawn or prune a child branch on higher coercivity flips
        if coercivity > 0.65 and len(self.children) < 4:
            self.children.append(ASTNode(op="LEAF", value=self.value, harmonic_hz=self.harmonic_hz))
        elif len(self.children) > 0 and flip_count % 5 == 0:
            self.children.pop(0)

        note_label = f"{note_names[step % len(note_names)]}{3 + (step // 12) + octave_shift}"
        return f"{note_label}({self.harmonic_hz}Hz:{self.op}#{self.value})"


# --- 3. Self-Rewriting Brainfuck Binary Emitter & VM ---

def emit_self_rewriting_bf(arpeggio: List[str], root: ASTNode) -> bytes:
    """
    Emit a compact Brainfuck 'binary' (UTF-8/ASCII bytecode) that mutates its own
    data/instruction cells during execution, seeded by the mutated AST and arpeggio.
    """
    seed = (root.value ^ len(arpeggio)) & 0x1F
    inc_pulse = "+" * max(1, (seed % 7) + 1)
    # Self-modifying layout:
    # Cell 0: mutable rewrite counter / self-patch value
    # Cell 1: scratch accumulator
    # Cell 2..: output buffer / live rewritten opcode cell
    bf_source = (
        f"{inc_pulse}"                  # Seed Cell 0 with initial rewrite energy
        "[->"                           # Decrement Cell 0, move to Cell 1
        ">>>+++<<<"                     # Mutate Cell 4 ("self-rewriting" target cell)
        "+.<-]"                         # Increment Cell 2, emit byte, loop back to Cell 0
        ">[-]>[-]>[-]"                  # Clear working cells after rewrite pass
        "++++++++++[>++++++++++<-]>+."  # Emit newline ('\n', ASCII 10)
    )
    return bf_source.encode("ascii")


def run_brainfuck(binary: bytes, max_steps: int = 10000) -> str:
    """Execute the emitted Brainfuck binary and allow cell 4 to rewrite cell 2."""
    code = bytearray(binary)
    tape = [0] * 64
    ptr = 0
    pc = 0
    steps = 0
    out: List[str] = []

    # Precompute matching brackets
    jumps = {}
    stack = []
    for idx, b in enumerate(code):
        if b == ord("["):
            stack.append(idx)
        elif b == ord("]"):
            start = stack.pop()
            jumps[start] = idx
            jumps[idx] = start

    while pc < len(code) and steps < max_steps:
        steps += 1
        op = chr(code[pc])
        if op == ">":
            ptr = (ptr + 1) % len(tape)
        elif op == "<":
            ptr = (ptr - 1) % len(tape)
        elif op == "+":
            tape[ptr] = (tape[ptr] + 1) & 0xFF
        elif op == "-":
            tape[ptr] = (tape[ptr] - 1) & 0xFF
        elif op == ".":
            # Self-rewriting twist: tape[4] dynamically shifts emitted byte value
            rewritten_byte = (tape[ptr] + (tape[4] & 0x0F)) & 0x7F
            if rewritten_byte < 32 and rewritten_byte != 10:
                rewritten_byte = 65 + (rewritten_byte % 26)  # Keep printable A-Z
            out.append(chr(rewritten_byte))
        elif op == "[":
            if tape[ptr] == 0:
                pc = jumps[pc]
        elif op == "]":
            if tape[ptr] != 0:
                pc = jumps[pc]
        pc += 1

    return "".join(out).strip()


def compile_cassette_tape(tape_text: str) -> dict:
    """Full compilation pipeline: unrolled tape -> AST flux mutation -> synth arpeggio -> BF binary."""
    spool = unroll_tape(tape_text)
    root = ASTNode(op="ROOT", value=1)
    arpeggio: List[str] = []
    flip_count = 0
    prev_polarity = spool[0].polarity if spool else 1

    for seg in spool:
        if seg.polarity != prev_polarity:
            flip_count += 1
            prev_polarity = seg.polarity
            arpeggio.append(root.mutate_on_flip(flip_count, seg.coercivity))

    bf_binary = emit_self_rewriting_bf(arpeggio, root)
    vm_output = run_brainfuck(bf_binary)
    return {
        "tape_length": len(spool),
        "polarity_flips": flip_count,
        "ast_branches": len(root.children),
        "synth_arpeggio": " -> ".join(arpeggio) if arpeggio else "C3(130.81Hz:ROOT#1)",
        "bf_binary": bf_binary.decode("ascii"),
        "vm_output": vm_output,
    }


if __name__ == "__main__":
    sample_spool = "TDK-SA90::HIGH-BIAS//MAGNETIC-FLUX-STREAM-1988"
    result = compile_cassette_tape(sample_spool)
    for key, val in result.items():
        print(f"{key}: {val}")