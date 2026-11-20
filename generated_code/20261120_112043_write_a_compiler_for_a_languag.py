"""A compiler and continental barometric VM for *AetherScript*, a language whose sole data type is the weather pattern."""

from __future__ import annotations

from dataclasses import dataclass, field
from enum import Enum, auto
from typing import Dict, List, Optional, Tuple


# --- 1. Core Weather Data Type ---

@dataclass(frozen=True)
class Weather:
    """Immutable barometric & meteorological state: pressure (hPa), humidity (0..1), wind (m/s)."""
    pressure: float
    humidity: float
    wind: float

    def clamped(self) -> "Weather":
        return Weather(
            pressure=max(940.0, min(1060.0, self.pressure)),
            humidity=max(0.0, min(1.0, self.humidity)),
            wind=max(0.0, min(65.0, self.wind)),
        )

    def collide(self, other: "Weather") -> Tuple["Weather", "Weather", str]:
        """Simulate two air masses colliding along a pressure gradient."""
        dp = self.pressure - other.pressure
        avg_p = (self.pressure + other.pressure) * 0.5
        avg_h = (self.humidity + other.humidity) * 0.5
        shear = abs(dp) * 0.18 + abs(self.wind - other.wind) * 0.5

        if abs(dp) < 3.0:
            # Stalled boundary: gentle mixing and light mist.
            event = "stationary front"
            a = Weather(avg_p, min(1.0, avg_h + 0.05), max(1.0, (self.wind + other.wind) * 0.5)).clamped()
            b = Weather(avg_p, min(1.0, avg_h + 0.05), max(1.0, (self.wind + other.wind) * 0.5)).clamped()
        elif dp > 0:
            # High pressure drives into low pressure: steepening gradient & squall uplift.
            event = "cold/high surge"
            condense = min(0.35, abs(dp) * 0.012 * other.humidity)
            a = Weather(self.pressure - dp * 0.25, max(0.0, self.humidity - condense * 0.5), self.wind + shear).clamped()
            b = Weather(other.pressure + dp * 0.35, max(0.0, other.humidity - condense), other.wind + shear * 1.25).clamped()
        else:
            # Low pressure pulls warm moist inflow: cyclonic deepening & rain bands.
            event = "cyclonic convergence"
            condense = min(0.40, abs(dp) * 0.015 * self.humidity)
            a = Weather(self.pressure - dp * 0.35, max(0.0, self.humidity - condense), self.wind + shear * 1.25).clamped()
            b = Weather(other.pressure + dp * 0.25, max(0.0, other.humidity - condense * 0.5), other.wind + shear).clamped()

        return a, b, event

    def classify(self) -> str:
        if self.wind >= 33.0 and self.pressure < 985.0:
            return "GALE/STORM"
        if self.pressure < 1002.0 and self.humidity >= 0.65:
            return "RAIN_FRONT"
        if self.pressure >= 1020.0 and self.humidity < 0.40:
            return "HIGH_CLEAR"
        if self.humidity >= 0.75:
            return "MIST_BANK"
        return "BREEZE"


# --- 2. Lexer ---

class TokType(Enum):
    IDENT = auto()
    NUMBER = auto()
    LPAREN = auto()
    RPAREN = auto()
    COMMA = auto()
    SEMI = auto()
    ARROW = auto()      # -> (push front toward region)
    COLLIDE = auto()    # >< (collide two weather patterns)
    MERGE = auto()      # +  (blend air masses)
    DAMPEN = auto()     # -  (shed moisture/energy)
    LET = auto()
    AT = auto()         # at <region> <expr>;
    PULSE = auto()      # pulse <steps>;
    REPORT = auto()     # report;
    EOF = auto()


@dataclass(frozen=True)
class Token:
    kind: TokType
    value: str
    line: int


KEYWORDS = {
    "let": TokType.LET,
    "at": TokType.AT,
    "pulse": TokType.PULSE,
    "report": TokType.REPORT,
}


