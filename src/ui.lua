local UI = {}

UI.fontTitle = nil
UI.fontBig = nil
UI.fontMed = nil
UI.fontSmall = nil

function UI.load()
    UI.fontTitle = love.graphics.newFont(40)
    UI.fontBig = love.graphics.newFont(28)
    UI.fontMed = love.graphics.newFont(18)
    UI.fontSmall = love.graphics.newFont(14)
end

-- Pomoćna funkcija za centriranje teksta
local function drawCenteredText(text, y, font, color)
    love.graphics.setFont(font)
    if color then love.graphics.setColor(color) else love.graphics.setColor(1,1,1) end
    local screenW = love.graphics.getWidth()
    local textW = font:getWidth(text)
    love.graphics.print(text, (screenW - textW) / 2, y)
end

function UI.drawMenu(selectedIndex, numPlayers)
    local screenW = love.graphics.getWidth()
    
    -- Naslov
    drawCenteredText("VJESALO (Multiplayer)", 120, UI.fontTitle)

    local items = { 
        "Start Game", 
        "Broj igraca: < " .. numPlayers .. " >", 
        "Quit" 
    }
    
    -- Stavke izbornika
    for i, item in ipairs(items) do
        local text = (i == selectedIndex) and ("> " .. item .. " <") or item
        local color = (i == selectedIndex) and {1, 1, 0} or {1, 1, 1}
        drawCenteredText(text, 260 + i * 60, UI.fontBig, color)
    end

    -- Upute na dnu
    love.graphics.setColor(0.6, 0.6, 0.6)
    drawCenteredText("Tipke: Gore/Dolje, Enter.", 520, UI.fontSmall)
    drawCenteredText("Strelica lijevo/desno za promjenu broja igraca.", 540, UI.fontSmall)
end

function UI.drawRoundEnd(title, msg, subtitle)
    local screenW = love.graphics.getWidth()
    
    -- Glavni naslov (npr. KRAJ RUNDE)
    drawCenteredText(title, 200, UI.fontTitle, {1, 1, 1})
    
    -- Poruka (npr. tko je pobijedio)
    drawCenteredText(msg or "", 280, UI.fontMed, {1, 1, 0})
    
    -- Podnaslov (npr. Upute za tipke)
    drawCenteredText(subtitle or "", 360, UI.fontSmall, {0.8, 0.8, 0.8})
end

function UI.drawHighscoreInput(title, msg, currentInput)
    local screenW = love.graphics.getWidth()
    
    drawCenteredText(title, 150, UI.fontTitle, {1, 1, 0})
    drawCenteredText(msg, 230, UI.fontBig, {1, 1, 1})

    -- Input box centriranje
    local boxW, boxH = 300, 50
    local boxX = (screenW - boxW) / 2
    local boxY = 280
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", boxX, boxY, boxW, boxH)
    
    -- Tekst unutar boxa
    local displayText = currentInput .. "_"
    local textW = UI.fontBig:getWidth(displayText)
    love.graphics.print(displayText, (screenW - textW) / 2, boxY + 10)

    drawCenteredText("Pritisni ENTER za potvrdu", 350, UI.fontSmall, {0.7, 0.7, 0.7})
end

function UI.drawLeaderboard(scores, subtitle)
    local screenW = love.graphics.getWidth()
    
    drawCenteredText("TOP 3 IGRACA", 100, UI.fontTitle, {1, 0.5, 0})

    for i, entry in ipairs(scores) do
        local color = {1,1,1}
        if i == 1 then color = {1, 0.84, 0} -- Gold
        elseif i == 2 then color = {0.75, 0.75, 0.75} -- Silver
        elseif i == 3 then color = {0.8, 0.5, 0.2} -- Bronze
        end
        
        -- Formatiranje retka (Ime ....... Bodovi)
        local scoreText = string.format("%d. %-12s  %d", i, (entry.name ~= "" and entry.name or "---"), entry.score)
        drawCenteredText(scoreText, 180 + i * 60, UI.fontBig, color)
    end

    drawCenteredText(subtitle or "", 480, UI.fontSmall, {1, 1, 1})
end

---------------------------------------------------------
-- ZASLON IGRE (Ovaj dio nije mijenjan u smislu pozicije)
---------------------------------------------------------

function UI.drawCurrentPlayer(player, timeLeft)
    love.graphics.setFont(UI.fontBig)
    love.graphics.setColor(1, 1, 0)
    love.graphics.print("Na redu: " .. player.name, 400, 50)
    love.graphics.setFont(UI.fontSmall)
    love.graphics.setColor(1,1,1)
    love.graphics.print(("Vrijeme: %.0fs"):format(timeLeft), 820, 62)
