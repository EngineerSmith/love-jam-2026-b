local lg = love.graphics

local graphicsManager = require("src.core.graphicsManager")

local camera = require("s3d:camera")
local transform = require("s3d:transform")
local characterPlane = require("s3d:characterPlane")
local levelManager = require("s3d:levelManager")

local states = { }

states.opening = {
  timeToOpen = 5,
  enter = function(state, self)
    self.timer = 0
  end,
  update = function(state, self, dt)
    self.timer = self.timer + dt
    if self.timer >= state.timeToOpen then
      self:changeState("stable")
    end
  end,
}

states.stable = { }

states.entering = {
  timeToEnter = 1.2,
  enter = function(state, self)
    self.timer = 0
    self.triggeredLevelChange = false
    self.cleanedUp = false
    local player = self.currentLevel and self.currentLevel.player
    if player then
      player.isInTransition = true
      self.playerStartPos = { unpack(player.transform.position) }
      self.playerStartScale = player.transform.scale[1]
    end
  end,
  exit = function(_, self)
    self.triggeredLevelChange = false
  end,
  update = function(state, self, dt)
    self.timer = self.timer + dt
    local p = math.min(1, self.timer / state.timeToEnter)
    local ease = p * p * p * p

    local player = self.currentLevel and self.currentLevel.player
    if player and self.playerStartPos then
      local gatePos = self.transform.position
      local startX, startY, startZ = unpack(self.playerStartPos)

      local _, h = self:getDimensions()

      local currentX = startX + (gatePos[1] - startX) * ease
      local currentY = startY + (gatePos[2] - startY) * ease
      local currentZ = startZ + ((gatePos[3] + 0.5) + (h / 2 * characterPlane.pixelUnits) - startZ) * (p * p)
      player.transform:set(currentX, currentY, currentZ)

      local scaleFactor = math.max(0.01, self.playerStartScale * (1 - ease))
      player.transform:scaleBy(scaleFactor, scaleFactor, scaleFactor)
    end

    if p >= 0.5 and not self.triggeredLevelChange then
      self.triggeredLevelChange = true
      if self.targetLevel then
        local nx, ny = .5, .5
        if player then
          local x, y, _ = unpack(player.transform.position)
          local screenX, screenY = camera.current:project(x, y, .5)
          nx, ny = screenX / lg.getWidth(), screenY / lg.getHeight()
        end
        levelManager.setActiveLevel(self.targetLevel, nx, ny, self.targetFlag)
      end
    end

    if p >= 1 then
      -- Note, as soon as the next level load is complete, this will pause (no more gate.update calls)
      -- til level is loaded again - which often means a new instance than it reaching this point anyway
      self:changeState("stable")
    end
  end,
}

states.closing = {
  timeToClose = 5,
  enter = function(state, self)
    self.timer = 0
  end,
  exit = function(state, self)
    self:removeFromLevel()
  end,
  update = function(state, self, dt)
    self.timer = self.timer + dt
    if self.timer >= state.timeToClose then
      self:changeState(nil)
    end
  end
}

local stateMT = {
  enter = function() end,
  exit = function() end,
  update = function() end,
}
stateMT.__index = stateMT
for _, state in pairs(states) do setmetatable(state, stateMT) end

local gate = {
  _levelIgnore = true, -- exclude having a shadow
}
gate.__index = gate

gate.new = function(level, x, y, z, color, state)
  if not level then error() end

  local self = setmetatable({
    currentLevel = level,
    color = color or { .4, .6, .7, 1 },
    transform = transform.new():set(x, y, z),
    flareAngle = 0,
  }, gate)

  state = state or "opening"
  if type(state) == "string" then
    self:changeState(state)
  end

  self.currentLevel:addCharacter(self) -- asks level to draw itself

  return self
end

gate.setTo = function(self, targetLevel, levelFlag)
  self.targetLevel = targetLevel
  self.targetFlag = levelFlag
end

gate.removeFromLevel = function(self)
  if not self.currentLevel then return end
  self.currentLevel:removeCharacter(self)
  self.currentLevel = nil
end

gate.changeState = function(self, state)
  if type(state) == "string" then
    state = states[state]
  end
  if self.currentState then
    self.currentState:exit(self)
  end
  self.currentState = state
  if self.currentState then
    self.currentState:enter(self)
  end
end

gate.update = function(self, dt)
  local spinSpeed = 1
  if self.currentState == states.stable then
    spinSpeed = 2
  elseif self.currentState == states.entering then
    spinSpeed = 6
  end
  self.flareAngle = (self.flareAngle + dt * spinSpeed) % (math.pi * 2)

  if self.currentState then
    self.currentState:update(self, dt)
  end

  if self.currentState == states.stable and self.targetLevel and
      self.currentLevel and self.currentLevel.player then
    local player = self.currentLevel.player
    if not player.isInTransition then
      local p = self.transform.position
      local pPos = player.transform.position

      local dx = pPos[1] - p[1]
      local dy = pPos[2] - p[2]
      local dz = pPos[3] - p[3]
      local magSq = dx * dx + dy * dy + dz * dz

      local triggerRange = 1.0
      if magSq <= triggerRange * triggerRange then
        self:changeState("entering")
      end
    end
  end
