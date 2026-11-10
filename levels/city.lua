
local camera = require("s3d:camera")
local levelManager = require("s3d:levelManager")

local player = require("lj26b:player")

local trainingDummy = require("lj26b:entities.trainingDummy")
local wolf = require("lj26b:entities.wolf")

local itemDefinitions = require("lj26b:inventory.itemDefinitions")

return function(level)

  local cityCamera = camera.new()

  level.getResourceKeys = function(_, outKeys, inMap)
    trainingDummy:getSpriteResourceKeys(outKeys, inMap)
    wolf:getSpriteResourceKeys(outKeys, inMap)
  end

  level.active = function(_, flag)
    cityCamera:setCurrent()
    cityCamera:setAspectRatio(love.graphics.getDimensions())
    if flag then -- Player overrides "addtoLevel" to define it's default state on new level
      player:addToLevel(level, level:getFlag(flag))
    else
      player:addToLevel(level)
    end
    level:setPlayer(player)

    local pt = player.transform
    local x, y, z = pt.position[1], pt.position[2], pt.position[3]
    cityCamera:lookAt(x + 3, y, z + 2.5, x, y, z + 1.5)
    local screenX, screenY = cityCamera:project(x, y, z + .5)
    levelManager.setTransitionPos(screenX / love.graphics.getWidth(), screenY / love.graphics.getHeight())

    local td = trainingDummy:clone()
    td:addToLevel(level, { -2, -2, 0 })
    local td = trainingDummy:clone()
    td:addToLevel(level, { -2,  0, 0 })
    local td = trainingDummy:clone()
    td:addToLevel(level, { -2,  2, 0 })

    local wolf = wolf:clone()
    wolf:addToLevel(level, { -5, 0, 0 }) 

    itemDefinitions["void_peach"]:spawn(level, { 3, -3, 0 })
    itemDefinitions["wolf_tuff"]:spawn(level, { 3, -2.5, 0 })
    itemDefinitions["slime_jelly"]:spawn(level, { 3, -2, 0 })
    itemDefinitions["empty_jar"]:spawn(level, { 3, -1.5, 0 })
    itemDefinitions["void_jam"]:spawn(level, { 3, -1, 0 })
    itemDefinitions["stringy_jam"]:spawn(level, { 3, -.5, 0 })
    -- itemDefinitions["stick"]:spawn(level, { -3, -3, 0 })
  end

  level.deactivate = function()
    player:removeFromLevel(level)
    for _, char in ipairs(level.characters) do
      if char.removeFromLevelWorld then
        char:removeFromLevelWorld()
      end
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