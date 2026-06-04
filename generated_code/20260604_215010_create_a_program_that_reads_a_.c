#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <string.h>
#include <pthread.h>
#include <unistd.h>
#include <stdint.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <signal.h>

/*--------------------------------------------------------------
Dependencies (must be installed):
 - PortAudio (for audio capture)
 - FFTW3 (for FFT)
 - libmicrohttpd (for lightweight HTTP server)
 Compile with:
 gcc -o audio_forest audio_forest.c -lportaudio -lfftw3 -lmicrohttpd -lm -lpthread
--------------------------------------------------------------*/

#include <portaudio.h>
#include <fftw3.h>
#include <microhttpd.h>

#define SAMPLE_RATE   44100
#define FRAMES_PER_BUFFER 1024
#define FFT_SIZE      1024
#define PORT          8080

/* Global structures for sharing audio analysis results */
typedef struct {
    float spectral_centroid;
    float timbre_variance;
    int   onset;               /* 1 if onset detected, else 0 */
    pthread_mutex_t lock;
} analysis_t;

static analysis_t g_analysis = {0,0,0,PTHREAD_MUTEX_INITIALIZER};

/*------------------- Audio Callback ---------------------------*/
static int audioCallback(const void *inputBuffer, void *outputBuffer,
                         unsigned long framesPerBuffer,
                         const PaStreamCallbackTimeInfo* timeInfo,
                         PaStreamCallbackFlags statusFlags,
                         void *userData)
{
    (void)outputBuffer; (void)timeInfo; (void)statusFlags; (void)userData;
    const float *in = (const float*)inputBuffer;
    static float window[FFT_SIZE];
    static fftwf_plan plan = NULL;
    static float *in_buf = NULL;
    static fftwf_complex *out_buf = NULL;
    static int idx = 0;

    if (!plan) {
        in_buf = fftwf_malloc(sizeof(float)*FFT_SIZE);
        out_buf = fftwf_malloc(sizeof(fftwf_complex)* (FFT_SIZE/2+1));
        plan = fftwf_plan_dft_r2c_1d(FFT_SIZE, in_buf, out_buf, FFTW_MEASURE);
        /* Hann window */
        for (int i=0;i<FFT_SIZE;i++) window[i]=0.5f*(1.0f-cosf(2.0f*M_PI*i/(FFT_SIZE-1)));
    }

    for (unsigned long i=0;i<framesPerBuffer;i++) {
        in_buf[idx] = in[i] * window[idx];
        idx++;
        if (idx==FFT_SIZE) {
            fftwf_execute(plan);
            /* Compute magnitude spectrum */
            float sumMag=0.0f, sumFreq=0.0f, sumSq=0.0f;
            for (int k=0;k<=FFT_SIZE/2;k++) {
                float re=out_buf[k][0];
                float im=out_buf[k][1];
                float mag=sqrtf(re*re+im*im);
                float freq = (float)k * SAMPLE_RATE / FFT_SIZE;
                sumMag+=mag;
                sumFreq+=mag*freq;
                sumSq+=mag*mag;
            }
            float centroid = sumMag>0 ? sumFreq/sumMag : 0.0f;
            float variance = sumMag>0 ? sqrtf(fmaxf(0.0f, (sumSq/sumMag) - centroid*centroid)) : 0.0f;

            /* Simple onset detection: compare energy to moving average */
            static float energy_avg=0.0f;
            float frameEnergy=0.0f;
            for (int k=0;k<=FFT_SIZE/2;k++) {
                float re=out_buf[k][0];
                float im=out_buf[k][1];
                frameEnergy+=re*re+im*im;
            }
            int onset = (frameEnergy > 1.5f*energy_avg) ? 1 : 0;
            energy_avg = 0.9f*energy_avg + 0.1f*frameEnergy;

            pthread_mutex_lock(&g_analysis.lock);
            g_analysis.spectral_centroid = centroid;
            g_analysis.timbre_variance   = variance;
            g_analysis.onset            = onset;
            pthread_mutex_unlock(&g_analysis.lock);

            idx=0;
        }
    }
    return paContinue;
}

