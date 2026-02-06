local WordManager = {}

WordManager.bank = {
    {category="Gradovi", word="DUBROVNIK"},
    {category="Tech", word="UMJETNA INTELIGENCIJA"},
    {category="Tech", word="PROGRAMIRANJE"},
    {category="Životinje", word="KROKODIL"},
    {category="Filmovi", word="THE MATRIX"},
}

function WordManager.getRandom()
    return WordManager.bank[love.math.random(1, #WordManager.bank)]
end

return WordManager
