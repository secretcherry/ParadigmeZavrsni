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

-- ---------- MENU ----------
function UI.drawMenu(selectedIndex)
    love.graphics.setFont(UI.fontTitle)
    love.graphics.setColor(1,1,1)
    love.graphics.print("VJESALO (Multiplayer)", 320, 120)

    local items = { "Start Game", "Quit" }
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
    love.graphics.print("Tipke: Gore/Dolje, Enter. ESC izlaz.", 440, 500)
end

-- ---------- HUD ----------
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
        if i == currentTurn then
            love.graphics.setColor(0,1,0)
        else
            love.graphics.setColor(1,1,1)
        end

        local botTag = p.isBot and " [BOT]" or ""
        -- Zamijenjen emoji tekstom
        local shieldTag = p.shield and " [SHIELD]" or ""
        love.graphics.print(
            p.name .. botTag .. "  Score: " .. p.score .. "  Streak: " .. p.streak .. shieldTag,
            400,
            150 + i * 24
        )
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
    love.graphics.print(
        "PRAVILA:\n" ..
        "- Upisi slovo ili cijelu rijec i stisni Enter\n" ..
        "- Ako ponovis isto slovo: dobit ces poruku da probas drugo\n" ..
        "- Promasaj dodaje dio hangmana i prelazi potez\n" ..
        "- Hint otkriva slovo (kosta bodove)\n" ..
        "- Shield blokira sljedecu gresku (kosta bodove)\n" ..
        "- Pogadanje cijele rijeci: tocno = win, netocno = kazna\n" ..
        "- Cilj: najvise bodova nakon svih rundi",
        50, 470
    )
end

-- ---------- HANGMAN GRAPHIC (simple + shake) ----------
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
        if i == 1 then love.graphics.circle("line", hx, hy, 18)
        elseif i == 2 then love.graphics.line(hx, hy+18, hx, hy+75)
        elseif i == 3 then love.graphics.line(hx, hy+35, hx-28, hy+55)
        elseif i == 4 then love.graphics.line(hx, hy+35, hx+28, hy+55)
        elseif i == 5 then love.graphics.line(hx, hy+75, hx-22, hy+110)
        elseif i == 6 then love.graphics.line(hx, hy+75, hx+22, hy+110)
        elseif i == 7 then love.graphics.points(hx-6, hy-4)
        elseif i == 8 then love.graphics.points(hx+6, hy-4)
        elseif i == 9 then love.graphics.arc("line", "open", hx, hy+6, 8, math.rad(20), math.rad(160))
        elseif i == 10 then love.graphics.rectangle("line", hx-10, hy-48, 20, 18)
        end
    end

    for i=1, parts do part(i) end
end

function UI.drawHangmanGraphic(mistakes, maxMistakes, shakeT)
    local x, y = 50, 80

    local sx, sy = 0, 0
    if shakeT and shakeT > 0 then
        sx = love.math.random(-4, 4)
        sy = love.math.random(-4, 4)
    end

    love.graphics.push()
    love.graphics.translate(sx, sy)
    love.graphics.setColor(1,1,1)
    drawGallows(x, y)

    local partsToDraw = math.min(mistakes, maxMistakes or mistakes)
    drawParts(x, y, partsToDraw)
    love.graphics.pop()
end

function UI.drawHangmanText(mistakes, maxMistakes)
    love.graphics.setFont(UI.fontSmall)
    love.graphics.setColor(1,1,1)
    love.graphics.print(("Greske: %d/%d"):format(mistakes, maxMistakes), 50, 50)
end

-- ---------- ROUND END / MATCH END ----------
function UI.drawRoundEnd(title, msg, subtitle)
    love.graphics.setFont(UI.fontTitle)
    love.graphics.setColor(1,1,1)
    love.graphics.print(title, 380, 170)

    love.graphics.setFont(UI.fontMed)
    love.graphics.print(msg or "", 340, 250)

    love.graphics.setFont(UI.fontSmall)
    love.graphics.print(subtitle or "N = sljedeca runda | R = restart match", 380, 310)
end

return UI