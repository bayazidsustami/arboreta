#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <math.h>
#include <time.h>

#define SAMPLE_RATE 44100
#define BUFFER_SIZE 512
#define MAX_RANKS 4

/* Represents a microtonal organ pipe with pitch bending and harmonic registration */
typedef struct {
    double frequency;     /* Fundamental frequency in Hz (microtonally tuned) */
    double phase;         /* Current phase offset [0, 1) */
    double harmonic_mult; /* Registration harmonic multiplier */
    double wind_pressure; /* Airflow intensity governing amplitude and pitch drift */
} OrganPipe;

/* Translates incoming raw satellite telemetry telemetry frames into musical parameters */
typedef struct {
    uint32_t raw_altitude;  /* Orbital altitude in meters */
    uint16_t raw_velocity;  /* Orbital speed in m/s */
    uint8_t  solar_flux;    /* Solar panel flux level */
    int8_t   thermal_state; /* Internal module temperature */
} TelemetryFrame;

/* Generates simulated satellite telemetry streams using dynamic orbital dynamics */
static TelemetryFrame ingest_telemetry(double time_sec) {
    TelemetryFrame frame;
    frame.raw_altitude = 400000 + (uint32_t)(5000.0 * sin(time_sec * 0.001));
    frame.raw_velocity = 7660 + (uint16_t)(100.0 * cos(time_sec * 0.002));
    frame.solar_flux = (uint8_t)(128.0 + 127.0 * sin(time_sec * 0.05));
    frame.thermal_state = (int8_t)(20.0 + 15.0 * cos(time_sec * 0.01));
    return frame;
}

/* Converts telemetry values to 24-Tone Equal Temperament (24-TET) microtonal frequencies */
static double telemetry_to_microtonal_freq(uint32_t alt, int8_t temp, int step) {
    /* Base pitch derived from orbital altitude mapping */
    int midi_cents = (alt % 4800) / 100; /* Map to 48 microtonal steps (2 octaves) */
    int microtonal_pitch = midi_cents + (temp % 12);
    
    /* 24-TET calculation: Freq = A4 (440Hz) * 2^((step - 69) / 24) */
    double octave_offset = (double)(microtonal_pitch + step * 3 - 24) / 24.0;
    return 220.0 * pow(2.0, octave_offset);
}

int main(void) {
    OrganPipe rank[MAX_RANKS];
    TelemetryFrame current_frame;
    double time_sec = 0.0;
    double delta_t = 1.0 / SAMPLE_RATE;
    int16_t audio_buffer[BUFFER_SIZE];

    /* Initialize pipe rank harmonics (Fundamental, Quint, Octave, Micro-Third) */
    double harmonics[MAX_RANKS] = {1.0, 1.4983, 2.0, 2.4142}; 
    for (int i = 0; i < MAX_RANKS; i++) {
        rank[i].phase = 0.0;
        rank[i].harmonic_mult = harmonics[i];
        rank[i].wind_pressure = 0.0;
    }

    /* Continuously translate telemetry stream into generative organ audio */
    while (1) {
        /* Ingest live satellite frame every frame interval */
        current_frame = ingest_telemetry(time_sec);

        /* Map solar flux and thermal variation into organ wind-chest pressure dynamics */
        double target_pressure = (double)current_frame.solar_flux / 255.0;

        for (int i = 0; i < MAX_RANKS; i++) {
            /* Map altitude & velocity to 24-TET microtonal fundamental frequencies */
            double base_freq = telemetry_to_microtonal_freq(
                current_frame.raw_altitude, 
                current_frame.thermal_state, 
                i
            );
            
            /* Apply slight wind drift based on satellite velocity jitter */
            double wind_drift = 1.0 + 0.002 * sin(time_sec * 3.14 + i);
            rank[i].frequency = base_freq * rank[i].harmonic_mult * wind_drift;

            /* Smoothly slew organ pipe wind pressure */
            rank[i].wind_pressure += (target_pressure - rank[i].wind_pressure) * 0.01;
        }

        /* Synthesize raw PCM 16-bit mono audio stream */
        for (int s = 0; s < BUFFER_SIZE; s++) {
            double sample = 0.0;

            for (int i = 0; i < MAX_RANKS; i++) {
                /* Pipe organ tone generation using additive synthesis with wind-chest instability */
                double wave = sin(2.0 * M_PI * rank[i].phase);
                /* Add subtle organ chiff/breath noise scaled by wind pressure */
                double chiff = ((double)rand() / RAND_MAX - 0.5) * 0.05 * rank[i].wind_pressure;
                
                sample += (wave + chiff) * (0.2 * rank[i].wind_pressure);

                /* Advance pipe phase accumulator */
                rank[i].phase += rank[i].frequency * delta_t;
                if (rank[i].phase >= 1.0) {
                    rank[i].phase -= 1.0;
                }
            }

            time_sec += delta_t;

            /* Soft-clipping limiter to maintain ambient warmth */
            if (sample > 1.0) sample = 1.0;
            if (sample < -1.0) sample = -1.0;

            audio_buffer[s] = (int16_t)(sample * 32767.0);
        }

        /* Pipe raw PCM audio output directly to stdout for streaming/playback */
        fwrite(audio_buffer, sizeof(int16_t), BUFFER_SIZE, stdout);
    }

    return 0;
}