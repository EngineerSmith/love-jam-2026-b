local room = require("lj26b:levels.rooms.baseRoom").newRoom()
room.__index = room

local margin = 1
room.width = 10 + margin * 2
room.height = 10 + margin * 2

room.sockets = {
  { position = { 0,  5 + margin, 0 }, direction = { 0,  1, 0 } },
  { position = { 0, -5 - margin, 0 }, direction = { 0, -1, 0 } },
  { position = { 5 + margin,  0, 0 }, direction = { 1,  0, 0 } },
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

  level:addStaticVisual("lj26b:models/Dungeon/cave/Planes/Plane_4", p(margin/2, 0, -0.1))
    :scaleBy((room.width- margin)/10, room.height/10, 1)
    :rotateByTransform(transform)

  -- for i = -4, 4, 2 do addWall(level, rng, p(i, -5.5, -0.1)):rotateByTransform(transform) end
  -- for i = -4, 4, 2 do addWall(level, rng, p(5.5, i, -0.1)):rotateAroundZ(math.rad(-90)):rotateByTransform(transform) end
  for i = -5, 5, 2 do addWall(level, rng, p(-5.5, i, -0.1)):rotateAroundZ(math.rad(90)):rotateByTransform(transform) end

  -- addWall(level, rng, p(5.9, 5.9, -0.1))
  --   :rotateAroundZ(math.rad(-45-90))
  --   :rotateByTransform(transform)

  -- addWall(level, rng, p(5.9, -5.9, -0.1))
  --   :rotateAroundZ(math.rad(-45-90+180))
  --   :rotateByTransform(transform)

  for _ = 1, 5 do
    local x, y, z = p((rng:random(-45, 45) / 10), rng:random(-45, 45) / 10, 0)
    if math.abs(x) > 1.5 and math.abs(y) > 1.5 then 
      addRock(level, x, y, z)
        :rotateAroundZ(rotations[rng:random(#rotations)])
    end
  end

  return self
end

local wolf = require("lj26b:entities.wolf")
local slime = require("lj26b:entities.slime")
room.activate = function(self)
  local target = love.math.random() > 0.5 and wolf or slime
  local m = target:clone()
  m:addToLevel(self.level, { self.p(-1, 0, 0) })
  local m = slime:clone()
  m:addToLevel(self.level, { self.p( 1, 0, 0) })
end

return room