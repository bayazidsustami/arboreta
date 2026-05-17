function love.load()
    -- Initialize window and settings
    love.window.setTitle("Emotional Tone Generative Art")
    love.window.setMode(800, 600)
    math.randomseed(os.time())
    
    -- Define emotional parameters for poetry interpretation
    local emotions = {
        joy = { color = {255, 100, 100}, shift = {x=2, y=-3}, weight = 0.8 },
        sadness = { color = {100, 100, 255}, shift = {x=-1, y=3}, weight = 0.7 },
        anger = { color = {255, 100, 100}, shift = {x=4, y=1}, weight = 1.0 },
        peace = { color = {100, 255, 100}, shift = {x=0, y=0}, weight = 0.5 },
        wonder = { color = {255, 255, 100}, shift = {x=-2, y=-2}, weight = 0.9 }
    }
    
    -- Sample unpublished poetry (simulated input)
    local poetry = "Joyful wonders fill my heart, Yet shadows of sadness linger. Anger boils beneath the surface, Peaceful moments bring calm, Wonder at the infinite stars."
    
    -- Parse poetry to calculate emotional weights
    local emotionalWeights = {}
    for word in string.gmatch(poetry, "%w+") do
        if emotions[string.lower(word)] then
            emotionalWeights[word] = (emotionalWeights[word] or 0) + 1
        end
    end
    
    -- Normalize emotional weights
    local totalWeight = 0
    for _, count in pairs(emotionalWeights) do
        totalWeight = totalWeight + count
    end
    
    -- Create dominant emotional parameters
    local dominantEmotion
    local maxWeight = 0
    for emotion, count in pairs(emotionalWeights) do
        if count > maxWeight then
            maxWeight = count
            dominantEmotion = emotion
        end
    end
    
    local emotionParams = emotions[dominantEmotion]
    
    -- Initialize pixel grid
    local pixelSize = 5
    local gridSizeX = love.graphics.getWidth() / pixelSize
    local gridSizeY = love.graphics.getHeight() / pixelSize
    
    -- Generate pixel states with emotional influence
    self.pixels = {}
    for x = 1, gridSizeX do
        self.pixels[x] = {}
        for y = 1, gridSizeY do
            -- Create stochastic offset based on emotional tone
            local offsetX = math.floor(emotionParams.shift.x * math.sin(x * 0.1))
            local offsetY = math.floor(emotionParams.shift.y * math.cos(y * 0.1))
            
            self.pixels[x][y] = {
                baseX = x,
                baseY = y,
                currentX = x + offsetX,
                currentY = y + offsetY,
                color = {
                    r = emotionParams.color[1] + math.random(-20, 20),
                    g = emotionParams.color[2] + math.random(-20, 20),
                    b = emotionParams.color[3] + math.random(-20, 20),
                    a = 200 + math.random(0, 55)
                },
                phase = math.random() * math.pi * 2,
                speed = 0.01 + math.random() * 0.03
            }
        end
    end
    
    -- Time tracking for animation
    self.time = 0
end

function love.update(dt)
    self.time = self.time + dt
    
    -- Update pixel positions based on emotional tone
    for x = 1, #self.pixels do
        for y = 1, #self.pixels[x] do
            local pixel = self.pixels[x][y]
            
            -- Calculate wave-like movement based on emotional parameters
            local waveX = math.sin(self.time * pixel.speed + pixel.phase) * 2
            local waveY = math.cos(self.time * pixel.speed * 0.7 + pixel.phase) * 1.5
            
            -- Apply stochastic element to movement
            pixel.currentX = pixel.baseX + waveX + math.sin(self.time * 2 + x * 0.1) * 0.5
            pixel.currentY = pixel.baseY + waveY + math.cos(self.time * 1.8 + y * 0.1) * 0.5
            
            -- Shift color subtly over time
            pixel.color.r = math.floor(128 + 127 * math.sin(self.time * 0.2 + pixel.phase))
            pixel.color.g = math.floor(128 + 127 * math.cos(self.time * 0.15 + pixel.phase * 1.3))
            pixel.color.b = math.floor(128 + 127 * math.sin(self.time * 0.25 + pixel.phase * 0.7))
        end
    end
end

function love.draw()
    -- Draw pixels based on current positions
    local pixelSize = 5
    for x = 1, #self.pixels do
        for y = 1, #self.pixels[x] do
            local pixel = self.pixels[x][y]
            love.graphics.setColor(
                pixel.color.r,
                pixel.color.g,
                pixel.color.b,
                pixel.color.a
            )
            love.graphics.rectangle(
                "fill",
                pixel.currentX * pixelSize,
                pixel.currentY * pixelSize,
                pixelSize,
                pixelSize
            )
        end
    end
    
    -- Display dominant emotional tone
    love.graphics.setColor(255, 255, 255)
    love.graphics.print("Emotional Tone: " .. self.dominantEmotion, 10, 10)
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    end
end