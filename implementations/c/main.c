#include "renderer.h"
#include "audio.h"
#include "sokol_app.h"
#include "sokol_audio.h"
#include "sokol_log.h"
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static Audio audio;
static bool keys[SAPP_MAX_KEYCODES];
static float x=184, y=380, time_s, cooldown;
static int frames, frame_limit;
static const char *capture;
static void init(void) {
    if (!renderer_init(GNARLAXX_ASSET_ROOT) || !audio_load(&audio, GNARLAXX_ASSET_ROOT)) exit(1);
    saudio_setup(&(saudio_desc){.sample_rate=44100, .num_channels=2, .buffer_frames=512,
        .packet_frames=128, .num_packets=16, .logger.func=slog_func});
    printf("C foundation: graphics ready, audio=%s, decoded audio=%.2f MiB\n",
        saudio_isvalid()?"ready":"unavailable", audio.decoded_bytes/1048576.0);
}
static void frame(void) {
    float dt=(float)fmin(sapp_frame_duration(), .05);
    time_s+=dt; cooldown-=dt;
    x += ((keys[SAPP_KEYCODE_D]?1:0)-(keys[SAPP_KEYCODE_A]?1:0))*200*dt;
    y += ((keys[SAPP_KEYCODE_S]?1:0)-(keys[SAPP_KEYCODE_W]?1:0))*200*dt;
    x=fmaxf(0,fminf(368,x)); y=fmaxf(32,fminf(452,y));
    if (keys[SAPP_KEYCODE_SPACE] && cooldown<=0) {audio_play(&audio,SOUND_PLAYER_SHOT,.5f);cooldown=.15f;}
    if (saudio_isvalid()) {
        int remaining=saudio_expect(); float buffer[2048];
        while (remaining>0) {int n=remaining>1024?1024:remaining;audio_mix(&audio,buffer,n,saudio_sample_rate());saudio_push(buffer,n);remaining-=n;}
    }
    renderer_begin();
    for(int layer=0;layer<2;layer++) for(int row=-1;row<17;row++) for(int col=0;col<13;col++) {
        Sprite id=(Sprite)((layer?SPR_STARS_NEAR_0:SPR_STARS_FAR_0)+((row+2)%2)*2+col%2);
        renderer_sprite(id,col*32,row*32+fmodf(time_s*(layer?28:9),64),1,0xffffffff);
    }
    renderer_sprite(SPR_TITLE,68,80,1,0xffffffff);
    renderer_text("C / SOKOL / METAL",128,150,1,0x82dae9ff);
    renderer_text("WASD MOVE - SPACE SOUND",112,220,1,0xffffffff);
    renderer_sprite(keys[SAPP_KEYCODE_A]?SPR_PLAYER_LEFT:keys[SAPP_KEYCODE_D]?SPR_PLAYER_RIGHT:SPR_PLAYER_IDLE,x,y,1,0xffffffff);
    renderer_present();
    if(frame_limit && ++frames>=frame_limit) {if(capture&&!renderer_capture(capture))exit(2);sapp_request_quit();}
}
static void event(const sapp_event *e) {
    if(e->key_code<SAPP_MAX_KEYCODES && (e->type==SAPP_EVENTTYPE_KEY_DOWN||e->type==SAPP_EVENTTYPE_KEY_UP))keys[e->key_code]=e->type==SAPP_EVENTTYPE_KEY_DOWN;
    if(e->type==SAPP_EVENTTYPE_KEY_DOWN&&e->key_code==SAPP_KEYCODE_ESCAPE)sapp_request_quit();
}
static void cleanup(void){saudio_shutdown();audio_destroy(&audio);renderer_shutdown();}
sapp_desc sokol_main(int argc,char **argv){
    for(int i=1;i<argc;i++){
        if(!strcmp(argv[i],"--frames")&&i+1<argc)frame_limit=atoi(argv[++i]);
        else if(!strcmp(argv[i],"--capture")&&i+1<argc)capture=argv[++i];
    }
    return (sapp_desc){.init_cb=init,.frame_cb=frame,.event_cb=event,.cleanup_cb=cleanup,
        .width=800,.height=1000,.window_title="Gnarlaxx - C",.high_dpi=true,.sample_count=1,
        .icon.sokol_default=true,.logger.func=slog_func};
}
