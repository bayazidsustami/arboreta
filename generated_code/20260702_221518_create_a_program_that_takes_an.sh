#!/usr/bin/env bash
# poetmandala.sh – turn a poem into a live‑updating mandala shader
# Dependencies: glslviewer (or any GLSL runner that watches the file), awk, sed, tr

# ---------- CONFIG ----------
SHADER_FILE="/tmp/poem_mandala.glsl"
PARAMS_FILE="/tmp/poem_params.txt"
UPDATE_INTERVAL=0.2   # seconds between shader rewrites
# ---------------------------------------------------------

# Simple syllable counter (naïve vowel groups)
syllable_count() {
    echo "$1" | tr '[:upper:]' '[:lower:]' |
    sed -E 's/[^aeiouy]+//g' |
    grep -o '[aeiouy]+' | wc -l
}

# Very crude stress estimator: even syllables stressed
stress_pattern() {
    local cnt=$1
    local pattern=""
    for ((i=1;i<=cnt;i++)); do
        (( i % 2 )) && pattern+="1" || pattern+="0"
    done
    echo "$pattern"
}

# Mood detection via tiny sentiment word lists
mood_score() {
    local word=$1
    case "$word" in
        love|joy|bright|hope|sun*) echo 1 ;;
        sad|dark|pain|cry|rain*) echo -1 ;;
        *) echo 0 ;;
    esac
}

# Build initial shader skeleton
cat >"$SHADER_FILE" <<'EOF'
#version 330 core
out vec4 fragColor;
uniform float iTime;
uniform vec3 moodColor;

void main(){
    vec2 uv = (gl_FragCoord.xy / vec2(800.0,600.0)) * 2.0 - 1.0;
    float r = length(uv);
    float a = atan(uv.y, uv.x);
    // swirling mandala pattern
    float n = sin(10.0*a + iTime*0.5) * cos(5.0*r - iTime);
    float intensity = smoothstep(0.4,0.0,abs(n));
    fragColor = vec4(moodColor * intensity, 1.0);
}
EOF

# Function to recompute parameters from poem text
update_params() {
    local text="$1"
    local total_syll=0 total_stress=0 total_mood=0 wordcnt=0

    for w in $text; do
        ((wordcnt++))
        syl=$(syllable_count "$w")
        ((total_syll+=syl))
        stress=$(stress_pattern "$syl")
        # count stressed (1) vs unstressed (0)
        stress1=$(echo "$stress" | tr -cd '1' | wc -c)
        ((total_stress+=stress1))
        mood=$(mood_score "$w")
        ((total_mood+=mood))
    done

    # Derive colors from mood average (-1..1)
    avg_mood=$(awk "BEGIN{print $total_mood/$wordcnt}")
    # map to HSV hue: sad->blue (0.6), neutral->green (0.33), joy->red (0.0)
    hue=$(awk "BEGIN{ if($avg_mood<0) h=0.6+0.33*$avg_mood; else h=0.33-0.33*$avg_mood; print h }")
    # convert HSV to RGB (simple)
    rgb=$(awk -v h=$hue 'function f(n){return n<0?0:n>1?1:n}
        BEGIN{
            i=int(h*6); f=h*6-i; p=0; q=1-f; t=f;
            switch(i%6){
                case 0: r=1; g=t; b=0; break;
                case 1: r=q; g=1; b=0; break;
                case 2: r=0; g=1; b=p; break;
                case 3: r=0; g=q; b=1; break;
                case 4: r=p; g=0; b=1; break;
                case 5: r=1; g=0; b=t; break;
            }
            printf "%.3f %.3f %.3f", r,g,b;
        }')
    echo "$rgb" >"$PARAMS_FILE"
}

# Start glslviewer in background, watching the shader file
glslviewer "$SHADER_FILE" &
VIEWER_PID=$!

# Main loop: read poem from stdin, update shader parameters
printf "Enter your poem (Ctrl-D to finish):\n"
poem=$(cat)   # read whole stdin
# preprocess: keep only words
words=$(echo "$poem" | tr -c '[:alnum:]' ' ' | tr '[:upper:]' '[:lower:]')
update_params "$words"

# Watch parameters file and inject uniform updates into shader
while kill -0 $VIEWER_PID 2>/dev/null; do
    if [[ -f $PARAMS_FILE ]]; then
        read -r r g b <"$PARAMS_FILE"
        # inject uniform values as a #define block (rewriting shader)
        sed -i "/uniform vec3 moodColor;/c\uniform vec3 moodColor = vec3($r,$g,$b);" "$SHADER_FILE"
    fi
    sleep "$UPDATE_INTERVAL"
done

# cleanup
kill $VIEWER_PID 2>/dev/null
rm -f "$SHADER_FILE" "$PARAMS_FILE"