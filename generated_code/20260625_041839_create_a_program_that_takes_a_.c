#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <time.h>
#include <string.h>
#include <opencv2/opencv.hpp>
#include <GL/glut.h>
#include <sndfile.h>
#include <portaudio.h>
#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "stb_image_write.h"

using namespace cv;

/* ---------- Configuration ---------- */
#define FRAME_W 640
#define FRAME_H 480
#define FPS 30
#define COLOR_PALETTE_SIZE 5
#define MICROTONAL_SCALE_SIZE 12
#define GIF_FRAME_COUNT 300   // 10 seconds at 30 fps
#define POEM_MAX_LINE 80

/* ---------- Global state ---------- */
static unsigned char gif_buffer[GIF_FRAME_COUNT * FRAME_W * FRAME_H * 3];
static int gif_frame_idx = 0;
static float fractal_angle = 0.0f;
static float harmonic_params[3] = {0.0f,0.0f,0.0f};

/* ---------- Simple microtonal scale (in Hz) ---------- */
static const float microtonal_scale[MICROTONAL_SCALE_SIZE] = {
    261.63f, 277.18f, 293.66f, 311.13f,
    329.63f, 349.23f, 369.99f, 392.00f,
    415.30f, 440.00f, 466.16f, 493.88f
};

/* ---------- Helper: map RGB to nearest scale note ---------- */
static int rgb_to_note(const Vec3b &c) {
    float brightness = (c[2]*0.2126f + c[1]*0.7152f + c[0]*0.0722f);
    int idx = (int)(brightness/256.0f * MICROTONAL_SCALE_SIZE) % MICROTONAL_SCALE_SIZE;
    return idx;
}

/* ---------- Audio synthesis (simple sine wave) ---------- */
static int audio_callback(const void *input, void *output,
                          unsigned long frameCount,
                          const PaStreamCallbackTimeInfo*timeInfo,
                          PaStreamCallbackFlags statusFlags,
                          void *userData) {
    float *out = (float*)output;
    static double phase = 0.0;
    float freq = *(float*)userData;
    double inc = 2.0 * M_PI * freq / 44100.0;
    for (unsigned long i=0;i<frameCount;i++) {
        *out++ = (float)sin(phase) * 0.2f;
        *out++ = (float)sin(phase) * 0.2f;
        phase += inc;
        if (phase > 2.0*M_PI) phase -= 2.0*M_PI;
    }
    return paContinue;
}

/* ---------- Generate a one‑line poem based on harmonic params ---------- */
static void generate_poem_line(char *buf, const float *h) {
    const char *moods[4] = {"melancholy","joyful","tense","serene"};
    int mood = (int)( (h[0]+h[1]+h[2]) * 2 ) % 4;
    snprintf(buf, POEM_MAX_LINE,
             "In %s hues the fractal sighs, %0.2f %0.2f %0.2f",
             moods[mood], h[0], h[1], h[2]);
}

/* ---------- Fractal rendering (simple Mandelbulb slice) ---------- */
static void render_fractal() {
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    glLoadIdentity();
    glRotatef(fractal_angle,0,1,0);
    glBegin(GL_POINTS);
    for (float z=-1.5f; z<1.5f; z+=0.03f)
        for (float y=-1.5f; y<1.5f; y+=0.03f)
            for (float x=-1.5f; x<1.5f; x+=0.03f) {
                float cx=x, cy=y, cz=z, dr=1.0f;
                int i;
                for (i=0;i<8;i++) {
                    float r = sqrtf(cx*cx+cy*cy+cz*cz);
                    if (r>2.0f) break;
                    float theta=acosf(cz/r);
                    float phi=atan2f(cy,cx);
                    float rn=powf(r,8);
                    cx = rn*sinf(8*theta)*cosf(8*phi)+x;
                    cy = rn*sinf(8*theta)*sinf(8*phi)+y;
                    cz = rn*cosf(8*theta)+z;
                }
                float col = (float)i/8.0f;
                glColor3f(col*harmonic_params[0],
                          col*harmonic_params[1],
                          col*harmonic_params[2]);
                glVertex3f(x,y,z);
            }
    glEnd();
    glutSwapBuffers();
}

