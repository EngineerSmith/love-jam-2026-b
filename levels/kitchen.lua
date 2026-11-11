local slick = require("libs.slick")

local camera = require("s3d:camera")
local levelManager = require("s3d:levelManager")

local player = require("lj26b:player")

local itemDefinitions = require("lj26b:inventory.itemDefinitions")

local cookingPot = require("lj26b:cookingPot")

local gate = require("lj26b:gate")

return function(level)

  local kitchenCamera = camera.new()
  kitchenCamera.fov = math.rad(70)

  level.active = function(_, flag)
    kitchenCamera:setCurrent()
    kitchenCamera:setAspectRatio(love.graphics.getDimensions())
    player.transform:scaleBy(1, 1, 1)
    player.isInTransition = false
    if flag then
      player:addToLevel(level, level:getFlag(flag))
    else
      player:addToLevel(level)
    end
    level:setPlayer(player)

    local pt = player.transform
    local x, y, z = pt.position[1], pt.position[2], pt.position[3]
    kitchenCamera:lookAt(4, 0, 2, x, y, z + .5)
    local screenX, screenY = kitchenCamera:project(x, y, z + .5)
    levelManager.setTransitionPos(screenX / love.graphics.getWidth(), screenY / love.graphics.getHeight())

    cookingPot.setSpawnPoint(-2, 0, .5, -.5, 0, 0)
  end

  level.update = function(self, dt)
    getmetatable(level).update(self, dt)

    local pt = player.transform
    local x, y, z = pt.position[1], pt.position[2], pt.position[3]
    camera.current:lookAt(4, 0, 2, x, y, z + .5)

    ---
    cookingPot.update(dt)

    local lidProp = level:getProp("pot_lid")
    local potProp = level:getProp("pot")
    if cookingPot.bubbleTimer > 0 then
      local t = love.timer.getTime() * 25

      local lift = 0.08 + math.sin(t * 1.3) * 0.03
      local tiltX = math.sin(t * 2.1) * 0.05
      local tiltY = math.sin(t * 1.7) * 0.05

      lidProp.transform:set(-2, 0, 1.4 + lift)
        :rotateQ(1, 0, 0, 0)
        :rotateAroundX(tiltX)
        :rotateAroundY(tiltY)

      local pulse = math.sin(t * 1.5) * 0.03
      potProp.transform:scaleBy(1 + pulse, 1 + pulse, 1 - pulse * 0.5)
    elseif cookingPot.openTimer > 0 then
      local progress = 1 - (cookingPot.openTimer / cookingPot.timeToOpen)
      local ease = math.sin(progress * math.pi * 0.5)

      local lift = 0.08 + ease * 0.2
      local back = ease * 0.25
      local tiltY = ease * math.rad(20)

      lidProp.transform:set(-2 - back, 0, 1.4 + lift)
        :rotateQ(1, 0, 0, 0)
        :rotateAroundY(tiltY)

      local t = love.timer.getTime()
      local pulse = (math.sin(t * 12) * 0.025) * (1 - progress)
      potProp.transform:scaleBy(1 + pulse, 1 + pulse, 1- pulse * 0.5)
    else
      lidProp.transform:set(-2, 0, 1.4):rotateQ(1, 0, 0, 0)
      potProp.transform:scaleBy(1, 1, 1)
    end
  end

  level:setLight(
    { 0.40, 0.35,  0.85 },
    { 1.05,  1.00, 0.92 },
    { 0.58,  0.58, 0.62 }
  )
  level.shadow.intensity = 0.8
  level.shadow.softness = 0.2

  level:addFlag("spawn", { 1, 0, 0 })

  level:addStaticVisual("lj26b:models/kitchen/kitchen_floor_2", 0, 0, -0.1)

  level:addStaticVisual("lj26b:models/kitchen/kitchen_wall", -3.5, 0, 0):rotateAroundZ(math.rad(-90))
  -- level:addStaticVisual("lj26b:models/kitchen/kitchen_wall",  3.3, 0, 0):rotateAroundZ(math.rad(-90))
  level:addStaticVisual("lj26b:models/kitchen/kitchen_wall", 0, -3.5, 0):rotateAroundZ(math.rad(180))
  level:addStaticVisual("lj26b:models/kitchen/kitchen_wall", 0,  3.5, 0):rotateAroundZ(math.rad(180))

  level:addStaticModel("s3d:cube", 0, -3, -.2):scaleBy(3, 1, 1)
  level:addStaticModel("s3d:cube", 0,  3, -.2):scaleBy(3, 1, 1)

  level:addDynamicModelWithShape("lj26b:models/kitchen/pot", "pot",
    slick.newCircleShape(0, 0, 1.25),
  -2, 0, -.1)

  level:addDynamicVisual("lj26b:models/kitchen/pot_lid", "pot_lid", -2, 0, 1.4)
end