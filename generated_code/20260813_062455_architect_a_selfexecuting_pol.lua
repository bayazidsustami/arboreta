-- Polyphonic Fractal Quine: Translates source code into audio-genetic fractal branches.
local s = "-- Polyphonic Fractal Quine: Translates source code into audio-genetic fractal branches.\nlocal s = %q\nlocal src = s:format(s)\n\n-- Translate source bytes to resonant audio frequencies and mutate fractal branches\nlocal depth = 0\nprint(\"=== POLYPHONIC AUDIO-GENETIC FRACTAL TREE ===\")\nfor i = 1, #src do\n    local b = src:byte(i)\n    local freq = 110 * (2 ^ ((b %% 36) / 12)) -- Polyphonic scale resonant frequency\n    local mutation = string.char(((b * 3 + i) %% 94) + 32) -- Genetic mutation\n    if b %% 11 == 0 then\n        depth = (depth + 1) %% 5\n        local branch = string.rep(\"│   \", depth) .. \"├── [♪ \" .. math.floor(freq) .. \" Hz] 🧬 Mut: \" .. mutation\n        print(branch)\n    end\nend\nprint(\"=============================================\\n\")\n\nio.write(src)"
local src = s:format(s)

-- Translate source bytes to resonant audio frequencies and mutate fractal branches
local depth = 0
print("=== POLYPHONIC AUDIO-GENETIC FRACTAL TREE ===")
for i = 1, #src do
    local b = src:byte(i)
    local freq = 110 * (2 ^ ((b % 36) / 12)) -- Polyphonic scale resonant frequency
    local mutation = string.char(((b * 3 + i) % 94) + 32) -- Genetic mutation
    if b % 11 == 0 then
        depth = (depth + 1) % 5
        local branch = string.rep("│   ", depth) .. "├── [♪ " .. math.floor(freq) .. " Hz] 🧬 Mut: " .. mutation
        print(branch)
    end
end
print("=============================================\n")

io.write(src)