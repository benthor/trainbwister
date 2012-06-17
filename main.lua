sounds = {}
sounddir = "letters"
math.randomseed(os.time())

function love.load()
    -- TODO: load savegame
    for _,letter in ipairs{"C", "D", "G", "K", "P", "Q", "T", "V"} do
        table.insert(sounds, love.audio.newSource(sounddir .. "/" .. letter .. ".wav", "static"))
    end
end

function drawcross()
    local x = love.graphics.getWidth()/2
    local y = love.graphics.getHeight()/2
    -- the below only draws an outline but can't be filled.
    --love.graphics.polygon('line', x-20, y-5, x-5, y-5, x-5, y-20, x+5, y-20, x+5, y-5, x+20, y-5, x+20, y+5, x+5, y+5, x+5, y+20, x-5, y+20, x-5, y+5, x-20, y+5)
    love.graphics.rectangle('fill', x-20, y-2, 40, 4)
    love.graphics.rectangle('fill', x-2, y-20, 4, 40)
end

-- draws a square in the outlying quadrants of the 9x9 grid
-- (automatically excludes the middle)
-- call in range [0,7] for best results
-- XXX REALLY UGLY
function drawsquare(n)
    -- exclude middle 
    if n >= 4 then
        n = n+1
    end
    -- leave margin in any direction
    local margin = 20
   
    local max = love.graphics.getHeight()
    local width = love.graphics.getWidth()
    
    -- find maximum edge length
    local squaresize = (max - 4*margin) / 3 

    local x = max - (((n % 3)+1) * (margin + squaresize))
    local y = max - ((math.floor(n/3) + 1) * (margin + squaresize))

    -- draw with offset to account for rectengular window
    love.graphics.rectangle('fill', x+(width-max)/2,y, squaresize, squaresize)
end


function playsound(n)
    love.audio.play(sounds[n+1])
    sounds[n+1]:rewind()
end


-- generate number series based on number of trials,
-- specify a desired bias for the n-back hitrate (in %)
function nback(n, trials, hitrate)
    local result = {}
    -- function to generate a number between 0 and 7
    -- assumes math.random never returns 1
    local rand = function() return math.floor(math.random()*8) end
    -- fill the buffer
    for i=1,n do
        table.insert(result, rand())
    end
    -- trials + n result in 'trials'-number of selections in n-back
    for i=n+1,trials+n do
                stimulus = math.floor(math.random()*8)
        -- we have a hitrate of 1/8 anyway so
        -- we have to adjust the bias downward
        -- FIXME, biases < 1/8 are ignored
        local probability = hitrate/100 - 1/8
        if math.random() <= probability then
            -- we have a hit, put in stimulus from n results back
            table.insert(result, result[i-n])
        else
            table.insert(result, rand())
        end
    end
    return result
end


function trialscreen(a,v,backa,backv)
    local t = {}
    -- initialize, set timer to 0, play the sound, ..,
    t.init = function()
        t.start = love.timer.getTime()
        t.now = t.start
        playsound(a)
        t.valid = true
    end
    -- statistics
    t.stats = {}
    if a == backa then t.stats['audio nback?'] = true end
    if v == backv then t.stats['visual nback?'] = true end
    t.update = function(dt)
        t.now = love.timer.getTime()
        if love.keyboard.isDown("a") then
            t.stats['audio response'] = t.now - t.start
        end
        if love.keyboard.isDown("o") then
            t.stats['visual response'] = t.now - t.start
        end
        if t.now - t.start >= 3 then
            t.valid = false
        end
    end
    t.draw = function()
        drawcross()
        if t.now - t.start < 0.5 then
            drawsquare(v)
        end
    end
    return t
end


function mktrialscreens(n, trials, hitrate)
    local audio = nback(n, trials, hitrate)
    local visual = nback(n, trials, hitrate)
    local t = {}
    for i=1,n do
        table.insert(t, trialscreen(audio[i],visual[i]))
    end
    for i=n+1,trials+n do
        table.insert(t, trialscreen(audio[i],visual[i],audio[i-n], visual[i-n]))
    end
    return t
end

function evaluate(trials, n, hitrate)
    local acorrect = 0
    local vcorrect = 0
    local all = #trials
    for _, t in ipairs(trials) do
        if t.stats['audio nback?'] then
            if t.stats['audio response'] then
                acorrect = acorrect + 1
            end
        else
            if not t.stats['audio response'] then
                acorrect = acorrect + 1
            end
        end
        if t.stats['visual nback?'] then
            if t.stats['visual response'] then
                vcorrect = vcorrect + 1
            end
        else
            if not t.stats['visual response'] then
                vcorrect = vcorrect + 1
            end
        end
    end
    local aratio = acorrect/all
    local vratio = vcorrect/all
    print(os.date(), n, hitrate, aratio, vratio)
    return aratio,vratio
end


n = 1
hitrate = 30
number = 20
trials = mktrialscreens(n,number,hitrate)
running = False
index = 0
function love.update(dt)
    if running then
        -- stupid bootstrapping
        -- XXX FUGLY!
        if index == 0 then
            trial = trials[1]
            trial.init()
            index = index + 1
        else
            trial = trials[index]
            if trial.valid then
                trial.update(dt)
            else
                index = index+1
                local tr = trials[index]
                if tr then
                    tr.init()
                else
                    running = False
                    a, v = evaluate(trials, n, hitrate)
                    if a >= 0.9 and v >= 0.9 then
                        n = n + 1
                    elseif (a <= 0.7 or a <= 0.7) and n > 1 then
                        n = n - 1
                    end
                    trials = mktrialscreens(n,number,hitrate)
                    index = 0 
                end

            end
        end
    end
end

function love.draw()
    if index > 0 and index <= # trials then
        trials[index].draw()
    else
        love.graphics.print("New N: "..n, 400, 300)
    end
end

function love.keypressed(key)
    -- maybe introduce context?
    if key == "escape" then
        love.event.quit()
    end
    if key == "return" then
        running = love.timer.getTime()
    end
end
