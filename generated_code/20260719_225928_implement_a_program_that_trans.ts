import { Octokit } from "@octokit/rest";

// --- Types & Interfaces ---
interface CodeChange {
  type: 'variable_rename' | 'deletion' | 'syntax_error' | 'standard';
  details: string;
}

interface JazzElement {
  time: string;
  action: string;
  description: string;
}

// --- Mock Data Generator for Standalone Execution ---
// In a production environment, this would parse git diffs or AST trees from Webhooks.
const generateMockCommits = (): CodeChange[] => {
  const changes: CodeChange[] = [
    { type: 'standard', details: 'Added basic loop structure.' },
    { type: 'variable_rename', details: 'Renamed x to userProfileCount' },
    { type: 'deletion', details: 'Removed 45 lines of legacy boilerplate.' },
    { type: 'standard', details: 'Refactored utility functions.' },
    { type: 'syntax_error', details: 'Missing closing parenthesis on line 42.' },
    { type: 'variable_rename', details: 'Renamed data to validatedPayload' },
    { type: 'deletion', details: 'Deleted unused experimental endpoint.' },
  ];
  return changes;
};

// --- The Generative Jazz Conductor ---
class JazzConductor {
  private currentKey: string = 'C Major';
  private octokit: Octokit | null = null;

  constructor(repoOwner?: string, repoName?: string) {
    if (repoOwner && repoName) {
      // If credentials are provided, we could initialize real GitHub polling
      this.octokit = new Octokit();
    }
  }

  /**
   * Processes a specific code change and translates it into a jazz performance element.
   */
  public translateCodeToJazz(change: CodeChange): JazzElement {
    const timestamp = new Date().toLocaleTimeString();

    switch (change.type) {
      case 'variable_rename':
        this.currentKey = this.deriveKeySignature(change.details);
        return {
          time: timestamp,
          action: '🎵 Key Modulation',
          description: `Variable rename detected ("${change.details}"). Smooth modulation to ${this.currentKey}.`
        };

      case 'deletion':
        return {
          time: timestamp,
          action: '🥁 Syncopated Drum Break',
          description: `Code deletion event! Triggering a fast 5/4 swing break to clean the sonic slate.`
        };

      case 'syntax_error':
        return {
          time: timestamp,
          action: '🎹 Dissonant Chord (Diminished/Sharp 11)',
          description: `Syntax Error! Injecting a tense, crunchy C7#11 chord to reflect the broken build.`
        };

      case 'standard':
      default:
        return {
          time: timestamp,
          action: '🎷 Walking Bass & Comping',
          description: `Standard commit. Laying down a steady, rhythmic walking bassline in ${this.currentKey}.`
        };
    }
  }

  /**
   * Generates a pseudo-random key signature based on the length of the renamed variable.
   */
  private deriveKeySignature(details: string): string {
    const keys = ['Db Major', 'G Minor', 'Ab Major', 'F# Major', 'E Minor', 'A Major', 'Bb Major'];
    const index = details.length % keys.length;
    return keys[index];
  }

  /**
   * Drives the real-time simulation of the generative jazz track.
   */
  public async perform(cycles: number = 7): Promise<void> {
    console.log("================================================================================");
    console.log("🎷 STARTING REAL-TIME GIT-JAZZ GENERATOR 🎷");
    console.log(`Starting Jam Session. Initial Key: ${this.currentKey}`);
    console.log("================================================================================");

    const stream = generateMockCommits();
    
    for (let i = 0; i < Math.min(cycles, stream.length); i++) {
      // Simulate real-time delay between incoming repository events
      await new Promise(resolve => setTimeout(resolve, 1500));
      
      const jazzElement = this.translateCodeToJazz(stream[i]);
      
      console.log(`[${jazzElement.time}] ${jazzElement.action}`);
      console.log(`      > ${jazzElement.description}\n`);
    }

    console.log("================================================================================");
    console.log("🏁 Outro: The repository goes quiet. The band fades out on a major 9th chord.");
    console.log("================================================================================");
  }
}

// --- Execution Entry Point ---
const session = new JazzConductor();
session.perform();