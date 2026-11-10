local lg = love.graphics

local graphicsManager = require("src.core.graphicsManager")

local transform = require("s3d:transform")
local characterPlane = require("s3d:characterPlane")
local camera = require("s3d:camera")

local inventory = require(":inventory")

local item = {
  -- _levelIgnore = true
}
item.__index = item

item.new = function(id, config)
  -- make item type
  local self = setmetatable({
    id = id,
    name = config.name or "UNKNOWN",
    itemType = config.itemType or "unknown",
    tooltip = config.tooltip or nil,
    sprite = config.sprite,
    stats = config.stats,
    pickupRadius = config.pickupRadius or 1.5,
    collectRadius = config.collectRadius or 0.1,
    magnetSpeed = config.magnetSpeed or 1.5,
    stackable = true,
  }, item)

  if type(config.stackable) ~= "nil" then
    self.stackable = config.stackable
  end

  if self.sprite then
    self.sprite:start()
  end

  return self
end

local sortId = 0.5 -- hacky but, works (Copying char id)
item.clone = function(self, overrideConfig)
  overrideConfig = overrideConfig or { }

  local clone = setmetatable({
    id = self.id,
    sortId = sortId,
    name = self.name,
    itemType = self.itemType,
    tooltip = self.tooltip,
    sprite = self.sprite,
    stats = self.stats,
    pickupRadius = overrideConfig.pickupRadius or self.pickupRadius,
    collectRadius = overrideConfig.collectRadius or self.collectRadius,
    magnetSpeed = overrideConfig.magnetSpeed or self.magnetSpeed,
    stackable = self.stackable,
    time = love.math.random() * 6.28,
    freeze = 0.75,
  }, item)
  sortId = sortId + 1

  return clone
end

item.spawn = function(self, level, position)
  local newItem = self:clone()
  newItem.transform = transform.new()

  if type(position) == "table" then
    local x, y, z = unpack(position)
    if camera.current then
      local camX, camY = camera.current.eye[1], camera.current.eye[2]

      local dx, dy = camX - x, camY - y
      local mag = math.sqrt(dx * dx + dy * dy)
      if mag > 1e-4 then
        x = x + (dx / mag) * 0.1
        y = y + (dy / mag) * 0.1
      end
    end
    newItem.transform:set(x, y, z)
  end
  newItem.currentLevel = level
  level:addCharacter(newItem)
end

item.removeFromLevel = function(self)
  if not self.currentLevel then return end
  self.currentLevel:removeCharacter(self)
  self.currentLevel = nil
end

item.eq = function(self, other)
  if type(other) == "string" then
    return self.id == other
  end
  return type(other) == "table" and self.id == other.id
end

item.update = function(self, dt)
  if not self.currentLevel then return end

  self.freeze = self.freeze - dt
  self.time = self.time + dt
  local bounce = math.abs(math.sin(self.time * 3)) * .25

  local ix, iy = self.transform.position[1], self.transform.position[2]

  if self.freeze < 0 then
    local player = self.currentLevel.player
    if player and player.transform then
      local px, py = player.transform.position[1], player.transform.position[2]
      local dx, dy = px - ix, py - iy
      local magSq = dx * dx + dy * dy
      if magSq <= (self.collectRadius * self.collectRadius) then
        if inventory.add(self) then
          self:removeFromLevel()
        end
      elseif magSq <= (self.pickupRadius * self.pickupRadius) then
        local mag = math.sqrt(magSq)
        local ndx, ndy = dx / mag, dy / mag
        ix = ix + ndx * self.magnetSpeed * dt
        iy = iy + ndy * self.magnetSpeed * dt
      end
    end
  end

  self.transform:set(ix, iy, bounce)
end

item.getPlaneDirection = function(self)
  local pp = self.transform.position
  local ce = camera.current.eye
  local toCamX = ce[1] - pp[1]
  local toCamY = ce[2] - pp[2]

  -- TODO validate correct view angle
  if math.abs(toCamX) >= math.abs(toCamY) then
    return toCamX > 0 and "x-" or "x+"
  else
    return toCamY > 0 and "y-" or "y+"
  end
end

item.getDimensions = function(self)
  if self.sprite then
    return self.sprite:getDimensions()
  end
  return 32, 32
end

item.draw = function(self, shader)
  if not shader then return end
  if not self.sprite then return end
  if not self.transform then return end

  local texture, quad = self.sprite:get()
  if not texture or not quad then return end

  graphicsManager.setUniform(shader, "u_Color", { self.sprite:getColor() })
  graphicsManager.setUniform(shader, "u_ModelMatrix", self.transform:getMatrix())

  characterPlane.drawQuad(texture, quad, shader, self:getPlaneDirection(), 1/48)
end

return item