def tokenize(source: str) -> List[Token]:
    tokens: List[Token] = []
    i, n, line = 0, len(source), 1

    while i < n:
        ch = source[i]
        if ch in " \t\r":
            i += 1
        elif ch == "\n":
            line += 1
            i += 1
        elif ch == "#" :
            while i < n and source[i] != "\n":
                i += 1
        elif source.startswith("->", i):
            tokens.append(Token(TokType.ARROW, "->", line))
            i += 2
        elif source.startswith("><", i):
            tokens.append(Token(TokType.COLLIDE, "><", line))
            i += 2
        elif ch == "(":
            tokens.append(Token(TokType.LPAREN, "(", line))
            i += 1
        elif ch == ")":
            tokens.append(Token(TokType.RPAREN, ")", line))
            i += 1
        elif ch == ",":
            tokens.append(Token(TokType.COMMA, ",", line))
            i += 1
        elif ch == ";":
            tokens.append(Token(TokType.SEMI, ";", line))
            i += 1
        elif ch == "+":
            tokens.append(Token(TokType.MERGE, "+", line))
            i += 1
        elif ch == "-":
            tokens.append(Token(TokType.DAMPEN, "-", line))
            i += 1
        elif ch.isdigit() or (ch == "." and i + 1 < n and source[i + 1].isdigit()):
            start = i
            while i < n and (source[i].isdigit() or source[i] == "."):
                i += 1
            tokens.append(Token(TokType.NUMBER, source[start:i], line))
        elif ch.isalpha() or ch == "_":
            start = i
            while i < n and (source[i].isalnum() or source[i] in "_"):
                i += 1
            word = source[start:i]
            tokens.append(Token(KEYWORDS.get(word, TokType.IDENT), word, line))
        else:
            raise SyntaxError(f"Unexpected character {ch!r} at line {line}")

    tokens.append(Token(TokType.EOF, "", line))
    return tokens


# --- 3. AST & Parser ---

class Expr:
    pass


@dataclass
class WeatherLit(Expr):
    pressure: float
    humidity: float
    wind: float


@dataclass
class VarRef(Expr):
    name: str


@dataclass
class BinOp(Expr):
    op: str
    left: Expr
    right: Expr


class Stmt:
    pass


@dataclass
class LetStmt(Stmt):
    name: str
    expr: Expr


@dataclass
class AtStmt(Stmt):
    region: str
    expr: Expr


@dataclass
class DriveStmt(Stmt):
    source_expr: Expr
    target_region: str


@dataclass
class PulseStmt(Stmt):
    steps: int


@dataclass
class ReportStmt(Stmt):
    pass


