#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

/* Simple MIDI parser (type 0, only Note On/Off and Set Tempo) */
typedef struct {
    uint32_t time;      /* absolute ticks */
    uint8_t  type;      /* 0 = note_on, 1 = note_off, 2 = tempo */
    uint8_t  channel;
    uint8_t  note;      /* 0-127 for note events */
    uint8_t  vel;       /* velocity */
    uint32_t tempo;     /* microseconds per quarter note for tempo events */
} Event;

static uint32_t read_uint32_be(FILE *f){ uint32_t v; fread(&v,4,1,f); return __builtin_bswap32(v);}
static uint16_t read_uint16_be(FILE *f){ uint16_t v; fread(&v,2,1,f); return __builtin_bswap16(v);}
static uint32_t read_varlen(FILE *f){
    uint32_t v=0, b;
    do{
        b=fgetc(f);
        v=(v<<7)|(b&0x7F);
    }while(b&0x80);
    return v;
}

/* Write escaped JSON string */
static void json_escape(FILE *out, const char *s){
    fputc('"',out);
    for(;*s;s++){
        if(*s=='"'||*s=='\\') { fputc('\\',out); fputc(*s,out);}
        else if(*s=='\n') fputs("\\n",out);
        else fputc(*s,out);
    }
    fputc('"',out);
}

int main(int argc,char**argv){
    if(argc!=2){fprintf(stderr,"usage: %s file.mid\n",argv[0]);return 1;}
    FILE *f=fopen(argv[1],"rb");
    if(!f){perror("fopen");return 1;}
    /* header */
    if(read_uint32_be(f)!=0x4D546864){fprintf(stderr,"not a MIDI file\n");return 1;}
    fseek(f,6,SEEK_CUR); /* header length + format/type */
    uint16_t ntrks=read_uint16_be(f);
    uint16_t division=read_uint16_be(f);
    uint32_t tick_per_quarter=division;
    Event *events=NULL;
    size_t evcnt=0, evcap=0;
    uint32_t tempo=500000; /* default 120 BPM */
    for(int t=0;t<ntrks;t++){
        if(read_uint32_be(f)!=0x4D54726B){fprintf(stderr,"bad track\n");return 1;}
        uint32_t trklen=read_uint32_be(f);
        long trkend=ftell(f)+trklen;
        uint32_t abstime=0;
        int running_status=0;
        while(ftell(f)<trkend){
            uint32_t delta=read_varlen(f);
            abstime+=delta;
            int c=fgetc(f);
            if(c&0x80){ running_status=c; }
            else{ ungetc(c,f); c=running_status; }
            uint8_t type=c>>4, chan=c&0x0F;
            if(type==0xF){ /* meta or sysex */
                int meta=fgetc(f);
                uint32_t len=read_varlen(f);
                if(meta==0x51 && len==3){ /* set tempo */
                    uint32_t us=
                        (fgetc(f)<<16)|(fgetc(f)<<8)|fgetc(f);
                    if(evcnt==evcap){evcap=evcap?evcap*2:128;events=realloc(events,evcap*sizeof*events));}
                    events[evcnt++] = (Event){abstime,2,0,0,0,us};
                }else fseek(f,len,SEEK_CUR);
            }else if(type==0x9 && type!=0x8){ /* Note On */
                uint8_t note=fgetc(f), vel=fgetc(f);
                if(vel==0){ type=0x8; } /* treat zero velocity as Note Off */
                if(evcnt==evcap){evcap=evcap?evcap*2:128;events=realloc(events,evcap*sizeof*events));}
                events[evcnt++] = (Event){abstime,0,chan,note,vel,0};
            }else if(type==0x8){ /* Note Off */
                uint8_t note=fgetc(f), vel=fgetc(f);
                if(evcnt==evcap){evcap=evcap?evcap*2:128;events=realloc(events,evcap*sizeof*events));}
                events[evcnt++] = (Event){abstime,1,chan,note,vel,0};
            }else{
                /* skip other messages */
                fgetc(f); fgetc(f);
            }
        }
    }
    fclose(f);
    /* sort events by time */
    qsort(events,evcnt,sizeof*events,
        (int(*)(const void*,const void*))[](const Event*a,const Event*b){return (int)(a->time-b->time);});
    /* write HTML */
    FILE *out=fopen("output.html","w");
    if(!out){perror("fopen out");return 1;}
    fprintf(out,"<!DOCTYPE html><html><head><meta charset='utf-8'><title>MIDI Fractal</title>"
                "<style>body{margin:0;background:#000;color:#0f0;font-family:monospace}"
                "#canvas{position:absolute;top:0;left:0;width:100%%;height:100%%}</style></head><body>"
                "<canvas id='canvas'></canvas><script>"
                "const ctx=document.getElementById('canvas').getContext('2d');"
                "let W=canvas.width=window.innerWidth, H=canvas.height=window.innerHeight;"
                "window.onresize=()=>{W=canvas.width=innerWidth;H=canvas.height=innerHeight;};"
                "const events=[");
    for(size_t i=0;i<evcnt;i++){
        Event *e=&events[i];
        fprintf(out,"{t:%u,type:%u,ch:%u,n:%u,v:%u,tempo:%u}",e->time,e->type,e->channel,e->note,e->vel,e->tempo);
        if(i+1<evcnt) fputc(',',out);
    }
    fprintf(out,"];"
                "let tpq=%u,curTempo=500000,ptr=0,now=0;"
                "function midiToFreq(n){return 440*Math.pow(2,(n-69)/12);}"
                "function schedule(){"
                "if(ptr>=events.length)return;"
                "let e=events[ptr];"
                "let delta=e.t-now;"
                "let ms=delta*curTempo/tpq/1000;"
                "setTimeout(()=>{handle(e);now=e.t;ptr++;schedule();},ms);"
                "}"
                "function handle(e){"
                "if(e.type===2){curTempo=e.tempo;return;}"
                "let freq=midiToFreq(e.n);"
                "let osc=new (window.AudioContext||webkitAudioContext)().createOscillator();"
                "osc.type='sine';osc.frequency.value=freq;osc.connect((new AudioContext()).destination);"
                "if(e.type===0){osc.start(); setTimeout(()=>osc.stop(),0.3*1000);} // note on"
                "drawFractal(e.n,e.ch);"
                "}"
                "function drawFractal(note,ch){"
                "let maxIter=30+ (note%10);"
                "let scale=4/(1+ch*0.5);"
                "for(let i=0;i<maxIter;i++){"
                "let x=(Math.random()*2-1)*scale, y=(Math.random()*2-1)*scale;"
                "let zx=0, zy=0, iter=0;"
                "while(zx*zx+zy*zy<4 && iter<50){let xt=zx*zx-zy*zy+x; zy=2*zx*zy+y; zx=xt; iter++;}"
                "let col=iter===50?0:Math.floor(255*iter/50);"
                "ctx.fillStyle='rgb('+col+','+(255-col)+','+((note*5)%255)+')';"
                "ctx.fillRect(W/2+zx*W/4,H/2+zy*H/4,2,2);}"
                "}"
                "schedule();"
                "</script></body></html>");
    fclose(out);
    free(events);
    return 0;
}