import os
import random
import socket
import sys
import time
from dataclasses import dataclass, field
from typing import List, Dict, Tuple

# =====================================================================
# Gothic Cathedral Compiler: Network Traffic -> Architectural Blueprint
# =====================================================================

@dataclass
class PacketSymbol:
    """Represents a single packet scanned from the network stream."""
    protocol: str
    size: int
    ttl: int
    is_dropped: bool
    source_port: int
    dest_port: int

class TrafficLexer:
    """Sniffs network traffic and produces lexical packet tokens."""
    def __init__(self, sample_count: int = 40):
        self.sample_count = sample_count

    def scan(self) -> List[PacketSymbol]:
        packets = []
        # Attempt live raw socket capture; fallback to network simulation if unprivileged
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_RAW, socket.IPPROTO_ICMP)
            s.settimeout(0.1)
            for _ in range(self.sample_count):
                try:
                    data, addr = s.recvfrom(65535)
                    is_dropped = random.random() < 0.15
                    packets.append(PacketSymbol(
                        protocol="ICMP",
                        size=len(data),
                        ttl=data[8] if len(data) > 8 else 64,
                        is_dropped=is_dropped,
                        source_port=80,
                        dest_port=80
                    ))
                except socket.timeout:
                    break
            s.close()
        except PermissionError:
            # Synthetic network lexer simulating real system noise
            protocols = ["TCP", "UDP", "HTTP", "DNS", "TLS"]
            for _ in range(self.sample_count):
                proto = random.choice(protocols)
                size = random.randint(64, 1500)
                ttl = random.choice([32, 64, 128])
                # Dropped packets manifest under heavy volume or random drop
                is_dropped = (size > 1200 and random.random() < 0.3) or (random.random() < 0.12)
                packets.append(PacketSymbol(
                    protocol=proto,
                    size=size,
                    ttl=ttl,
                    is_dropped=is_dropped,
                    source_port=random.randint(1024, 65535),
                    dest_port=random.choice([80, 443, 53, 22])
                ))
        return packets

@dataclass
class CathedralBlueprint:
    """Abstract Syntax Tree representing the gothic cathedral structure."""
    nave_length: int
    spire_height: int
    buttress_count: int
    rose_window_complexity: int
    gargoyles: List[Tuple[int, str]] = field(default_factory=list)

class ArchitecturalCompiler:
    """Compiles network packet metrics into architectural cathedral components."""
    def compile(self, stream: List[PacketSymbol]) -> CathedralBlueprint:
        total_volume = sum(p.size for p in stream)
        avg_ttl = sum(p.ttl for p in stream) // max(len(stream), 1)
        
        nave_length = max(16, min(48, total_volume // 1000))
        spire_height = max(6, min(20, avg_ttl // 4))
        buttress_count = max(4, min(16, len(stream) // 3))
        rose_window_complexity = len(set(p.dest_port for p in stream))
        
        gargoyles = []
        for idx, packet in enumerate(stream):
            if packet.is_dropped:
                decay_stage = random.choice([
                    "Cracked stone gargoyle with severed wing",
                    "Eroded grotesque spouting broken masonry",
                    "Crumbling gargoyle head hanging by iron tendon",
                    "Fissured chimera with shattered muzzle"
                ])
                gargoyles.append((idx % buttress_count, decay_stage))

        return CathedralBlueprint(
            nave_length=nave_length,
            spire_height=spire_height,
            buttress_count=buttress_count,
            rose_window_complexity=rose_window_complexity,
            gargoyles=gargoyles
        )

class CathedralRenderer:
    """Renders the compiled cathedral blueprint into visual ASCII schematics."""
    def render_ascii(self, bp: CathedralBlueprint) -> str:
        lines = []
        lines.append("=" * 72)
        lines.append("      GOTHIC CATHEDRAL PROCEDURAL BLUEPRINT (NETWORK TRAFFIC AST)")
        lines.append("=" * 72)
        
        center = bp.nave_length // 2 + 10
        pad = " " * center
        
        # Spire & Cross
        lines.append(f"{pad}+")
        lines.append(f"{pad}/\\")
        for _ in range(bp.spire_height // 3):
            lines.append(f"{pad}||")
        lines.append(f"{pad[:center-1]}/||\\")
        
        # Rose Window
        rose = " (O) " if bp.rose_window_complexity < 3 else "([@])"
        lines.append(f"{pad[:center-2]}{rose}")
        
        # Nave Roof
        roof = "/" + "=" * bp.nave_length + "\\"
        lines.append("      " + roof)
        
        # Wall / Flying Buttresses with Gargoyles (Dropped Packets)
        gargoyle_map = {}
        for pos, desc in bp.gargoyles:
            gargoyle_map[pos] = gargoyle_map.get(pos, 0) + 1
            
        wall = "      |" + " " * bp.nave_length + "|"
        lines.append(wall)
        
        b_spacing = max(1, bp.nave_length // (bp.buttress_count + 1))
        buttress_line = list("      |" + " " * bp.nave_length + "|")
        
        for i in range(1, bp.buttress_count + 1):
            idx = 7 + i * b_spacing
            if idx < len(buttress_line) - 1:
                if (i - 1) in gargoyle_map:
                    buttress_line[idx] = "G"  # Dropped packet gargoyle
                else:
                    buttress_line[idx] = "|"
                    
        lines.append("".join(buttress_line) + "  <-- Flying Buttresses [G = Crumbling Gargoyle]")
        lines.append("      |" + "_" * bp.nave_length + "|")
        lines.append("     / " + " " * bp.nave_length + " \\")
        
        # Diagnostics Log
        lines.append("\n--- DROPPED PACKETS: MANIFESTED GARGOYLE REGISTRY ---")
        if not bp.gargoyles:
            lines.append(" [No dropped packets detected. Sanctuary walls remain immaculate.]")
        else:
            for b_idx, decay in bp.gargoyles[:10]:
                lines.append(f" [Buttress #{b_idx + 1:02d}] -> {decay}")
            if len(bp.gargoyles) > 10:
                lines.append(f" ... and {len(bp.gargoyles) - 10} more decayed grotesques embedded in outer walls.")
                
        return "\n".join(lines)

def main():
    print("Capturing live system network traffic...")
    lexer = TrafficLexer(sample_count=45)
    packets = lexer.scan()
    print(f"Captured {len(packets)} network symbols.")
    
    print("Compiling packet stream into Gothic Cathedral AST...")
    compiler = ArchitecturalCompiler()
    blueprint = compiler.compile(packets)
    
    renderer = CathedralRenderer()
    print("\n" + renderer.render_ascii(blueprint))

if __name__ == "__main__":
    main()