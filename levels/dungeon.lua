local lfs = love.filesystem

local logger = LOGGER:extend("level"):extend("dungeon", "bright_yellow")

local vornmath = require("libs.vornmath")

local graphicsManager = require("src.core.graphicsManager")

local camera = require("s3d:camera")
local transform = require("s3d:transform")
local levelManager = require("s3d:levelManager")

local player = require("lj26b:player")

local roomRPathPrefix = "lj26b:levels.rooms."

local dungeonCamera = camera.new()

local getRoomTemplates = function(directoryPath, rawRequire)
  local roomTemplates = {
    entrance = { },
    exit = { },
    normal = { },
    deadEnd = { },
  }
  if lfs.getInfo(directoryPath, "directory") then
    local files = lfs.getDirectoryItems(directoryPath) or { }
    for _, file in ipairs(files) do
      if lfs.getInfo(directoryPath .. "/" .. file, "file") then
        local filename, changed = file:gsub("%.lua$", "")
        if changed ~= 0 then
          local rpath = rawRequire .. filename
          local success, room = pcall(require, rpath)
          if success and room then
            room.id = filename
            if room.flags and room.flags.entrance then
              table.insert(roomTemplates.entrance, room)
            elseif room.flags and room.flags.exit then
              table.insert(roomTemplates.exit, room)
            elseif #room.sockets == 1 then
              table.insert(roomTemplates.deadEnd, room)
            else
              table.insert(roomTemplates.normal, room)
            end
          else
            logger:warning(("Issue requiring room[%s]: %s"):format(file, room))
          end
        end
      end
    end
  end
  return roomTemplates
end

local setLevelForFlag = function(level, flag)
  if flag == "forest" then
    level:setLightPreset("noon")
  else
    -- level:setLightPreset("midnight")
    -- level:setLight(
    --   { 0.20, 0.30, -0.80 },
    --   { 0.35, 0.40,  0.50 },
    --   { 0.15, 0.16,  0.20 }
    -- )
    -- level:setLight(
    --   { 0.00, 0.00, -1.00 },
    --   { 0.5, 0.35, 0.20 },
    --   { .18, .14, .10 }
    -- )
    level:setLight(
      { 0.20, 0.30, 0.80 },
      { 0.70, 0.75,  0.85 },
      { 0.30, 0.32,  0.38 }
    )
    -- level:setLight(
    --   { 0.00, 0.00, -1.00 },
    --   { 0.80, 0.55, 0.30 },
    --   { .35, .25, .18 }
    -- )
    -- level:setLight(
    --   { 0.20, 0.30, 0.80 },
    --   { 1.10, 1.15,  1.25 },
    --   { 0.50, 0.52,  0.60 }
    -- )
  end
end

local rotateBOxMAthICALLY = function(box) -- I'm running out of function names at this point
  local cosR = math.abs(math.cos(box.r))
  local sinR = math.abs(math.sin(box.r))

  local halfW = (box.w * cosR + box.h * sinR) * .5
  local halfH = (box.h * cosR + box.w * sinR) * .5
  return halfW, halfH
end

local checkOverlap = function(newBox, placedBoxes)
  local allowedSink = .5
  local newW, newH = rotateBOxMAthICALLY(newBox)
  for _, box in ipairs(placedBoxes) do
    local boxW, boxH = rotateBOxMAthICALLY(box)
    if math.abs(newBox.x - box.x) < (newW + boxW) - allowedSink and
       math.abs(newBox.y - box.y) < (newH + boxH) - allowedSink then
      return true
    end
  end
  return false
end

