local room = require("lj26b:levels.rooms.baseRoom").newRoom()
room.__index = room

local margin = 1
room.width = 10 + margin * 2
room.height = 10 + margin * 2

room.flags = {
  exit = { position = { 0, 1, 0 } }
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

room.build = function(level, transform, rng, roomId)
  local p = room.getTransformPointFunc(transform)
  local self = setmetatable({
    level = level,
    transform = transform,
    p = p,
  }, room)

  level:addStaticVisual("lj26b:models/Dungeon/cave/Planes/Plane_1", p(0, margin/2, -0.1))
    :scaleBy((room.width - margin * 2)/10, (room.height - margin)/10, 1)
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

  addRock(level, p(-1.0, -3.0, -0.1)):rotateAroundZ(rotations[rng:random(#rotations)])
  addRock(level, p(-2.0, -1.0, -0.1)):rotateAroundZ(rotations[rng:random(#rotations)])
  addRock(level, p(-3.0,  0.5, -0.1)):rotateAroundZ(rotations[rng:random(#rotations)])

  addRock(level, p(1.0, -3.0, -0.1)):rotateAroundZ(rotations[rng:random(#rotations)])
  addRock(level, p(2.0, -1.0, -0.1)):rotateAroundZ(rotations[rng:random(#rotations)])
  addRock(level, p(3.0,  0.5, -0.1)):rotateAroundZ(rotations[rng:random(#rotations)])

  level:addDynamicModel("lj26b:models/Dungeon/cave/Rock_2", roomId .. ".1", p(-2.5, 3.0, -2.7))
  level:addDynamicModel("lj26b:models/Dungeon/cave/Rock_2", roomId .. ".2", p( 2.5, 3.0, -2.7))


  return self
end

room.activate = function(self)
  
end

local gate = require("lj26b:gate")

room.update = function(self, dt)
  local player = self.level.player
  if self.isExit and player and not self.gate then
    local x, y, z = self.p(0, 0, 0)
    local px, py, pz = unpack(player.transform.position, 1, 3)
    local dx, dy, dz = x - px, y - py, z - pz
    local magSq = dx * dx + dy * dy + dz * dz
    if magSq <= (10.0 * 10.0) then
      self.moveRocks = self.moveRocks or true
    end
    if magSq <= (6.5 * 6.5) then
      local x, y, z = unpack(self.flags.exit.position, 1, 3)
      local tx, ty, tz = unpack(self.transform.position)
      self.gate = gate.new(self.level, tx + x, ty + y, tz + z)
      self.gate:setTo("game:city", "spawn")
    end
  end
  if self.moveRocks then
    local r1 = self.level:getProp(self.roomId .. ".1")
    local r2 = self.level:getProp(self.roomId .. ".2")

    if r1.transform.position[3] < -0.1 then
      r1.transform:move(nil, nil, math.min(1, .5 * dt))
      if r1.transform.position[3] > -0.1 then
        r1.transform:set(nil, nil, -0.1)
      end
    end
    if r2.transform.position[3] < -0.1 then
      r2.transform:move(nil, nil, math.min(1, .5 * dt))
      if r2.transform.position[3] > -0.1 then
        r2.transform:set(nil, nil, -0.1)
      end
    end
  end
end

return room