end

gate.getPlaneDirection = function(self)
  local pp = self.transform.position
  local ce = camera.current.eye
  local toCamX = ce[1] - pp[1]
  local toCamY = ce[2] - pp[2]

  if math.abs(toCamX) >= math.abs(toCamY) then
    return toCamX > 0 and "x-" or "x+"
  else
    return toCamY > 0 and "y-" or "y+"
  end
end

local canvas = {
  lg.newCanvas(80, 80),
  stencil = false,
}

gate.getDimensions = function(self)
  return canvas[1]:getDimensions()
end

local colors = {
  { .85, .85, .85, 1 },
  { .60, .60, .60, 1 },
  { .45, .45, .45, 1 },
  { .30, .30, .30, 1 },
  { .15, .15, .15, 1 },
}

local planeOrientations = {
  ["x+"] = { right = {  0,  1, 0 }, up = { 0, 0, 1 } },
  ["x-"] = { right = {  0, -1, 0 }, up = { 0, 0, 1 } },
  ["y+"] = { right = { -1,  0, 0 }, up = { 0, 0, 1 } },
  ["y-"] = { right = {  1,  0, 0 }, up = { 0, 0, 1 } },
}

gate.draw = function(self, shader)
  lg.push("all")
  lg.reset(); lg.origin()
  lg.setCanvas(canvas)
  lg.clear(0, 0, 0, 0)
  lg.setBlendMode("alpha", "alphamultiply")

  local cx, cy = canvas[1]:getDimensions()
  cx, cy = cx / 2, cy / 2
  local maxRadius = cx - 5

  local scale = 1
  if self.currentState == states.opening then
    local p = math.min(1, self.timer / states.opening.timeToOpen)
    scale = math.sin(p * math.pi * 0.5)
  elseif self.currentState == states.closing then
    local p = math.min(1, self.timer / states.closing.timeToClose)
    scale = 1 - p
  end

  local eye = camera.current.eye
  local pos = self.transform.position

  local dx = eye[1] - pos[1]
  local dy = eye[2] - pos[2]
  local dz = eye[3] - pos[3]

  local planeDirection = self:getPlaneDirection()
  local orient = planeOrientations[planeDirection] or planeOrientations["x+"]
  local localX = dx * orient.right[1] + dy * orient.right[2] + dz * orient.right[3]
  local localY = dx * orient.up[1] + dy * orient.up[2] + dz * orient.up[3]

  local maxParallax = 8
  local parallaxX = math.max(-maxParallax, math.min(maxParallax, localX * 2))
  local parallaxY = math.max(-maxParallax, math.min(maxParallax, localY * 2))

  local numRings = #colors
  for i = 1, numRings do
    local color = colors[i]
    local depthFactor = (i / numRings) * 1.8
    local ringX = cx - parallaxX * depthFactor
    local ringY = cy - parallaxY * depthFactor

    local ringRadius = (maxRadius * (1 - (i - 1) * 0.16)) * scale -- magic number
    if ringRadius > 0 then
      lg.setColor(color)
      lg.circle("fill", ringX, ringY, ringRadius)
    end
  end

  if scale > 0.1 then
    local numFlares = 5
    local orbitRadius = (maxRadius + 2) * scale
    local trailSteps = 4

    for f = 1, numFlares do
      local baseAngle = self.flareAngle + (f / numFlares) * math.pi * 2

      for t = trailSteps, 1, -1 do
        local angle = baseAngle - (t * 0.08)
        local fx = cx + math.cos(angle) * orbitRadius
        local fy = cy + math.sin(angle) * orbitRadius

        local alpha = (1 - (t / (trailSteps + 1))) * .8 * scale
        local radius = (3.0 - (t * .4)) * scale

        lg.setColor(1, 1, 1, alpha)
        lg.circle("fill", fx, fy, math.max(.5, radius))
      end

      local fx = cx + math.cos(baseAngle) * orbitRadius
      local fy = cy + math.sin(baseAngle) * orbitRadius
      lg.setColor(1,1,1, .95 * scale)
      lg.circle("fill", fx, fy, 2.5 * scale)
    end
  end

  lg.pop()

  graphicsManager.setUniform(shader, "u_Color", self.color)
  graphicsManager.setUniform(shader, "u_ModelMatrix", self.transform:getMatrix())
  characterPlane.draw(canvas[1], shader, planeDirection)
end

return gate