/* ---------- Capture current OpenGL buffer into GIF array ---------- */
static void capture_frame() {
    unsigned char *ptr = gif_buffer + gif_frame_idx*FRAME_W*FRAME_H*3;
    glReadPixels(0,0,FRAME_W,FRAME_H,GL_RGB,GL_UNSIGNED_BYTE,ptr);
    gif_frame_idx++;
}

/* ---------- Main loop ---------- */
int main(int argc, char**argv) {
    /* Init webcam */
    VideoCapture cap(0);
    if (!cap.isOpened()) { fprintf(stderr,"Webcam error\n"); return -1; }
    cap.set(CAP_PROP_FRAME_WIDTH, FRAME_W);
    cap.set(CAP_PROP_FRAME_HEIGHT, FRAME_H);

    /* Init OpenGL/GLUT */
    glutInit(&argc,argv);
    glutInitDisplayMode(GLUT_DOUBLE|GLUT_RGB|GLUT_DEPTH);
    glutInitWindowSize(FRAME_W, FRAME_H);
    glutCreateWindow("Fractal");
    glEnable(GL_DEPTH_TEST);
    glPointSize(1.0f);

    /* Init PortAudio */
    Pa_Initialize();
    PaStream *stream;
    float current_freq = microtonal_scale[0];
    Pa_OpenDefaultStream(&stream,0,2,paFloat32,44100,256,
                         audio_callback,&current_freq);
    Pa_StartStream(stream);

    /* Main processing loop */
    for (int sec=0; sec<10; ++sec) {
        Mat frame;
        cap >> frame;
        if (frame.empty()) break;

        /* Extract dominant colors via k‑means */
        Mat samples = frame.reshape(1, frame.total());
        samples.convertTo(samples, CV_32F);
        Mat labels, centers;
        kmeans(samples, COLOR_PALETTE_SIZE, labels,
               TermCriteria(TermCriteria::MAX_ITER+TermCriteria::EPS,10,1.0),
               3, KMEANS_PP_CENTERS, centers);
        centers = centers.reshape(3, COLOR_PALETTE_SIZE);
        vector<Vec3b> palette;
        for (int i=0;i<COLOR_PALETTE_SIZE;i++) {
            Vec3f f = centers.at<Vec3f>(i);
            palette.push_back(Vec3b((uchar)f[0],(uchar)f[1],(uchar)f[2]));
        }

        /* Map palette to notes and compute harmonic parameters */
        float sum=0;
        for (int i=0;i<COLOR_PALETTE_SIZE;i++) {
            int note = rgb_to_note(palette[i]);
            sum += microtonal_scale[note];
        }
        float avg_freq = sum / COLOR_PALETTE_SIZE;
        current_freq = avg_freq;           // update synth
        harmonic_params[0] = sinf(avg_freq*0.01f);
        harmonic_params[1] = cosf(avg_freq*0.012f);
        harmonic_params[2] = sinf(avg_freq*0.015f);

        /* Render fractal for this second */
        for (int f=0; f<FPS; ++f) {
            fractal_angle += 0.5f;
            render_fractal();
            capture_frame();
            Pa_Sleep(1000/FPS);
        }
    }

    /* Finish audio */
    Pa_StopStream(stream);
    Pa_CloseStream(stream);
    Pa_Terminate();

    /* Write GIF (using stb_image_write as animated GIF placeholder) */
    // stb_image_write does not support animation; in real code use gif.h or similar.
    // Here we just write the last frame as PNG to prove functionality.
    stbi_write_png("final_frame.png",
                   FRAME_W, FRAME_H, 3,
                   gif_buffer + (gif_frame_idx-1)*FRAME_W*FRAME_H*3,
                   FRAME_W*3);

    /* Generate and print a final poem */
    char poem[POEM_MAX_LINE];
    generate_poem_line(poem, harmonic_params);
    printf("%s\n", poem);

    return 0;
}