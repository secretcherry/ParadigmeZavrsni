local Storage = {}

-- Ime datoteke u save direktoriju (AppData/Roaming/Love/...)
local FILENAME = "leaderboard.txt"
-- Tajni kljuc za generiranje potpisa (da korisnik ne moze samo izracunati novi hash)
local SECRET_SALT = "H7g#m@n_S3cuR3_K3y!"

-- Pomocna funkcija za defaultne vrijednosti
local function getDefaults()
    return {
        {name="", score=0},
        {name="", score=0},
        {name="", score=0}
    }
end

function Storage.save(scores)
    -- 1. Pretvori tablicu u string format: "ime,bodovi;ime,bodovi;..."
    local lines = {}
    for _, entry in ipairs(scores) do
        -- Osiguraj da nema separatora u imenu (za svaki slucaj)
        local safeName = entry.name:gsub("[;,|]", "")
        table.insert(lines, safeName .. "," .. tostring(entry.score))
    end
    local rawData = table.concat(lines, ";")

    -- 2. Izracunaj hash (Checksum) da sprijecis varanje
    -- Koristimo rawData + SECRET_SALT tako da nitko ne moze samo generirati MD5/SHA1 bez kljuca
    local hash = love.data.encode("string", "hex", love.data.hash("sha1", rawData .. SECRET_SALT))

    -- 3. Spoji podatke i hash
    local combined = rawData .. "||" .. hash

    -- 4. Kodiraj u Base64 da ne bude citljivo ljudima (Obfuscation)
    local encodedData = love.data.encode("string", "base64", combined)

    -- 5. Zapisi
    love.filesystem.write(FILENAME, encodedData)
end

function Storage.load()
    -- Ako datoteka ne postoji, kreiraj je s defaultnim vrijednostima i vrati ih
    if not love.filesystem.getInfo(FILENAME) then
        local def = getDefaults()
        Storage.save(def)
        return def
    end

    -- Ucitaj sadrzaj
    local encodedContent = love.filesystem.read(FILENAME)

    -- Dekodiraj Base64
    local ok, decodedContent = pcall(love.data.decode, "string", "base64", encodedContent)
    
    -- Ako dekodiranje nije uspjelo (korisnik unio gluposti), vrati default
    if not ok or not decodedContent then
        print("Save file corrupted (base64 error). Resetting.")
        return getDefaults()
    end

    -- Razdvoji podatke i hash (trazimo separator "||")
    local rawData, savedHash = decodedContent:match("^(.*)||(%w+)$")

    if not rawData or not savedHash then
        print("Save file corrupted (structure error). Resetting.")
        return getDefaults()
    end

    -- Provjeri integritet: Izracunaj hash ponovno i usporedi
    local calculatedHash = love.data.encode("string", "hex", love.data.hash("sha1", rawData .. SECRET_SALT))

    if calculatedHash ~= savedHash then
        print("Save file tampered with! (Cheater detected). Resetting.")
        -- Ako se hash ne podudara, netko je rucno mijenjao file. Vrati default.
        return getDefaults()
    end

    -- Parsiraj podatke natrag u tablicu
    local scores = {}
    for item in rawData:gmatch("([^;]+)") do
        local name, score = item:match("^(.*),(%d+)$")
        if name and score then
            table.insert(scores, {name = name, score = tonumber(score)})
        end
    end

    -- Sortiraj i limitiraj (za svaki slucaj)
    table.sort(scores, function(a,b) return a.score > b.score end)
    while #scores > 3 do table.remove(scores) end
    
    -- Ako je lista prazna ili kraca od 3 zbog greske u parsiranju, popuni
    while #scores < 3 do
        table.insert(scores, {name="", score=0})
    end

    return scores
end

return Storage