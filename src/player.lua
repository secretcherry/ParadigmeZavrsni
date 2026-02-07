local Player = {}
Player.__index = Player

function Player.new(name)
    local self = setmetatable({}, Player)
    self.name = name
    self.score = 0
    self.streak = 0
    self.shield = false
    return self
end

function Player:addScore(points)
    self.score = math.max(0, self.score + points)
end

return Player