class Parser:
    def __init__(self, tokens: List[Token]) -> None:
        self.tokens = tokens
        self.pos = 0

    def peek(self, offset: int = 0) -> Token:
        idx = min(self.pos + offset, len(self.tokens) - 1)
        return self.tokens[idx]

    def consume(self, expected: Optional[TokType] = None) -> Token:
        tok = self.peek()
        if expected and tok.kind != expected:
            raise SyntaxError(f"Expected {expected.name} at line {tok.line}, got {tok.kind.name} ({tok.value!r})")
        self.pos += 1
        return tok

    def parse_program(self) -> List[Stmt]:
        stmts: List[Stmt] = []
        while self.peek().kind != TokType.EOF:
            stmts.append(self.parse_stmt())
        return stmts

    def parse_stmt(self) -> Stmt:
        tok = self.peek()
        if tok.kind == TokType.LET:
            self.consume(TokType.LET)
            name = self.consume(TokType.IDENT).value
            self.consume(TokType.ARROW)
            expr = self.parse_expr()
            self.consume(TokType.SEMI)
            return LetStmt(name, expr)
        if tok.kind == TokType.AT:
            self.consume(TokType.AT)
            region = self.consume(TokType.IDENT).value
            expr = self.parse_expr()
            self.consume(TokType.SEMI)
            return AtStmt(region, expr)
        if tok.kind == TokType.PULSE:
            self.consume(TokType.PULSE)
            steps = int(float(self.consume(TokType.NUMBER).value))
            self.consume(TokType.SEMI)
            return PulseStmt(max(1, steps))
        if tok.kind == TokType.REPORT:
            self.consume(TokType.REPORT)
            self.consume(TokType.SEMI)
            return ReportStmt()

        # Front-driving statement: <expr> -> <region>;
        expr = self.parse_expr()
        if self.peek().kind == TokType.ARROW:
            self.consume(TokType.ARROW)
            region = self.consume(TokType.IDENT).value
            self.consume(TokType.SEMI)
            return DriveStmt(expr, region)

        raise SyntaxError(f"Unexpected statement starting with {tok.value!r} at line {tok.line}")

    def parse_expr(self) -> Expr:
        left = self.parse_term()
        while self.peek().kind in (TokType.COLLIDE, TokType.MERGE, TokType.DAMPEN):
            op_tok = self.consume()
            right = self.parse_term()
            left = BinOp(op_tok.value, left, right)
        return left

    def parse_term(self) -> Expr:
        tok = self.peek()
        if tok.kind == TokType.NUMBER:
            # Shorthand weather literal: <pressure>
            p = float(self.consume(TokType.NUMBER).value)
            return WeatherLit(p, 0.5, 8.0)
        if tok.kind == TokType.IDENT:
            name = self.consume(TokType.IDENT).value
            if self.peek().kind == TokType.LPAREN:
                # Full weather constructor: name(pressure, humidity, wind)
                self.consume(TokType.LPAREN)
                p = float(self.consume(TokType.NUMBER).value)
                self.consume(TokType.COMMA)
                h = float(self.consume(TokType.NUMBER).value)
                self.consume(TokType.COMMA)
                w = float(self.consume(TokType.NUMBER).value)
                self.consume(TokType.RPAREN)
                if name != "air":
                    raise SyntaxError(f"Unknown weather constructor {name!r} at line {tok.line}; use 'air(p, h, w)'")
                return WeatherLit(p, h, w)
            return VarRef(name)
        if tok.kind == TokType.LPAREN:
            self.consume(TokType.LPAREN)
            expr = self.parse_expr()
            self.consume(TokType.RPAREN)
            return expr
        raise SyntaxError(f"Unexpected expression token {tok.value!r} at line {tok.line}")


# --- 4. Bytecode Compiler ---

class Op(Enum):
    PUSH_WEATHER = auto()
    LOAD_VAR = auto()
    STORE_VAR = auto()
    BLEND = auto()
    DAMPEN = auto()
    COLLIDE_FRONT = auto()
    SEED_REGION = auto()
    DRIVE_FRONT = auto()
    ADVANCE_CONTINENT = auto()
    EMIT_REPORT = auto()


@dataclass
class Instr:
    op: Op
    arg: object = None


def compile_ast(stmts: List[Stmt]) -> List[Instr]:
    code: List[Instr] = []

    def emit_expr(expr: Expr) -> None:
        if isinstance(expr, WeatherLit):
            code.append(Instr(Op.PUSH_WEATHER, Weather(expr.pressure, expr.humidity, expr.wind).clamped()))
        elif isinstance(expr, VarRef):
            code.append(Instr(Op.LOAD_VAR, expr.name))
        elif isinstance(expr, BinOp):
            emit_expr(expr.left)
            emit_expr(expr.right)
            if expr.op == "+":
                code.append(Instr(Op.BLEND))
            elif expr.op == "-":
                code.append(Instr(Op.DAMPEN))
            elif expr.op == "><":
                code.append(Instr(Op.COLLIDE_FRONT))
            else:
                raise CompilerError(f"Unsupported operator {expr.op!r}")
        else:
            raise CompilerError(f"Unknown AST expression {type(expr).__name__}")

    for stmt in stmts:
        if isinstance(stmt, LetStmt):
            emit_expr(stmt.expr)
            code.append(Instr(Op.STORE_VAR, stmt.name))
        elif isinstance(stmt, AtStmt):
            emit_expr(stmt.expr)
            code.append(Instr(Op.SEED_REGION, stmt.region))
        elif isinstance(stmt, DriveStmt):
            emit_expr(stmt.source_expr)
            code.append(Instr(Op.DRIVE_FRONT, stmt.target_region))
        elif isinstance(stmt, PulseStmt):
            code.append(Instr(Op.ADVANCE_CONTINENT, stmt.steps))
        elif isinstance(stmt, ReportStmt):
            code.append(Instr(Op.EMIT_REPORT))

    return code


