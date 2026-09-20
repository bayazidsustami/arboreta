# Self-modifying magnetic declination constellation & MIDI lullaby generator
import time
import math
import sys
import urllib.request
import json

def get_magnetic_declination():
    # Fetch or simulate live magnetic declination data
    try:
        url = "[https://www.ngdc.noaa.gov/geomag-web/calculators/calculateDeclination?lat=40&lon=-105&resultFormat=json](https://www.ngdc.noaa.gov/geomag-web/calculators/calculateDeclination?lat=40&lon=-105&resultFormat=json)"
        req = urllib.request.urlopen(url, timeout=2)
        data = json.loads(req.read().decode('utf-8'))
        return float(data['result'][0]['declination'])
    except Exception:
        # Fallback simulated live variation if network is unavailable
        return 11.5 + math.sin(time.time() * 0.5) * 2.0

def generate_satellite_lullaby_midi(bytecode, filename="lost_satellites.mid"):
    # Compiles bytecode into a rudimentary MIDI file (MIDI format 0)
    # Lullaby about lost satellites encoded in notes derived from bytecode
    header = b'MThd\x00\x00\x00\x06\x00\x00\x00\x01\x00\x60'
    track_data = bytearray()
    
    # Meta event: Track Name "Lost Satellites Lullaby"
    track_data.extend(b'\x00\xff\x03\x18Lost Satellites Lullaby')
    
    # Map bytecode bytes to a pentatonic scale (lullaby feel)
    scale = [60, 63, 65, 67, 70, 72] # C minor pentatonic
    for b in bytecode[:30]:
        note = scale[b % len(scale)]
        duration = (b % 4 + 1) * 48 # delta time
        # Note on
        track_data.extend(bytes([0, 0x90, note, 64]))
        track_data.extend(bytes([duration, 0x80, note, 0]))
        
    # End of track
    track_data.extend(b'\x00\xff\x2f\x00')
    track_header = b'MTrk' + len(track_data).to_bytes(4, 'big')
    
    with open(filename, 'wb') as f:
        f.write(header + track_header + track_data)

def self_modify_and_run():
    # Self-modifying element: dynamically inspects runtime function bytecode
    target_func = constellation_frame
    print("Initializing orbital telemetry and magnetic tracking...")
    
    # Generate MIDI lullaby from this function's bytecode
    generate_satellite_lullaby_midi(target_func.__code__.co_code)
    print("MIDI lullaby compiled successfully to 'lost_satellites.mid'.")

    for i in range(10):
        declination = get_magnetic_declination()
        constellation_frame(declination, i)
        time.sleep(0.4)

def constellation_frame(dec, step):
    # Renders a flickering ASCII constellation based on declination
    width = 40
    star_pos = int((dec + 20) * (width / 40)) % width
    sky = [' '] * width
    sky[max(0, min(width-1, star_pos))] = '*'
    sky[max(0, min(width-1, (star_pos + 12) % width))] = '.'
    sky[max(0, min(width-1, (star_pos + 25) % width))] = 'o'
    
    print(f"Dec: {dec:+.2f}° | " + "".join(sky) + f" [Orbit {step}]")

if __name__ == '__main__':
    self_modify_and_run()