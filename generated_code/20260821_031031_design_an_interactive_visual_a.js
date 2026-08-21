import { useEffect, useRef } from 'react';

// Main Application Component for Web Application Environment
export default function WikipediaTapestry() {
  const canvasRef = useRef(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    let animationFrameId;

    // Resize handling
    const resize = () => {
      canvas.width = window.innerWidth;
      canvas.height = window.innerHeight;
    };
    resize();
    window.addEventListener('resize', resize);

    // Topic Category to Hue mapping
    const TOPIC_HUES = {
      tech: 200,      // Electric Blue
      science: 160,   // Teal/Emerald
      culture: 330,   // Magenta/Rose
      history: 35,    // Gold/Amber
      geography: 90,  // Leaf Green
      politics: 10,   // Crimson
      general: 270    // Deep Violet
    };

    // Classify Wikipedia edits based on title/summary keywords
    const classifyTopic = (title = '') => {
      const lower = title.toLowerCase();
      if (/tech|software|computer|internet|ai|data|code|game|wiki/.test(lower)) return 'tech';
      if (/science|physics|biology|space|chem|med|planet|species/.test(lower)) return 'science';
      if (/music|film|art|book|actor|album|culture|sport|league/.test(lower)) return 'culture';
      if (/war|history|century|empire|revolution|king|president|battle/.test(lower)) return 'history';
      if (/city|country|river|mountain|state|island|map|location/.test(lower)) return 'geography';
      if (/election|law|party|gov|politic|court|minister/.test(lower)) return 'politics';
      return 'general';
    };

    // Calculate edit sentiment/intent based on character delta
    const analyzeSentiment = (delta) => {
      if (delta > 200) return { label: 'Major Addition', polarity: 1.0, tension: 0.2 };
      if (delta > 0) return { label: 'Minor Addition', polarity: 0.5, tension: 0.5 };
      if (delta === 0) return { label: 'Format/Refactor', polarity: 0.0, tension: 0.8 };
      if (delta > -100) return { label: 'Minor Removal', polarity: -0.5, tension: 1.2 };
      return { label: 'Major Reversion', polarity: -1.0, tension: 2.0 };
    };

    // Thread class representing individual continuous warp/weft streams
    class Thread {
      constructor(editData) {
        this.reset(editData);
      }

      reset(edit) {
        const topic = classifyTopic(edit.title);
        const sentiment = analyzeSentiment(edit.delta);

        this.hue = TOPIC_HUES[topic] + (Math.random() * 30 - 15);
        this.saturation = Math.min(100, Math.max(40, 50 + Math.abs(edit.delta) * 0.1));
        this.lightness = edit.bot ? 70 : 45 + sentiment.polarity * 15;

        // Size dictates thread thickness
        this.thickness = Math.min(12, Math.max(0.8, Math.log2(Math.abs(edit.delta) + 1) * 0.8));

        // Sentiment controls wave frequency and wobble speed
        this.frequency = 0.005 + sentiment.tension * 0.015;
        this.wobbleSpeed = 0.01 + Math.random() * 0.02;

        // Positioning
        this.isWarp = Math.random() > 0.5; // Vertical or Horizontal weaving
        this.x = this.isWarp ? Math.random() * canvas.width : 0;
        this.y = this.isWarp ? 0 : Math.random() * canvas.height;

        this.length = 0;
        this.maxLength = this.isWarp ? canvas.height : canvas.width;
        this.speed = 2 + Math.random() * 3 + Math.min(5, Math.abs(edit.delta) * 0.01);
        this.phase = Math.random() * Math.PI * 2;
        this.alpha = 0.7;
        this.decay = 0.0005;
        this.title = edit.title;
        this.user = edit.user;
      }

      update() {
        this.length += this.speed;
        this.phase += this.wobbleSpeed;
        this.alpha -= this.decay;
        return this.length < this.maxLength && this.alpha > 0;
      }

      draw(context) {
        context.save();
        context.beginPath();

        const offset = Math.sin(this.length * this.frequency + this.phase) * (10 / this.thickness);

        if (this.isWarp) {
          const currentY = this.length;
          const currentX = this.x + offset;
          context.moveTo(currentX, Math.max(0, currentY - this.speed * 2));
          context.lineTo(currentX, currentY);
        } else {
          const currentX = this.length;
          const currentY = this.y + offset;
          context.moveTo(Math.max(0, currentX - this.speed * 2), currentY);
          context.lineTo(currentX, currentY);
        }

        context.strokeStyle = `hsla(${this.hue}, ${this.saturation}%, ${this.lightness}%, ${this.alpha})`;
        context.lineWidth = this.thickness;
        context.lineCap = 'round';
        context.shadowColor = `hsla(${this.hue}, 100%, 50%, 0.3)`;
        context.shadowBlur = this.thickness > 4 ? 6 : 0;
        context.stroke();
        context.restore();
      }
    }

    const threads = [];
    let socket;

    // Connect to Wikimedia EventStreams real-time edit stream
    const connectStream = () => {
      socket = new EventSource('[https://stream.wikimedia.org/v2/stream/recentchange](https://stream.wikimedia.org/v2/stream/recentchange)');

      socket.onmessage = (event) => {
        try {
          const data = JSON.parse(event.data);
          // Filter for main namespace article edits in English Wikipedia
          if (data.wiki === 'enwiki' && data.type === 'edit' && data.namespace === 0) {
            const edit = {
              title: data.title,
              user: data.user,
              delta: (data.length?.new || 0) - (data.length?.old || 0),
              bot: data.bot || false
            };

            // Spawn dynamic threads per edit
            const threadCount = Math.min(3, Math.max(1, Math.floor(Math.abs(edit.delta) / 100)));
            for (let i = 0; i < threadCount; i++) {
              if (threads.length < 300) {
                threads.push(new Thread(edit));
              }
            }
          }
        } catch (err) {
          // Silent stream parse safety
        }
      };

      socket.onerror = () => {
        setTimeout(connectStream, 5000);
      };
    };

    connectStream();

    // Render loop creating tapestry fabric trails
    const render = () => {
      // Lightly decay canvas background to preserve weave texture trails
      ctx.fillStyle = 'rgba(10, 8, 15, 0.03)';
      ctx.fillRect(0, 0, canvas.width, canvas.height);

      // Render woven threads
      for (let i = threads.length - 1; i >= 0; i--) {
        const thread = threads[i];
        thread.draw(ctx);
        if (!thread.update()) {
          threads.splice(i, 1);
        }
      }

      animationFrameId = requestAnimationFrame(render);
    };

    render();

    return () => {
      cancelAnimationFrame(animationFrameId);
      window.removeEventListener('resize', resize);
      if (socket) socket.close();
    };
  }, []);

  return (
    <div style={{ position: 'relative', width: '100vw', height: '100vh', overflow: 'hidden', background: '#0a080f' }}>
      <canvas ref={canvasRef} style={{ display: 'block' }} />
      <div style={{
        position: 'absolute',
        bottom: '20px',
        left: '20px',
        color: 'rgba(255,255,255,0.7)',
        fontFamily: 'monospace',
        fontSize: '12px',
        pointerEvents: 'none',
        background: 'rgba(0,0,0,0.5)',
        padding: '10px 15px',
        borderRadius: '8px',
        backdropFilter: 'blur(4px)'
      }}>
        <div style={{ fontWeight: 'bold', marginBottom: '4px' }}>WIKIPEDIA EDIT TAPESTRY</div>
        <div>Hue: Topic Category | Density/Width: Edit Delta Size</div>
        <div>Wobble: Edit Sentiment/Tension | Brightness: Human vs Bot</div>
      </div>
    </div>
  );
}