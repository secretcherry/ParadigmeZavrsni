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

function UI.drawMenu(selectedIndex, numPlayers)
    love.graphics.setFont(UI.fontTitle)
    love.graphics.setColor(1,1,1)
    love.graphics.print("VJESALO (Multiplayer)", 320, 120)

    local items = { "Start Game", "Broj igraca: < " .. numPlayers .. " >", "Quit" }
    love.graphics.setFont(UI.fontBig)

    for i, item in ipairs(items) do
        if i == selectedIndex then
            love.graphics.setColor(1, 1, 0)
            love.graphics.print("> " .. item, 470, 260 + i*50)
        else
            love.graphics.setColor(1,1,1)
            love.graphics.print(item, 500, 260 + i*50)
        end
    end

    love.graphics.setFont(UI.fontSmall)
    love.graphics.setColor(1,1,1)
    love.graphics.print("Tipke: Gore/Dolje, Enter.", 440, 500)
    love.graphics.print("Strelica lijevo/desno za promjenu broja igraca.", 440, 520)
end

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
        local botTag = p.isBot and " [BOT]" or ""
        local shieldTag = p.shield and " [SHIELD]" or ""
        love.graphics.print(p.name .. botTag .. "  Score: " .. p.score .. "  Streak: " .. p.streak .. shieldTag, 400, 150 + i * 24)
    end
    love.graphics.setColor(1,1,1)
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

-- Hangman graphics
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

function UI.drawRoundEnd(title, msg, subtitle)
    love.graphics.setFont(UI.fontTitle)
    love.graphics.setColor(1,1,1)
    love.graphics.print(title, 380, 170)
    love.graphics.setFont(UI.fontMed)
    love.graphics.print(msg or "", 340, 250)
    love.graphics.setFont(UI.fontSmall)
    love.graphics.print(subtitle or "", 380, 310)
end

-- [NOVO] Prikaz za upis imena
function UI.drawHighscoreInput(title, msg, currentInput)
    love.graphics.setFont(UI.fontTitle)
    love.graphics.setColor(1, 1, 0) -- zuta za highscore
    love.graphics.print(title, 420, 150)

    love.graphics.setFont(UI.fontBig)
    love.graphics.setColor(1,1,1)
    love.graphics.print(msg, 480, 230)

    -- Input box stil
    love.graphics.rectangle("line", 450, 280, 300, 50)
    love.graphics.print(currentInput .. "_", 460, 290)

    love.graphics.setFont(UI.fontSmall)
    love.graphics.print("Pritisni ENTER za potvrdu", 500, 350)
end

-- [NOVO] Prikaz leaderboard ljestvice
function UI.drawLeaderboard(scores, subtitle)
    love.graphics.setFont(UI.fontTitle)
    love.graphics.setColor(1, 0.5, 0) -- narancasta
    love.graphics.print("TOP 3 IGRACA", 450, 100)

    love.graphics.setFont(UI.fontBig)
    for i, entry in ipairs(scores) do
        local color = {1,1,1}
        if i == 1 then color = {1, 0.84, 0} -- Gold
        elseif i == 2 then color = {0.75, 0.75, 0.75} -- Silver
        elseif i == 3 then color = {0.8, 0.5, 0.2} -- Bronze
        end
        
        love.graphics.setColor(color)
        -- Format: 1. AAA ..... 1000
        love.graphics.print(string.format("%d. %-10s  %d", i, entry.name, entry.score), 450, 180 + i * 50)
    end

    love.graphics.setColor(1,1,1)
    love.graphics.setFont(UI.fontSmall)
    love.graphics.print(subtitle or "", 480, 450)
end

return UI