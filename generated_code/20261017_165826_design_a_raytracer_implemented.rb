#!/usr/bin/env ruby
# frozen_string_literal: true

# surreal_landscape_generator.rb
# Generates a self-contained HTML document featuring a CSS-based raytraced 
# surreal landscape of melting digital clocks via complex box-shadows, 
# coupled with a Web Audio API generative ambient soundscape modulated by mouse coordinates.

HTML_CONTENT = <<~HTML
  <!DOCTYPE html>
  <html lang="en">
  <head>
      <meta charset="UTF-8">
      <title>Surreal Melting Clocks - CSS Raytracer & Generative Audio</title>
      <style>
          body {
              margin: 0;
              height: 100vh;
              background: radial-gradient(circle at center, #1a0b2e 0%, #05020a 100%);
              overflow: hidden;
              display: flex;
              justify-content: center;
              align-items: center;
              font-family: monospace;
          }

          /* The surreal 3D landscape rendered via box-shadow raytracing simulation */
          .raytracer-viewport {
              position: relative;
              width: 1px;
              height: 1px;
              /* Simulating 3D voxels/geometry through layered box-shadows */
              box-shadow: 
                  /* Distant surreal mountains / terrain */
                  -200px -100px 40px 10px rgba(138, 43, 226, 0.4),
                  180px -120px 50px 15px rgba(75, 0, 130, 0.5),
                  0px -150px 80px 30px rgba(186, 85, 211, 0.3),
                  /* Melting digital clock 1 (Salvador Dali style distortion) */
                  -60px -20px 0px 12px #00ffcc,
                  -55px -10px 15px 8px rgba(0, 255, 204, 0.6),
                  -45px 15px 25px 6px rgba(0, 255, 204, 0.3),
                  -30px 40px 40px 4px rgba(0, 255, 204, 0.1),
                  /* Melting digital clock 2 */
                  90px 10px 0px 15px #ff007f,
                  85px 25px 20px 10px rgba(255, 0, 127, 0.5),
                  75px 50px 30px 6px rgba(255, 0, 127, 0.2),
                  /* Ground plane grid lines */
                  -300px 100px 2px 1px rgba(0, 255, 255, 0.2),
                  -150px 100px 2px 1px rgba(0, 255, 255, 0.2),
                  0px 100px 2px 1px rgba(0, 255, 255, 0.2),
                  150px 100px 2px 1px rgba(0, 255, 255, 0.2),
                  300px 100px 2px 1px rgba(0, 255, 255, 0.2);
              animation: melt 10s ease-in-out infinite alternate;
          }

          @keyframes melt {
              0% {
                  transform: scale(1) rotateX(15deg) rotateY(0deg);
                  filter: hue-rotate(0deg);
              }
              100% {
                  transform: scale(1.1) rotateX(25deg) rotateY(10deg);
                  filter: hue-rotate(90deg);
              }
          }

          .info {
              position: absolute;
              bottom: 20px;
              color: rgba(255, 255, 255, 0.6);
              font-size: 12px;
              letter-spacing: 2px;
              pointer-events: none;
              text-align: center;
              width: 100%;
          }
      </style>
  </head>
  <body>
      <div class="raytracer-viewport"></div>
      <div class="info">MOVE MOUSE TO MODULATE GENERATIVE AMBIENT SOUNDSCAPE</div>

      <script>
          // Generative Ambient Soundscape via Web Audio API modulated by mouse coordinates
          let audioCtx = null;
          let oscillator = null;
          let gainNode = null;
          let filterNode = null;

          function initAudio() {
              if (audioCtx) return;
              audioCtx = new (window.AudioContext || window.webkitAudioContext)();

              // Create ambient drone nodes
              oscillator = audioCtx.createOscillator();
              filterNode = audioCtx.createBiquadFilter();
              gainNode = audioCtx.createGain();

              oscillator.type = 'sawtooth';
              oscillator.frequency.setValueAtTime(55, audioCtx.currentTime); // Base A1 note

              filterNode.type = 'lowpass';
              filterNode.frequency.setValueAtTime(400, audioCtx.currentTime);

              gainNode.gain.setValueAtTime(0.05, audioCtx.currentTime);

              oscillator.connect(filterNode);
              filterNode.connect(gainNode);
              gainNode.connect(audioCtx.destination);

              oscillator.start();
          }

          window.addEventListener('mousemove', (e) => {
              if (!audioCtx) {
                  initAudio();
              }

              const xNorm = e.clientX / window.innerWidth;
              const yNorm = e.clientY / window.innerHeight;

              // Modulate frequency and filter based on mouse X/Y coordinates
              if (oscillator && filterNode) {
                  const freq = 55 + xNorm * 220; // Range: 55Hz to 275Hz
                  const cutoff = 100 + yNorm * 2000; // Range: 100Hz to 2100Hz
                  
                  oscillator.frequency.setTargetAtTime(freq, audioCtx.currentTime, 0.1);
                  filterNode.frequency.setTargetAtTime(cutoff, audioCtx.currentTime, 0.1);
              }
          });

          // Initial interaction trigger
          window.addEventListener('click', () => {
              if (!audioCtx) initAudio();
          }, { once: true });
      </script>
  </body>
  </html>
HTML

output_file = 'surreal_clocks.html'
File.write(output_file, HTML_CONTENT)
puts "Successfully generated #{output_file}. Open it in any modern browser to experience the surreal CSS raytracer and generative soundscape."