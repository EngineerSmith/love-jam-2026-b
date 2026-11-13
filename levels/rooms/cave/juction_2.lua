local room = require("lj26b:levels.rooms.baseRoom").newRoom()
room.__index = room

local margin = 1
room.width = 20 + margin * 2 + margin
room.height = 10 + margin * 2

room.sockets = {
  { position = {  5 + margin,  5 + margin, 0 }, direction = { 0,  1, 0 } },
  { position = { -5 - margin, -5 - margin, 0 }, direction = { 0, -1, 0 } },
  { position = {  10 + margin,  0, 0 }, direction = { 1,  0, 0 } },
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

room.build = function(level, transform, rng, roomId)
  local p = room.getTransformPointFunc(transform)
  local self = setmetatable({
    level = level,
    transform = transform,
    p = p,
  }, room)

  level:addStaticVisual("lj26b:models/Dungeon/cave/Planes/Plane_4", p(-margin/4, 0, -0.1))
    :scaleBy((room.width- margin/2)/10, room.height/10, 1)
    :rotateByTransform(transform)

  for i = 2, 10, 2 do addWall(level, rng, p(i, -5.5, -0.1)):rotateByTransform(transform) end
  for i = -10, 0, 2 do addWall(level, rng, p(i, 4.5, -0.1)):rotateAroundZ(math.rad(180)):rotateByTransform(transform) end
  for i = -5, 5, 2 do addWall(level, rng, p(-11.5, i, -0.1)):rotateAroundZ(math.rad(90)):rotateByTransform(transform) end

  addWall(level, rng, p(.5, 5.5, -0.1))
    :rotateAroundZ(math.rad(90))
    :rotateByTransform(transform)

  addWall(level, rng, p(.25, -5.75, -0.1))
    :rotateAroundZ(math.rad(-25))
    :rotateByTransform(transform)

  for _ = 1, 5 do
    local x, y, z = p((rng:random(-45, 45) / 10), rng:random(-45, 45) / 10, 0)
    if math.abs(x) > 1.5 and math.abs(y) > 1.5 then 
      addRock(level, x, y, z)
        :rotateAroundZ(rotations[rng:random(#rotations)])
    end
  end

  return self
end

local slime = require("lj26b:entities.slime")
local wolf = require("lj26b:entities.wolf")
room.activate = function(self)
  local w = wolf:clone()
  w:addToLevel(self.level, { self.p(-3, -1, 0) })
  local w = wolf:clone()
  w:addToLevel(self.level, { self.p(-3,  1, 0) })

  local s = slime:clone()
  s:addToLevel(self.level, { self.p(3, 0, 0) })
end

return room