local crowd = require("lj26b:entities.crowd")

local flockManager = { }
flockManager.__index = flockManager

local getSegmentData = function(p)
  local segments = { }
  local totalMag = 0
  if p and #p > 1 then
    for i = 1, #p - 1 do
      local p1, p2 = p[i], p[i + 1]
      local dx, dy = p2[1] - p1[1], p2[2] - p1[2]
      local mag = math.sqrt(dx * dx + dy * dy)
      segments[i] = mag
      totalMag = totalMag + mag
    end
  end
  return segments, totalMag
end

flockManager.new = function(level, budget, path)
  assert(not not path, "Bakka!!")
  local self = setmetatable({ }, flockManager)
  self.level = level
  self.agents = { }
  self.frameCounter = 0

  local reversedPath = { }
  for i = #path, 1, -1 do table.insert(reversedPath, path[i]) end

  local segmentLengths, totalLength = getSegmentData(path)
  local revSegmentLengths, revTotalLength = getSegmentData(reversedPath)

  for i = 1, budget do
    local useReversed = i % 2 == 0 and #reversedPath > 1
    local activePath = useReversed and reversedPath or path
    local activeSegments = useReversed and revSegmentLengths or segmentLengths
    local activeTotal = useReversed and revTotalLength or totalLength

    local c = crowd:clone()
    local spawnX, spawnY = 0, 0
    local spawnSegmentIndex = 1

    if activeTotal > 0 then
      local targetMag = love.math.random() * activeTotal
      local currentMag = 0
      for s = 1, #activeSegments do
        local mag = activeSegments[s]
        if targetMag <= currentMag + mag then
          local t = (targetMag - currentMag) / mag
          local p1, p2 = activePath[s], activePath[s + 1]
          spawnX = p1[1] + (p2[1] - p1[1]) * t
          spawnY = p1[2] + (p2[2] - p1[2]) * t
          spawnSegmentIndex = s
          break
        end
        currentMag = currentMag + mag
      end
    else
      local spawnPos = activePath[1] or { 0, 0, 0 }
      spawnX, spawnY = unpack(spawnPos, 1, 2)
    end

    local offsetX = (love.math.random() - 0.5) * 1.5
    local offsetY = (love.math.random() - 0.5) * 1.5

    c:addToLevel(level, { spawnX + offsetX, spawnY + offsetY, 0 })
    c:setPath(activePath)

    c.pathIndex = spawnSegmentIndex + 1
    if c.pathIndex > #activePath then c.pathIndex= 1 end
    c.target = activePath[c.pathIndex]

    local baseRadius = c.attributes.waypointRadius
    c.attributes.waypointRadius = math.min(0.8, baseRadius + (budget * 0.01))
    c.isFlocking = true
    c.cachedForceX = 0
    c.cachedForceY = 0
    table.insert(self.agents, c)
  end

  return self
end

flockManager.fleeToNearestWaypointAndSleep = function(self)
  for _, agent in ipairs(self.agents) do
    if agent.path and #agent.path > 0 then
      local ax, ay = unpack(agent.transform.position, 1, 2)
      local closestPoint = agent.path[1]
      local minMagSq = math.huge
      for _, point in ipairs(agent.path) do
        local dx, dy = point[1] - ax, point[2] - ay
        local magSq = dx * dx + dy * dy
        if magSq < minMagSq then
          minMagSq = magSq
          closestPoint = point
        end
      end
      local offsetX = (love.math.random() - .5) * 0.0
      local offsetY = (love.math.random() - .5) * 0.0
      local safeTarget = { closestPoint[1] + offsetX, closestPoint[2] + offsetY, closestPoint[3] or 0 }
      agent:setPath({ safeTarget })
      if agent.currentState ~= agent.states.move then
        agent:changeState("move")
      end
    end
  end
end

flockManager.update = function(self, dt)
  local player = self.level.player
  if not player or #self.agents == 0 then return end

  self.frameCounter = self.frameCounter + 1
  local sliceCount = 4

  local px, py = unpack(player.transform.position, 1, 2)
  
  local posCache = { }
  for i, agent in ipairs(self.agents) do
    posCache[i] = {
      x = agent.transform.position[1],
      y = agent.transform.position[2],
      agent = agent,
    }
  end

  for i, current in ipairs(posCache) do
    local agent = current.agent
    if (i + self.frameCounter) % sliceCount == 0 then
      if agent.isFlocking and agent.currentState == agent.states.move then
        local sepX, sepY = 0, 0
        local neighborCount = 0
        for j, other in ipairs(posCache) do
          if i ~= j then
            local dx = current.x - other.x
            local dy = current.y - other.y
            local magSq = dx * dx + dy * dy
            if magSq < 0.8 and magSq > 1e-4 then
              local mag = math.sqrt(magSq)
              sepX = sepX + (dx / mag) / mag
              sepY = sepY + (dy / mag) / mag
              neighborCount = neighborCount + 1
            end
          end
        end

        local pDx = current.x - px
        local pDy = current.y - py
        local pMagSq = pDx * pDx + pDy * pDy
        local thresholdSq = 2^2

        local pPushX, pPushY = 0, 0
        if pMagSq < thresholdSq and pMagSq > 1e-4 then
          local pMag = math.sqrt(pMagSq)
          local blastFactor = (3.0 - pMag) / 3.0

          local approachMultiplier = 1.0
          if agent.velocity then
            local vx, vy = unpack(agent.velocity, 1, 2)
            local vMagSq = vx * vx + vy * vy
            if vMagSq > 1e-4 then
              local vMag = math.sqrt(vMagSq)
              local nvx, nvy = vx / vMag, vy / vMag
              local toPlayerX, toPlayerY = -pDx / pMag, -pDy / pMag
              local dot = nvx * toPlayerX + nvy * toPlayerY
              approachMultiplier = 1.0 + (dot * 0.8)
              approachMultiplier = math.max(0.2, approachMultiplier)
            end
          end
          blastFactor = blastFactor * approachMultiplier
          pPushX = (pDx / pMag) * blastFactor * 2.3
          pPushY = (pDy / pMag) * blastFactor * 2.3

          local vx, vy = unpack(agent.velocity or { 0, 0 }, 1, 2)
          local xDampener, yDampener = 0.9, 0.9
          if player.currentState.motion == "idle" then
            xDampener, yDampener = 0.2, 0.2
          else
            if math.abs(vx) > math.abs(vy) then
              yDampener = 0.2
            elseif math.abs(vy) > math.abs(vx) then
              xDampener = 0.2
            end
          end
          pPushX = pPushX * xDampener
          pPushY = pPushY * yDampener
        end
        

        local forceX, forceY = sepX * .5 + pPushX, sepY * .5 + pPushY
        local forceMagSq = forceX * forceX + forceY * forceY
        if forceMagSq > 2^2 then -- maxForce
          local forceMag = math.sqrt(forceMagSq)
          agent.cachedForceX = forceX / forceMag
          agent.cachedForceY = forceY / forceMag
        else
          agent.cachedForceX = forceX
          agent.cachedForceY = forceY
        end
      else
        agent.cachedForceX, agent.cachedForceY = 0, 0
      end
    end

    if agent.cachedForceX ~= 0 and agent.cachedForceY ~= 0 then
      agent:moveTowardsDelta(agent.cachedForceX * dt, agent.cachedForceY * dt)
    end
  end
end

return flockManager