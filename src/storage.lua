local Storage = {}

local FILENAME = "leaderboard.txt"
local SECRET_SALT = "H7g#m@n_S3cuR3_K3y!"

local function getDefaults()
    return {
        {name="", score=0},
        {name="", score=0},
        {name="", score=0}
    }
end

function Storage.save(scores)
    local lines = {}
    for _, entry in ipairs(scores) do
        local safeName = entry.name:gsub("[;,|]", "")
        table.insert(lines, safeName .. "," .. tostring(entry.score))
    end
    local rawData = table.concat(lines, ";")
    local hash = love.data.encode("string", "hex", love.data.hash("sha1", rawData .. SECRET_SALT))
    local combined = rawData .. "||" .. hash
    local encodedData = love.data.encode("string", "base64", combined)
    love.filesystem.write(FILENAME, encodedData)
end

function Storage.load()
    if not love.filesystem.getInfo(FILENAME) then
        local def = getDefaults()
        Storage.save(def)
        return def
    end
    local encodedContent = love.filesystem.read(FILENAME)
    local ok, decodedContent = pcall(love.data.decode, "string", "base64", encodedContent)
    if not ok or not decodedContent then return getDefaults() end
    local rawData, savedHash = decodedContent:match("^(.*)||(%w+)$")
    if not rawData or not savedHash then return getDefaults() end
    local calculatedHash = love.data.encode("string", "hex", love.data.hash("sha1", rawData .. SECRET_SALT))
    if calculatedHash ~= savedHash then return getDefaults() end
    local scores = {}
    for item in rawData:gmatch("([^;]+)") do
        local name, score = item:match("^(.*),(%d+)$")
        if name and score then table.insert(scores, {name = name, score = tonumber(score)}) end
    end
    table.sort(scores, function(a,b) return a.score > b.score end)
    while #scores > 3 do table.remove(scores) end
    while #scores < 3 do table.insert(scores, {name="", score=0}) end
    return scores
end

return Storage