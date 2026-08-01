#include <iostream>
#include <string>
#include <vector>
#include <sstream>

// Plain Text Essay to Ecosystem HTML Compiler
// Reads an essay from std::cin and emits an HTML/JS simulation where words act as organisms.
int main() {
    std::string text, line;
    while (std::getline(std::cin, line)) {
        text += line + "\n";
    }
    
    // Fallback default essay if input is empty
    if (text.empty()) {
        text = "The digital realm breathes with silent code. Ideas flow like water, creating life from logic! Can artificial thought bloom into consciousness?";
    }

    // Escape characters to safely embed inside JavaScript string literal
    std::string escaped_text = "";
    for (char c : text) {
        if (c == '"') escaped_text += "\\\"";
        else if (c == '\\') escaped_text += "\\\\";
        else if (c == '\n') escaped_text += "\\n";
        else if (c == '\r') continue;
        else escaped_text += c;
    }

    // Output autonomous ecosystem web application
    std::cout << R"HTML(<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Ecosystem Essay Compiler</title>
    <style>
        body { margin: 0; overflow: hidden; background: #0d1117; color: #c9d1d9; font-family: monospace; user-select: none; }
        #canvas { position: absolute; top: 0; left: 0; width: 100vw; height: 100vh; }
        #stats { position: absolute; top: 12px; left: 12px; pointer-events: none; background: rgba(13,17,23,0.85); padding: 8px 14px; border-radius: 6px; border: 1px solid #30363d; font-size: 13px; }
    </style>
</head>
<body>
    <div id="stats">Organisms: <span id="org-count">0</span> | Punctuation Food: <span id="food-count">0</span></div>
    <canvas id="canvas"></canvas>
    <script>
        const rawText = ")HTML" << escaped_text << R"HTML(";
        const canvas = document.getElementById('canvas');
        const ctx = canvas.getContext('2d');
        let width = canvas.width = window.innerWidth;
        let height = canvas.height = window.innerHeight;

        window.addEventListener('resize', () => {
            width = canvas.width = window.innerWidth;
            height = canvas.height = window.innerHeight;
        });

        // Parse words and punctuation marks from text
        const words = rawText.match(/[a-zA-Z0-9']+/g) || ["void"];
        const puncts = rawText.match(/[.,!?;:]/g) || [".", "!", "?"];

        // Calculate string edit distance for semantic/structural similarity
        function similarity(a, b) {
            if (!a || !b) return 0;
            let m = a.length, n = b.length;
            let dp = Array.from({length: m + 1}, () => Array(n + 1).fill(0));
            for (let i = 0; i <= m; i++) dp[i][0] = i;
            for (let j = 0; j <= n; j++) dp[0][j] = j;
            for (let i = 1; i <= m; i++) {
                for (let j = 1; j <= n; j++) {
                    let cost = a[i-1].toLowerCase() === b[j-1].toLowerCase() ? 0 : 1;
                    dp[i][j] = Math.min(dp[i-1][j] + 1, dp[i][j-1] + 1, dp[i-1][j-1] + cost);
                }
            }
            return 1 - (dp[m][n] / Math.max(m, n));
        }

        class Food {
            constructor(symbol, x, y) {
                this.symbol = symbol;
                this.x = x || Math.random() * (width - 40) + 20;
                this.y = y || Math.random() * (height - 40) + 20;
                this.nutrition = 30;
            }
            draw() {
                ctx.fillStyle = '#ff7b72';
                ctx.font = 'bold 16px monospace';
                ctx.fillText(this.symbol, this.x, this.y);
            }
        }

        class WordOrganism {
            constructor(word, x, y) {
                this.word = word;
                this.x = x || Math.random() * (width - 100) + 50;
                this.y = y || Math.random() * (height - 100) + 50;
                this.vx = (Math.random() - 0.5) * 2;
                this.vy = (Math.random() - 0.5) * 2;
                this.energy = 60 + Math.random() * 40;
                this.hue = Math.floor(Math.random() * 360);
            }

            update(foods, organisms) {
                this.energy -= 0.08; // Metabolism drain

                // Find nearest punctuation food particle
                let nearest = null, minDist = Infinity;
                for (let f of foods) {
                    let d = Math.hypot(f.x - this.x, f.y - this.y);
                    if (d < minDist) { minDist = d; nearest = f; }
                }

                if (nearest) {
                    let dx = nearest.x - this.x;
                    let dy = nearest.y - this.y;
                    this.vx += (dx / minDist) * 0.12;
                    this.vy += (dy / minDist) * 0.12;
                } else {
                    this.vx += (Math.random() - 0.5) * 0.2;
                    this.vy += (Math.random() - 0.5) * 0.2;
                }

                // Speed limit & motion update
                let speed = Math.hypot(this.vx, this.vy);
                if (speed > 2.5) { this.vx = (this.vx / speed) * 2.5; this.vy = (this.vy / speed) * 2.5; }
                this.x += this.vx; this.y += this.vy;

                // Wall boundary physics
                if (this.x < 10 || this.x > width - 60) this.vx *= -1;
                if (this.y < 20 || this.y > height - 20) this.vy *= -1;

                // Consume punctuation food
                for (let i = foods.length - 1; i >= 0; i--) {
                    if (Math.hypot(foods[i].x - this.x, foods[i].y - this.y) < 18) {
                        this.energy += foods[i].nutrition;
                        foods.splice(i, 1);
                    }
                }

                // Mutate based on semantic similarity when colliding with other words
                for (let other of organisms) {
                    if (other === this) continue;
                    let d = Math.hypot(other.x - this.x, other.y - this.y);
                    if (d < 45) {
                        let sim = similarity(this.word, other.word);
                        if (sim > 0.35 && Math.random() < 0.03) {
                            this.mutate(other.word);
                        }
                    }
                }
            }

            mutate(targetWord) {
                let chars = this.word.split('');
                if (chars.length === 0) return;
                let idx = Math.floor(Math.random() * chars.length);
                let targetChar = targetWord[Math.floor(Math.random() * targetWord.length)];
                if (targetChar) {
                    chars[idx] = targetChar;
                    this.word = chars.join('');
                    this.hue = (this.hue + 25) % 360;
                }
            }

            draw() {
                ctx.fillStyle = `hsl(${this.hue}, 75%, 65%)`;
                ctx.font = '15px monospace';
                ctx.fillText(this.word, this.x, this.y);

                // Vitality / Energy bar
                ctx.fillStyle = this.energy > 30 ? '#56d364' : '#f85149';
                ctx.fillRect(this.x, this.y + 4, Math.max(0, this.energy * 0.3), 2);
            }
        }

        const foodList = puncts.map(p => new Food(p));
        const orgList = words.map(w => new WordOrganism(w));

        // Spawns punctuation food over time
        setInterval(() => {
            if (foodList.length < 60) {
                const syms = ['.', ',', '!', '?', ';', ':', '-'];
                foodList.push(new Food(syms[Math.floor(Math.random() * syms.length)]));
            }
        }, 600);

        function loop() {
            ctx.fillStyle = 'rgba(13, 17, 23, 0.22)';
            ctx.fillRect(0, 0, width, height);

            for (let f of foodList) f.draw();

            for (let i = orgList.length - 1; i >= 0; i--) {
                let org = orgList[i];
                org.update(foodList, orgList);
                org.draw();

                // Reproduction
                if (org.energy > 130) {
                    org.energy -= 60;
                    orgList.push(new WordOrganism(org.word, org.x + 12, org.y + 12));
                }

                // Death converts organism back into punctuation food
                if (org.energy <= 0) {
                    foodList.push(new Food('.', org.x, org.y));
                    orgList.splice(i, 1);
                }
            }

            document.getElementById('org-count').textContent = orgList.length;
            document.getElementById('food-count').textContent = foodList.length;

            requestAnimationFrame(loop);
        }

        loop();
    </script>
</body>
</html>
)HTML";

    return 0;
}