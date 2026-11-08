local camera = require("s3d:camera")
local player = require("lj26b:player")

return function(level)

  local kitchenCamera = camera.new()
  kitchenCamera.fov = math.rad(70)

  level.active = function(_, flag)
    kitchenCamera:setCurrent()
    if flag then
      player:addToLevel(level, level:getFlag(flag))
    else
      player:addToLevel(level)
    end
    level:setPlayer(player)
    local pt = player.transform
    local x, y, z = pt.position[1], pt.position[2], pt.position[3]
    -- camera.current:lookAt(x + 3, y, z + 1.5, x, y, z + .5)
  end

  level.update = function(self, dt)
    getmetatable(level).update(self, dt)

    local pt = player.transform
    local x, y, z = pt.position[1], pt.position[2], pt.position[3]
    camera.current:lookAt(4, 0, 2, x, y, z + .5)
  end

  level:setLight(
    { 0.40, 0.35,  0.85 },
    { 1.05,  1.00, 0.92 },
    { 0.58,  0.58, 0.62 }
  )
  level.shadow.intensity = 0.8
  level.shadow.softness = 0.2

  level:addFlag("spawn", { 0, 0, 0 })

  level:addStaticVisual("lj26b:models/kitchen/kitchen_floor_2", 0, 0, -0.1)

  level:addStaticVisual("lj26b:models/kitchen/kitchen_wall", -3.5, 0, 0):rotateAroundZ(math.rad(-90))
  -- level:addStaticVisual("lj26b:models/kitchen/kitchen_wall",  3.3, 0, 0):rotateAroundZ(math.rad(-90))
  level:addStaticVisual("lj26b:models/kitchen/kitchen_wall", 0, -3.5, 0):rotateAroundZ(math.rad(180))
  level:addStaticVisual("lj26b:models/kitchen/kitchen_wall", 0,  3.5, 0):rotateAroundZ(math.rad(180))

  level:addStaticModel("s3d:cube", 0, -3, -.2):scaleBy(3, 1, 1)
  level:addStaticModel("s3d:cube", 0,  3, -.2):scaleBy(3, 1, 1)
end