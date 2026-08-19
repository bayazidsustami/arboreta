package main

import (
	"fmt"
	"math"
	"math/cmplx"
	"os"
	"os/exec"
	"os/signal"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"

	"[github.com/gordonklaus/portaudio](https://github.com/gordonklaus/portaudio)"
)

// Grid dimensions for ASCII fluid dynamics rendering
const (
	width  = 80
	height = 30
	iter   = 4
)

// Fluid represents a 2D grid storing density and velocity fields (Navier-Stokes grid)
type Fluid struct {
	size       int
	dt         float64
	diff       float64
	visc       float64
	s          []float64
	density    []float64
	vx         []float64
	vy         []float64
	vx0        []float64
	vy0        []float64
	mu         sync.Mutex
}

// NewFluid initializes a new Eulerian fluid simulation grid
func NewFluid(size int, dt, diffusion, viscosity float64) *Fluid {
	n := size * size
	return &Fluid{
		size:    size,
		dt:      dt,
		diff:    diffusion,
		visc:    viscosity,
		s:       make([]float64, n),
		density: make([]float64, n),
		vx:      make([]float64, n),
		vy:      make([]float64, n),
		vx0:     make([]float64, n),
		vy0:     make([]float64, n),
	}
}

// AddDensity injects dye/density into the simulation at coordinate (x, y)
func (f *Fluid) AddDensity(x, y int, amount float64) {
	if x >= 0 && x < f.size && y >= 0 && y < f.size {
		f.density[y*f.size+x] += amount
	}
}

// AddVelocity injects force/velocity vectors into the simulation at coordinate (x, y)
func (f *Fluid) AddVelocity(x, y int, amountX, amountY float64) {
	if x >= 0 && x < f.size && y >= 0 && y < f.size {
		idx := y*f.size + x
		f.vx[idx] += amountX
		f.vy[idx] += amountY
	}
}

// Step advances the fluid simulation by one time-step using advection, diffusion, and projection
func (f *Fluid) Step() {
	f.mu.Lock()
	defer f.mu.Unlock()

	N := f.size
	visc, diff, dt := f.visc, f.diff, f.dt

	diffuse(1, f.vx0, f.vx, visc, dt, N)
	diffuse(2, f.vy0, f.vy, visc, dt, N)

	project(f.vx0, f.vy0, f.vx, f.vy, N)

	advect(1, f.vx, f.vx0, f.vx0, f.vy0, dt, N)
	advect(2, f.vy, f.vy0, f.vx0, f.vy0, dt, N)

	project(f.vx, f.vy, f.vx0, f.vy0, N)

	diffuse(0, f.s, f.density, diff, dt, N)
	advect(0, f.density, f.s, f.vx, f.vy, dt, N)
}

func setBnd(b int, x []float64, N int) {
	for i := 1; i < N-1; i++ {
		if b == 2 {
			x[i] = -x[1*N+i]
			x[(N-1)*N+i] = -x[(N-2)*N+i]
		} else {
			x[i] = x[1*N+i]
			x[(N-1)*N+i] = x[(N-2)*N+i]
		}

		if b == 1 {
			x[i*N] = -x[i*N+1]
			x[i*N+N-1] = -x[i*N+N-2]
		} else {
			x[i*N] = x[i*N+1]
			x[i*N+N-1] = x[i*N+N-2]
		}
	}

	x[0] = 0.5 * (x[1] + x[N])
	x[N-1] = 0.5 * (x[N-2] + x[2*N-1])
	x[(N-1)*N] = 0.5 * (x[(N-2)*N] + x[(N-1)*N+1])
	x[N*N-1] = 0.5 * (x[N*N-2] + x[(N-1)*N+N-2])
}

func linSolve(b int, x, x0 []float64, a, c float64, N int) {
	cRecip := 1.0 / c
	for k := 0; k < iter; k++ {
		for j := 1; j < N-1; j++ {
			for i := 1; i < N-1; i++ {
				x[j*N+i] = (x0[j*N+i] + a*(x[j*N+i+1]+x[j*N+i-1]+x[(j+1)*N+i]+x[(j-1)*N+i])) * cRecip
			}
		}
		setBnd(b, x, N)
	}
}

