
local camera = require("s3d:camera")
local player = require("lj26b:player")

return function(level)

  level.active = function(_, flag)
    if flag then
      player:addToLevel(level, level:getFlag(flag))
    else
      player:addToLevel(level)
    end
  end

  level.deactivate = function()
    player:removeFromLevel(level)
  end

  level.update = function(_, _)
    local pt = player.transform
    local x, y, z = pt.position[1], pt.position[2], pt.position[3]
    -- camera.current:lookAt(x + 3, y, z + 2.5, x, y, z + 1.5)
    camera.current:lookAt(x, y - 3, z + 2.5, x, y, z + 1.5)
    -- print(x + 3, y, z + 1.5 + x, x, y, z + 1.5)
    -- camera.current:lookAt(3, 0, 1.8, 0, 0, 1.8)
  end

  level:addFlag("new", { 0, 0, 0 })

  level:addStaticVisual("lj26b:models/Platform", 0, 0, -0.1)

end