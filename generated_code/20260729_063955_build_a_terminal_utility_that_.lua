local lfs_ok, lfs = pcall(require, "lfs")

local function run_cmd(cmd)
    local handle = io.popen(cmd)
    if not handle then return "" end
    local result = handle:read("*a")
    handle:close()
    return result or ""
end

local function parse_git_history()
    local log_cmd = 'git log --name-status --pretty=format:"COMMIT|%h|%an|%at" --no-merges'
    local raw_log = run_cmd(log_cmd)
    if raw_log == "" then
        print("Error: Not a git repository or no commits found.")
        os.exit(1)
    end

    local stats = {
        total_commits = 0,
        authors = {},
        files = {},
        first_commit_time = math.huge,
        last_commit_time = 0
    }

    local current_commit = nil

    for line in raw_log:gmatch("[^\r\n]+") do
        if line:sub(1, 7) == "COMMIT|" then
            local hash, author, timestamp = line:match("^COMMIT|([^|]+)|([^|]+)|(%d+)")
            timestamp = tonumber(timestamp)
            current_commit = { hash = hash, author = author, time = timestamp }
            
            stats.total_commits = stats.total_commits + 1
            stats.authors[author] = (stats.authors[author] or 0) + 1
            
            if timestamp < stats.first_commit_time then stats.first_commit_time = timestamp end
            if timestamp > stats.last_commit_time then stats.last_commit_time = timestamp end
        elseif current_commit then
            local status, filepath = line:match("^([AMD])%s+(.+)")
            if filepath then
                if not stats.files[filepath] then
                    stats.files[filepath] = {
                        changes = 0,
                        created = current_commit.time,
                        modified = current_commit.time,
                        authors = {},
                        deleted = false
                    }
                end
                
                local f = stats.files[filepath]
                f.changes = f.changes + 1
                f.authors[current_commit.author] = true
                if current_commit.time < f.created then f.created = current_commit.time end
                if current_commit.time > f.modified then f.modified = current_commit.time end
                if status == "D" then f.deleted = true end
            end
        end
    end

    return stats
end

local function map_to_star_system(stats)
    local repo_age = math.max(1, stats.last_commit_time - stats.first_commit_time)
    
    local unique_authors = 0
    for _ in pairs(stats.authors) do unique_authors = unique_authors + 1 end
    
    local stellar_class = "M (Red Dwarf)"
    local star_color = "\27[31m" -- Red
    if stats.total_commits > 1000 then
        stellar_class = "O (Blue Supergiant)"
        star_color = "\27[34;1m" -- Bright Blue
    elseif stats.total_commits > 500 then
        stellar_class = "B (Blue-White Star)"
        star_color = "\27[36;1m" -- Cyan
    elseif stats.total_commits > 200 then
        stellar_class = "A (White Star)"
        star_color = "\27[37;1m" -- White
    elseif stats.total_commits > 100 then
        stellar_class = "F (Yellow-White Star)"
        star_color = "\27[33;1m" -- Yellow-White
    elseif stats.total_commits > 50 then
        stellar_class = "G (Yellow Dwarf)"
        star_color = "\27[33m" -- Yellow
    elseif stats.total_commits > 20 then
        stellar_class = "K (Orange Dwarf)"
        star_color = "\27[33m" -- Orange
    end

    local system = {
        star = {
            class = stellar_class,
            color = star_color,
            commits = stats.total_commits,
            authors = unique_authors,
            radius = math.min(3.0, 1.0 + math.log(stats.total_commits + 1) * 0.3)
        },
        planets = {}
    }

    local index = 1
    for path, info in pairs(stats.files) do
        local lifespan = math.max(1, info.modified - info.created)
        local age_ratio = lifespan / repo_age
        
        local author_count = 0
        for _ in pairs(info.authors) do author_count = author_count + 1 end

        local orbit_radius = 4.0 + (index * 1.8) + (info.changes * 0.1)
        local orbit_speed = 0.5 / math.sqrt(orbit_radius)
        
        local mass = math.min(1.5, 0.2 + (info.changes * 0.05))
        local erosion = 1.0 - math.min(1.0, age_ratio) -- cosmic erosion from short file lifespan
        
        table.insert(system.planets, {
            name = path,
            radius = orbit_radius,
            speed = orbit_speed,
            angle = (index * 1.37) % (2 * math.pi),
            mass = mass,
            churn = info.changes,
            erosion = erosion,
            deleted = info.deleted,
            contributors = author_count
        })
        index = index + 1
        if index > 12 then break end -- render top 12 planets for terminal clarity
    end

    return system
