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
    letterHit = 10,        -- Mali bodovi za otkrivanje slova (održava streak)
    miss = -5,             -- Kazna za promašaj slova
    
    -- NOVO: Logika za pogađanje riječi
    perHiddenLetter = 50,  -- Koliko vrijedi svako NEOTKRIVENO slovo kad se pogodi riječ
    wordWinFixed = 100,    -- Fiksni bonus za pogađanje riječi
    
    wordCompleteBonus = 50, -- Bonus ako se riječ dovrši pogađanjem zadnjeg slova (manje od wordWinFixed)
    
    wordMiss = -20,        -- Veća kazna za promašaj cijele riječi
    streak3Mult = 1.2,     -- Smanjili smo mult malo da ne "razbije" igru
    streak5Mult = 1.5
}

local POWER = {
    hintCost = 15,
    shieldCost = 20,
}

-- ----- State -----
Game.state = "menu"
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

Game.timeLeft = SETTINGS.turnTime
Game.shakeT = 0
Game.skipInput = false 

Game.highscores = {}
Game.winnerPlayer = nil
Game.tempName = ""

-- ----- Audio -----
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

-- Broji koliko je jos ostalo neotkrivenih slova (underscores)
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
    for i = 1, Game.numPlayers do
        local p = Player.new("Igrac " .. i)
        p.isBot = false 
        table.insert(Game.players, p)
    end
    Game.turn = 1
    Game.round = 1
    Game.state = "play"
    startRound()
end

