--[[ 
Simple real‑time visual‑audio mapper 
Requires: LuaJIT, OpenCV (compiled with C API), sndfile/midi library (midialib.lua)
Run: luajit this_file.lua
--]]

local ffi = require("ffi")
local cv = ffi.load("opencv_core")          -- ensure OpenCV libs are in LD_LIBRARY_PATH
local cv_imgproc = ffi.load("opencv_imgproc")
local cv_videoio = ffi.load("opencv_videoio")
local cv_highgui = ffi.load("opencv_highgui")
local sys = require("os")
local math = require("math")
local bit = require("bit")
local midi = require("midialib")            -- simple pure‑Lua MIDI writer (must be in package.path)

-- C definitions (minimal subset)
ffi.cdef[[

typedef struct CvCapture CvCapture;
typedef struct IplImage IplImage;
typedef struct CvSeq CvSeq;
typedef struct CvSize { int width; int height; } CvSize;
typedef struct CvPoint { int x; int y; } CvPoint;
typedef struct CvScalar { double val[4]; } CvScalar;
typedef struct CvMat CvMat;

CvCapture* cvCreateFileCapture(const char* filename);
int cvGrabFrame(CvCapture* capture);
IplImage* cvRetrieveFrame(CvCapture* capture, int streamIdx);
void cvReleaseCapture(CvCapture** capture);
IplImage* cvCreateImage(CvSize size, int depth, int channels);
void cvReleaseImage(IplImage** image);
void cvCvtColor(const IplImage* src, IplImage* dst, int code);
void cvCalcOpticalFlowFarneback(const IplImage* prev, const IplImage* next,
                               IplImage* flow, double pyr_scale, int levels,
                               int winsize, int iterations, int poly_n,
                               double poly_sigma, int flags);
double cvCalcCovarMatrix(const CvArr* samples, int nsamples,
                         CvArr* cov_mat, CvArr* avg, int flags);
double cvNorm(const CvArr* src1, const CvArr* src2, int norm_type, const CvArr* mask);
void cvCopy(const CvArr* src, CvArr* dst, const CvArr* mask);
void cvSetZero(CvArr* arr);
void cvSetImageROI(IplImage* image, CvRect rect);
void cvResetImageROI(IplImage* image);

typedef struct CvRect { int x; int y; int width; int height; } CvRect;

enum { CV_BGR2GRAY = 6 };
enum { CV_TM_CCOEFF_NORMED = 5 };
enum { CV_L1 = 1 };
enum { CV_32FC1 = 5 };
enum { CV_8UC1 = 0 };
]]

-- Helper to wrap IplImage data as Lua table
local function img_to_table(img)
    local w, h = img.width, img.height
    local step = img.widthStep
    local data = ffi.cast("unsigned char*", img.imageData)
    local t = {}
    for y=0,h-1 do
        local row = {}
        for x=0,w-1 do
            row[x+1] = data[y*step + x]
        end
        t[y+1] = row
    end
    return t
end

-- Open default webcam (device 0)
local cap = cv_videoio.cvCreateFileCapture(0)
assert(cap ~= nil, "Cannot open webcam")

-- Prepare grayscale frames
local function grab_gray()
    cvGrabFrame(cap)
    local frame = cv_videoio.cvRetrieveFrame(cap, 0)
    assert(frame ~= nil, "No frame")
    local sz = ffi.new("CvSize", {width = frame.width, height = frame.height})
    local gray = cv.cvCreateImage(sz, ffi.C.CV_8UC1, 1)
    cv.cvCvtColor(frame, gray, ffi.C.CV_BGR2GRAY)
    return gray
end

-- Optical flow buffers
local prev = grab_gray()
local flow = cv.cvCreateImage(ffi.new("CvSize",{width=prev.width,height=prev.height}), ffi.C.CV_32FC2, 1)

-- MIDI setup
local midifile = midi.new()
midifile:setTempo(120)      -- default BPM
midifile:setDivision(480)   -- ticks per beat

-- ASCII waveform buffer
local waveform = {}
local wave_len = 80

-- Main loop
while true do
    local cur = grab_gray()
    -- Compute Farneback optical flow
    cv.cvCalcOpticalFlowFarneback(prev, cur, flow,
        0.5, 3, 15, 3, 5, 1.2, 0)

    -- Estimate motion intensity (average magnitude)
    local sum = 0
    local cnt = prev.width * prev.height
    local flow_ptr = ffi.cast("float*", flow.imageData)
    for i=0, cnt-1 do
        local fx = flow_ptr[i*2]
        local fy = flow_ptr[i*2+1]
        sum = sum + math.sqrt(fx*fx + fy*fy)
    end
    local motion_intensity = sum / cnt

    -- Visual entropy approximation (Shannon entropy of gray image)
    local hist = {}
    for i=0,255 do hist[i]=0 end
    local gray_ptr = ffi.cast("unsigned char*", cur.imageData)
    for i=0, cnt-1 do
        local v = gray_ptr[i]
        hist[v] = hist[v] + 1
    end
    local entropy = 0
    for i=0,255 do
        if hist[i] > 0 then
            local p = hist[i] / cnt
            entropy = entropy - p * math.log(p,2)
        end
    end

    -- Map entropy to musical parameters
    local tempo = 60 + entropy * 40          -- 60‑100 BPM
    local key  = math.floor(entropy * 12) % 12   -- 0‑11 (C to B)
    local instrument = 0x40 + (entropy * 40) % 32   -- variation of synth

    midifile:setTempo(tempo)
    midifile:setInstrument(1, instrument)

    -- Generate a note based on motion intensity
    local velocity = math.min(127, math.floor(motion_intensity*20))
    local pitch = 60 + key + (motion_intensity*12)
    midifile:noteOn(1, pitch, velocity)
    midifile:noteOff(1, pitch, 120)  -- short note

    -- Update ASCII waveform (simple sinusoid driven by intensity)
    local wave_char = (math.sin(os.clock()*tempo/60*2*math.pi) * motion_intensity*4) + wave_len/2
    table.insert(waveform, math.floor(wave_char))
    if #waveform > wave_len then table.remove(waveform,1) end

    -- Render heatmap + waveform to terminal
    sys.execute("clear")
    for y=1,prev.height,math.floor(prev.height/20) do
        local line = {}
        for x=1,prev.width,math.floor(prev.width/40) do
            local idx = ((y-1)*prev.width + (x-1))
            local fx = flow_ptr[idx*2]
            local fy = flow_ptr[idx*2+1]
            local mag = math.sqrt(fx*fx+fy*fy)
            local shade = math.min(255, math.floor(mag*10))
            table.insert(line, string.format("\27[48;2;%d;%d;%dm \27[0m", shade,0,255-shade))
        end
        print(table.concat(line))
    end
    -- overlay waveform
    local waveline = {}
    for i=1,#waveform do
        local pos = waveform[i]
        local segment = string.rep(" ", pos-1) .. "*" .. string.rep(" ", wave_len-pos)
        table.insert(waveline, segment)
    end
    for _,ln in ipairs(waveline) do
        print(ln)
    end

    -- Prepare next iteration
    cv.cvReleaseImage(prev)
    prev = cur

    -- small delay to limit CPU (approx 30 FPS)
    ffi.C.usleep(33333)
end

-- Cleanup (never reached in infinite loop)
cv.cvReleaseImage(prev)
cv.cvReleaseImage(flow)
cv_videoio.cvReleaseCapture(cap)
midifile:save("output.mid")