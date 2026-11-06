
local camera = require("s3d:camera").new()
local levelManager = require("s3d:levelManager")

require(":ui")
do -- Bug in my engine which means I have to require it first
  require(":levels.city")
  require(":levels.kitchen")
end
local player = require(":player")

levelManager.addLevelModifier("game:city", "lj26b:levels.city")
levelManager.addLevelModifier("game:kitchen", "lj26b:levels.kitchen")

CONTEXT.hook("load", function(scene)
  if scene == "init" then
    levelManager.warmLevel("game:city")
  elseif scene == "game" then
    levelManager.setActiveLevel("game:city", "new")
  end
end)

CONTEXT.hook("engine:update", function(dt)
  player:update(dt)
end, nil, { scene = "game" })

CONTEXT.hook("engine:draw", function(partialTick)
  player:draw()
end, nil, { scene = "game" })

CONTEXT.hook("resize", function(width, height)
  camera:setAspectRatio(width, height)
end, nil, { scene = "game" })
