local UI = require("src.ui")
local WordManager = require("src.wordManager")
local Player = require("src.player")

local Game = {}

-- ----- Config -----
local SETTINGS = {
    roundsToPlay = 5,
    turnTime = 15, -- sekundi po potezu
    players = {
        {name="Igrac 1", isBot=false},
        {name="Igrac 2", isBot=false}, -- promijeni na true za bota
    },
}

local SCORE = {
    letterHit = 10,
    miss = -6,
    repeatPenalty = 0,      -- ne kažnjavaj, samo poruka
    wordWinBase = 80,
    wordMiss = -18,
    streak3Mult = 1.5,
    streak5Mult = 2.0
}

local POWER = {
    hintCost = 15,
    shieldCost = 20,
}

-- ----- State -----
Game.state = "menu" -- menu, play, round_end, match_end
Game.menuIndex = 1

Game.players = {}
Game.turn = 1
Game.round = 1
Game.category = "-"

Game.word = ""
Game.mask = {}
Game.guessed = {}   -- set hit letters
Game.missed = {}    -- set missed letters
Game.mistakes = 0
Game.maxMistakes = 8

Game.input = ""
Game.message = ""
Game.showRules = true

Game.timeLeft = SETTINGS.turnTime
Game.shakeT = 0

-- ----- Audio (optional) -----
local sounds = {hit=nil, miss=nil, win=nil, lose=nil, click=nil}
local function safeLoadSound(path)
    local ok, src = pcall(love.audio.newSource, path, "static")
    if ok then return src end
    return nil
end
local function playS(s)
    if s then s:stop(); s:play() end
end

-- ----- Helpers -----
local function clamp(x,a,b) if x<a then return a elseif x>b then return b else return x end end

local function upperTrim(s)
    s = (s or ""):gsub("^%s+",""):gsub("%s+$","")
    s = s:gsub("%s+"," ")
    return s:upper()
end

local function buildMask(word)
    local m = {}
    for i=1,#word do
        local c = word:sub(i,i)
        if c == " " or c == "-" then m[i]=c else m[i]="_" end
    end
    return m
end

local function isWin(mask)
    for i=1,#mask do if mask[i] == "_" then return false end end
    return true
end

local function countOccurrences(word, ch)
    local n=0
    for i=1,#word do if word:sub(i,i)==ch then n=n+1 end end
    return n
end

local function reveal(word, mask, ch)
    local r=0
    for i=1,#word do
        if word:sub(i,i)==ch and mask[i]=="_" then
            mask[i]=ch
            r=r+1
        end
    end
    return r
end

