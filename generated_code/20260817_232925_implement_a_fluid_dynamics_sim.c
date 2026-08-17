/*
 * Perpetual Fluid Vortex CSS Generator
 * 
 * This C program outputs a single line of unformatted pure CSS.
 * When applied to a blank HTML document, it uses HTML/Body pseudo-elements,
 * organic morphing geometry, dual-rotating conic gradients, and heavy fluid 
 * blur-contrast thresholding to simulate continuous swirling liquid dynamics.
 */

#include <stdio.h>

int main(void) {
    puts("html,body{margin:0;height:100%;background:#020208;overflow:hidden;display:grid;place-items:center}body::before,body::after{content:'';position:absolute;width:160vmax;height:160vmax;background:conic-gradient(from 0deg,#000 0%,#0f2027 20%,#203a43 40%,#2c5364 60%,#00d2ff 80%,#000 100%);border-radius:41% 59% 45% 55%/52% 38% 62% 48%;animation:vortex 7s linear infinite;filter:blur(35px) contrast(200%);mix-blend-mode:screen}body::after{animation-duration:11s;animation-direction:reverse;opacity:0.75;background:conic-gradient(from 180deg,#000 0%,#4a00e0 30%,#8e2de2 60%,#00d2ff 85%,#000 100%)}@keyframes vortex{100%{transform:rotate(360deg)}}");
    return 0;
}