func diffuse(b int, x, x0 []float64, diff, dt float64, N int) {
	a := dt * diff * float64((N-2)*(N-2))
	linSolve(b, x, x0, a, 1+6*a, N)
}

func project(vx, vy, p, div []float64, N int) {
	for j := 1; j < N-1; j++ {
		for i := 1; i < N-1; i++ {
			div[j*N+i] = -0.5 * (vx[j*N+i+1] - vx[j*N+i-1] + vy[(j+1)*N+i] - vy[(j-1)*N+i]) / float64(N)
			p[j*N+i] = 0
		}
	}

	setBnd(0, div, N)
	setBnd(0, p, N)
	linSolve(0, p, div, 1, 6, N)

	for j := 1; j < N-1; j++ {
		for i := 1; i < N-1; i++ {
			vx[j*N+i] -= 0.5 * float64(N) * (p[j*N+i+1] - p[j*N+i-1])
			vy[j*N+i] -= 0.5 * float64(N) * (p[(j+1)*N+i] - p[(j-1)*N+i])
		}
	}
	setBnd(1, vx, N)
	setBnd(2, vy, N)
}

func advect(b int, d, d0, vx, vy []float64, dt float64, N int) {
	dt0 := dt * float64(N-2)
	for j := 1; j < N-1; j++ {
		for i := 1; i < N-1; i++ {
			x := float64(i) - dt0*vx[j*N+i]
			y := float64(j) - dt0*vy[j*N+i]

			if x < 0.5 {
				x = 0.5
			}
			if x > float64(N)-1.5 {
				x = float64(N) - 1.5
			}
			i0 := math.Floor(x)
			i1 := i0 + 1.0

			if y < 0.5 {
				y = 0.5
			}
			if y > float64(N)-1.5 {
				y = float64(N) - 1.5
			}
			j0 := math.Floor(y)
			j1 := j0 + 1.0

			s1 := x - i0
			s0 := 1.0 - s1
			t1 := y - j0
			t0 := 1.0 - t1

			i0i := int(i0)
			i1i := int(i1)
			j0i := int(j0)
			j1i := int(j1)

			d[j*N+i] = s0*(t0*d0[j0i*N+i0i]+t1*d0[j1i*N+i0i]) + s1*(t0*d0[j0i*N+i1i]+t1*d0[j1i*N+i1i])
		}
	}
	setBnd(b, d, N)
}

// Cooley-Tukey FFT algorithm for spectral audio processing
func fft(a []complex128) []complex128 {
	n := len(a)
	if n <= 1 {
		return a
	}
	even := make([]complex128, n/2)
	odd := make([]complex128, n/2)
	for i := 0; i < n/2; i++ {
		even[i] = a[2*i]
		odd[i] = a[2*i+1]
	}
	feven := fft(even)
	fodd := fft(odd)
	combined := make([]complex128, n)
	for k := 0; k < n/2; k++ {
		t := cmplx.Rect(1, -2*math.Pi*float64(k)/float64(n)) * fodd[k]
		combined[k] = feven[k] + t
		combined[k+n/2] = feven[k] - t
	}
	return combined
}

