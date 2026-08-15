import { EventEmitter } from 'events';

// ============================================================================
// Types & Domain Models
// ============================================================================

interface WeatherTelemetry {
  windSpeed: number;     // mph
  windDirection: number; // degrees 0-359
  pressure: number;      // hPa
  temperature: number;   // Celsius
}

type WindCompass = 'N' | 'NE' | 'E' | 'SE' | 'S' | 'SW' | 'W' | 'NW';
type PressureTrend = 'RISING' | 'FALLING' | 'STEADY';

// Word bank structured by syllable count (1, 2, 3, 4 syllables)
interface Lexicon {
  verbs: Map<number, string[]>;
  nouns: Map<number, string[]>;
  adjectives: Map<number, string[]>;
  imagery: Map<number, string[]>;
}

// ============================================================================
// Haiku Generator Engine
// ============================================================================

class ProceduralHaikuEngine {
  private lexicon: Lexicon = {
    verbs: new Map([
      [1, ['sighs', 'weeps', 'falls', 'sings', 'shifts', 'whispers', 'breathes', 'drifts', 'roars', 'calms']],
      [2, ['dances', 'gathers', 'whirls', 'slumbers', 'awakens', 'trembles', 'rises', 'shadows']],
      [3, ['awakens', 'surrenders', 'hesitates', 'disappears', 'illuminates']]
    ]),
    nouns: new Map([
      [1, ['wind', 'rain', 'sky', 'cloud', 'storm', 'gale', 'frost', 'mist', 'sun', 'air']],
      [2, ['tempest', 'zephyr', 'feather', 'horizon', 'shadow', 'breeze', 'autumn', 'winter']],
      [3, ['barometer', 'atmosphere', 'direction', 'solitude', 'wilderness']]
    ]),
    adjectives: new Map([
      [1, ['cold', 'swift', 'sharp', 'soft', 'bright', 'dark', 'deep', 'calm', 'wild', 'still']],
      [2, ['restless', 'silent', 'heavy', 'gentle', 'sudden', 'hollow', 'bitter', 'rising']],
      [3, ['unbroken', 'gathering', 'whispering', 'unseen', 'swirling']]
    ]),
    imagery: new Map([
      [1, ['leaf', 'bird', 'branch', 'stone', 'dust', 'sea']],
      [2, ['iron vane', 'rusting tin', 'rooftop edge', 'spinning brass', 'weather cock']],
      [3, ['dancing leaves', 'shifting clouds', 'falling rain', 'silent glass']]
    ])
  };

  /**
   * Generates a 5-7-5 Haiku based on environmental factors.
   */
  public compose(compass: WindCompass, trend: PressureTrend, speed: number): string[] {
    const seed = speed + compass.charCodeAt(0);
    
    // Syllable allocation rules
    // Line 1 (5): Adj(2) + Noun(1) + Verb(2) OR Imagery(3) + Verb(2)
    const line1 = (seed % 2 === 0)
      ? `${this.pick('adjectives', 2, seed)} ${this.pick('nouns', 1, seed + 1)} ${this.pick('verbs', 2, seed + 2)}`
      : `${this.pick('imagery', 3, seed)} ${this.pick('verbs', 2, seed + 1)}`;

    // Line 2 (7): Wind/Pressure Specific + Context
    let line2 = '';
    if (trend === 'FALLING') {
      line2 = `heavy sky drops low and ${this.pick('verbs', 1, seed + 3)}`;
    } else if (trend === 'RISING') {
      line2 = `clearing ${this.pick('nouns', 2, seed + 4)} ${this.pick('verbs', 2, seed + 5)} high`;
    } else {
      line2 = `the ${compass} ${this.pick('nouns', 1, seed)} ${this.pick('verbs', 2, seed + 6)} in silence`;
    }

    // Line 3 (5): Concluding imagery
    const line3 = `${this.pick('adjectives', 1, seed + 7)} ${this.pick('imagery', 2, seed + 8)} ${this.pick('verbs', 2, seed + 9)}`;

    return [line1, line2, line3];
  }

  private pick(category: keyof Lexicon, syllables: number, seed: number): string {
    const list = this.lexicon[category].get(syllables) || ['wind'];
    return list[Math.abs(Math.floor(seed)) % list.length];
  }
}

// ============================================================================
// ASCII Automaton Renderer
// ============================================================================

class WeatherVaneAutomaton {
  private frame: number = 0;

