-- Recursive Execution Stack Trace to Victorian Gothic Cathedral Blueprint Converter
-- Solves: Translates execution stack traces of recursive math into an SVG cathedral blueprint.

local math_sin, math_cos, math_pi, math_sqrt = math.sin, math.cos, math.pi, math.sqrt
local string_format = string.format

-- -----------------------------------------------------------------------------
-- 1. RECURSIVE MATHEMATICAL FUNCTION & TRACE CAPTURE ENGINE
-- -----------------------------------------------------------------------------
local trace = { nodes = {}, max_depth = 0, total_calls = 0, root = nil }
local stack = {}

-- Recursive function (Branching recurrence based on combinatorial expansion)
local function recursive_math(n, k)
    trace.total_calls = trace.total_calls + 1
    local depth = #stack + 1
    if depth > trace.max_depth then trace.max_depth = depth end

    local node = {
        id = trace.total_calls,
        depth = depth,
        n = n,
        k = k,
        children = {},
        parent = stack[#stack],
        x = 0, y = 0, x_index = 0
    }

    if node.parent then
        table.insert(node.parent.children, node)
    else
        trace.root = node
    end

    table.insert(trace.nodes, node)
    table.insert(stack, node)

    -- Recurrence relation logic
    local result
    if n <= 0 or k <= 0 or n == k then
        result = 1
    elseif (n + k) % 3 == 0 then
        result = recursive_math(n - 1, k) + recursive_math(n - 1, k - 1)
    else
        result = recursive_math(n - 1, k - 1) + recursive_math(n - 2, k)
    end

    node.result = result
    table.remove(stack)
    return result
end

-- Execute the recursive mathematical function to populate the stack trace
recursive_math(7, 5)

-- -----------------------------------------------------------------------------
-- 2. ARCHITECTURAL GEOMETRY LAYOUT ENGINE
-- -----------------------------------------------------------------------------
-- In-order traversal assigns spatial X coordinates to preserve execution tree topology
local x_counter = 0
local function layout_inorder(node)
    local half = math.floor(#node.children / 2)
    for i = 1, half do
        layout_inorder(node.children[i])
    end
    
    x_counter = x_counter + 1
    node.x_index = x_counter
    
    for i = half + 1, #node.children do
        layout_inorder(node.children[i])
    end
end
layout_inorder(trace.root)

-- Map nodes to 2D Blueprint Coordinates (Canvas: 1800 x 2200)
local canvas_w, canvas_h = 1800, 2200
local margin_x, base_y = 150, 1850
local printable_w = canvas_w - (margin_x * 2)
local height_scale = 1350

for _, node in ipairs(trace.nodes) do
    node.x = margin_x + (node.x_index / (x_counter + 1)) * printable_w
    -- Higher depth maps upward (Gothic height emphasis)
    node.y = base_y - ((node.depth - 1) / (trace.max_depth)) * height_scale
end

-- -----------------------------------------------------------------------------
-- 3. VICTORIAN GOTHIC SVG PATH GENERATORS
-- -----------------------------------------------------------------------------
local svg_elements = {}

local function emit(str)
    table.insert(svg_elements, str)
end

local function draw_path(d, stroke, width, fill, opacity, dash)
    stroke = stroke or "#00f0ff"
    width = width or 1.0
    fill = fill or "none"
    opacity = opacity or 1.0
    local dash_attr = dash and string_format(' stroke-dasharray="%s"', dash) or ""
    emit(string_format('<path d="%s" stroke="%s" stroke-width="%.2f" fill="%s" stroke-opacity="%.2f"%s/>',
        d, stroke, width, fill, opacity, dash_attr))
end

-- Gothic Pointed Arch (Equilateral Arch Vector Path)
local function gothic_arch_path(cx, arch_base_y, width, height)
    local half_w = width / 2
    local left_x = cx - half_w
    local right_x = cx + half_w
    local apex_y = arch_base_y - height
    -- Arc radius calculated for gothic intersection at apex
    local r = math_sqrt(width * width + height * height)
    return string_format("M %.2f,%.2f A %.2f,%.2f 0 0,1 %.2f,%.2f A %.2f,%.2f 0 0,1 %.2f,%.2f Z",
        left_x, arch_base_y, r, r, cx, apex_y, r, r, right_x, arch_base_y)
end

-- Spire Generator with Crockets
local function spire_path(cx, spire_base_y, width, height)
    local half_w = width / 2
    local apex_y = spire_base_y - height
    local path = string_format("M %.2f,%.2f L %.2f,%.2f L %.2f,%.2f",
        cx - half_w, spire_base_y, cx, apex_y, cx + half_w, spire_base_y)
    
    -- Add decorative Gothic crockets along spire edges
    local steps = 6
    for i = 1, steps - 1 do
        local t = i / steps
        local lx = (cx - half_w) + t * half_w
        local ly = spire_base_y - t * height
        local rx = (cx + half_w) - t * half_w
        local ry = spire_base_y - t * height
        path = path .. string_format(" M %.2f,%.2f L %.2f,%.2f", lx, ly, lx - 8, ly - 4)
        path = path .. string_format(" M %.2f,%.2f L %.2f,%.2f", rx, ry, rx + 8, ry - 4)
    end
    return path
end

-- Gothic Rose Window Generator
local function rose_window_path(cx, cy, radius, foils)
    local path = string_format("M %.2f,%.2f A %.2f,%.2f 0 1,0 %.2f,%.2f",
        cx - radius, cy, radius, radius, cx + radius, cy)
    path = path .. string_format(" A %.2f,%.2f 0 1,0 %.2f,%.2f", radius, radius, cx - radius, cy)
    
    -- Radial tracery and foils
    local foil_r = radius * 0.35
    for i = 0, foils - 1 do
        local angle = (i / foils) * math_pi * 2
        local fx = cx + math_cos(angle) * (radius * 0.55)
        local fy = cy + math_sin(angle) * (radius * 0.55)
        path = path .. string_format(" M %.2f,%.2f A %.2f,%.2f 0 1,0 %.2f,%.2f A %.2f,%.2f 0 1,0 %.2f,%.2f",
            fx - foil_r, fy, foil_r, foil_r, fx + foil_r, fy, foil_r, foil_r, fx - foil_r, fy)
        path = path .. string_format(" M %.2f,%.2f L %.2f,%.2f", cx, cy, cx + math_cos(angle) * radius, cy + math_sin(angle) * radius)
    end
    return path
end

-- Flying Buttress Path
local function flying_buttress_path(x1, y1, x2, y2, arch_height)
    local mid_x = (x1 + x2) / 2
    local mid_y = math.min(y1, y2) - arch_height
    return string_format("M %.2f,%.2f Q %.2f,%.2f %.2f,%.2f M %.2f,%.2f Q %.2f,%.2f %.2f,%.2f",
        x1, y1, mid_x, mid_y, x2, y2,
        x1, y1 - 15, mid_x, mid_y - 15, x2, y2 - 15)
end

-- -----------------------------------------------------------------------------
-- 4. SVG CANVAS & BLUEPRINT BACKGROUND SYNTHESIS
-- -----------------------------------------------------------------------------
emit(string_format('<svg xmlns="[http://www.w3.org/2000/svg](http://www.w3.org/2000/svg)" viewBox="0 0 %d %d" width="100%%" height="100%%">', canvas_w, canvas_h))
emit('<style>')
emit('  text { font-family: "Courier New", monospace; fill: #00f0ff; font-size: 11px; }')
emit('  .title { font-size: 20px; font-weight: bold; letter-spacing: 2px; fill: #ffffff; }')
emit('  .label { font-size: 10px; fill: #70d6ff; opacity: 0.8; }')
emit('</style>')

-- Blueprint Background (Deep Cyan/Dark Blue)
emit('<rect width="100%" height="100%" fill="#050e1a"/>')

-- Architectural Grid Lines
for x = 0, canvas_w, 50 do
    draw_path(string_format("M %d,0 L %d,%d", x, x, canvas_h), "#0a2540", 0.5, "none", 0.5)
end
for y = 0, canvas_h, 50 do
    draw_path(string_format("M 0,%d L %d,%d", y, canvas_w, y), "#0a2540", 0.5, "none", 0.5)
end

-- Major Structural Axis
draw_path(string_format("M %d,100 L %d,%d", canvas_w / 2, canvas_w / 2, base_y + 100), "#00f0ff", 1.0, "none", 0.4, "8,4")
draw_path(string_format("M 50,%d L %d,%d", base_y, canvas_w - 50, base_y), "#00f0ff", 1.5, "none", 0.8)

-- -----------------------------------------------------------------------------
-- 5. TRANSLATING STACK TRACE TO BLUEPRINT ARCHITECTURE
-- -----------------------------------------------------------------------------

-- Ground Portal & Main Foundation Arch (Root Frame Mapping)
local main_width = printable_w * 0.85
draw_path(gothic_arch_path(canvas_w / 2, base_y, main_width, height_scale * 1.1), "#00b4d8", 2.5, "none", 0.7)
draw_path(gothic_arch_path(canvas_w / 2, base_y, main_width * 0.6, height_scale * 0.85), "#00f0ff", 2.0, "none", 0.9)

-- Draw Rib Vaulting (Cross-connecting recursive child frames)
for _, node in ipairs(trace.nodes) do
    for _, child in ipairs(node.children) do
        -- Primary Structural Pier
        draw_path(string_format("M %.2f,%.2f L %.2f,%.2f", node.x, node.y, child.x, child.y), "#0077b6", 1.2, "none", 0.6)
        
        -- Vaulting Diagonal Ribs
        if child.x ~= node.x then
            local control_x = (node.x + child.x) / 2
            local control_y = math.min(node.y, child.y) - 30
            draw_path(string_format("M %.2f,%.2f Q %.2f,%.2f %.2f,%.2f",
                node.x, node.y, control_x, control_y, child.x, child.y), "#70d6ff", 0.8, "none", 0.5, "4,4")
        end
    end
end

-- Render Gothic Structural Features per Stack Frame Node
for _, node in ipairs(trace.nodes) do
    local arch_w = 40 + (node.result % 5) * 12
    local arch_h = 60 + node.depth * 15
    
    -- Node Base: Gothic Pointed Arch Window Frame
    draw_path(gothic_arch_path(node.x, node.y, arch_w, arch_h), "#00f0ff", 1.2, "none", 0.85)
    
    -- Flying Buttresses connecting adjacent branch nodes
    if node.parent then
        local arch_lift = 25 + math.abs(node.x - node.parent.x) * 0.15
        draw_path(flying_buttress_path(node.parent.x, node.parent.y, node.x, node.y, arch_lift), "#48cae4", 1.0, "none", 0.75)
    end

    -- Spires at Terminal Base Cases (Leaf Nodes)
    if #node.children == 0 then
        local spire_h = 100 + (node.result * 15)
        local spire_w = 24
        draw_path(spire_path(node.x, node.y - arch_h, spire_w, spire_h), "#caf0f8", 1.5, "none", 0.95)
        -- Finial Cross on top of spire
        local top_y = node.y - arch_h - spire_h
        draw_path(string_format("M %.2f,%.2f L %.2f,%.2f M %.2f,%.2f L %.2f,%.2f",
            node.x, top_y - 12, node.x, top_y + 4, node.x - 6, top_y - 6, node.x + 6, top_y - 6), "#ffffff", 1.5, "none", 1.0)
    end

    -- Rose Window placed at Central Heavy Recursion Nodes
    if node.depth == 3 or node.id == 1 then
        local rose_r = 35 + (node.result * 4)
        draw_path(rose_window_path(node.x, node.y - arch_h * 0.5, rose_r, 8), "#90e0ef", 1.2, "none", 0.9)
    end

    -- Blueprint Structural Annotations & Callouts
    emit(string_format('<text x="%.2f" y="%.2f" class="label">FRAME_#%02d [d:%d, val:%d]</text>',
        node.x + 8, node.y + 14, node.id, node.depth, node.result or 0))
    draw_path(string_format("M %.2f,%.2f L %.2f,%.2f", node.x, node.y, node.x + 6, node.y + 10), "#00f0ff", 0.8, "none", 0.7)
end

-- Central Grand Spire on Apex Stack Depth
local pinnacle_node = trace.root
draw_path(spire_path(canvas_w / 2, 380, 70, 260), "#ffffff", 2.0, "none", 1.0)

-- -----------------------------------------------------------------------------
-- 6. BLUEPRINT TITLE BLOCK & TECHNICAL LEGEND
-- -----------------------------------------------------------------------------
local bx, by, bw, bh = canvas_w - 520, canvas_h - 220, 470, 170
emit(string_format('<rect x="%d" y="%d" width="%d" height="%d" fill="#050e1a" stroke="#00f0ff" stroke-width="2" stroke-opacity="0.9"/>', bx, by, bw, bh))
emit(string_format('<rect x="%d" y="%d" width="%d" height="%d" fill="none" stroke="#00f0ff" stroke-width="0.8" stroke-dasharray="4,4"/>', bx + 5, by + 5, bw - 10, bh - 10))

emit(string_format('<text x="%d" y="%d" class="title">VICTORIAN GOTHIC CATHEDRAL</text>', bx + 20, by + 35))
emit(string_format('<text x="%d" y="%d" style="fill:#70d6ff;">ARCHITECTURAL BLUEPRINT FROM STACK TRACE</text>', bx + 20, by + 55))
draw_path(string_format("M %d,%d L %d,%d", bx + 20, by + 65, bx + bw - 20, by + 65), "#00f0ff", 1.0, "none", 0.8)

emit(string_format('<text x="%d" y="%d">MATHEMATICAL RECURRENCE: f(n,k) -> f(n-1,k) + f(n-1,k-1)</text>', bx + 20, by + 85))
emit(string_format('<text x="%d" y="%d">TOTAL STACK FRAMES GENERATED : %d</text>', bx + 20, by + 105, trace.total_calls))
emit(string_format('<text x="%d" y="%d">MAXIMUM RECURSION DEPTH     : %d LEVELS</text>', bx + 20, by + 125, trace.max_depth))
emit(string_format('<text x="%d" y="%d">VECTOR ENGINE               : PURE LUA SVG SYNTHESIS</text>', bx + 20, by + 145))

-- Compass Rose Symbol (Top Left Blueprint Watermark)
local cx, cy, cr = 120, 140, 45
draw_path(rose_window_path(cx, cy, cr, 4), "#00f0ff", 1.0, "none", 0.6)
emit(string_format('<text x="%d" y="%d" text-anchor="middle" style="font-weight:bold;">N</text>', cx, cy - cr - 8))
emit(string_format('<text x="%d" y="%d" text-anchor="middle" style="font-size:9px;">ELEVATION</text>', cx, cy + cr + 16))

emit('</svg>')

-- Output the resulting SVG to standard output
print(table.concat(svg_elements, "\n"))