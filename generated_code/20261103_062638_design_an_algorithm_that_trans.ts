interface Vector2D {
  x: number;
  y: number;
}

interface Shape {
  id: string;
  type: 'triangle' | 'square' | 'circle';
  position: Vector2D;
  velocity: Vector2D;
  basePitch: number;
}

interface MusicalEvent {
  timestamp: number;
  shapeId: string;
  note: number;
  pressure: number;
  canvasBounds: { width: number; height: number };
}

class AtmosphericFlockCanvas {
  private width: number = 800;
  private height: number = 800;
  private shrinkRate: number = 3.5;
  private shapes: Shape[] = [];
  private score: MusicalEvent[] = [];

  constructor(shapeCount: number, private basePressure: number = 1013.25) {
    const types: ('triangle' | 'square' | 'circle')[] = ['triangle', 'square', 'circle'];
    for (let i = 0; i < shapeCount; i++) {
      this.shapes.push({
        id: `geom_${i + 1}`,
        type: types[i % types.length],
        position: { x: Math.random() * this.width, y: Math.random() * this.height },
        velocity: { x: (Math.random() - 0.5) * 8, y: (Math.random() - 0.5) * 8 },
        basePitch: 48 + (i * 4) % 36 // Pentatonic-friendly scale spread
      });
    }
  }

  // Simulate incoming dynamic barometric pressure data stream
  private getAtmosphericPressure(tick: number): number {
    return this.basePressure + Math.sin(tick * 0.15) * 20 + Math.cos(tick * 0.05) * 10;
  }

  // Progress simulation step: shrink canvas, update physics, and trigger score notes on collision
  public tick(step: number): void {
    this.width = Math.max(120, this.width - this.shrinkRate);
    this.height = Math.max(120, this.height - this.shrinkRate);

    const currentPressure = this.getAtmosphericPressure(step);
    const pressureModulator = currentPressure / this.basePressure;

    for (const shape of this.shapes) {
      shape.position.x += shape.velocity.x * pressureModulator;
      shape.position.y += shape.velocity.y * pressureModulator;

      let boundaryHit = false;

      if (shape.position.x <= 0 || shape.position.x >= this.width) {
        shape.velocity.x *= -1;
        shape.position.x = Math.max(0, Math.min(this.width, shape.position.x));
        boundaryHit = true;
      }

      if (shape.position.y <= 0 || shape.position.y >= this.height) {
        shape.velocity.y *= -1;
        shape.position.y = Math.max(0, Math.min(this.height, shape.position.y));
        boundaryHit = true;
      }

      if (boundaryHit) {
        const pressureOffset = Math.floor((currentPressure - this.basePressure) / 5);
        const activeNote = Math.max(36, Math.min(96, shape.basePitch + pressureOffset));

        this.score.push({
          timestamp: step,
          shapeId: shape.id,
          note: activeNote,
          pressure: parseFloat(currentPressure.toFixed(2)),
          canvasBounds: { width: Math.round(this.width), height: Math.round(this.height) }
        });
      }
    }
  }

  public composeScore(durationTicks: number): MusicalEvent[] {
    for (let t = 1; t <= durationTicks; t++) {
      this.tick(t);
    }
    return this.score;
  }
}

// Execute simulation and output musical score
const synthesizer = new AtmosphericFlockCanvas(4, 1013.25);
const persistentScore = synthesizer.composeScore(40);
console.log(JSON.stringify(persistentScore, null, 2));