end

function UI.drawScoreboard(players, currentTurn, round, roundsToPlay, category)
    love.graphics.setFont(UI.fontMed)
    love.graphics.setColor(1,1,1)
    love.graphics.print(("Runda: %d/%d  |  Kategorija: %s"):format(round, roundsToPlay, category or "-"), 400, 95)
    love.graphics.print("Rezultati:", 400, 125)
    for i, p in ipairs(players) do
        if i == currentTurn then love.graphics.setColor(0,1,0) else love.graphics.setColor(1,1,1) end
        local shieldTag = p.shield and " [SHIELD]" or ""
        love.graphics.print(p.name .. "  Score: " .. p.score .. "  Streak: " .. p.streak .. shieldTag, 400, 150 + i * 24)
    end
end

function UI.drawWord(mask)
    love.graphics.setFont(love.graphics.newFont(34))
    love.graphics.setColor(1,1,1)
    love.graphics.print(table.concat(mask, " "), 400, 220)
end

function UI.drawGuesses(hitsList, missesList)
    love.graphics.setFont(UI.fontSmall)
    love.graphics.setColor(1,1,1)
    love.graphics.print("Pogodena slova: " .. (hitsList ~= "" and hitsList or "-"), 400, 310)
    love.graphics.print("Promasena slova: " .. (missesList ~= "" and missesList or "-"), 400, 330)
end

function UI.drawInput(inputText, hintCost, shieldCost)
    love.graphics.setFont(UI.fontMed)
    love.graphics.setColor(1,1,1)
    love.graphics.print("Unos (slovo ili rijec) + Enter:", 400, 370)
    love.graphics.print("> " .. (inputText or ""), 400, 398)
    love.graphics.setFont(UI.fontSmall)
    love.graphics.print(("Tipke: [F1] hint (-%d)  [F2] shield (-%d)  [TAB] pravila  [ESC] izlaz"):format(hintCost, shieldCost), 400, 430)
end

function UI.drawMessage(msg)
    love.graphics.setFont(UI.fontSmall)
    love.graphics.setColor(1,1,1)
    love.graphics.print(msg or "", 400, 455)
end

function UI.drawRules(show)
    if not show then return end
    love.graphics.setFont(UI.fontSmall)
    love.graphics.setColor(1,1,1)
    love.graphics.print("PRAVILA:\n- Upisi slovo ili cijelu rijec...\n- Hint i Shield kostaju bodove\n- Pobjeduje tko ima najvise bodova", 50, 470)
end

local function drawGallows(x, y)
    love.graphics.setLineWidth(6)
    love.graphics.line(x, y+220, x+180, y+220)
    love.graphics.line(x+40, y+220, x+40, y)
    love.graphics.line(x+40, y, x+140, y)
    love.graphics.line(x+140, y, x+140, y+40)
end

local function drawParts(x, y, parts)
    local hx, hy = x+140, y+60
    love.graphics.setLineWidth(4)
    local function part(i)
        if i==1 then love.graphics.circle("line", hx, hy, 18)
        elseif i==2 then love.graphics.line(hx, hy+18, hx, hy+75)
        elseif i==3 then love.graphics.line(hx, hy+35, hx-28, hy+55)
        elseif i==4 then love.graphics.line(hx, hy+35, hx+28, hy+55)
        elseif i==5 then love.graphics.line(hx, hy+75, hx-22, hy+110)
        elseif i==6 then love.graphics.line(hx, hy+75, hx+22, hy+110)
        elseif i==7 then love.graphics.points(hx-6, hy-4)
        elseif i==8 then love.graphics.points(hx+6, hy-4)
        elseif i==9 then love.graphics.arc("line", "open", hx, hy+6, 8, math.rad(20), math.rad(160))
        elseif i==10 then love.graphics.rectangle("line", hx-10, hy-48, 20, 18) end
    end
    for i=1, parts do part(i) end
end

function UI.drawHangmanGraphic(mistakes, maxMistakes, shakeT)
    local x, y = 50, 80
    local sx, sy = 0, 0
    if shakeT and shakeT > 0 then sx = love.math.random(-4, 4); sy = love.math.random(-4, 4) end
    love.graphics.push()
    love.graphics.translate(sx, sy)
    love.graphics.setColor(1,1,1)
    drawGallows(x, y)
    drawParts(x, y, math.min(mistakes, maxMistakes or mistakes))
    love.graphics.pop()
end

function UI.drawHangmanText(mistakes, maxMistakes)
    love.graphics.setFont(UI.fontSmall)
    love.graphics.setColor(1,1,1)
    love.graphics.print(("Greske: %d/%d"):format(mistakes, maxMistakes), 50, 50)
end

return UI