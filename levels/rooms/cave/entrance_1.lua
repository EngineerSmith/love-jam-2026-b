local room = require("lj26b:levels.rooms.baseRoom").newRoom()
room.__index = room

local margin = 1
room.width = 10 + margin * 2
room.height = 10 + margin * 2

room.flags = {
  entrance = { position = { -3, 0, 0 } }
}

room.sockets = {
  { position = { 0, 5 + margin, 0 }, direction = { 0, 1, 0 } }
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

  for i = -5, 5, 2 do addWall(level, rng, p(i, -5.5, -0.1)):rotateByTransform(transform) end
  for i = -5, 5, 2 do addWall(level, rng, p(5.5, i, -0.1)):rotateAroundZ(math.rad(-90)):rotateByTransform(transform) end
  for i = -5, 5, 2 do addWall(level, rng, p(-5.5, i, -0.1)):rotateAroundZ(math.rad(90)):rotateByTransform(transform) end

  addWall(level, rng, p(4.5, -4.5, -0.1))
    :rotateAroundZ(math.rad(135+180))
    :rotateByTransform(transform)

  addWall(level, rng, p(-4.5, -4.5, -0.1))
    :rotateAroundZ(math.rad(-135+180))
    :rotateByTransform(transform)


  local count = 0
  for _ = 1, 5 do
    if rng:random() > 0.2 then
      addRock(level, p((rng:random(-5, 10) / 10) + 3.5, rng:random(-40, 40) / 10, 0)):rotateAroundZ(rotations[rng:random(#rotations)])
      count = count + 1
      if count >= 3 then break end
    end
  end

  local count = 0
  for _ = 1, 5 do
    if rng:random() > 0.2 then
      addRock(level, p(rng:random(-40, 40) / 10, (rng:random(-5, 10) / 10) - 3.5, 0)):rotateAroundZ(rotations[rng:random(#rotations)])
      count = count + 1
      if count >= 3 then break end
    end
  end

  addRock(level, p(-4, 4, 0)):rotateAroundZ(rotations[rng:random(#rotations)])


  return self
end

local gate = require("lj26b:gate")
local closingColor = { .5, .1, .1, 1 }
local closingFinishColor = { .3, .05, .05, 1 }

room.activate = function(self)
  if self.isSpawn then
    self.gateTimer = 0
    local x, y, z = unpack(self.flags.entrance.position, 1, 3)
    self.gate = gate.new(self.level, x - 1, y, z, { unpack(closingColor, 1, 4) }, "stable")
  end
end

local maxTime = 1
room.update = function(self, dt)
  if self.isSpawn and self.gateTimer and self.gate then
    self.gateTimer = self.gateTimer + dt
    local p = math.min(1, math.max(0, self.gateTimer / maxTime))
    local r, g, b, a = unpack(closingColor, 1, 4)
    local fr, fg, fb, fa = unpack(closingFinishColor, 1, 4)
    local dr, dg, db, da = r + (fr - r) * p, b + (fb - b) * p, g + (fg - g) * p, a + (fa - a) * p
    self.gate.color[1], self.gate.color[2], self.gate.color[3], self.gate.color[4] = dr, dg, db, da
    if self.gateTimer >= maxTime then
      self.gate.color[1], self.gate.color[2], self.gate.color[3], self.gate.color[4] = fr, fg, fb, fa
      self.gate:changeState("closing")
      self.gateTimer = nil
    end
  end
end

return room