func main() {
	// Initialize audio engine
	portaudio.Initialize()
	defer portaudio.Terminate()

	const sampleRate = 44100
	const bufferSize = 512
	audioBuffer := make([]float32, bufferSize)

	stream, err := portaudio.OpenDefaultStream(1, 0, sampleRate, bufferSize, audioBuffer)
	if err != nil {
		fmt.Printf("Error opening microphone stream: %v\n", err)
		return
	}
	defer stream.Close()

	if err := stream.Start(); err != nil {
		fmt.Printf("Error starting stream: %v\n", err)
		return
	}
	defer stream.Stop()

	// Initialize simulation engine
	fluid := NewFluid(80, 0.1, 0.00001, 0.000001)

	// Clean exit handling
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)

	// Hide cursor and clear terminal window
	fmt.Print("\033[?25l\033[2J")
	defer fmt.Print("\033[?25h\033[2J\033[H")

	// Characters for ASCII fluid density gradient representation
	asciiRamp := " .':-~+=*x%#@"

	ticker := time.NewTicker(33 * time.Millisecond)
	defer ticker.Stop()

	for {
		select {
		case <-sigChan:
			return
		case <-ticker.C:
			// Read microphone audio input buffer
			_ = stream.Read()

			// Fast Fourier Transform (FFT) analysis on live audio input
			fftInput := make([]complex128, bufferSize)
			for i, v := range audioBuffer {
				// Hann windowing to prevent spectral leakage
				window := 0.5 * (1 - math.Cos(2*math.Pi*float64(i)/float64(bufferSize-1)))
				fftInput[i] = complex(float64(v)*window, 0)
			}
			fftOutput := fft(fftInput)

			// Extract Low, Mid, and High frequency band amplitudes
			var low, mid, high float64
			for i := 1; i < bufferSize/2; i++ {
				mag := cmplx.Abs(fftOutput[i])
				if i < 15 {
					low += mag
				} else if i < 60 {
					mid += mag
				} else {
					high += mag
				}
			}

			// Map frequency energy to physical fluid forces
			low = math.Min(low*0.8, 100)
			mid = math.Min(mid*0.5, 100)
			high = math.Min(high*0.3, 100)

			// Driver 1: Low frequencies (Bass) create strong central upward jet and density
			if low > 2.0 {
				fluid.AddDensity(40, 70, low*15)
				fluid.AddVelocity(40, 70, 0, -low*2.0)
			}

			// Driver 2: Mid frequencies generate vortex turbulence at left boundary
			if mid > 1.5 {
				fluid.AddDensity(15, 40, mid*10)
				fluid.AddVelocity(15, 40, mid*1.5, -mid*0.5)
			}

			// Driver 3: High frequencies trigger swirling force at right boundary
			if high > 1.0 {
				fluid.AddDensity(65, 40, high*10)
				fluid.AddVelocity(65, 40, -high*1.5, high*0.5)
			}

			// Advance fluid physics step
			fluid.Step()

			// Prepare screen buffer for flicker-free rendering
			var sb strings.Builder
			sb.WriteString("\033[H") // Move cursor to home position

			fluid.mu.Lock()
			for y := 0; y < height; y++ {
				for x := 0; x < width; x++ {
					d := fluid.density[y*width+x]
					// Map density to ASCII ramp index
					idx := int(d * float64(len(asciiRamp)-1) / 50.0)
					if idx < 0 {
						idx = 0
					}
					if idx >= len(asciiRamp) {
						idx = len(asciiRamp) - 1
					}

					// Dynamic Color response: change ANSI colors based on velocity magnitude
					vx := fluid.vx[y*width+x]
					vy := fluid.vy[y*width+x]
					speed := math.Sqrt(vx*vx + vy*vy)
					colorCode := 34 // Blue
					if speed > 3.0 {
						colorCode = 31 // Red
					} else if speed > 1.5 {
						colorCode = 33 // Yellow
					} else if speed > 0.5 {
						colorCode = 32 // Green
					}

					if idx > 0 {
						sb.WriteString("\033[" + strconv.Itoa(colorCode) + "m" + string(asciiRamp[idx]) + "\033[0m")
					} else {
						sb.WriteByte(' ')
					}
				}
				sb.WriteByte('\n')
			}
			fluid.mu.Unlock()

			// Render ASCII audio fluid simulation frame to terminal output
			fmt.Print(sb.String())
		}
	}
}

// Utility to suppress Terminal echo
func execCmd(name string, args ...string) {
	cmd := exec.Command(name, args...)
	cmd.Stdout = os.Stdout
	_ = cmd.Run()
}