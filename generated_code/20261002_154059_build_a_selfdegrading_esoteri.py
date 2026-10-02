import sys
import time
import urllib.request
import json
import tracemalloc

# Fetches real-time local weather via wttr.in JSON API
def fetch_weather():
    try:
        url = "[https://wttr.in/?format=j1](https://wttr.in/?format=j1)"
        req = urllib.request.Request(url, headers={'User-Agent': 'curl'})
        with urllib.request.urlopen(req, timeout=3) as response:
            data = json.loads(response.read().decode())
            current = data['current_condition'][0]
            desc = current.get('weatherDesc', [{'value': 'Clear'}])[0]['value']
            temp = current.get('temp_C', '20')
            return desc, temp
    except Exception:
        return "Clear", "20"

# Translates weather conditions into ASCII sprites
def render_sprite(weather):
    weather_lower = weather.lower()
    if "rain" in weather_lower or "drizzle" in weather_lower:
        return ["  / / /  ", " / 🌧️ / ", "  / / /  "]
    elif "cloud" in weather_lower or "overcast" in weather_lower:
        return ["  .-.    ", " ( (☁️) ) ", "  `-’    "]
    elif "snow" in weather_lower:
        return ["  * . *  ", " . ❄️ . * ", "  * . *  "]
    else:
        return ["  * * *  ", " *  🌞  * ", "  * * *  "]

# Emits a simulated musical frequency using terminal alerts and visual cues
def play_musical_sprite(sprite, temp):
    freq = int(temp) * 15
    sys.stdout.write(f"\x07[Frequency: {freq}Hz Melody]\n")
    for line in sprite:
        print(line)
    sys.stdout.flush()

def main():
    # Start tracking memory to detect self-degrading leaks
    tracemalloc.start()
    print("Initializing Ephemeral Weather Constellation Interpreter...")
    
    weather, temp = fetch_weather()
    sprite = render_sprite(weather)
    
    # Bucket used to intentionally simulate a memory leak over time
    memory_leak_simulator = []
    
    for cycle in range(6):
        # Check current memory consumption
        current_mem, _ = tracemalloc.get_traced_memory()
        
        # Self-degradation trigger: if memory growth exceeds threshold, permanently vanish
        if current_mem > 300000:
            print("\n[CRITICAL ERROR] Memory leak detected! The ephemeral constellation is collapsing...")
            print("[SELF-DEGRADING] Purging interpreter states from memory permanently...")
            sys.exit(42)
            
        print(f"\n--- Constellation Pulse {cycle + 1} | Forecast: {weather} ({temp}°C) ---")
        play_musical_sprite(sprite, temp)
        
        # Intentionally inflate memory to trigger the self-degrading mechanism
        memory_leak_simulator.append("█" * 150000 * (cycle + 1))
        time.sleep(0.4)
        
    tracemalloc.stop()
    print("\nExecution finished without triggering memory degradation.")

if __name__ == "__main__":
    main()