--[[ 
Lua script: live‑sound → FFT → SVG mandala frames
Requires: LuaJIT, PortAudio (compiled as libportaudio), kissfft (or any FFT lib) 
Place libportaudio.so / libportaudio.dll and libkissfft.so in the same directory.
--]]

local ffi = require("ffi")
local C = ffi.C

--=== PortAudio bindings ===
ffi.cdef[[
typedef ... PaStream;
typedef int PaError;
typedef unsigned long PaSampleFormat;
typedef unsigned long PaStreamFlags;
typedef double PaTime;
typedef struct PaDeviceInfo {
    int structVersion;
    const char *name;
    int hostApi;
    int maxInputChannels;
    int maxOutputChannels;
    double defaultLowInputLatency;
    double defaultLowOutputLatency;
    double defaultHighInputLatency;
    double defaultHighOutputLatency;
    double defaultSampleRate;
} PaDeviceInfo;

PaError Pa_Initialize(void);
PaError Pa_Terminate(void);
int Pa_GetDeviceCount(void);
const PaDeviceInfo* Pa_GetDeviceInfo(int device);
PaError Pa_OpenDefaultStream( PaStream**,
                              int numInputChannels,
                              int numOutputChannels,
                              PaSampleFormat sampleFormat,
                              double sampleRate,
                              unsigned long framesPerBuffer,
                              void* streamCallback,
                              void* userData );
PaError Pa_StartStream(PaStream*);
PaError Pa_StopStream(PaStream*);
PaError Pa_CloseStream(PaStream*);
]]

local SAMPLE_RATE = 44100
local FRAMES_PER_BUFFER = 1024
local CHANNELS = 1
local SAMPLE_FORMAT = 0x00000001   -- paFloat32

--=== KissFFT bindings (float, real->complex) ===
ffi.cdef[[
typedef struct kiss_fft_cfg_struct *kiss_fft_cfg;
typedef struct kiss_fft_cpx {
    float r;
    float i;
} kiss_fft_cpx;

kiss_fft_cfg kiss_fft_alloc(int nfft, int inverse_fft, void * mem, size_t *lenmem);
void kiss_fft(kiss_fft_cfg cfg,const kiss_fft_cpx *fin,kiss_fft_cpx *fout);
void kiss_fft_cleanup(void);
]]

local kiss = ffi.load("kissfft")   -- adjust name if needed

--=== Global buffers ===
local input_buf = ffi.new("float[?]", FRAMES_PER_BUFFER)
local output_buf = ffi.new("kiss_fft_cpx[?]", FRAMES_PER_BUFFER)

local fft_cfg = kiss.kiss_fft_alloc(FRAMES_PER_BUFFER, 0, nil, nil)

--=== Simple callback that copies data into input_buf ===
local cb_cdef = ffi.typeof("int(void*, void*, unsigned long, const PaTime*, const PaTime*, unsigned long)")
local stream_cb = ffi.cast(cb_cdef, function(input, output, frameCount, timeInfo, statusFlags, userData)
    if input == nil then return 0 end
    local src = ffi.cast("float*", input)
    ffi.copy(input_buf, src, frameCount * ffi.sizeof("float"))
    return 0
end)

--=== Helper: magnitude of complex array ===
local function magnitude_spectrum()
    kiss.kiss_fft(fft_cfg, input_buf, output_buf)
    local mags = {}
    for i=0,FRAMES_PER_BUFFER/2-1 do
        local re = output_buf[i].r
        local im = output_buf[i].i
        mags[i+1] = math.sqrt(re*re + im*im)
    end
    return mags
end

--=== SVG generation ===
local function svg_header(w,h)
    return string.format([[
<?xml version="1.0" encoding="UTF-8"?>
<svg width="%d" height="%d" viewBox="0 0 %d %d"
     xmlns="http://www.w3.org/2000/svg">
<rect width="100%%" height="100%%" fill="black"/>
]], w,h,w,h)
end

local function svg_footer()
    return "</svg>\n"
end

-- map a band to a motif
local function draw_motif(ax, ay, radius, hue, kind)
    local col = string.format("hsl(%d,80%%,60%%)", hue%360)
    if kind==1 then
        return string.format('<circle cx="%d" cy="%d" r="%d" stroke="%s" fill="none" stroke-width="2"/>',
            ax, ay, radius, col)
    elseif kind==2 then
        return string.format('<polygon points="%d,%d %d,%d %d,%d" stroke="%s" fill="none" stroke-width="2"/>',
            ax-radius, ay, ax+radius, ay, ax, ay-radius, col)
    else
        return string.format('<path d="M %d %d L %d %d" stroke="%s" stroke-width="2"/>',
            ax-radius, ay, ax+radius, ay, col)
    end
end

local function make_frame(frame_idx, spectrum)
    local W,H = 800,800
    local cx,cy = W/2, H/2
    local maxR = math.min(W,H)/2 - 20
    local svg = {}
    table.insert(svg, svg_header(W,H))
    local band_count = #spectrum
    for i=1,band_count do
        local amp = spectrum[i]
        local angle = (i/band_count) * 2*math.pi + frame_idx*0.01
        local r = (amp/10) * maxR
        local x = cx + math.cos(angle)*r
        local y = cy + math.sin(angle)*r
        local kind = (i % 3) + 1
        local hue = (i*7 + frame_idx*2) % 360
        table.insert(svg, draw_motif(x,y,5+ (amp*2), hue, kind))
    end
    table.insert(svg, svg_footer())
    return table.concat(svg)
end

--=== Main loop ===
local function main()
    assert(C.Pa_Initialize() == 0, "PortAudio init failed")
    local stream = ffi.new("PaStream*[1]")
    assert(C.Pa_OpenDefaultStream(stream,
        CHANNELS,0,SAMPLE_FORMAT,SAMPLE_RATE,FRAMES_PER_BUFFER,
        stream_cb, nil) == 0, "Open stream failed")
    assert(C.Pa_StartStream(stream[0]) == 0, "Start stream failed")
    print("Recording... press Ctrl+C to stop.")
    local frame = 0
    while true do
        -- simple busy‑wait for buffer to fill
        ffi.C.sleep(0.03)   -- 30 ms ≈ 1 buffer
        local mags = magnitude_spectrum()
        local svg = make_frame(frame, mags)
        local fname = string.format("frame_%05d.svg", frame)
        local f = io.open(fname, "w")
        f:write(svg)
        f:close()
        print("saved", fname)
        frame = frame + 1
        if frame >= 300 then break end   -- generate 300 frames then exit
    end
    C.Pa_StopStream(stream[0])
    C.Pa_CloseStream(stream[0])
    C.Pa_Terminate()
    kiss.kiss_fft_cleanup()
end

main()