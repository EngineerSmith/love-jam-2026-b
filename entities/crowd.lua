local physicsManager = require("src.core.physicsManager")
local sprite = require("src.core.graphicsManager.sprite")

local camera = require("s3d:camera")

local character = require("lj26b:character")

local crowdBrain = function(char, dt)
  if not char.path or #char.path == 0 then
    if char.currentState ~= char.states.idle then
      char:changeState(char.states.idle)
    end
    return
  end

  if char.currentState ~= char.states.move then
    char:changeState(char.states.move)
  end

  if char.currentState == char.states.move then
    char.pathIndex = char.pathIndex or 1

    local cx, cy = char.transform.position[1], char.transform.position[2]
    local target = char.target or char.path[char.pathIndex]
    local tx, ty = target[1] or cx, target[2] or cy
    local dx, dy = tx - cx, ty - cy
    local magSq = dx * dx + dy * dy

    local waypointRadius = char.attributes.waypointRadius or 0.2
    if magSq <= waypointRadius * waypointRadius then
      if #char.path == 1 then
        char.path = nil
        char.target = nil
        char.velocity = { 0, 0 }
        char:changeState("idle")
        char:removeFromLevelWorld()
        return
      end
      char.pathIndex = char.pathIndex + 1
    end

    if char.pathIndex > #char.path then
      char.pathIndex = 1
    end
    local p = char.path[char.pathIndex]
    local scatterX = love.math.random() - 0.5
    local scatterY = love.math.random() - 0.5
    char.target = { p[1] + scatterX, p[2] + scatterY }
  end
end

local orientations = {
  ["x+"] = { right = {  0, -1 }, forward = {  0, -1 } },
  ["x-"] = { right = {  0,  1 }, forward = {  0,  1 } },
  ["y+"] = { right = {  1,  0 }, forward = {  1,  0 } },
  ["y-"] = { right = { -1,  0 }, forward = { -1,  0 } },
}

local updateCrowdSpriteDirection = function(self, char)
  local dx, dy = 0, 0
  if char.velocity then            dx, dy = unpack(char.velocity, 1, 2) end
  if dx * dx + dy * dy < 2e-4 then dx, dy = unpack(char.facing,   1, 2) end

  local mag = math.sqrt(dx * dx + dy * dy)
  if mag < 1e-4 then return end
  local ndx, ndy = dx / mag, dy / mag

  local camForwardX, camForwardY, camRightX, camRightY = camera.current:getHorizontalAxes()
  local forwardDot = ndx * camForwardX + ndy * camForwardY
  local rightDot = ndx * camRightX + ndy * camRightY

  local targetAnimKey = "side"
  if math.abs(forwardDot) > math.abs(rightDot) then
    targetAnimKey = forwardDot > 0 and "up" or "down"
  else
    targetAnimKey = "side"
    if rightDot > 0 then
      char.facing[1], char.facing[2] =  camRightX,  camRightY
    else
      char.facing[1], char.facing[2] = -camRightX, -camRightY
    end
  end

  if self.currentAnimKey ~= targetAnimKey then
    self.currentAnimKey = targetAnimKey
    local sprite = self.sprites[self.motion .. "_" .. targetAnimKey]
    if sprite then
      if self.sprite then self.sprite:stop(true) end
      self.sprite = sprite:start()
    end
  end
end

local states = { }

states.idle = {
  sprites = {
    idle_side = sprite.new("lj26b:characters/crowd/Idle_Side"),
    idle_up = sprite.new("lj26b:characters/crowd/Idle_Up"),
    idle_down = sprite.new("lj26b:characters/crowd/Idle_Down"),
  },
  enter = function(self, char)
    self.motion = "idle"
    self.currentAnimKey = "side"
    self.sprite = self.sprites.idle_side:start()
  end,
  update = function(self, char, dt)
    updateCrowdSpriteDirection(self, char)
    if char.velocity and (char.velocity[1]^2 + char.velocity[2]^2) > 1e-2 then 
      char:changeState(char.states.move)
    end
  end,
}

states.move = {
  sprites = {
    move_side = sprite.new("lj26b:characters/crowd/Walk_Side"),
    move_up = sprite.new("lj26b:characters/crowd/Walk_Up"),
    move_down = sprite.new("lj26b:characters/crowd/Walk_Down"),
  },
  enter = function(self, char)
    self.motion = "move"
    self.currentAnimKey = "side"
    self.sprite = self.sprites.move_side:start()
    char.stuckTimer = 0
  end,
  update = function(self, char, dt)
    updateCrowdSpriteDirection(self, char)

    if char.target then
      local cx, cy = char.transform.position[1], char.transform.position[2]
      local tx, ty = char.target[1] or cx, char.target[2] or cy
      local dx, dy = tx - cx, ty - cy
      local mag = math.sqrt(dx * dx + dy * dy)
      if mag < 1e-4 then return end

      local speed = char.attributes.walkSpeed
      local step = speed * dt
      local deltaX, deltaY
      if mag <= step then
        deltaX, deltaY = dx, dy
        char.velocity = { 0, 0 }
      else
        local ndx, ndy = dx / mag, dy / mag
        deltaX, deltaY = ndx * speed * dt, ndy * speed * dt
        char.velocity = { ndx * speed, ndy * speed}
      end
      char:moveTowardsDelta(deltaX, deltaY)

      -- Stuck
      local prevX, prevY = cx, cy
      local newX, newY = char.transform.position[1], char.transform.position[2]
      local actualMovedX, actualMovedY = newX - prevX, newY - prevY
      local actualMovedMagSq = actualMovedX * actualMovedX + actualMovedY * actualMovedY

      local waypointRadius = char.attributes.waypointRadius or 0.3
      if mag > waypointRadius and actualMovedMagSq < (0.05 * step)^2 then
        char.stuckTimer = char.stuckTimer + dt
        if char.stuckTimer > 1.0 then
          char.stuckTimer = 0
          char.velocity = { 0, 0 }
          char.pathIndex = char.pathIndex + 1
          char:changeState(char.states.idle)
        end
      else
        char.stuckTimer = 0
      end
    end
  end,
}

local crowd = character.new({
  shape = require("libs.slick").newCircleShape(0, 0, .2, nil, physicsManager.getTag("player")),
  states = states,
  defaultState = "idle",
  brain = crowdBrain,
  attributes = {
    maxHealth = 1,
    currentHealth = 1,
    invulnerable = true,
    walkSpeed = 2.0,
    waypointRadius = 0.3,
  }
})

-- path is an array of points, { { x1, y1 }, { x2, y2}, ..., { xn, yb } }
crowd.setPath = function(self, path)
  self.path = path
  -- TODO pick nearest waypoint? or calculate nearest point to character, along the path
  -- Pick the closest waypoint, and it's neighbors, if a point between their lines is closest,  target the destination of that line (If we targetted the line itself, crowdBrain would be confused)
  self.pathIndex = 1
  self.target = path[self.pathIndex]
end

return crowd