local function checkLeaderboardEligibility(player)
    Game.highscores = Storage.load()
    if #Game.highscores < 3 then return true end
    local lowest = Game.highscores[#Game.highscores]
    if player.score > lowest.score then return true end
    return false
end

local function endRound(title, msg)
    if Game.round >= SETTINGS.roundsToPlay then
        local best = Game.players[1]
        for i=2,#Game.players do if Game.players[i].score > best.score then best = Game.players[i] end end
        
        Game.winnerPlayer = best
        Game.message = msg or ""
        
        if checkLeaderboardEligibility(best) then
            Game.state = "highscore_entry"
            Game.tempName = ""
            Game.skipInput = false 
        else
            Game.state = "match_end"
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
        Game.message = ("Slovo '%s' je vec pogodeno."):format(ch)
        playS(sounds.click)
        return
    end
    if Game.missed[ch] then
        Game.message = ("Slovo '%s' je vec promaseno."):format(ch)
        playS(sounds.click)
        return
    end

    local occ = countOccurrences(Game.word, ch)
    if occ > 0 then
        local revealed = reveal(Game.word, Game.mask, ch)
        Game.guessed[ch] = true

        p.streak = p.streak + 1
        
        -- Bodovi za slovo su manji, ali se množe s brojem pojavljivanja
        local pts = applyStreakMult(p, SCORE.letterHit * revealed)
        p:addScore(pts)
        Game.message = ("%s pogodio '%s' (+%d)"):format(p.name, ch, pts)
        playS(sounds.hit)

        -- Ako je slovo kompletiralo riječ (nema više underscora)
        if isWin(Game.mask) then
            -- Ovdje NE dajemo veliki bonus za pogađanje cijele riječi jer je igrač išao linijom manjeg otpora
            local bonus = applyStreakMult(p, SCORE.wordCompleteBonus)
            p:addScore(bonus)
            playS(sounds.win)
            endRound("KRAJ RUNDE", ("%s je kompletirao rijec! Bonus +%d. Rijec: %s"):format(p.name, bonus, Game.word))
        end
    else
        Game.missed[ch] = true
        p.streak = 0
        p:addScore(SCORE.miss)
        local added = addMistake(p, 1)
        if added then
            Game.message = ("%s promasio '%s' (%d bodova)"):format(p.name, ch, SCORE.miss)
            playS(sounds.miss)
        end

        if Game.mistakes >= Game.maxMistakes then
            playS(sounds.lose)
            endRound("KRAJ RUNDE", ("Hangman gotov! Rijec je bila: %s"):format(Game.word))
        else
            nextTurn()
        end
    end
end

local function handleWordGuess(guess)
    local p = currentPlayer()

    if guess == Game.word then
        -- Izračunaj koliko je slova BILO skriveno prije ovog poteza
        local hiddenCount = countHidden(Game.mask)
        
        -- Otkrij sve za vizualni dojam
        for i=1,#Game.word do Game.mask[i] = Game.word:sub(i,i) end

        -- LOGIKA BODOVANJA:
        -- Nagrada = (BrojSkrivenih * CijenaPoSlovu) + FiksniBonus
        -- Npr. Riječ od 8 slova, 0 otkrivenih: (8 * 50) + 100 = 500 bodova
        -- Npr. Riječ od 8 slova, 6 otkrivenih (ostalo 2): (2 * 50) + 100 = 200 bodova
        -- Ako je korisnik otkrio 7/8 slova pojedinačno dobio je 7*10=70 bodova.
        -- Sad pogađa riječ: (1 * 50) + 100 = 150. Ukupno 220.
        -- 220 < 500. Sustav radi.
        
        local rawPoints = (hiddenCount * SCORE.perHiddenLetter) + SCORE.wordWinFixed
        local totalPoints = applyStreakMult(p, rawPoints)
        
        p:addScore(totalPoints)
        p.streak = p.streak + 2 -- Bonus streak za hrabrost
        
        playS(sounds.win)
        endRound("KRAJ RUNDE", ("%s POGODIO RIJEC! (+%d)\n(Skriveno slova: %d)"):format(p.name, totalPoints, hiddenCount))
    else
        p.streak = 0
        p:addScore(SCORE.wordMiss)
        local added = addMistake(p, 2) -- Pogađanje riječi košta 2 greške
        if added then
            Game.message = ("Netocna rijec! %s (%d bodova)"):format(p.name, SCORE.wordMiss)
            playS(sounds.miss)
        end

        if Game.mistakes >= Game.maxMistakes then
            playS(sounds.lose)
            endRound("KRAJ RUNDE", ("Hangman gotov! Rijec je bila: %s"):format(Game.word))
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
    
    -- Bot logika: Ako je malo slova ostalo, probaj pogoditi riječ (jednostavna simulacija "pameti")
    -- Za sada samo gađa slova
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
    Game.highscores = Storage.load()

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
        Game.timeLeft = Game.timeLeft - dt
        if Game.timeLeft <= 0 then
            local p = currentPlayer()
            p.streak = 0
            p:addScore(SCORE.miss)
            addMistake(p, 1)
            Game.message = "Vrijeme isteklo! Potez prebacen."
            if Game.mistakes >= Game.maxMistakes then
                playS(sounds.lose)
                endRound("KRAJ RUNDE", ("Hangman gotov! Rijec je bila: %s"):format(Game.word))
            else
                nextTurn()
            end
        end
        botTakeTurn()
    end
end

function Game.draw()
    love.graphics.clear(0.05, 0.05, 0.07, 1)

    if Game.state == "menu" then
        UI.drawMenu(Game.menuIndex, Game.numPlayers)
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
        UI.drawRoundEnd("KRAJ RUNDE", Game.message, "N = sljedeca runda | R = restart match")
        return
    end

    if Game.state == "match_end" then
        local best = Game.winnerPlayer
        UI.drawRoundEnd("KRAJ MATCHA", ("Pobjednik: %s (Score: %d)\n%s"):format(best.name, best.score, Game.message or ""), "L = Leaderboard | R = novi match | ESC = izlaz")
        return
    end

    if Game.state == "highscore_entry" then
        UI.drawHighscoreInput("NOVI REKORD!", "Upisi svoje ime:", Game.tempName)
        return
    end

    if Game.state == "leaderboard" then
        UI.drawLeaderboard(Game.highscores, "R = novi match | ESC = izbornik")
        return
    end
end

function Game.textinput(t)
    if Game.skipInput then
        Game.skipInput = false
        return
    end

    if Game.state == "play" then
        if t:match("[%a]") or t == " " or t == "-" then
            Game.input = Game.input .. t:upper()
        end
    elseif Game.state == "highscore_entry" then
        if #Game.tempName < 10 then
            if t:match("[%w]") then
                Game.tempName = Game.tempName .. t:upper()
            end
        end
    end
end

function Game.keypressed(key)
    if key == "escape" then 
        if Game.state == "leaderboard" then 
            Game.state = "menu"
            return
        end
        love.event.quit() 
    end

    if Game.state == "menu" then
        if key == "down" then 
            Game.menuIndex = math.min(3, Game.menuIndex + 1)
            playS(sounds.click) 
        end
        if key == "up" then 
            Game.menuIndex = math.max(1, Game.menuIndex - 1)
            playS(sounds.click) 
        end
        if Game.menuIndex == 2 then
            if key == "left" then
                Game.numPlayers = math.max(1, Game.numPlayers - 1)
                playS(sounds.click)
            elseif key == "right" then
                Game.numPlayers = math.min(4, Game.numPlayers + 1)
                playS(sounds.click)
            end
        end
        if key == "return" or key == "kpenter" then
            if Game.menuIndex == 1 then
                startMatch()
            elseif Game.menuIndex == 3 then
                love.event.quit()
            end
        end
        return
    end

    if Game.state == "round_end" then
        if key == "n" then
            Game.round = Game.round + 1
            Game.state = "play"
            Game.turn = ((Game.round - 1) % #Game.players) + 1
            startRound()
            Game.skipInput = true
        elseif key == "r" then
            startMatch()
            Game.skipInput = true
        end
        return
    end

    if Game.state == "match_end" then
        if key == "r" then 
            startMatch() 
            Game.skipInput = true
        elseif key == "l" then
            Game.state = "leaderboard"
        end
        return
    end

    if Game.state == "highscore_entry" then
        if key == "backspace" then
            Game.tempName = Game.tempName:sub(1, -2)
        elseif key == "return" or key == "kpenter" then
            if #Game.tempName > 0 then
                table.insert(Game.highscores, {name=Game.tempName, score=Game.winnerPlayer.score})
                table.sort(Game.highscores, function(a,b) return a.score > b.score end)
                while #Game.highscores > 3 do table.remove(Game.highscores) end
                Storage.save(Game.highscores)
                Game.state = "leaderboard"
                playS(sounds.win)
            end
        end
        return
    end

    if Game.state == "leaderboard" then
        if key == "r" then
            startMatch()
            Game.skipInput = true
        end
        return
    end

    -- PLAY
    if Game.state == "play" then
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
                Game.message = ("Hint kosta %d bodova."):format(POWER.hintCost)
                playS(sounds.click)
                return
            end

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
            handleLetter(ch)
            Game.message = ("Hint: otkriveno '%s' (-%d)"):format(ch, POWER.hintCost)
            nextTurn()
            return
        end

        if key == "f2" then
            local p = currentPlayer()
            if p.shield then
                Game.message = "Shield je vec aktivan."
                return
            end
            if p.score < POWER.shieldCost then
                Game.message = ("Shield kosta %d bodova."):format(POWER.shieldCost)
                return
            end
            p:addScore(-POWER.shieldCost)
            p.shield = true
            Game.message = ("Shield aktiviran (-%d)."):format(POWER.shieldCost)
            nextTurn()
            return
        end

        if key == "return" or key == "kpenter" then
            local guess = upperTrim(Game.input)
            local wordLen = #Game.word
            local guessLen = #guess

            if guess == "" then
                Game.message = "Upisi slovo ili rijec pa Enter."
                return
            end
            Game.input = ""

            if guessLen == 1 then
                handleLetter(guess)
            elseif guessLen == wordLen then
                handleWordGuess(guess)
            else
                Game.message = ("Nevazeci unos! Mora biti 1 slovo ili tocno %d znakova."):format(wordLen)
                playS(sounds.click)
            end
        end
    end
end

return Game