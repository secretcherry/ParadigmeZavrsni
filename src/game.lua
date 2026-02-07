local UI = require("src.ui")
local WordManager = require("src.wordManager")
local Player = require("src.player")
local Storage = require("src.storage")

local Game = {}

-- ----- Config -----
local SETTINGS = {
    roundsToPlay = 5,
    turnTime = 15,
}

local SCORE = {
    letterHit = 10,
    miss = -5,
    perHiddenLetter = 50,
    wordWinFixed = 100,
    wordCompleteBonus = 50,
    wordMiss = -20,
    streak3Mult = 1.2,
    streak5Mult = 1.5
}

local POWER = {
    hintCost = 15,
    shieldCost = 20,
}

-- ----- State -----
Game.state = "menu" -- menu, transition_freeze, play, round_end, match_end, highscore_entry, leaderboard, confirmation
Game.previousState = "" -- Za povratak ako se odustane od izlaza
Game.menuIndex = 1
Game.numPlayers = 1

Game.players = {}
Game.turn = 1
Game.round = 1
Game.category = "-"

Game.word = ""
Game.mask = {}
Game.guessed = {}
Game.missed = {}
Game.mistakes = 0
Game.maxMistakes = 8

Game.input = ""
Game.message = ""
Game.showRules = true
Game.skipInput = false 

Game.timeLeft = SETTINGS.turnTime
Game.shakeT = 0

Game.highscores = {}
Game.winnerPlayer = nil
Game.tempName = ""

-- ----- Audio System -----
local sounds = {
    click = nil,
    correct = nil,
    enterGame = nil,
    gameOver = nil,
    bgmMenu = nil,
    bgmGame = nil
}

local function loadAudio(path, type)
    local ok, src = pcall(love.audio.newSource, path, type)
    if ok then return src else print("Failed to load audio: " .. path) return nil end
end

local function playClick()
    if sounds.click then
        local s = sounds.click:clone()
        s:play()
    end
end

local function playSfx(s)
    if s then
        if s:isPlaying() then s:stop() end
        s:play()
    end
end

local function playMusic(track)
    if track == sounds.bgmMenu then
        if sounds.bgmGame and sounds.bgmGame:isPlaying() then sounds.bgmGame:stop() end
    elseif track == sounds.bgmGame then
        if sounds.bgmMenu and sounds.bgmMenu:isPlaying() then sounds.bgmMenu:stop() end
    end
    
    if track and not track:isPlaying() then
        track:setLooping(true)
        track:setVolume(0.5)
        track:play()
    end
end

local function stopMusic()
    if sounds.bgmMenu then sounds.bgmMenu:stop() end
    if sounds.bgmGame then sounds.bgmGame:stop() end
end

-- ----- Helpers -----
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

local function countHidden(mask)
    local c = 0
    for i=1,#mask do if mask[i] == "_" then c=c+1 end end
    return c
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
    return math.max(6, math.min(16, 6 + math.floor(len/2)))
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

local function beginGameplay()
    stopMusic() 
    Game.players = {}
    for i = 1, Game.numPlayers do
        table.insert(Game.players, Player.new("Igrac " .. i))
    end
    Game.turn = 1
    Game.round = 1
    Game.state = "play"
    playMusic(sounds.bgmGame)
    startRound()
end

local function initStartSequence()
    if sounds.enterGame and not sounds.enterGame:isPlaying() then
        sounds.enterGame:play()
    end
    Game.state = "transition_freeze" 
end

