local lg = love.graphics

local transform = require("s3d:transform")
local characterPlane = require("s3d:characterPlane")
local camera = require("s3d:camera")

local graphicsManager = require("src.core.graphicsManager")
local gm = graphicsManager

local character = { }
character.__index = character

character.new = function(config)
  config = config or { }

  local self = setmetatable({
    transform = transform.new(),
    levelInfo = { },
    lastFacingSign = 1,
    facing = config.facing or { 0, 1 },
    attributes = config.attributes or { },
    shape = config.shape,
    brain = config.brain,
  }, character)

  self.currentState = nil

  return self
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

-- TODO a character should be only allowed in one level at a time
character.addToLevel = function(self, level, position)
  if type(position) == "table" then
    self.transform:set(unpack(position))
  end
  if self.shape and level.world then
    level.world:add(self, self.transform.position[1], self.transform.position[2], self.shape)
    self.levelInfo.world = level.world
    self.levelInfo.id = level.id
  end
end

character.removeFromLevel = function(self, level)
  if level and level.world then
    level.world:remove(self)
  end
  self.levelInfo.world = nil
  self.levelInfo.id = nil
end

character.update = function(self, dt)
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
    return self.lastFacingSign > 0 and "x-" or "x+"
  else
    return self.lastFacingSign > 0 and "y+" or "y-"
  end
end

local shaderKey = "s3d:characterPlane"
gm.loadShader(shaderKey)
character.draw = function(self)
  local shader = gm.getShader(shaderKey)
  if not shader then return end

  if not self.currentState or not self.currentState.sprite then return end
  local texture, quad = self.currentState.sprite:get()
  if not texture or not quad then return end

  lg.push() -- TODO if level draws characters, level draw can handle setting depthMode and cullMode for all
  lg.setDepthMode("lequal", true)
  lg.setMeshCullMode("none")
  gm.setUniform(shader, "u_ModelMatrix", self.transform:getMatrix())
  camera.setUniforms(shader)
  characterPlane.drawQuad(texture, quad, shader, self:getPlaneDirection())
  lg.pop()
end

return character