  // Compass pointers indexed by 8 principal directions
  private vanePointers: Record<WindCompass, string[]> = {
    N:  ['   ^   ', '  /|\\  ', '   |   '],
    NE: ['    /--','  / /  ','  /    '],
    E:  ['   /==>', '  /    ', '       '],
    SE: ['  \\    ', '  \\ \\  ', '    \\--'],
    S:  ['   |   ', '  \\|/  ', '   v   '],
    SW: ['--/    ', '  \\ \\  ', '    \\  '],
    W:  ['<==/   ', '    \\  ', '       '],
    NW: ['  \\    ', '  \\ \\  ', '    \\--']
  };

  /**
   * Render the complete terminal canvas.
   */
  public render(
    telemetry: WeatherTelemetry,
    compass: WindCompass,
    trend: PressureTrend,
    haiku: string[]
  ): void {
    this.frame++;
    const spinner = ['|', '/', '-', '\\'][this.frame % 4];
    const pointer = this.vanePointers[compass];

    // Build the weathercock graphic with spinning animated gear/rotor
    const asciiGraphic = [
      `       [${spinner}] NW   N   NE`,
      `        |     \\  |  /`,
      `     ${pointer[0]}  W--(+)--E`,
      `     ${pointer[1]}     /  |  \\`,
      `     ${pointer[2]}   SW   S   SE`,
      `        |`,
      `   =============`
    ];

    // Clear console (ANSI escape sequence)
    process.stdout.write('\x1Bc');

    console.log('====================================================');
    console.log('       PROCEDURAL WEATHER-VANE AUTOMATON             ');
    console.log('====================================================');
    
    // Display ASCII Graphic
    asciiGraphic.forEach(line => console.log(line));
    console.log('----------------------------------------------------');

    // Display Telemetry Dashboard
    console.log(` WIND VECTOR : ${telemetry.windSpeed.toFixed(1)} mph @ ${telemetry.windDirection}° (${compass})`);
    console.log(` BAROMETER   : ${telemetry.pressure.toFixed(1)} hPa [${trend}]`);
    console.log(` TEMP        : ${telemetry.temperature.toFixed(1)}°C`);
    console.log('----------------------------------------------------');
    console.log('                HAIKU INSCRIPTION                   ');
    console.log('----------------------------------------------------');

    // Display Haiku with visual formatting
    console.log(`   * ${haiku[0]}`);
    console.log(`   * ${haiku[1]}`);
    console.log(`   * ${haiku[2]}`);
    console.log('====================================================');
  }
}

// ============================================================================
// Telemetry Simulator & Controller
// ============================================================================

class WeatherTelemetrySimulator extends EventEmitter {
  private current: WeatherTelemetry = {
    windSpeed: 12.5,
    windDirection: 45,
    pressure: 1013.25,
    temperature: 18.0
  };

  private prevPressure: number = 1013.25;

  constructor() {
    super();
  }

  public start(intervalMs: number = 1500): void {
    setInterval(() => {
      this.mutate();
      this.emit('telemetry', this.current, this.getPressureTrend());
    }, intervalMs);
  }

  private mutate(): void {
    // Random walk simulation for weather metrics
    this.current.windSpeed = Math.max(0, this.current.windSpeed + (Math.random() - 0.48) * 3);
    this.current.windDirection = (this.current.windDirection + (Math.random() - 0.5) * 20 + 360) % 360;
    
    this.prevPressure = this.current.pressure;
    this.current.pressure += (Math.random() - 0.5) * 1.2;
    this.current.temperature += (Math.random() - 0.5) * 0.2;
  }

  private getPressureTrend(): PressureTrend {
    const diff = this.current.pressure - this.prevPressure;
    if (diff > 0.15) return 'RISING';
    if (diff < -0.15) return 'FALLING';
    return 'STEADY';
  }
}

// ============================================================================
// Orchestration / Main Entry Point
// ============================================================================

function degreesToCompass(deg: number): WindCompass {
  const directions: WindCompass[] = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
  const index = Math.round(deg / 45) % 8;
  return directions[index];
}

function main() {
  const simulator = new WeatherTelemetrySimulator();
  const haikuEngine = new ProceduralHaikuEngine();
  const automaton = new WeatherVaneAutomaton();

  simulator.on('telemetry', (data: WeatherTelemetry, trend: PressureTrend) => {
    const compass = degreesToCompass(data.windDirection);
    const poem = haikuEngine.compose(compass, trend, data.windSpeed);
    automaton.render(data, compass, trend, poem);
  });

  simulator.start(1000);
}

// Run automaton
main();