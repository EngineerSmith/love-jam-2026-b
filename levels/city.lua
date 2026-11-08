
local camera = require("s3d:camera")
local player = require("lj26b:player")

local trainingDummy = require("lj26b:entities.trainingDummy")
local wolf = require("lj26b:entities.wolf")

return function(level)

  local cityCamera = camera.new()

  level.getResourceKeys = function(_, outKeys, inMap)
    trainingDummy:getSpriteResourceKeys(outKeys, inMap)
    wolf:getSpriteResourceKeys(outKeys, inMap)
  end

  level.active = function(_, flag)
    cityCamera:setCurrent()
    if flag then -- Player overrides "addtoLevel" to define it's default state on new level
      player:addToLevel(level, level:getFlag(flag))
    else
      player:addToLevel(level)
    end
    level:setPlayer(player)

    local td = trainingDummy:clone()
    td:addToLevel(level, { -2, -2, 0 })
    local td = trainingDummy:clone()
    td:addToLevel(level, { -2,  0, 0 })
    local td = trainingDummy:clone()
    td:addToLevel(level, { -2,  2, 0 })

    local wolf = wolf:clone()
    wolf:addToLevel(level, { -5, 0, 0 })
  end

  level.deactivate = function()
    player:removeFromLevel(level)
    for _, char in ipairs(level.characters) do
      char:removeFromLevelWorld()
    end
    level:removeAllCharacter()
  end

  level.update = function(self, dt)
    getmetatable(level).update(self, dt)

    local pt = player.transform
    local x, y, z = pt.position[1], pt.position[2], pt.position[3]
    camera.current:lookAt(x + 3, y, z + 2.5, x, y, z + 1.5)
    -- camera.current:lookAt(x, ys - 3, z + 2.5, x, y, z + 1.5)
    -- print(x + 3, y, z + 1.5 + x, x, y, z + 1.5)
    -- camera.current:lookAt(3, 0, 1.8, 0, 0, 1.8)
  end

  level:addFlag("spawn", { 0, 0, 0 })

  level:addStaticVisual("lj26b:models/Platform", 0, 0, -0.1)

end