end

local function project_3d(x, y, z, pitch, yaw)
    local cos_y, sin_y = math.cos(yaw), math.sin(yaw)
    local cos_p, sin_p = math.cos(pitch), math.sin(pitch)

    local x1 = x * cos_y - z * sin_y
    local z1 = x * sin_y + z * cos_y

    local y2 = y * cos_p - z1 * sin_p
    local z2 = y * sin_p + z1 * cos_p

    local distance = 30
    local scale = 25 / (z2 + distance)
    local screen_x = math.floor(x1 * scale + 40)
    local screen_y = math.floor(y2 * scale * 0.5 + 15)

    return screen_x, screen_y, z2
end

local function render_system(system, time_step)
    local width, height = 80, 30
    local buffer = {}
    local z_buffer = {}

    for y = 1, height do
        buffer[y] = {}
        z_buffer[y] = {}
        for x = 1, width do
            buffer[y][x] = " "
            z_buffer[y][x] = 10000
        end
    end

    local pitch, yaw = 0.45, time_step * 0.05

    -- Render Star
    local sx, sy, sz = project_3d(0, 0, 0, pitch, yaw)
    if sx >= 1 and sx <= width and sy >= 1 and sy <= height then
        buffer[sy][sx] = system.star.color .. "☼\27[0m"
        z_buffer[sy][sx] = sz
    end

    -- Render Planetary Orbits and Bodies
    for _, planet in ipairs(system.planets) do
        local current_angle = planet.angle + (time_step * planet.speed)
        local px = math.cos(current_angle) * planet.radius
        local pz = math.sin(current_angle) * planet.radius
        local py = 0

        local screen_x, screen_y, depth = project_3d(px, py, pz, pitch, yaw)

        if screen_x >= 1 and screen_x <= width and screen_y >= 1 and screen_y <= height then
            if depth < z_buffer[screen_y][screen_x] then
                z_buffer[screen_y][screen_x] = depth
                
                local char = "●"
                local color = "\27[32m" -- Green for active files
                
                if planet.deleted then
                    char = "░" -- Eroded/dead file debris
                    color = "\27[90m" -- Gray
                elseif planet.erosion > 0.6 then
                    char = "•"
                    color = "\27[31m" -- Highly eroded (short-lived)
                elseif planet.churn > 20 then
                    char = "◯"
                    color = "\27[35;1m" -- High churn (gas giant)
                end
                
                buffer[screen_y][screen_x] = color .. char .. "\27[0m"
            end
        end
    end

    -- Clear screen and print frame
    io.write("\27[H")
    for y = 1, height do
        local line = {}
        for x = 1, width do
            table.insert(line, buffer[y][x])
        end
        print(table.concat(line))
    end

    print(string.format("\27[1mStellar Class:\27[0m %s%s\27[0m | \27[1mCommits:\27[0m %d | \27[1mPlanets (Files):\27[0m %d",
        system.star.color, system.star.class, system.star.commits, #system.planets))
    print("\27[90mLegend: ☼ Star  ● Planet  ◯ High Churn  • Eroded  ░ Deleted\27[0m")
end

local function main()
    io.write("\27[2J\27[?25l") -- Clear screen & hide cursor
    local stats = parse_git_history()
    local system = map_to_star_system(stats)

    local time_step = 0
    local running = true

    while running do
        render_system(system, time_step)
        time_step = time_step + 0.1
        
        -- Portable sleep (approx 0.05s)
        local t = os.clock()
        while os.clock() - t < 0.05 do end
    end
    
    io.write("\27[?25h") -- Restore cursor
end

main()