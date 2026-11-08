local lg = love.graphics

local transform = require("s3d:transform")
local characterPlane = require("s3d:characterPlane")
local camera = require("s3d:camera")

local graphicsManager = require("src.core.graphicsManager")

local stateFactory = require("lj26b:stateFactory")
local damageNumbers = require("lj26b:damageNumbers")

local character = { }
character.__index = character

local id = 0
character.new = function(config)
  config = config or { }

  local self = setmetatable({
    id = id,
    transform = transform.new(),
    lastFacingSign = 1,
    facing = config.facing or { 0, 1 },
    attributes = config.attributes or { },
    shape = config.shape,
    brain = config.brain,
    states = { },
    _rawStates = config.states,
    _defaultStateName = config.defaultState,
  }, character)
  id = id + 1

  if config.states then
    for name, rawDefinition in pairs(config.states) do
      self.states[name] = stateFactory.new(rawDefinition)
      if self.states[name].sprites then
        for key, sprite in pairs(self.states[name].sprites) do
          self.states[name].sprites[key] = sprite:clone()
        end
      end
    end
  end

  self.currentState = nil
  self.currentLevel = nil

  return self
end

character.clone = function(self, overrideConfig)
  overrideConfig = overrideConfig or { }

  local cloneAttributes = { }
  for k, v in pairs(self.attributes) do
    cloneAttributes[k] = v
  end
  for k, v in pairs(overrideConfig.attributes or { }) do
    cloneAttributes[k] = v
  end

  local clone = character.new({
    facing = overrideConfig.facing or { self.facing[1], self.facing[2] },
    shape = overrideConfig.shape or self.shape,
    states = self._rawStates,
    defaultState = self._defaultStateName,
    attributes = cloneAttributes,
    brain = overrideConfig.brain or self.brain,
  })
  setmetatable(clone, { __index = self })

  return clone
end

character.getSpriteResourceKeys = function(self, outKeys, inMap)
  outKeys = outKeys or { }
  inMap = inMap or { }

  for _, state in pairs(self.states) do
    state.getSpriteResourceKeys(outKeys, inMap)
  end

  return outKeys, inMap
end

character.changeState = function(self, newState)
  if self.currentState then
    self.currentState:exit(self)
  end
  self.currentState = newState
  if self.currentState then
    self.currentState:enter(self)
  end
end

character.addToLevel = function(self, level, position)
  if self.currentLevel then self:removeFromLevel() end

  if type(position) == "table" then
    self.transform:set(unpack(position))
  end
  self.currentLevel = level

  if self.shape and self.currentLevel.world then
    self.currentLevel.world:add(self, self.transform.position[1], self.transform.position[2], self.shape)
  end
  self.currentLevel:addCharacter(self)

  if self._defaultStateName then
    self:changeState(self.states[self._defaultStateName])
  end
end

character.removeFromLevel = function(self, level)
  level = level or self.currentLevel
  if not level then return end

  self:removeFromLevelWorld()
  level:removeCharacter(self)

  if level == self.currentLevel then
    self.currentLevel = nil
  end
end

character.removeFromLevelWorld = function(self, level)
  level = level or self.currentLevel
  if not level then return end

  if level.world and level.world:has(self) and self.shape then
    level.world:remove(self)
  end
end

local collisionResponses = {
  slide = function() return "slide" end,
  touch = function() return "touch" end,
  cross = function() return "cross" end,
  bounce = function() return "bounce" end,
}

character.moveTowardsGoal = function(self, goalX, goalY, collisionResponse)
  if not self.currentLevel then return end

  local actualX, actualY = self.currentLevel.world:move(self, goalX, goalY, collisionResponse and collisionResponses[collisionResponse] or nil)
  self.transform:set(actualX, actualY, self.transform.position[3])
end

character.moveTowardsDelta = function(self, deltaX, deltaY, collisionResponse)
  local goalX = self.transform.position[1] + deltaX
  local goalY = self.transform.position[2] + deltaY

  self:moveTowardsGoal(goalX, goalY, collisionResponse)
end

character.takeHit = function(self, damage)
  if not self.attributes.currentHealth then return false end
  if self.attributes.invulnerable then return false end

  damage = damage or 10
  self.attributes.currentHealth = math.max(0, self.attributes.currentHealth - damage)

  local _, spriteH = self:getDimensions()
  local scaledHeight = spriteH * characterPlane.pixelUnits
  damageNumbers.spawn(self.transform.position[1], self.transform.position[2],
      self.transform.position[3] + scaledHeight, damage)

  if self.attributes.currentHealth < 0 then
    self.attributes.currentHealth = 0
    -- TODO handle
  end
  return true
end

character.update = function(self, dt)
  if self.brain then
    self.brain(self, dt)
  end
  if self.currentState then
    self.currentState:update(self, dt)
  end
end

character.getPlaneDirection = function(self)
  local pp = self.transform.position
  local ce = camera.current.eye
  local toCamX = ce[1] - pp[1]
  local toCamY = ce[2] - pp[2]

  local _, _, camRightX, camRightY = camera.current:getHorizontalAxes()
  local screenFacing = self.facing[1] * camRightX + self.facing[2] * camRightY

  if math.abs(screenFacing) > 1e-2 then
    self.lastFacingSign = screenFacing > 0 and 1 or -1
  end

  if math.abs(toCamX) >= math.abs(toCamY) then
    -- return self.lastFacingSign > 0 and "x-" or "x+"
    -- return toCamX > 0 and "x-" or "x+"
    local isPositive = (toCamX > 0) == (self.lastFacingSign > 0)
    return isPositive and "x-" or "x+"
  else
    -- return self.lastFacingSign > 0 and "y+" or "y-"
    -- return toCamY > 0 and "y-" or "y+"
    local isPositive = (toCamY > 0) == (self.lastFacingSign > 0)
    return isPositive and "y-" or "y+"
  end
end

character.getDimensions = function(self)
  if self.currentState and self.currentState.sprite then
    return self.currentState.sprite:getDimensions()
  end
  return 32, 32
end

character.draw = function(self, shader)
  if not shader then return end

  if not self.currentState or not self.currentState.sprite then return end
  local texture, quad = self.currentState.sprite:get()
  if not texture or not quad then return end

  graphicsManager.setUniform(shader, "u_Color", { self.currentState.sprite:getColor() })
  graphicsManager.setUniform(shader, "u_ModelMatrix", self.transform:getMatrix())
  characterPlane.drawQuad(texture, quad, shader, self:getPlaneDirection())
  -- print(self.facing, self:getPlaneDirection(), camera.current.eye, self.transform.position)
end

return character