local function setToSortedString(set)
    local t={}
    for k,_ in pairs(set) do t[#t+1]=k end
    table.sort(t)
    return table.concat(t, " ")
end

local function applyStreakMult(p, pts)
    local mult = 1.0
    if p.streak >= 5 then mult = SCORE.streak5Mult
    elseif p.streak >= 3 then mult = SCORE.streak3Mult end
    return math.floor(pts * mult + 0.5)
end

local function computeMaxMistakes(word)
    local len=0
    for i=1,#word do
        local c=word:sub(i,i)
        if c~=" " and c~="-" then len=len+1 end
    end
    return clamp(6 + math.floor(len/2), 6, 16)
end

local function currentPlayer()
    return Game.players[Game.turn]
end

local function nextTurn()
    Game.turn = Game.turn % #Game.players + 1
    Game.timeLeft = SETTINGS.turnTime
end

local function startRound()
    local item = WordManager.getRandom()
    Game.word = upperTrim(item.word)
    Game.category = item.category or "-"
    Game.mask = buildMask(Game.word)
    Game.guessed = {}
    Game.missed = {}
    Game.mistakes = 0
    Game.maxMistakes = computeMaxMistakes(Game.word)
    Game.input = ""
    Game.message = ""
    Game.timeLeft = SETTINGS.turnTime
    Game.shakeT = 0

    for _,p in ipairs(Game.players) do
        p.streak = 0
        p.shield = false
    end
end

local function startMatch()
    Game.players = {}
    for _, cfg in ipairs(SETTINGS.players) do
        local p = Player.new(cfg.name)
        p.isBot = cfg.isBot
        table.insert(Game.players, p)
    end
    Game.turn = 1
    Game.round = 1
    Game.state = "play"
    startRound()
end

local function endRound(title, msg)
    if Game.round >= SETTINGS.roundsToPlay then
        Game.state = "match_end"
        Game.message = msg or ""
    else
        Game.state = "round_end"
        Game.message = msg or ""
    end
end

local function addMistake(p, amount)
    amount = amount or 1
    if p.shield then
        p.shield = false
        Game.message = "🛡️ Shield blokirao grešku!"
        return false
    end
    Game.mistakes = Game.mistakes + amount
    Game.shakeT = 0.25
    return true
end

-- ----- Guess logic -----
local function handleLetter(ch)
    local p = currentPlayer()

    if Game.guessed[ch] then
        Game.message = ("Slovo '%s' je već pogođeno. Probaj drugo."):format(ch)
        playS(sounds.click)
        return
    end
    if Game.missed[ch] then
        Game.message = ("Slovo '%s' je već promašeno. Probaj drugo."):format(ch)
        playS(sounds.click)
        return
    end

    local occ = countOccurrences(Game.word, ch)
    if occ > 0 then
        local revealed = reveal(Game.word, Game.mask, ch)
        Game.guessed[ch] = true

        p.streak = p.streak + 1
        local pts = applyStreakMult(p, SCORE.letterHit * revealed)
        p:addScore(pts)
        Game.message = ("✅ %s pogodio '%s' (+%d)"):format(p.name, ch, pts)
        playS(sounds.hit)

        -- correct keeps turn (competitive)
        if isWin(Game.mask) then
            local bonus = applyStreakMult(p, SCORE.wordWinBase)
            p:addScore(bonus)
            playS(sounds.win)
            endRound("KRAJ RUNDE", ("🎉 %s je pogodio riječ! Bonus +%d. Riječ: %s"):format(p.name, bonus, Game.word))
        end
    else
        Game.missed[ch] = true
        p.streak = 0
        p:addScore(SCORE.miss)
        local added = addMistake(p, 1)
        if added then
            Game.message = ("❌ %s promašio '%s' (%d bodova)"):format(p.name, ch, SCORE.miss)
            playS(sounds.miss)
        end

        if Game.mistakes >= Game.maxMistakes then
            playS(sounds.lose)
            endRound("KRAJ RUNDE", ("💀 Hangman gotov! Riječ je bila: %s"):format(Game.word))
        else
            nextTurn()
        end
    end
end

local function handleWordGuess(guess)
    local p = currentPlayer()

    if guess == Game.word then
        -- reveal all
        for i=1,#Game.word do Game.mask[i] = Game.word:sub(i,i) end

        local bonus = applyStreakMult(p, SCORE.wordWinBase + 40)
        p:addScore(bonus)
        p.streak = p.streak + 2
        playS(sounds.win)
        endRound("KRAJ RUNDE", ("🏆 %s je pogodio CIJELU riječ! +%d."):format(p.name, bonus))
    else
        p.streak = 0
        p:addScore(SCORE.wordMiss)
        local added = addMistake(p, 2)
        if added then
            Game.message = ("❌ Netočna riječ! %s (%d bodova)"):format(p.name, SCORE.wordMiss)
            playS(sounds.miss)
        end

        if Game.mistakes >= Game.maxMistakes then
            playS(sounds.lose)
            endRound("KRAJ RUNDE", ("💀 Hangman gotov! Riječ je bila: %s"):format(Game.word))
        else
            nextTurn()
        end
    end
end

-- ----- Bot (simple frequency strategy) -----
local FREQ = {"A","E","I","O","U","N","R","S","T","L","K","M","P","D","G","B","V","J","Z","C","H","F","Y","X","W","Q"}
local function botTakeTurn()
    local p = currentPlayer()
    if not p.isBot then return end
    -- pick first not tried letter from frequency list
    for _, ch in ipairs(FREQ) do
        if not Game.guessed[ch] and not Game.missed[ch] then
            handleLetter(ch)
            return
        end
    end
end

-- ----- LOVE2D API -----
function Game.load()
    UI.load()
    love.math.setRandomSeed(os.time())

    -- optional sounds (stavi .wav u assets/sounds/)
    sounds.hit  = safeLoadSound("assets/sounds/hit.wav")
    sounds.miss = safeLoadSound("assets/sounds/miss.wav")
    sounds.win  = safeLoadSound("assets/sounds/win.wav")
    sounds.lose = safeLoadSound("assets/sounds/lose.wav")
    sounds.click = safeLoadSound("assets/sounds/click.wav")

    Game.state = "menu"
    Game.menuIndex = 1
end

function Game.update(dt)
    if Game.shakeT > 0 then Game.shakeT = math.max(0, Game.shakeT - dt) end

    if Game.state == "play" then
        -- timer
        Game.timeLeft = Game.timeLeft - dt
        if Game.timeLeft <= 0 then
            local p = currentPlayer()
            p.streak = 0
            p:addScore(SCORE.miss)
            addMistake(p, 1)
            Game.message = "⏳ Vrijeme isteklo! Potez prebačen."
            if Game.mistakes >= Game.maxMistakes then
                playS(sounds.lose)
                endRound("KRAJ RUNDE", ("💀 Hangman gotov! Riječ je bila: %s"):format(Game.word))
            else
                nextTurn()
            end
        end

        -- bot autoplay
        botTakeTurn()
    end
end

function Game.draw()
    love.graphics.clear(0.05, 0.05, 0.07, 1)

    if Game.state == "menu" then
        UI.drawMenu(Game.menuIndex)
        return
    end

    if Game.state == "play" then
        UI.drawHangmanGraphic(Game.mistakes, Game.maxMistakes, Game.shakeT)
        UI.drawHangmanText(Game.mistakes, Game.maxMistakes)

        UI.drawCurrentPlayer(currentPlayer(), Game.timeLeft)
        UI.drawScoreboard(Game.players, Game.turn, Game.round, SETTINGS.roundsToPlay, Game.category)

        UI.drawWord(Game.mask)
        UI.drawGuesses(setToSortedString(Game.guessed), setToSortedString(Game.missed))
        UI.drawInput(Game.input, POWER.hintCost, POWER.shieldCost)
        UI.drawMessage(Game.message)

        UI.drawRules(Game.showRules)
        return
    end

    if Game.state == "round_end" then
        UI.drawRoundEnd("KRAJ RUNDE", Game.message, "N = sljedeća runda | R = restart match")
        return
    end

    if Game.state == "match_end" then
        -- winner
        local best = Game.players[1]
        for i=2,#Game.players do if Game.players[i].score > best.score then best = Game.players[i] end end
        UI.drawRoundEnd("KRAJ MATCHA", ("Pobjednik: %s (Score: %d)\n%s"):format(best.name, best.score, Game.message or ""), "R = novi match | ESC izlaz")
        return
    end
end

function Game.textinput(t)
    if Game.state ~= "play" then return end
    if t:match("[%a]") or t == " " or t == "-" then
        Game.input = Game.input .. t:upper()
    end
end

function Game.keypressed(key)
    if key == "escape" then love.event.quit() end

    if Game.state == "menu" then
        if key == "down" then Game.menuIndex = math.min(2, Game.menuIndex + 1); playS(sounds.click) end
        if key == "up" then Game.menuIndex = math.max(1, Game.menuIndex - 1); playS(sounds.click) end
        if key == "return" or key == "kpenter" then
            if Game.menuIndex == 1 then
                startMatch()
            else
                love.event.quit()
            end
        end
        return
    end

    if Game.state == "round_end" then
        if key == "n" then
            Game.round = Game.round + 1
            Game.state = "play"
            -- rotate starting player each round
            Game.turn = ((Game.round - 1) % #Game.players) + 1
            startRound()
        elseif key == "r" then
            startMatch()
        end
        return
    end

    if Game.state == "match_end" then
        if key == "r" then startMatch() end
        return
    end

    -- PLAY
    if key == "tab" then
        Game.showRules = not Game.showRules
        return
    end

    if key == "backspace" then
        Game.input = Game.input:sub(1, -2)
        return
    end

    if key == "f1" then

        local p = currentPlayer()
        if p.score < POWER.hintCost then
            Game.message = ("Hint košta %d bodova."):format(POWER.hintCost)
            playS(sounds.click)
            return
        end

        -- find a hidden letter
        local hidden = {}
        for i=1,#Game.word do
            if Game.mask[i] == "_" then
                local ch = Game.word:sub(i,i)
                if ch ~= " " and ch ~= "-" then hidden[#hidden+1] = ch end
            end
        end
        if #hidden == 0 then
            Game.message = "Nema skrivenih slova."
            return
        end

        p:addScore(-POWER.hintCost)
        p.streak = 0
        local ch = hidden[love.math.random(#hidden)]
        handleLetter(ch) -- handleLetter već radi sve (i štiti od ponavljanja)
        Game.message = ("💡 Hint: otkriveno '%s' (-%d)"):format(ch, POWER.hintCost)
        nextTurn() -- hint završava potez (balans)
        return
    end

    if key == "f2" then
        local p = currentPlayer()
        if p.shield then
            Game.message = "Shield je već aktivan."
            return
        end
        if p.score < POWER.shieldCost then
            Game.message = ("Shield košta %d bodova."):format(POWER.shieldCost)
            return
        end
        p:addScore(-POWER.shieldCost)
        p.shield = true
        Game.message = ("🛡️ Shield aktiviran (-%d)."):format(POWER.shieldCost)
        nextTurn()
        return
    end

    if key == "return" or key == "kpenter" then
        local guess = upperTrim(Game.input)
        Game.input = ""

        if guess == "" then
            Game.message = "Upiši slovo ili riječ pa Enter."
            return
        end

        if #guess == 1 then
            handleLetter(guess)
        else
            handleWordGuess(guess)
        end
    end
end

return Game
