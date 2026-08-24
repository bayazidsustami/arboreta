// Self-Modulated WebAudio AST Generative Synthesizer
// This Rust WebAssembly module reads its own source code AST (Abstract Syntax Tree)
// and uses the recursive tree hierarchy to schedule a rhythmic and harmonic WebAudio score.

use proc_macro2::{TokenStream, TokenTree};
use std::str::FromStr;
use wasm_bindgen::prelude::*;
use web_sys::{AudioContext, GainNode, OscillatorNode, OscillatorType};

// Embed the module's own source code at compile time for AST inspection.
const SELF_SOURCE: &str = include_str!(file!());

#[wasm_bindgen(start)]
pub fn main_js() -> Result<(), JsValue> {
    // 1. Initialize the WebAudio context and master output gain stage
    let ctx = AudioContext::new()?;
    let master_gain = ctx.create_gain()?;
    master_gain.gain().set_value(0.15);
    master_gain.connect(&ctx.destination())?;

    // 2. Parse the self-referential Rust code into a macro AST token stream
    let tokens = TokenStream::from_str(SELF_SOURCE)
        .map_err(|e| JsValue::from_str(&format!("AST Parse Error: {:?}", e)))?;

    // 3. Traverse the AST nodes to build and schedule the generative score
    let start_time = ctx.current_time() + 0.1;
    walk_ast_branch(&ctx, &master_gain, tokens, start_time, 0.25, 0);

    Ok(())
}

/// Recursively traverses AST syntax trees (Group, Ident, Punct, Literal)
/// mapping node depth, token type, and subtree weight into WebAudio nodes.
fn walk_ast_branch(
    ctx: &AudioContext,
    output: &GainNode,
    tokens: TokenStream,
    mut time: f64,
    step_duration: f64,
    depth: usize,
) -> f64 {
    for token in tokens {
        match token {
            // Sub-branches (delimited blocks `{...}`, `(...)`, `[...]`) generate chordal layers
            TokenTree::Group(group) => {
                let inner_stream = group.stream();
                let branch_duration = step_duration * 0.8;
                
                // Polyphonic recursion: process nested AST branches deeper down the tree
                let sub_end_time = walk_ast_branch(
                    ctx,
                    output,
                    inner_stream,
                    time,
                    branch_duration,
                    depth + 1,
                );
                
                // Advance score timeline by the parsed length of the branch
                time = sub_end_time;
            }
            
            // Identifiers modulate frequency pitch according to token length and structural depth
            TokenTree::Ident(ident) => {
                let len = ident.to_string().len() as f32;
                let pitch = 110.0 * (1.5f32).powi((len % 12.0) as i32) * (depth as f32 * 0.2 + 1.0);
                
                schedule_ast_synth_note(ctx, output, pitch, OscillatorType::Sawtooth, time, step_duration * 0.5);
                time += step_duration;
            }

            // Punctuation tokens introduce rhythmic percussive blips and polyrhythmic delays
            TokenTree::Punct(punct) => {
                let char_code = punct.as_char() as u32;
                let pitch = 800.0 + (char_code % 1200) as f32;
                let synth_type = if punct.as_char() == ';' { OscillatorType::Square } else { OscillatorType::Triangle };

                schedule_ast_synth_note(ctx, output, pitch, synth_type, time, 0.05);
                time += step_duration * 0.5;
            }

            // Numeric/String literals construct sub-bass grounding pulses
            TokenTree::Literal(lit) => {
                let lit_len = lit.to_string().len() as f32;
                let bass_freq = 55.0 + (lit_len * 5.0);
                
                schedule_ast_synth_note(ctx, output, bass_freq, OscillatorType::Sine, time, step_duration * 1.5);
                time += step_duration * 1.25;
            }
        }
    }
    time
}

/// Schedules an individual WebAudio oscillator node with an exponential gain decay envelope.
fn schedule_ast_synth_note(
    ctx: &AudioContext,
    output: &GainNode,
    freq: f32,
    wave: OscillatorType,
    start_time: f64,
    duration: f64,
) {
    if let (Ok(osc), Ok(note_gain)) = (ctx.create_oscillator(), ctx.create_gain()) {
        osc.set_type(wave);
        osc.frequency().set_value(freq);

        // Exponential decay amplitude envelope
        let gain_param = note_gain.gain();
        gain_param.set_value_at_time(0.4, start_time).ok();
        gain_param.exponential_ramp_to_value_at_time(0.0001, start_time + duration).ok();

        // Connect signal routing: Osc -> Note Gain Envelope -> Master Gain
        osc.connect(&note_gain).ok();
        note_gain.connect(output).ok();

        // Play note according to score timing
        osc.start_with_when(start_time).ok();
        osc.stop_with_when(start_time + duration).ok();
    }
}