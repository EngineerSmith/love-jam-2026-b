local room = require("lj26b:levels.rooms.baseRoom").newRoom()
room.__index = room

local margin = 1
room.width = 10 + margin * 2
room.height = 4 + margin * 2

room.sockets = {
  { position = { 0, 2 + margin, 0 }, direction = { 0, 1, 0 } }
}

local walls = {
  "lj26b:models/Dungeon/cave/Wall",
  "lj26b:models/Dungeon/cave/Wall_2",
  "lj26b:models/Dungeon/cave/Wall_3",
}
local addWall = function(level, rng, x, y, z)
  local model = walls[rng:random(#walls)]
  return level:addStaticModel(model, x, y, z)
end

local addRock = function(level, x, y, z)
  return level:addStaticModel("lj26b:models/Dungeon/cave/Rock", x, y, z)
end

local rotations = { math.pi * 0.5, math.pi, math.pi * 1.5, math.pi * 2 }

room.build = function(level, transform, rng)
  local p = room.getTransformPointFunc(transform)
  local self = setmetatable({
    level = level,
    p = p,
  }, room)

  level:addStaticVisual("lj26b:models/Dungeon/cave/Planes/Plane_1", p(0, margin/2, -0.1))
    :scaleBy((room.width - margin*2)/10, (room.height - margin)/10, 1)
    :rotateByTransform(transform)

  for i = -4, 4, 2 do addWall(level, rng, p(i, -2, -0.1)):rotateByTransform(transform) end
  for i = -2, 2, 2 do addWall(level, rng, p(5.5, i, -0.1)):rotateAroundZ(math.rad(-90)):rotateByTransform(transform) end
  for i = -2, 2, 2 do addWall(level, rng, p(-5.5, i, -0.1)):rotateAroundZ(math.rad(90)):rotateByTransform(transform) end

  addWall(level, rng, p(4.0, -1.0, -0.1))
    :rotateAroundZ(math.rad(135+180))
    :rotateByTransform(transform)

  addWall(level, rng, p(-4.0, -1.0, -0.1))
    :rotateAroundZ(math.rad(-135+180))
    :rotateByTransform(transform)

  return self
end

local wolf = require("lj26b:entities.wolf")
room.activate = function(self)
  local w = wolf:clone()
  w:addToLevel(self.level, { self.p(0, -.5, 0) })
end

return room