local generateDungeon = function(level, roomTemplates, rng)
  local layoutNodes = { }
  local placedBoxes = { }
  local branchSockets = { }

  local tryPlaceSpecificRoom = function(chosenRoom, targetSocket)
    if not chosenRoom or #chosenRoom.sockets == 0 then return nil end

    local socketIndices = { }
    for i = 1, #chosenRoom.sockets do socketIndices[i] = i end
    for i = #socketIndices, 2, -1 do
      local j = rng:random(i)
      socketIndices[i], socketIndices[j] = socketIndices[j], socketIndices[i]
    end

    for _, roomSocketIndex in ipairs(socketIndices) do
      local roomSocket = chosenRoom.sockets[roomSocketIndex]
      local reqDirX = -targetSocket.direction[1]
      local reqDirY = -targetSocket.direction[2]

      local localDirX = roomSocket.direction[1]
      local localDirY = roomSocket.direction[2]

      local targetAngle = math.atan2(reqDirY, reqDirX)
      local localAngle = math.atan2(localDirY, localDirX)
      local rawRot = targetAngle - localAngle

      local chosenRotation = math.floor((rawRot / (math.pi * .5)) + .5) * (math.pi * .5)

      local t = transform.new()
        :rotateAroundZ(chosenRotation)
      
      local rotatedLocalSocketPosition = t:transformPoint(roomSocket.position)
      local roomWorldX = targetSocket.position[1] - rotatedLocalSocketPosition[1]
      local roomWorldY = targetSocket.position[2] - rotatedLocalSocketPosition[2]

      local candidateBox = {
        x = roomWorldX,
        y = roomWorldY,
        w = chosenRoom.width,
        h = chosenRoom.height,
        r = chosenRotation
      }

      if not checkOverlap(candidateBox, placedBoxes) then
        t:set(roomWorldX, roomWorldY, 0)
        local newSockets = { }
        local c = math.cos(chosenRotation)
        local s = math.sin(chosenRotation)
        for i, sock in ipairs(chosenRoom.sockets) do
          if i ~= roomSocketIndex then
            local dx, dy = unpack(sock.direction, 1, 2)
            local rDir = {
              dx * c - dy * s,
              dx * s + dy * c,
              0,
            }

            table.insert(newSockets, {
              position = t:transformPoint(sock.position),
              direction = rDir,
            })
          end
        end
        return {
          template = chosenRoom,
          transform = t,
          rotation = chosenRotation,
          box = candidateBox,
          sockets = newSockets,
        }
      end
    end
    return nil
  end

  local tryPlaceAnyRoomFromPool = function(pool, targetSocket, rng)
    if #pool == 0 then return nil end

    local indices = { }
    for i = 1, #pool do indices[i] = i end
    for i = #indices, 2, -1 do
      local j = rng:random(i)
      indices[i], indices[j] = indices[j], indices[i]
    end

    for _, index in ipairs(indices) do
      local placedResult = tryPlaceSpecificRoom(pool[index], targetSocket)
      if placedResult then return placedResult end
    end
    return nil
  end

  if #roomTemplates.entrance == 0 then
    logger:warning("No entrance room templates found!")
    return layoutNodes
  end

  local entRoom = roomTemplates.entrance[rng:random(#roomTemplates.entrance)]
  local t = transform.new()
  local entBox = { x = t.position[1], y = t.position[2], w = entRoom.width, h = entRoom.height, r = 0 }

  local entNode = {
    template = entRoom,
    transform = t,
    rotation = 0,
    box = entBox,
    sockets = { },
    isSpawn = true,
  }

  for _, socket in ipairs(entRoom.sockets) do
    table.insert(entNode.sockets, {
      position = t:transformPoint(socket.position),
      direction = socket.direction,
    })
  end

  table.insert(layoutNodes, entNode)
  table.insert(placedBoxes, entBox)

  if #entNode.sockets == 0 then return layoutNodes end

  local startSocketIndex = rng:random(#entNode.sockets)
  local currentChainSocket = entNode.sockets[startSocketIndex]
  for i, sock in ipairs(entNode.sockets) do
    if i ~= startSocketIndex then
      table.insert(branchSockets, sock)
    end
  end

  local targetNormalCount = #roomTemplates.normal > 0 and math.min(rng:random(4, 7), math.max(1, #roomTemplates.normal * 2)) or 0
  local currentNormalPlaced = 0

  while currentNormalPlaced < targetNormalCount and #roomTemplates.normal > 0 do
    local chosenRoom = roomTemplates.normal[rng:random(#roomTemplates.normal)]
    local placedResult = tryPlaceSpecificRoom(chosenRoom, currentChainSocket)

    if placedResult then
      table.insert(layoutNodes, {
        template = placedResult.template,
        transform = placedResult.transform,
        rotation = placedResult.rotation,
      })
      table.insert(placedBoxes, placedResult.box)

      if #placedResult.sockets > 0 then
        local nextChainIndex = rng:random(#placedResult.sockets)
        currentChainSocket = placedResult.sockets[nextChainIndex]
        for i, sock in ipairs(placedResult.sockets) do
          if i ~= nextChainIndex then
            table.insert(branchSockets, sock)
          end
        end
      else
        break
      end
      currentNormalPlaced = currentNormalPlaced + 1
    else -- Try alt normal room if first attempt overlaps (e.g. if it makes a circle)
      local found = false
      for _ = 1, #roomTemplates.normal do
        chosenRoom = roomTemplates.normal[rng:random(#roomTemplates.normal)]
        placedResult = tryPlaceSpecificRoom(chosenRoom, currentChainSocket)
        if placedResult then
          table.insert(layoutNodes, {
            template = placedResult.template,
            transform = placedResult.transform,
            rotation = placedResult.rotation,
          })
          table.insert(placedBoxes, placedResult.box)
          if #placedResult.sockets > 0 then
            local nextChainIndex = rng:random(#placedResult.sockets)
            currentChainSocket = placedResult.sockets[nextChainIndex]
            for i, sock in ipairs(placedResult.sockets) do
              if i ~= nextChainIndex then
                table.insert(branchSockets, sock)
              end
            end
          else
            break
          end
          currentNormalPlaced = currentNormalPlaced + 1
          found = true
          break
        end
      end
      if not found then break end
    end
  end

  local exitPool = (#roomTemplates.exit > 0) and roomTemplates.exit or roomTemplates.deadEnd
  if #exitPool > 0 then
    local placedExit = false
    for _, pool in ipairs({ exitPool --[[, roomTemplates.deadEnd, roomTemplates.normal ]] }) do
      if #pool > 0 then
        for _ = 1, #pool do
          local exitRoom = pool[rng:random(#pool)]
          local placedResult = tryPlaceSpecificRoom(exitRoom, currentChainSocket)
          if placedResult then
            table.insert(layoutNodes, {
              template = placedResult.template,
              transform = placedResult.transform,
              rotation = placedResult.rotation,
              isExit = true,
            })
            table.insert(placedBoxes, placedResult.box)

            placedExit = true
            break
          end
        end
        if placedExit then break end
      end
    end
  end

  local openSocketsCount = 0
  for _, branchSocket in ipairs(branchSockets) do
    local offshootLength = rng:random(1, 2)
    if offshootLength == 1 then
      local placedResult = tryPlaceAnyRoomFromPool(roomTemplates.deadEnd, branchSocket, rng)
      if placedResult then
        table.insert(layoutNodes, {
          template = placedResult.template,
          transform = placedResult.transform,
          rotation = placedResult.rotation,
        })
        table.insert(placedBoxes, placedResult.box)
      else
        openSocketsCount = openSocketsCount + 1
      end
    else
      if #roomTemplates.normal > 0 and #roomTemplates.deadEnd > 0 then
        local normalRoom = roomTemplates.normal[rng:random(#roomTemplates.normal)]
        local placedNormal = tryPlaceSpecificRoom(normalRoom, branchSocket)
        if placedNormal then
          table.insert(layoutNodes, {
            template = placedNormal.template,
            transform = placedNormal.transform,
            rotation = placedNormal.rotation,
          })
          table.insert(placedBoxes, placedNormal.box)
          -- Cap remaining sockets
          for _, normalSock in ipairs(placedNormal.sockets) do
            local placedResult = tryPlaceAnyRoomFromPool(roomTemplates.deadEnd, normalSock, rng)
            if placedResult then
              table.insert(layoutNodes, {
                template = placedResult.template,
                transform = placedResult.transform,
                rotation = placedResult.rotation,
              })
              table.insert(placedBoxes, placedResult.box)
            else
              openSocketsCount = openSocketsCount + 1
            end
          end
        else
          if #roomTemplates.deadEnd > 0 then
            local placedResult = tryPlaceAnyRoomFromPool(roomTemplates.deadEnd, branchSocket, rng)
            if placedResult then
              table.insert(layoutNodes, {
                template = placedResult.template,
                transform = placedResult.transform,
                rotation = placedResult.rotation,
              })
              table.insert(placedBoxes, placedResult.box)
            else
              openSocketsCount = openSocketsCount + 1
            end
          end
        end
      elseif #roomTemplates.deadEnd > 0 then
        local placedResult = tryPlaceAnyRoomFromPool(roomTemplates.deadEnd, branchSocket, rng)
        if placedResult then
          table.insert(layoutNodes, {
            template = placedResult.template,
            transform = placedResult.transform,
            rotation = placedResult.rotation,
          })
          table.insert(placedBoxes, placedResult.box)
        else
          openSocketsCount = openSocketsCount + 1
        end
      else
        openSocketsCount = openSocketsCount + 1
      end
    end
  end

  return layoutNodes, placedBoxes, openSocketsCount, #branchSockets
end

return function(level, flag)

  level.modelShader = "s3d:caveShader"
  graphicsManager.loadShader(level.modelShader)

  level.deactivate = function()
    levelManager._levels[level.id] = nil
    -- remove itself, when level is unloaded, so this function
    -- is ran again than using it's result cached as it changes depending on the flag
  end

  setLevelForFlag(level, flag)

  local rooms = { }
  if flag == "forest" or flag == "cave" then
    local roomsPath = roomRPathPrefix .. flag
    local filepath, rawRequire = RESOLVE(roomsPath)

    local roomTemplates = getRoomTemplates(filepath, rawRequire .. ".")
    local rng = love.math.newRandomGenerator(love.math.random(0, 2^32 - 1), love.math.random(0, 2^32 - 1))

    local hasExcessiveConsecutiveRooms = function(layout, maxRepeats)
      local currentTemplate, count = nil, 0
      for _, room in ipairs(layout) do
        if room.template == currentTemplate then
          count = count + 1
          if count > maxRepeats then
            return true
          end
        else
          currentTemplate = room.template
          count = 1
        end
      end
      return false
    end

    local layout, boxes, openSockets, numBranches
    local attempts = 0
    local limit = 1000
    while true do
      attempts = attempts + 1
      layout, boxes, openSockets, numBranches = generateDungeon(level, roomTemplates, rng)
      local hasSpawn, hasExit = false, false
      for _, room in ipairs(layout) do
        hasSpawn, hasExit = hasSpawn or room.isSpawn, hasExit or room.isExit
      end
      local hasRepeats = hasExcessiveConsecutiveRooms(layout, 4)
      if (hasSpawn and hasExit and openSockets == 0 and not hasRepeats and numBranches ~= 0) or attempts == limit + 1 then
        break
      else
        local reason
        if not hasSpawn or not hasExit then
          reason = (reason and reason .. " & " or "") .. "Missing flag: "..(not hasSpawn and "SPAWN" or "") .. (not hasSpawn and not hasExit and " and " or "") .. (not hasExit and "EXIT" or "")
        end
        if openSockets ~= 0 then
          reason = (reason and reason .. " & " or "") .. "Sockets left open: " .. tostring(openSockets)
        end
        if hasRepeats then
          reason = (reason and reason .. " & " or "") .. "Found repeats"
        end
        if numBranches == 0 then
          reason = (reason and reason .. " & " or "") .. "Has no branches"
        end
        if reason then
          logger:info("Failed layout, reason:", reason)
        end
      end
    end
    if attempts > limit then
      logger:error("Reached max attempts while generating dungeon. Tell a programmer that they're dumb. Optionally, the one who wrote this code")
      error(); return
    end

    level.boxes = boxes

    for i, room in ipairs(layout) do
      local roomId = tostring(i)
      local r = room.template.build(level, room.transform, rng, roomId)
      r.roomId = roomId

      r.isSpawn = room.isSpawn
      r.isExit = room.isExit
      local tp = room.transform.position
      if r.isSpawn then
        level.boxes[i].isSpawn = true
        if r.flags.entrance and r.flags.entrance.position then
          local pos = r.flags.entrance.position
          level:addFlag("spawn", { tp[1] + pos[1], tp[2] + pos[2], tp[3] + pos[3] })
        else
          level:addFlag("spawn", { unpack(tp, 1, 3) })
        end
      elseif r.isExit then
        level.boxes[i].isExit = true
        if r.flags.exit and r.flags.exit.position then
          local pos = r.flags.exit.position
          level:addFlag("exit", { tp[1] + pos[1], tp[2] + pos[2], tp[3] + pos[3] })
        else
          level:addFlag("exit", { unpack(tp, 1, 3) })
        end
      end
      table.insert(rooms, r)
    end
    logger:info(("Created dungeon[%s] with %d rooms, took %d attempts"):format(flag, #rooms, attempts))
  end

  local wolf = require("lj26b:entities.wolf")
  local slime = require("lj26b:entities.slime")
  level.getResourceKeys = function(_, outKeys, inMap)
    wolf:getSpriteResourceKeys(outKeys, inMap)
    slime:getSpriteResourceKeys(outKeys, inMap)
  end

  local closedGate, gateTimer, startColor
  level.active = function(level, flag)
    dungeonCamera:setCurrent()
    dungeonCamera:setAspectRatio(love.graphics.getDimensions())

    player.transform:scaleBy(1,1,1)
    player.isInTransition = false

    local spawn = level:getFlag("spawn")
    player:addToLevel(level, spawn)
    level:setPlayer(player)

    for _, room in ipairs(rooms) do
      room:activate()
    end

    level.shadowPushBack = 0.05
  end

  level.update = function(self, dt)
    getmetatable(level).update(self, dt)

    local pt = player.transform
    local x, y, z = pt.position[1], pt.position[2], pt.position[3]
    camera.current:lookAt(x + 3, y - 1, 3.5, x, y, 1)

    for _, room in ipairs(rooms) do
      if room.update then
        room:update(dt)
      end
    end
  end

  local lg = love.graphics
  level.draw = function(...)
    local s = graphicsManager.getShader(level.modelShader)
    if s then
      local c = camera.current
      local p = { unpack(level.player.transform.position, 1, 3)}
      p[3] = p[3] + .5
      graphicsManager.setUniform(s, "u_CameraPosition", c.eye)
      graphicsManager.setUniform(s, "u_PlayerPosition", p)
      graphicsManager.setUniform(s, "u_OcclusionRadius", 1.7)
    end

    getmetatable(level).draw(...)

    if not level.boxes or false then return end
    lg.push("all")
    lg.reset(); lg.origin()
    lg.translate(lg.getWidth()/6, lg.getHeight()/6)
    lg.rotate(math.rad(-90)); lg.scale(-1, 1) -- To match camera-ish angle
    for _, box in ipairs(level.boxes) do
      lg.push()
      lg.translate(box.x, box.y)
      lg.rotate(box.r)
      if box.isSpawn then lg.setColor(.6, .6, 1, 1)
      elseif box.isExit then lg.setColor(1, .8, .4, 1)
      else lg.setColor(1, 1, 1, 1) end
      lg.rectangle("fill", -box.w/2, -box.h/2, box.w, box.h)
      lg.pop()
    end
    lg.pop()
  end

end
