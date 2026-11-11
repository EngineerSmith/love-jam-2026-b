local baseRoom = { }
baseRoom.__index = baseRoom

baseRoom.newRoom = function()
  return setmetatable({ }, baseRoom)
end

baseRoom.getTransformPointFunc = function(transform)
  local _vec
  return function(x, y, z)
    return unpack(transform:transformPoint({ x, y, z }, _vec), 1, 3)
  end
end

baseRoom.activate = function() end

return baseRoom