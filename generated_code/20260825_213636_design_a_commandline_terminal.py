import time
import random
import sys
import os

# --- Haiku Vocabulary Bank ---
SUBJECTS = [
    ["Silent data frame", "A lonely packet", "Glowing byte stream", "Ghostly header", "Distant signal"],
    ["TCP handshake", "UDP whisper", "Routing table shift", "Wandering payload", "Subnet shadow"],
    ["Unseen bit pattern", "Ethernet echo", "Symmetric cipher", "Transient buffer", "Dark wire pulse"]
]

MIDDLE_LINES = [
    ["drifts through the dark silent wire", "crosses the deep fiber optic", "searches for an open port", "flies across the local node"],
    ["waiting for a response now", "carrying a hidden payload", "echoing in the ether", "leaving no trace in memory"],
    ["shifting through space and time now", "bound for a distant domain", "traversing the outer switch", "weaving through active networks"]
]

CLOSING_LINES = [
    ["destination reached", "lost into the void", "connection is alive", "the echo responds", "packets fall like rain"],
    ["seeking a response", "silence on the port", "data flows away", "terminal is calm", "bound to the display"],
    ["light upon the glass", "routed to the cloud", "checksum is complete", "latency remains", "signal fades to black"]
]

def generate_haiku():
    """Generates a pseudo-random Haiku representing a packet header interpretation."""
    line1 = random.choice(SUBJECTS[0])
    line2 = random.choice(MIDDLE_LINES[0])
    line3 = random.choice(CLOSING_LINES[0])
    return [line1, line2, line3]

def get_color_code(latency_ms):
    """Returns ANSI color code dynamically based on latency (ms)."""
    if latency_ms < 20:
        return "\033[38;5;46m"  # Crisp Green (Low latency)
    elif latency_ms < 60:
        return "\033[38;5;51m"  # Cyan
    elif latency_ms < 120:
        return "\033[38;5;226m" # Yellow (Moderate latency)
    elif latency_ms < 250:
        return "\033[38;5;208m" # Orange
    else:
        return "\033[38;5;196m" # Crimson Red (High latency)

RESET_COLOR = "\033[0m"

def simulate_packet_header():
    """Generates synthetic network packet header attributes and simulated latency."""
    src_ip = f"192.168.{random.randint(1,255)}.{random.randint(1,255)}"
    dst_ip = f"10.0.{random.randint(1,255)}.{random.randint(1,255)}"
    protocol = random.choice(["TCP", "UDP", "ICMP"])
    port = random.choice([80, 443, 22, 53, 8080])
    latency = random.expovariate(1/50) + 5.0 # Simulated latency in milliseconds
    return {
        "src": src_ip,
        "dst": dst_ip,
        "proto": protocol,
        "port": port,
        "latency": latency
    }

def run_emulator():
    """Main terminal emulator loop rendering network packet streams as Haikus."""
    os.system('cls' if os.name == 'nt' else 'clear')
    print("\033[1;37m=== NETWORK HAIKU PACKET STREAM EMULATOR ===\033[0m\n")
    print("Capturing packet headers and translating to poetical resonance...\n")
    
    try:
        while True:
            pkt = simulate_packet_header()
            haiku = generate_haiku()
            color = get_color_code(pkt['latency'])
            
            header_info = f"[{pkt['proto']}] {pkt['src']} -> {pkt['dst']}:{pkt['port']} | Latency: {pkt['latency']:.1f}ms"
            
            print(f"{color}┌─ HEADER: {header_info}{RESET_COLOR}")
            print(f"{color}│  {haiku[0]}{RESET_COLOR}")
            print(f"{color}│  {haiku[1]}{RESET_COLOR}")
            print(f"{color}└─ {haiku[2]}{RESET_COLOR}\n")
            
            time.sleep(random.uniform(0.8, 2.0))
    except KeyboardInterrupt:
        print("\n\033[1;30mStream terminated by user. Terminal returned to silence.\033[0m")
        sys.exit(0)

if __name__ == "__main__":
    run_emulator()