local function endRound(title, msg)
    stopMusic() 
    if Game.round >= SETTINGS.roundsToPlay then
        local best = Game.players[1]
        for i=2,#Game.players do if Game.players[i].score > best.score then best = Game.players[i] end end
        Game.winnerPlayer = best
        Game.message = msg or ""
        
        Game.highscores = Storage.load()
        local isEligible = (#Game.highscores < 3 or best.score > Game.highscores[#Game.highscores].score)
        
        if isEligible then
            Game.state = "highscore_entry"
            Game.tempName = ""
            playSfx(sounds.correct)
        else
            Game.state = "match_end"
            playSfx(sounds.correct)
        end
    else
        Game.state = "round_end"
        Game.message = msg or ""
    end
end

local function addMistake(p, amount)
    amount = amount or 1
    if p.shield then
        p.shield = false
        Game.message = "Shield blokirao gresku!"
        playSfx(sounds.correct)
        return false
    end
    Game.mistakes = Game.mistakes + amount
    Game.shakeT = 0.25
    return true
end

local function handleLetter(ch)
    local p = currentPlayer()
    if Game.guessed[ch] or Game.missed[ch] then
        playClick()
        return
    end

    local occ = countOccurrences(Game.word, ch)
    if occ > 0 then
        local revealed = reveal(Game.word, Game.mask, ch)
        Game.guessed[ch] = true
        p.streak = p.streak + 1
        local pts = applyStreakMult(p, SCORE.letterHit * revealed)
        p:addScore(pts)
        Game.message = ("%s pogodio '%s' (+%d)"):format(p.name, ch, pts)
        playSfx(sounds.correct)

        if isWin(Game.mask) then
            local bonus = applyStreakMult(p, SCORE.wordCompleteBonus)
            p:addScore(bonus)
            playSfx(sounds.correct)
            endRound("KRAJ RUNDE", ("%s je kompletirao rijec! Bonus +%d"):format(p.name, bonus))
        end
    else
        Game.missed[ch] = true
        p.streak = 0
        p:addScore(SCORE.miss)
        if addMistake(p, 1) then
            Game.message = ("%s promasio '%s'"):format(p.name, ch)
        end
        if Game.mistakes >= Game.maxMistakes then
            playSfx(sounds.gameOver)
            endRound("KRAJ RUNDE", ("Hangman gotov! Rijec: %s"):format(Game.word))
        else
            nextTurn()
        end
    end
end

local function handleWordGuess(guess)
    local p = currentPlayer()
    if guess == Game.word then
        local hiddenCount = countHidden(Game.mask)
        for i=1,#Game.word do Game.mask[i] = Game.word:sub(i,i) end
        local rawPoints = (hiddenCount * SCORE.perHiddenLetter) + SCORE.wordWinFixed
        local totalPoints = applyStreakMult(p, rawPoints)
        p:addScore(totalPoints)
        p.streak = p.streak + 2 
        playSfx(sounds.correct)
        endRound("KRAJ RUNDE", ("%s POGODIO RIJEC! (+%d)"):format(p.name, totalPoints))
    else
        p.streak = 0
        p:addScore(SCORE.wordMiss)
        addMistake(p, 2)
        if Game.mistakes >= Game.maxMistakes then
            playSfx(sounds.gameOver)
            endRound("KRAJ RUNDE", ("Hangman gotov! Rijec: %s"):format(Game.word))
        else
            nextTurn()
        end
    end
end

-- ----- LOVE2D API -----
function Game.load()
    UI.load()
    love.math.setRandomSeed(os.time())
    Game.highscores = Storage.load()

    sounds.click     = loadAudio("assets/sounds/click.mp3", "static")
    sounds.correct   = loadAudio("assets/sounds/correct answer.mp3", "static")
    sounds.enterGame = loadAudio("assets/sounds/enter game.mp3", "static")
    sounds.gameOver  = loadAudio("assets/sounds/Game over.mp3", "static")
    sounds.bgmMenu   = loadAudio("assets/sounds/main screen background music.mp3", "stream")
    sounds.bgmGame   = loadAudio("assets/sounds/main game background.mp3", "stream")

    Game.state = "menu"
    playMusic(sounds.bgmMenu)
end

function Game.update(dt)
    if Game.state == "transition_freeze" then
        if sounds.enterGame and not sounds.enterGame:isPlaying() then
            beginGameplay()
        end
        return 
    end

    -- Zamrzni update logiku ako smo u confirmation screenu
    if Game.state == "confirmation" then return end

    if Game.shakeT > 0 then Game.shakeT = math.max(0, Game.shakeT - dt) end

    if Game.state == "play" then
        Game.timeLeft = Game.timeLeft - dt
        if Game.timeLeft <= 0 then
            local p = currentPlayer()
            p.streak = 0
            p:addScore(SCORE.miss)
            playClick()
            addMistake(p, 1)
            if Game.mistakes >= Game.maxMistakes then
                playSfx(sounds.gameOver)
                endRound("KRAJ RUNDE", "Vrijeme isteklo!")
            else
                nextTurn()
            end
        end
    end
end

function Game.draw()
    love.graphics.clear(0.05, 0.05, 0.07, 1)

    if Game.state == "menu" or Game.state == "transition_freeze" then
        UI.drawMenu(Game.menuIndex, Game.numPlayers)
    elseif Game.state == "play" then
        UI.drawHangmanGraphic(Game.mistakes, Game.maxMistakes, Game.shakeT)
        UI.drawHangmanText(Game.mistakes, Game.maxMistakes)
        UI.drawCurrentPlayer(currentPlayer(), Game.timeLeft)
        UI.drawScoreboard(Game.players, Game.turn, Game.round, SETTINGS.roundsToPlay, Game.category)
        UI.drawWord(Game.mask)
        UI.drawGuesses(setToSortedString(Game.guessed), setToSortedString(Game.missed))
        UI.drawInput(Game.input, POWER.hintCost, POWER.shieldCost)
        UI.drawMessage(Game.message)
        UI.drawRules(Game.showRules)
    elseif Game.state == "round_end" then
        UI.drawRoundEnd("KRAJ RUNDE", Game.message, "N = sljedeca runda | R = restart match")
    elseif Game.state == "match_end" then
        local best = Game.winnerPlayer
        UI.drawRoundEnd("KRAJ MATCHA", ("Pobjednik: %s"):format(best.name), "L = Leaderboard | R = novi match | ESC = izbornik")
    elseif Game.state == "highscore_entry" then
        UI.drawHighscoreInput("NOVI REKORD!", "Upisi ime:", Game.tempName)
    elseif Game.state == "leaderboard" then
        UI.drawLeaderboard(Game.highscores, "R = novi match | ESC = izbornik")
    elseif Game.state == "confirmation" then
        UI.drawRoundEnd("POVRATAK U MENI?", "Napredak nece biti spremljen!", "Y = Potvrdi | ESC = Odustani")
    end
end

function Game.textinput(t)
    if Game.state == "confirmation" then return end
    if Game.skipInput then 
        Game.skipInput = false
        return 
    end

    if Game.state == "play" then
        if t:match("[%a]") or t == " " or t == "-" then
            playClick()
            Game.input = Game.input .. t:upper()
        end
    elseif Game.state == "highscore_entry" then
        if #Game.tempName < 10 and t:match("[%w]") then
            playClick()
            Game.tempName = Game.tempName .. t:upper()
        end
    end
end

function Game.keypressed(key)
    if Game.state == "transition_freeze" then 
        return 
    end

    -- Logika za ESC potvrdu
    if Game.state == "confirmation" then
        if key == "y" then
            playClick()
            Game.state = "menu"
            playMusic(sounds.bgmMenu)
        elseif key == "escape" then
            playClick()
            Game.state = Game.previousState -- Vrati se tamo gdje si bio
        end
        return
    end

    if key == "escape" then 
        playClick()
        if Game.state == "menu" then
            love.event.quit() -- Jedino u glavnom meniju ESC gasi igru
        else
            -- Za sva ostala stanja, traži potvrdu za izlaz u meni
            Game.previousState = Game.state
            Game.state = "confirmation"
        end
        return 
    end

    if Game.state == "menu" then
        if key == "down" then Game.menuIndex = math.min(3, Game.menuIndex + 1); playClick() end
        if key == "up" then Game.menuIndex = math.max(1, Game.menuIndex - 1); playClick() end
        if Game.menuIndex == 2 then
            if key == "left" then Game.numPlayers = math.max(1, Game.numPlayers - 1); playClick()
            elseif key == "right" then Game.numPlayers = math.min(4, Game.numPlayers + 1); playClick() end
        end
        if key == "return" or key == "kpenter" then
            if Game.menuIndex == 1 then initStartSequence()
            elseif Game.menuIndex == 3 then playClick(); love.event.quit() end
        end
    elseif Game.state == "play" then
        if key == "tab" then playClick(); Game.showRules = not Game.showRules
        elseif key == "backspace" then playClick(); Game.input = Game.input:sub(1, -2)
        elseif key == "f1" then
            playClick()
            local p = currentPlayer()
            if p.score >= POWER.hintCost then
                local hidden = {}
                for i=1,#Game.word do if Game.mask[i] == "_" then table.insert(hidden, Game.word:sub(i,i)) end end
                if #hidden > 0 then
                    p:addScore(-POWER.hintCost)
                    handleLetter(hidden[love.math.random(#hidden)])
                    nextTurn()
                end
            end
        elseif key == "f2" then
            playClick()
            local p = currentPlayer()
            if not p.shield and p.score >= POWER.shieldCost then
                p:addScore(-POWER.shieldCost)
                p.shield = true
                nextTurn()
            end
        elseif key == "return" or key == "kpenter" then
            playClick()
            local guess = upperTrim(Game.input)
            if guess ~= "" then
                Game.input = ""
                if #guess == 1 then handleLetter(guess)
                elseif #guess == #Game.word then handleWordGuess(guess) end
            end
        end
    elseif Game.state == "round_end" then
        if key == "n" then 
            playClick()
            Game.skipInput = true 
            Game.round = Game.round + 1
            Game.state = "play"
            playMusic(sounds.bgmGame)
            startRound()
        elseif key == "r" then 
            playClick()
            initStartSequence() 
        end
    elseif Game.state == "match_end" then
        if key == "r" then playClick(); initStartSequence()
        elseif key == "l" then playClick(); Game.state = "leaderboard" end
    elseif Game.state == "highscore_entry" then
        if key == "backspace" then playClick(); Game.tempName = Game.tempName:sub(1, -2)
        elseif (key == "return" or key == "kpenter") and #Game.tempName > 0 then
            playClick()
            table.insert(Game.highscores, {name=Game.tempName, score=Game.winnerPlayer.score})
            table.sort(Game.highscores, function(a,b) return a.score > b.score end)
            Storage.save(Game.highscores)
            Game.state = "leaderboard"
            playSfx(sounds.correct)
        end
    elseif Game.state == "leaderboard" then
        if key == "r" then playClick(); initStartSequence() end
    end
end

return Game