class CompilerError(Exception):
    pass


# --- 5. Miniature Continent & Barometric VM ---

# 4x3 miniature continent grid: (row, col) -> region name
CONTINENT_GRID: List[List[str]] = [
    ["nw_fjord", "north_ridge", "baltic_steppe", "ne_tundra"],
    ["west_coast", "heartland",    "basin_plain",   "east_bluff"],
    ["sw_cape",    "south_valley", "delta_lowland", "se_archipelago"],
]

REGION_COORDS: Dict[str, Tuple[int, int]] = {
    name: (r, c)
    for r, row in enumerate(CONTINENT_GRID)
    for c, name in enumerate(row)
}


class BarometricVM:
    def __init__(self) -> None:
        self.vars: Dict[str, Weather] = {}
        self.stack: List[Weather] = []
        self.grid: Dict[str, Weather] = {
            name: Weather(1013.0, 0.45, 6.0) for name in REGION_COORDS
        }
        self.tick = 0
        self.events: List[str] = []

    def _neighbors(self, region: str) -> List[str]:
        r, c = REGION_COORDS[region]
        adj: List[str] = []
        for dr, dc in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            nr, nc = r + dr, c + dc
            if 0 <= nr < len(CONTINENT_GRID) and 0 <= nc < len(CONTINENT_GRID[0]):
                adj.append(CONTINENT_GRID[nr][nc])
        return adj

    def _resolve_region(self, name: str) -> str:
        if name not in REGION_COORDS:
            known = ", ".join(sorted(REGION_COORDS))
            raise RuntimeError(f"Unknown continent region {name!r}. Valid regions: {known}")
        return name

    def step_simulation(self, steps: int) -> None:
        for _ in range(steps):
            self.tick += 1
            next_grid = dict(self.grid)
            visited_pairs = set()

            for reg in REGION_COORDS:
                for nb in self._neighbors(reg):
                    pair = tuple(sorted((reg, nb)))
                    if pair in visited_pairs:
                        continue
                    visited_pairs.add(pair)

                    w1, w2 = next_grid[reg], next_grid[nb]
                    # Adjacent cells with a pressure gradient or active wind interact as fronts.
                    if abs(w1.pressure - w2.pressure) >= 4.0 or (w1.wind + w2.wind) >= 24.0:
                        nw1, nw2, ev = w1.collide(w2)
                        next_grid[reg] = nw1
                        next_grid[nb] = nw2
                        if abs(w1.pressure - w2.pressure) >= 10.0 or max(nw1.wind, nw2.wind) >= 25.0:
                            self.events.append(f"t={self.tick}: {ev} between {reg} and {nb}")

            # Gentle relaxation toward mild continental equilibrium so fronts stay dynamic rather than flat.
            for reg, w in next_grid.items():
                relaxed = Weather(
                    pressure=w.pressure + (1013.0 - w.pressure) * 0.04,
                    humidity=w.humidity + (0.45 - w.humidity) * 0.04,
                    wind=max(1.0, w.wind * 0.92),
                ).clamped()
                next_grid[reg] = relaxed

            self.grid = next_grid

    def format_map(self) -> str:
        lines = [f"=== CONTINENT BAROMETRIC MAP (tick {self.tick}) ==="]
        for row in CONTINENT_GRID:
            cells = []
            for reg in row:
                w = self.grid[reg]
                cells.append(f"{reg:14s} {w.pressure:6.1f}hPa h={w.humidity:.2f} w={w.wind:4.1f} [{w.classify():10s}]")
            lines.append(" | ".join(cells))
        if self.events:
            lines.append("--- Notable Front Collisions ---")
            lines.extend(f"  * {e}" for e in self.events[-6:])
        return "\n".join(lines)

    def execute(self, program: List[Instr]) -> str:
        outputs: List[str] = []
        for ins in program:
            if ins.op == Op.PUSH_WEATHER:
                assert isinstance(ins.arg, Weather)
                self.stack.append(ins.arg)
            elif ins.op == Op.LOAD_VAR:
                assert isinstance(ins.arg, str)
                if ins.arg not in self.vars:
                    raise RuntimeError(f"Unbound weather pattern {ins.arg!r}")
                self.stack.append(self.vars[ins.arg])
            elif ins.op == Op.STORE_VAR:
                assert isinstance(ins.arg, str)
                self.vars[ins.arg] = self.stack.pop()
            elif ins.op == Op.BLEND:
                b = self.stack.pop()
                a = self.stack.pop()
                self.stack.append(Weather(
                    (a.pressure + b.pressure) * 0.5,
                    (a.humidity + b.humidity) * 0.5,
                    (a.wind + b.wind) * 0.5,
                ).clamped())
            elif ins.op == Op.DAMPEN:
                b = self.stack.pop()
                a = self.stack.pop()
                self.stack.append(Weather(
                    a.pressure + (a.pressure - b.pressure) * 0.25,
                    max(0.0, a.humidity - b.humidity * 0.4),
                    max(0.0, a.wind - b.wind * 0.3),
                ).clamped())
            elif ins.op == Op.COLLIDE_FRONT:
                b = self.stack.pop()
                a = self.stack.pop()
                na, nb, ev = a.collide(b)
                self.tick += 1
                self.events.append(f"t={self.tick}: direct clash ({ev}) -> {na.classify()} & {nb.classify()}")
                # Keep the higher-energy resulting front on the expression stack.
                winner = na if na.wind >= nb.wind else nb
                self.stack.append(winner)
            elif ins.op == Op.SEED_REGION:
                assert isinstance(ins.arg, str)
                reg = self._resolve_region(ins.arg)
                self.grid[reg] = self.stack.pop().clamped()
            elif ins.op == Op.DRIVE_FRONT:
                assert isinstance(ins.arg, str)
                reg = self._resolve_region(ins.arg)
                incoming = self.stack.pop().clamped()
                existing = self.grid[reg]
                na, nb, ev = incoming.collide(existing)
                self.grid[reg] = nb
                # Spill residual momentum into the first neighbor along the grid.
                nbs = self._neighbors(reg)
                if nbs:
                    spill_reg = nbs[0]
                    _, spilled, _ = na.collide(self.grid[spill_reg])
                    self.grid[spill_reg] = spilled
                self.events.append(f"t={self.tick}: front driven into {reg} ({ev})")
            elif ins.op == Op.ADVANCE_CONTINENT:
                assert isinstance(ins.arg, int)
                self.step_simulation(ins.arg)
            elif ins.op == Op.EMIT_REPORT:
                outputs.append(self.format_map())
        return "\n\n".join(outputs)


def compile_and_run(source: str) -> str:
    tokens = tokenize(source)
    ast = Parser(tokens).parse_program()
    bytecode = compile_ast(ast)
    vm = BarometricVM()
    return vm.execute(bytecode)


SAMPLE_PROGRAM = """
# Define base weather patterns (only data type: Weather(pressure_hPa, humidity, wind_ms))
let polar_high -> air(1042, 0.22, 18);
let tropical_low -> air(976, 0.92, 26);
let coastal_mist -> air(1008, 0.85, 9);

# Seed initial air masses across the miniature continent
at nw_fjord polar_high;
at west_coast coastal_mist;
at south_valley tropical_low;

# Collide fronts and drive resulting weather across regions
(polar_high >< tropical_low) -> heartland;
(tropical_low + coastal_mist) -> basin_plain;
(polar_high - coastal_mist) -> north_ridge;

pulse 4;
report;
"""


if __name__ == "__main__":
    print(compile_and_run(SAMPLE_PROGRAM))