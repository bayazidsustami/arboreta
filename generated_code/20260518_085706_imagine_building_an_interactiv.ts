```typescript
// Generative Poetry System - Weather-inspired Living Text Installation
// This creates an evolving poetic experience based on simulated weather data

interface WeatherData {
  temperature: number;
  humidity: number;
  windSpeed: number;
  pressure: number;
  condition: 'sunny' | 'cloudy' | 'rainy' | 'stormy' | 'misty';
  timestamp: Date;
}

interface PoeticElements {
  vowels: string;
  consonants: string;
  rhythmPattern: number[];
  imagery: string[];
  mood: string;
}

class WeatherPoetryGenerator {
  private weatherHistory: WeatherData[] = [];
  private stanzaCounter: number = 0;
  private galleryWords: string[] = [];
  
  // Atmospheric word banks organized by weather condition
  private readonly weatherLexicon = {
    sunny: {
      adjectives: ['golden', 'radiant', 'blazing', 'luminous', 'crystalline'],
      verbs: ['shimmer', 'dance', 'flare', 'pulse', 'ignite'],
      nouns: ['light', 'flare', 'crown', 'domain', 'symphony'],
      sounds: ['whisper', 'hum', 'trill', 'chime', 'glisten']
    },
    cloudy: {
      adjectives: ['muffled', 'drifting', 'veiled', 'suspended', 'opalescent'],
      verbs: ['drift', 'gather', 'hover', 'unfurl', 'cascade'],
      nouns: ['mist', 'veil', 'hush', 'canvas', 'lament'],
      sounds: ['murmur', 'sigh', 'echo', 'ripple', 'float']
    },
    rainy: {
      adjectives: ['silver', 'pattering', 'washing', 'dripping', 'melancholy'],
      verbs: ['pour', 'trace', 'nurture', 'cascade', 'whisper'],
      nouns: ['tears', 'threads', 'paths', 'ritual', 'memory'],
      sounds: ['patter', 'splash', 'trickle', 'drum', 'weep']
    },
    stormy: {
      adjectives: ['electric', 'turbulent', 'cracking', 'furious', 'galvanic'],
      verbs: ['crack', 'roar', 'surge', 'rend', 'ignite'],
      nouns: ['thunder', 'chaos', 'beacon', 'tempest', 'revolution'],
      sounds: ['crash', 'boom', 'split', 'howl', 'rage']
    },
    misty: {
      adjectives: ['ethereal', 'floating', 'gauzy', 'uncanny', 'diaphanous'],
      verbs: ['dissolve', 'merge', 'veil', 'transform', 'materialize'],
      nouns: ['ghost', 'veil', 'threshold', 'reverie', 'phantom'],
      sounds: ['hush', 'sibilance', 'whisper', 'fade', 'melt']
    }
  };

  // Generate simulated weather data with temporal patterns
  generateWeather(): WeatherData {
    const hour = new Date().getHours();
    const dayProgress = (hour % 12) / 12;
    
    // Weather transitions throughout virtual day
    let condition: WeatherData['condition'] = 'sunny';
    if (dayProgress < 0.2) condition = 'misty';
    else if (dayProgress < 0.4) condition = 'sunny';
    else if (dayProgress < 0.6) condition = Math.random() > 0.5 ? 'cloudy' : 'rainy';
    else if (dayProgress < 0.8) condition = 'stormy';
    else condition = 'cloudy';

    const weather: WeatherData = {
      temperature: Math.round(15 + Math.random() * 20 + Math.sin(dayProgress * Math.PI) * 10),
      humidity: Math.round(40 + Math.random() * 40),
      windSpeed: Math.round(Math.random() * 15),
      pressure: Math.round(1000 + Math.random() * 30),
      condition,
      timestamp: new Date()
    };

    this.weatherHistory.push(weather);
    if (this.weatherHistory.length > 10) this.weatherHistory.shift();
    return weather;
  }

  // Extract poetic elements from weather data
  extractPoeticElements(weather: WeatherData): PoeticElements {
    const lexicon = this.weatherLexicon[weather.condition];
    
    // Temperature affects vowel/consonant balance
    const vowelRatio = Math.max(0.3, Math.min(0.7, (weather.temperature - 15) / 30 + 0.5));
    const vowelCount = Math.round(15 * vowelRatio);
    const consonantCount = 15 - vowelCount;
    
    const vowels = 'aeiou'.repeat(Math.ceil(vowelCount / 5)).slice(0, vowelCount);
    const consonants = 'bcdfghjklmnpqrstvwxyz'.repeat(Math.ceil(consonantCount / 21)).slice(0, consonantCount);
    
    // Wind speed determines rhythm complexity
    const rhythmPattern = Array.from({ length: 3 + Math.floor(weather.windSpeed / 5) }, (_, i) => 
      Math.round((weather.humidity / 100) * (4 + i % 3))
    );

    return {
      vowels,
      consonants,
      rhythmPattern,
      imagery: [
        ...lexicon.adjectives.map(a => `the ${a} ${lexicon.nouns[Math.floor(Math.random() * lexicon.nouns.length)]}`),
        ...lexicon.verbs.map(v => `${v} like ${lexicon.sounds[Math.floor(Math.random() * lexicon.sounds.length)]}`)
      ],
      mood: weather.condition
    };
  }

  // Generate a stanza based on weather and gallery memory
  generateStanza(weather: WeatherData, elements: PoeticElements): string {
    const { vowels, consonants, rhythmPattern, imagery, mood } = elements;
    const lexicon = this.weatherLexicon[mood];
    
    // Incorporate gallery memory - echo previous words
    const memoryEcho = this.galleryWords.length > 0 
      ? ` ${this.galleryWords[Math.floor(Math.random() * this.galleryWords.length)]}` 
      : '';
    
    // Create syllables based on rhythm pattern
    const lines: string[] = [];
    for (let lineIdx = 0; lineIdx < rhythmPattern.length; lineIdx++) {
      const syllableCount = rhythmPattern[lineIdx];
      let line = '';
      
      for (let sylIdx = 0; sylIdx < syllableCount; sylIdx++) {
        const useVowel = sylIdx % 2 === 0 || Math.random() > 0.5;
        const syllable = useVowel 
          ? vowels[Math.floor(Math.random() * vowels.length)] + 
            (Math.random() > 0.5 ? consonants[Math.floor(Math.random() * consonants.length)] : '')
          : consonants[Math.floor(Math.random() * consonants.length)] + 
            vowels[Math.floor(Math.random() * vowels.length)];
        
        line += syllable + (sylIdx < syllableCount - 1 ? '-' : '');
        
        // Add imagery at line breaks
        if (sylIdx === syllableCount - 1 && imagery.length > 0) {
          line += `, ${imagery[Math.floor(Math.random() * imagery.length)]}`;
          this.galleryWords.push(...imagery);
          if (this.galleryWords.length > 50) this.galleryWords = this.galleryWords.slice(-50);
        }
      }
      
      line += memoryEcho;
      lines.push(line.charAt(0).toUpperCase() + line.slice(1) + '.');
    }
    
    this.stanzaCounter++;
    return lines.join('\n');
  }

  // Generate complete poem with title
  generatePoem(weather: WeatherData): string {
    const elements = this.extractPoeticElements(weather);
    const title = this.generateTitle(weather, elements);
    const stanzas: string[] = [];
    
    // Generate 3 evolving stanzas
    for (let i = 0; i < 3; i++) {
      stanzas.push(this.generateStanza(weather, elements));
    }
    
    return `${title}\n\n${stanzas.join('\n\n')}`;
  }

  // Create weather-responsive title
  private generateTitle(weather: WeatherData, elements: PoeticElements): string {
    const lexicon = this.weatherLexicon[weather.condition];
    const templates = [
      `${lexicon.adjectives[0].charAt(0).toUpperCase() + lexicon.adjectives[0].slice(1)} ${lexicon.nouns[0]}`,
      `Measurements of ${weather.temperature}° Reverie`,
      `${weather.condition.charAt(0).toUpperCase() + weather.condition.slice(1)} Algorithms`,
      `Signal from Station ${Math.floor(Math.random() * 100)}`,
      `Barometric Lullaby (${weather.pressure}hPa)`
    ];
    return templates[Math.floor(Math.random() * templates.length)];
  }

  // Gallery installation rendering with animation cues
  renderInstallation(poem: string): string {
    const lines = poem.split('\n');
    let installation = '\n' + '═'.repeat(50) + '\n';
    
    lines.forEach((line, index) => {
      const indent = '  '.repeat(index % 3);
      const animation = Math.sin(index * 0.5) > 0 ? '↻' : '↺';
      installation += `${indent}${animation} ${line}\n`;
    });
    
    installation += '═'.repeat(50) + '\n';
    return installation;
  }
}

// Living Gallery System - manages real-time evolution
class LivingGallery {
  private generator: WeatherPoetryGenerator;
  private isActive: boolean = false;
  private intervalId?: NodeJS.Timeout;
  
  constructor() {
    this.generator = new WeatherPoetryGenerator();
  }
  
  start(): void {
    if (this.isActive) return;
    this.isActive = true;
    
    console.log('\n🌿 DIGITAL GALLERY INSTALLATION: Weather Poetry System 🌿\n');
    
    // Generate initial poem
    this.cycle(true);
    
    // Continue evolving
    this.intervalId = setInterval(() => this.cycle(), 8000);
  }
  
  stop(): void {
    this.isActive = false;
    if (this.intervalId) clearInterval(this.intervalId);
  }
  
  private cycle(initial: boolean = false): void {
    const weather = this.generator.generateWeather();
    const poem = this.generator.generatePoem(weather);
    const installation = this.generator.renderInstallation(poem);
    
    console.clear();
    console.log(installation);
    
    // Display weather telemetry
    console.log(`Conditions: ${weather.condition} | ${weather.temperature}°C | ${weather.humidity}% humidity | ${weather.windSpeed} m/s winds`);
    console.log(`Last updated: ${weather.timestamp.toLocaleTimeString()}`);
    console.log('\nThe gallery breathes with the atmosphere...\n');
  }
}

// Interactive shell interface
class InteractiveGallery extends LivingGallery {
  private readline = require('readline');
  private rl = this.readline.createInterface({
    input: process.stdin,
    output: process.stdout
  });
  
  constructor() {
    super();
  }
  
  start(): void {
    super.start();
    this.setupInteraction();
  }
  
  private setupInteraction(): void {
    this.rl.on('line', (input: string) => {
      const cmd = input.trim().toLowerCase();
      
      if (cmd === 'pause') {
        this.stop();
        console.log('\n⏸️  Gallery paused. Press any key to resume...');
        this.rl.pause();
      } else if (cmd === 'exit' || cmd === 'quit') {
        this.stop();
        console.log('\n🌙 Gallery closing. Thank you for visiting.\n');
        process.exit(0);
      } else if (cmd === 'weather') {
        const w = this['generator'].generateWeather();
        console.log(`\n📡 Current Atmospheric Data:`);
        console.log(JSON.stringify(w, null, 2));
      } else {
        console.log(`Commands: pause | exit | weather`);
      }
    });
    
    this.rl.on('close', () => {
      this.stop();
      process.exit(0);
    });
  }
}

// Main execution
const gallery = new InteractiveGallery();
gallery.start();

// Graceful shutdown
process.on('SIGINT', () => {
  console.log('\n\n🌙 Gallery closing gracefully...\n');
  process.exit(0);
});
```