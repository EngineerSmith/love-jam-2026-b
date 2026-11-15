local lg = love.graphics

local slick = require("libs.slick")

local windowManager = require("src.core.windowManager")
local assetManager = require("src.core.assetManager")

local camera = require("s3d:camera")
local levelManager = require("s3d:levelManager")

local uiManager = require("menu:uiManager")

local player = require("lj26b:player")

local trainingDummy = require("lj26b:entities.trainingDummy")
local wolf = require("lj26b:entities.wolf")
local crowd = require("lj26b:entities.crowd")

local flockManager = require("lj26b:flockManager")

local itemDefinitions = require("lj26b:inventory.itemDefinitions")

local gate = require("lj26b:gate")

return function(level)
  local cityCamera = camera.new()

  level.getResourceKeys = function(_, outKeys, inMap)
    trainingDummy:getSpriteResourceKeys(outKeys, inMap)
    wolf:getSpriteResourceKeys(outKeys, inMap)
    crowd:getSpriteResourceKeys(outKeys, inMap)
  end

  local updateFloorPlane = function()
    local pixelUnits = 1 / 16

    local prop = level:getProp("groundPlane")
    if not prop then return end
    local model = assetManager.get(prop.resourceKey)
    if not model then return end
    local o = model.objects[1]
    local m = o.material
    local texture = assetManager.get(m.diffuseTexture)
    if not texture then return end
    local width, height = texture:getDimensions()
    local scaleW, scaleH = width * pixelUnits, height * pixelUnits
    prop.transform:scaleBy(scaleW, scaleH, 1)
  end

  local storeFrontCrowd
  local parkCrowd
  level.active = function(_, flag)
    if flag == "tutorial" then
      level.state = "tutorial"
    elseif flag == "spawn" then
      level.state = "new"
    else
      level.state = "old"
    end

    local jumpTo
    if type(flag) == "table" then -- Coming back from kitchen
      local x, y, z, prevState = unpack(flag)
      level.state = prevState
      jumpTo = { x, y, z }
      if level.state == "kitchen" then
        flag = "kitchen"
        level.state = "new"
        if level.world and level.world:has("tutorialBlock") then
          level.world:remove("tutorialBlock")
        end
        uiManager.push("game:menu.tutorial3")
      end
    end

    cityCamera:setCurrent()
    cityCamera:setAspectRatio(love.graphics.getDimensions())
    cityCamera:setPerspective(math.rad(75))
    player.transform:scaleBy(1, 1, 1)
    player.isInTransition = false
    player.isInCutscene = false
    if flag then -- Player overrides "addtoLevel" to define it's default state on new level
      local f = flag
      if f == "tutorial" then
        f = "spawn"
      end
      local fResult = level:getFlag(f)
      player:addToLevel(level, jumpTo or fResult)
    else
      player:addToLevel(level)
    end
    level:setPlayer(player)

    local pt = player.transform
    local x, y, z = pt.position[1], pt.position[2], pt.position[3]
    cityCamera:lookAt(x + 3, y, 2.5, x, y, 1.5)
    local screenX, screenY = cityCamera:project(x, y, z + .5)
    levelManager.setTransitionPos(screenX / love.graphics.getWidth(), screenY / love.graphics.getHeight())

    level:setLight(
      { -0.20, -0.25, 0.65 },
      { 1.00, 0.98, 0.93 },
      { 0.35, 0.35, 0.35 }
    )
    updateFloorPlane()

    local g = gate.new(level, -6.8, -7.7, 0, { .7, .7, .7 }, "stable")
    g:setTo("game:dungeon", "cave_1")
    local g = gate.new(level, -11.5, -1.8, 0, { .7, .3, .2 }, "stable")
    g:setTo("game:dungeon", "cave_2")

    ---- tutorial box
    local td = trainingDummy:clone()
    td:addToLevel(level, { 19.5, -15, 0 })
    local td = trainingDummy:clone()
    td:addToLevel(level, { 19.5, -13, 0 })
    local td = trainingDummy:clone()
    td:addToLevel(level, { 19.5, -11, 0 })

    if flag == "tutorial" then
      local w, h = 9, 1
      local x, y = -w/2, -h/2
      level.world:add("tutorialBlock", 17.5, -18.5, slick.newRectangleShape(x, y, w, h))
      player.isInCutscene = true
      uiManager.push("game:menu.tutorial1")
      level.state = "kitchen"
    end

    storeFrontCrowd = flockManager.new(level, 200, {
      { 25.5, -21, 0 },
      {-22.5, -21, 0 },
    })
    parkCrowd = flockManager.new(level, 20, {
      { -18.5, -21, 0 },
      { -11, -22, 0 },
      { -15.5, -20, 0 },
      { -16, -18, 0 },
      { -16.8, -12.8, 0 },
      { -16.7, -6, 0 },
      { -19.5, -0.5, 0 },
      { -20, 6.5, 0 },
      { -19.8, 21.8, 0 },
      { -18.7, 27.2, 0 },
      { -16, 32.2, 0 },
      { -9, 31.8, 0 },
      { -9.1, 29.2, 0 },
      { -7.6, 23.7, 0 },
      { -7.4, 16.67, 0 },
      { -9.4, 13.1, 0 },
      { -13.5, 9.5, 0 },
      { -15.5, 3.1, 0 },
      { -16, -2, 0 },
      { -16.2, -7, 0 },
      { -15.3, -8.6, 0 },
      { -16, -16, 0 },
      { -16, -19.2, 0 },
    })

    itemDefinitions["void_jam"]:spawn(level, { -13, 35.5, 0 })
    itemDefinitions["stringy_jam"]:spawn(level, { -15, 35.5, 0 })
  end

  level.deactivate = function()
    player:removeFromLevel(level)
    for _, char in ipairs(level.characters) do
      if char.removeFromLevelWorld then
        char:removeFromLevelWorld()
      end
    end
    level:removeAllCharacter()

    if level.state == "kitchen" or level.state == "tutorial" then
      -- Probably entering the kitchen
      uiManager.pop("game:menu.tutorial1")
    end
  end

  local t, g = 10 
  level.update = function(self, dt)
    getmetatable(level).update(self, dt)
    updateFloorPlane()

    if storeFrontCrowd then storeFrontCrowd:update(dt) end
    if parkCrowd then parkCrowd:update(dt) end


    local pt = player.transform
    local px, py, z = pt.position[1], pt.position[2], pt.position[3]
    local ax, ay = -1, -4
    -- if  then
    --   ax, ay = 0, -3
    -- end
    if px > 13 and py < -18.5 then
      ax, ay = 0, -3
    elseif px > -6  and py < -18.5 then
      ax = 2
      ay = -5
    elseif px < -6 and py > -17.5 then
      ax, ay = -3, -2
    end

    if px < 3 and storeFrontCrowd and level.state == "new" then
      storeFrontCrowd:fleeToNearestWaypointAndSleep()
      player.isInCutscene = true
      g = gate.new(level, 2.5, -18.7, 0, { .7, .7, .7 })
      level.state = "cutscene"
      t = 0
    end
    if level.state == "cutscene" then
      t = t + dt
      if t >= 4 then
        level.state = "cutscene2"
        g:setTo("game:dungeon", "cave_0")
      end
      if t >= 2 then
        camera.current:lookAt(2.5, -25, 3, 2.5, -19.5, 1)
      end
    elseif level.state == "cutscene2" then
      camera.current:lookAt(2.5, -24, 2, 2.5, -19.5, 1)
      -- drag player towards gate position
      local gx, gy = unpack(g.transform.position, 1, 2)
      local dx, dy = gx - px, gy - py
      local mag = math.sqrt(dx * dx + dy * dy)
      if mag > 0.1 then
        local speed = 4 * dt
        if mag > speed then

        end
        player:moveTowardsDelta(dx / mag * speed, dy / mag * speed)
      else
        level.state = "cutscene3"
      end
    elseif level.state == "cutscene3" then
      if player.isInTransition then
        player.isInCutscene = false
      end 
      camera.current:lookAt(2.5, -25, 3, 2.5, -19.5, 1)
    else
      px = math.min(math.max(px, -18.5), 20)
      camera.current:lookAt(px + ax, py + ay, 2.5, px, py, 1.5)
    end

  end

  level.draw = function(...)
    getmetatable(level).draw(...)
    lg.push("all")
    lg.reset(); lg.origin()
    local scale = windowManager.scale
    local font = assetManager.getFont("lj26b:fonts/Comic_Neue/ComicNeue-Regular", 14 * scale)
    if font then
      if not player.isInTransition and not player.isInCutscene then
        local text = [[
Move: WASD
Kitchen: Tab
Inventory: E
]]
        lg.print(text, font, 5 * scale, 5 * scale)
      elseif player.isInCutscene then
        lg.print("Continue: Mouse 1 (left mouse button)", font, 5 * scale, 5 * scale)
      end
    end
    lg.pop()
  end

  level:addFlag("spawn", { 17, -11.5, 0 })
  level:addFlag("cave_1", { -9, -7.7, 0 })
  level:addFlag("cave_2", { -11.5, -4.5, 0 })

  -- level:addStaticVisual("lj26b:models/Platform", 0, 0, -0.1)
  assetManager.loadAsset("lj26b:models/city/Textures/floor") -- prewarm texture
  love.timer.sleep(1e-3) -- sleep 10ms to try and load texture asap to prevent race in level.active
  level:addDynamicVisual("lj26b:models/city/Platform", "groundPlane", 0, 0, -0.1)
    :rotateAroundZ(math.rad(-90))

  do -- Adds road barriers
    for i = 1, 39 do
      level:addStaticModel("lj26b:models/city/barrier", (26 - .5) + (i-1) * -1.25, -23.5)
      :rotateAroundZ(math.rad(-90))
    end
    
    for i = 1, 4 do
      level:addStaticModel("lj26b:models/city/barrier", 26, -23.5+.75+(i-1)*1.25)
    end

    for i = 1, 4 do
      level:addStaticModel("lj26b:models/city/barrier", -23, -23.5+.75+(i-1)*1.25)
    end
  end

  do -- buildings
    do -- tutorial box
      level:addStaticModel("lj26b:models/city/coobe", 23.5, -12, -.1)
        :scaleBy(5, 12.5, 6)

      level:addStaticModel("lj26b:models/city/coobe", 18, -5, -.1)
        :scaleBy(10, 2, 5)

      level:addStaticModel("lj26b:models/city/coobe", 11, -12, -.1)
        :scaleBy(5, 12.5, 7)
    end

    do -- store front
      level:addStaticModel("lj26b:models/city/coobe", 4.5, -17, -.1)
        :scaleBy(8, 2, 4)

      level:addStaticModel("lj26b:models/city/coobe", -2, -16.5, -.1)
        :scaleBy(5, 2, 6)

      -- Helps NPCs not get stuck in building corners
      level:addStaticModelWithShape("lj26b:models/city/coobe", slick.newCircleShape(0, 0, 0.2), 8.5, -18.2, -2) -- shape is placeholder
      level:addStaticModelWithShape("lj26b:models/city/coobe", slick.newCircleShape(0, 0, 0.5), 0.75, -17.5, -2) -- shape is placeholder
    end
  end

  do -- park
    do -- fence
      -- GATE SIDE (north)
      for i = 1, 4 do
        level:addStaticModel("lj26b:models/city/parkFence", (-22.75) + (i - 1) * 1.5, -18, -.1)
          :rotateAroundZ(math.rad(-90))
      end
      for i = 1, 7 do
        level:addStaticModel("lj26b:models/city/parkFence", (-14.5) + (i - 1) * 1.5, -18, -.1)
          :rotateAroundZ(math.rad(-90))
      end
    end

    for i = 1, 39 do
      level:addStaticModel("lj26b:models/city/parkFence", -22, -17.25 + (i-1)*1.5, -.1)
    end

    for i = 1, 39 do
      level:addStaticModel("lj26b:models/city/parkFence", -4.8, -17.25 + (i-1)*1.5, -.1)
    end

    for i = 1, 12 do
      level:addStaticVisual("lj26b:models/city/parkFence", -21.5 + (i-1)*1.5, 40, -.1)
        :rotateAroundZ(math.rad(90))
    end

  end

  -- level:addStaticModel("lj26b:models/Dungeon/cave/Rock_2", 0, 10, 0)



end