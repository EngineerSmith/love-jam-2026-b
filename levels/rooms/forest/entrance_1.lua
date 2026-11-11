local room = require("lj26b:levels.rooms.baseRoom").newRoom()
room.__index = room

room.width = 10
room.height = 10

room.flags = {
  entrance = { 0, 0, 0 }
}

room.sockets = {
  { position = { 0, 5, 0 }, direction = { 0, 1, 0 } }
}

local addTree = function(level, x, y, z)
  level:addStaticModelWithShape("lj26b:models/Mini Forest/tree",
    require("libs.slick").newCircleShape(0, 0, .4), x, y, z)
end

local addTreeBig = function(level, x, y, z)
  level:addStaticModelWithShape("lj26b:models/Mini Forest/tree-high",
    require("libs.slick").newCircleShape(0, 0, .3), x, y, z)
end

room.build = function(level, transform, rng)
  local self = setmetatable({ }, room)
  local p = room.getTransformPointFunc(transform)

  level:addStaticVisual("lj26b:models/Dungeon/Plane_1", p(0, 0, -0.1))
    :rotateQ(transform.rotation.a, transform.rotation.b, transform.rotation.c, transform.rotation.d)

  addTree(level, p(3, -3, -0.1))

  addTreeBig(level, p(3, 0, -0.1))

  return self
end

room.activate = function(self)
  if self.isSpawn then
    -- camera.current, add Camera to rails
  end
end

return room