local room = require("lj26b:levels.rooms.baseRoom").newRoom()
room.__index = room

room.width = 10
room.height = 10

room.flags = {
  exit = { 0, 0, 0 }
}

room.sockets = {
  { position = { 0, 5, 0 }, direction = { 0, 1, 0 } }
}

room.build = function(level, transform, rng)
  local self = setmetatable({ }, room)
  local p = room.getTransformPointFunc(transform)

  level:addStaticVisual("lj26b:models/Dungeon/Plane_1", p(0, 0, -0.1))
    :rotateQ(transform.rotation.a, transform.rotation.b, transform.rotation.c, transform.rotation.d)

  return self
end

return room