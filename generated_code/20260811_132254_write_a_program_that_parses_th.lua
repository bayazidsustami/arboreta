-- Generative 3D Constellation Map from Git History
-- Parses git commit history (or simulates history) to compute celestial 3D coordinates,
-- luminosity, and spectral types based on code churn, author hash, and test suite pass rates.
-- Exports the constellation to a 3D Wavefront OBJ file.

local function execute_git_log()
    local cmd = 'git log --pretty=format:"COMMIT|%H|%an|%at|%s" --numstat 2>NUL || git log --pretty=format:"COMMIT|%H|%an|%at|%s" --numstat 2>/dev/null'
    local handle = io.popen(cmd)
    if not handle then return nil end
    local output = handle:read("*a")
    handle:close()
    if not output or #output == 0 or output:find("fatal") then return nil end
    return output
end

local function generate_mock_log()
    local authors = {"Ada Lovelace", "Alan Turing", "Grace Hopper", "Linus Torvalds", "Margaret Hamilton"}
    local lines = {}
    local now = os.time()
    for i = 1, 40 do
        local hash = string.format("%040x", i * 987654321)
        local author = authors[(i % #authors) + 1]
        local timestamp = now - (40 - i) * 86400
        local is_pass = (i % 4 ~= 0)
        local msg = "Commit " .. i .. (is_pass and " [test: pass]" or " [fix syntax error]")
        table.insert(lines, string.format("COMMIT|%s|%s|%d|%s", hash, author, timestamp, msg))
        local added = (i * 23) % 200 + 10
        local deleted = (i * 13) % 90
        table.insert(lines, string.format("%d\t%d\tsrc/core/engine.lua", added, deleted))
    end
    return table.concat(lines, "\n")
end

local function hash_string(str)
    local hash = 5381
    for i = 1, #str do
        hash = ((hash * 33) + string.byte(str, i)) % 2^32
    end
    return hash
end

local function parse_git_history(raw_data)
    local commits = {}
    local current_commit = nil

    for line in raw_data:gmatch("[^\r\n]+") do
        if line:find("^COMMIT|") then
            if current_commit then table.insert(commits, current_commit) end
            local _, hash, author, timestamp, subject = line:match("^(COMMIT)|([^|]+)|([^|]+)|([^|]+)|(.*)$")
            current_commit = {
                hash = hash,
                author = author or "Unknown",
                timestamp = tonumber(timestamp) or os.time(),
                subject = subject or "",
                added = 0,
                deleted = 0,
                test_passed = subject and (subject:lower():find("pass") ~= nil or subject:lower():find("fix") == nil) or false
            }
        elseif current_commit then
            local added, deleted = line:match("^(%d+)\t(%d+)")
            if added and deleted then
                current_commit.added = current_commit.added + tonumber(added)
                current_commit.deleted = current_commit.deleted + tonumber(deleted)
            end
        end
    end
    if current_commit then table.insert(commits, current_commit) end
    return commits
end

local function calculate_constellation(commits)
    local stars = {}
    local count = #commits
    if count == 0 then return stars end

    local min_time = commits[1].timestamp
    local max_time = commits[count].timestamp
    local time_span = math.max(1, max_time - min_time)

    -- Stellar Spectral Classification (O, B, A, F, G, K, M)
    local spectral_types = {"O (Blue)", "B (Deep Blue)", "A (White)", "F (Yellow-White)", "G (Yellow)", "K (Orange)", "M (Red)"}

    for i, commit in ipairs(commits) do
        local total_churn = commit.added + commit.deleted
        local time_factor = (commit.timestamp - min_time) / time_span
        
        -- Map commits onto a 3D celestial sphere using a logarithmic spiral
        local phi = time_factor * math.pi * 8
        local author_hash = hash_string(commit.author)
        local theta = (author_hash % 360) * (math.pi / 180) + (i / count) * math.pi
        local radius = 60 + math.log(total_churn + 1) * 12 + (time_factor * 25)

        -- 3D Cartesian coordinates
        local x = radius * math.sin(theta) * math.cos(phi)
        local y = radius * math.sin(theta) * math.sin(phi)
        local z = radius * math.cos(theta)

        -- Spectral class tied to author identity; Luminosity tied to churn & test results
        local spec_idx = (author_hash % #spectral_types) + 1
        local spec_type = spectral_types[spec_idx]
        local base_lum = math.log10(total_churn + 2) * 2.5
        local luminosity = commit.test_passed and (base_lum * 1.5) or (base_lum * 0.4)

        table.insert(stars, {
            id = i,
            hash = commit.hash:sub(1, 7),
            author = commit.author,
            x = x, y = y, z = z,
            spectral_type = spec_type,
            luminosity = luminosity,
            churn = total_churn,
            passed = commit.test_passed
        })
    end
    return stars
end

local function export_obj(stars, filename)
    local file = io.open(filename, "w")
    if not file then return false end

    file:write("# Generative 3D Constellation Map from Git History\n")
    file:write("# Generated Stars: " .. #stars .. "\n\n")

    -- Write Vertices (Star Positions)
    for _, star in ipairs(stars) do
        file:write(string.format("v %.4f %.4f %.4f # Star [%s] %s Type:%s Lum:%.2f\n",
            star.x, star.y, star.z, star.hash, star.author, star.spectral_type, star.luminosity))
    end

    file:write("\n# Chronological Constellation Edges\n")
    for i = 1, #stars - 1 do
        file:write(string.format("l %d %d\n", i, i + 1))
    end

    file:write("\n# Author Lineage Constellation Edges\n")
    local author_last = {}
    for i, star in ipairs(stars) do
        if author_last[star.author] then
            file:write(string.format("l %d %d\n", author_last[star.author], i))
        end
        author_last[star.author] = i
    end

    file:close()
    return true
end

-- Main Execution Pipeline
local raw_log = execute_git_log()
if not raw_log or #raw_log == 0 then
    print("[Info] No Git repo detected. Generating simulated constellation dataset...")
    raw_log = generate_mock_log()
end

local commits = parse_git_history(raw_log)
local stars = calculate_constellation(commits)

print("==========================================================")
print("             3D GENERATIVE CONSTELLATION MAP              ")
print("==========================================================")
print(string.format("Parsed %d commits into 3D celestial star nodes.\n", #stars))

for i = 1, math.min(8, #stars) do
    local s = stars[i]
    print(string.format("Star #%02d [%s] | %-16s | Spectral: %-16s | Lum: %5.2f | Status: %s | Pos: (%6.1f, %6.1f, %6.1f)",
        s.id, s.hash, s.author, s.spectral_type, s.luminosity, s.passed and "PASS" or "FAIL", s.x, s.y, s.z))
end

if #stars > 8 then
    print(string.format("... and %d more star systems mapped.", #stars - 8))
end

local output_filename = "constellation.obj"
if export_obj(stars, output_filename) then
    print("\n[Success] 3D Constellation map exported to '" .. output_filename .. "' (Wavefront OBJ format).")
end