/*------------------- HTTP Server -----------------------------*/
static int answer_to_connection(void *cls,
                                struct MHD_Connection *connection,
                                const char *url,
                                const char *method,
                                const char *version,
                                const char *upload_data,
                                size_t *upload_data_size,
                                void **con_cls)
{
    (void)cls; (void)version; (void)upload_data; (void)upload_data_size; (void)con_cls;
    if (0 != strcmp(method, "GET"))
        return MHD_NO;

    if (strcmp(url, "/") == 0) {
        const char *page =
            "<!DOCTYPE html>"
            "<html><head><meta charset='utf-8'><title>Audio Forest</title>"
            "<style>body{margin:0;overflow:hidden;}</style>"
            "</head><body>"
            "<canvas id='glcanvas'></canvas>"
            "<script>"
            "let canvas=document.getElementById('glcanvas');"
            "canvas.width=window.innerWidth;canvas.height=window.innerHeight;"
            "let gl=canvas.getContext('webgl');"
            "if(!gl){document.body.innerHTML='WebGL not supported';}"
            "function resize(){canvas.width=window.innerWidth;canvas.height=window.innerHeight;}"
            "window.onresize=resize;"
            "let ws=new WebSocket('ws://' + location.hostname + ':8081');"
            "let forest=[];let camPos=[0,0,5];"
            "ws.onmessage=e=>{let d=JSON.parse(e.data);"
            "  // Simple rule: add a branch when onset"
            "  if(d.onset){forest.push({x: Math.random()*2-1, y:0, z: Math.random()*2-1, c:d.centroid});}"
            "};"
            "function draw(){"
            "  gl.viewport(0,0,canvas.width,canvas.height);"
            "  gl.clearColor(0.1,0.1,0.15,1);gl.clear(gl.COLOR_BUFFER_BIT|gl.DEPTH_BUFFER_BIT);"
            "  // Placeholder: render points for each node"
            "  forest.forEach(node=>{"
            "    // compute color from centroid"
            "    let col=Math.min(1,node.c/2000);"
            "    // draw using simple GL points (not fully implemented)"
            "  });"
            "  requestAnimationFrame(draw);"
            "}"
            "draw();"
            "</script>"
            "</body></html>";
        struct MHD_Response *resp = MHD_create_response_from_buffer(strlen(page),
                                    (void*)page, MHD_RESPMEM_PERSISTENT);
        int ret = MHD_queue_response(connection, MHD_HTTP_OK, resp);
        MHD_destroy_response(resp);
        return ret;
    }
    return MHD_NO;
}

/*------------------- WebSocket Thread ------------------------*/
#include <sys/types.h>
#include <sys/socket.h>
#include <netdb.h>

static void *ws_thread(void *arg)
{
    (void)arg;
    int sockfd = socket(AF_INET, SOCK_STREAM, 0);
    struct sockaddr_in servaddr = {0};
    servaddr.sin_family = AF_INET;
    servaddr.sin_addr.s_addr = INADDR_ANY;
    servaddr.sin_port = htons(8081);
    bind(sockfd, (struct sockaddr*)&servaddr, sizeof(servaddr));
    listen(sockfd, 5);
    while (1) {
        int client = accept(sockfd, NULL, NULL);
        if (client < 0) continue;
        /* Very tiny WebSocket handshake (no validation) */
        char buffer[1024];
        recv(client, buffer, sizeof(buffer), 0);
        const char *resp =
            "HTTP/1.1 101 Switching Protocols\r\n"
            "Upgrade: websocket\r\n"
            "Connection: Upgrade\r\n"
            "Sec-WebSocket-Accept: placeholder\r\n\r\n";
        send(client, resp, strlen(resp), 0);
        /* Send JSON updates at 30 Hz */
        while (1) {
            pthread_mutex_lock(&g_analysis.lock);
            float c = g_analysis.spectral_centroid;
            float t = g_analysis.timbre_variance;
            int o   = g_analysis.onset;
            pthread_mutex_unlock(&g_analysis.lock);
            char json[128];
            snprintf(json, sizeof(json),
                     "{\"centroid\":%.2f,\"timbre\":%.2f,\"onset\":%d}",
                     c, t, o);
            /* Simple unmasked frame */
            uint8_t hdr[2] = {0x81, (uint8_t)strlen(json)};
            send(client, hdr, 2, 0);
            send(client, json, strlen(json), 0);
            usleep(33333);
        }
        close(client);
    }
    close(sockfd);
    return NULL;
}

/*------------------- Main ------------------------------------*/
int main(void)
{
    PaError err;
    PaStream *stream;
    Pa_Initialize();
    err = Pa_OpenDefaultStream(&stream,
                               1,          /* mono input */
                               0,          /* no output */
                               paFloat32,
                               SAMPLE_RATE,
                               FRAMES_PER_BUFFER,
                               audioCallback,
                               NULL);
    if (err != paNoError) {fprintf(stderr,"PortAudio error\n");return 1;}
    Pa_StartStream(stream);

    struct MHD_Daemon *daemon = MHD_start_daemon(MHD_USE_SELECT_INTERNALLY,
                                                 PORT,
                                                 NULL,NULL,
                                                 &answer_to_connection,
                                                 NULL,
                                                 MHD_OPTION_END);
    if (!daemon) {fprintf(stderr,"Failed to start HTTP daemon\n");return 1;}

    pthread_t ws_tid;
    pthread_create(&ws_tid, NULL, ws_thread, NULL);

    printf("Server running at http://localhost:%d\nPress Ctrl+C to quit.\n", PORT);
    while (1) pause();

    /* Cleanup (unreachable) */
    Pa_StopStream(stream);
    Pa_CloseStream(stream);
    Pa_Terminate();
    MHD_stop_daemon(daemon);
    return 0;
}