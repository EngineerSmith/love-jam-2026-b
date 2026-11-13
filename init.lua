
local camera = require("s3d:camera")
local levelManager = require("s3d:levelManager")

require(":ui")
require(":damageNumbers")
require(":inventory.itemDefinitions")
do -- Bug in my engine which means I have to require it first (See require issue on whiteboard)
  require(":levels.city")
  require(":levels.kitchen")
end
local player = require(":player")
local inventory = require(":inventory")

require(":levels.city")
require(":levels.kitchen")
require(":levels.dungeon")
levelManager.addLevelModifier("game:city", "lj26b:levels.city")
levelManager.addLevelModifier("game:kitchen", "lj26b:levels.kitchen")
levelManager.addLevelModifier("game:dungeon", "lj26b:levels.dungeon")

CONTEXT.hook("load", function(scene)
  if scene == "init" then
    levelManager.warmLevel("game:city")
    levelManager.warmLevel("game:kitchen")
  elseif scene == "game" then
    levelManager.setActiveLevel("game:city", .5, .5, "spawn")
  end
end)

CONTEXT.hook("engine:update", function(dt)
  inventory.update(dt)
end, nil, { scene = "game" })

CONTEXT.hook("engine:draw", function(partialTick)
  inventory.drawToasts()
end, -100, { scene = "game" })

CONTEXT.hook("resize", function(width, height)
  camera.current:setAspectRatio(width, height)
end, nil, { scene = "game" })
