local sprite = require("src.core.graphicsManager.sprite")

local camera = require("s3d:camera")

local character = require("lj26b:character")
local itemDefinitions = require(":inventory.itemDefinitions")

local wolfBrain = function(char, dt)
  if char.currentState == char.states.stagger or char.currentState == char.states.death then return end
  if not char.currentLevel or not char.currentLevel.player then return end

  local player = char.currentLevel.player

  local cx, cy = char.transform.position[1], char.transform.position[2]
  local px, py = player.transform.position[1], player.transform.position[2]
  local dx, dy = px - cx, py - cy
  local magSq = dx * dx + dy * dy

  local aggroRadius = char.attributes.aggroRadius
  local attackRadius = char.attributes.attackRadius

  if char.currentState == char.states.idle then
    if magSq <= (aggroRadius * aggroRadius) then
      char:changeState(char.states.move)
      char.target = player
    end
  elseif char.currentState == char.states.move then
    local camForwardX, camForwardY, camRightX, camRightY = camera.current:getHorizontalAxes()
    -- local lateralDist = math.abs(dx * camRightX + dy * camRightY)
    local depthDist = math.abs(dx * camForwardX + dy * camForwardY)

    local verticalAlignmentThreshold = 0.45
    if magSq <= (attackRadius * attackRadius) and depthDist <= verticalAlignmentThreshold and
        char.attributes.attackCooldown <= 0 then
      char:changeState(char.states.attack)
    elseif magSq > (aggroRadius * aggroRadius * 1.3) then
      char.target = nil
      char:changeState(char.states.idle)
    end
  end

end

local states = { }

states.idle = {
  sprites = {
    idle = sprite.new("lj26b:characters/wolf/Idle_Side"),
  },
  enter = function(self, char)
    self.motion = "idle"
    self.sprite = self.sprites.idle:start()
  end,
}

states.move = {
  sprites = {
    move = sprite.new("lj26b:characters/wolf/Walk_Side"),
  },
  enter = function(self, char)
    self.motion = "hunting"
    self.sprite = self.sprites.move:start()
    self.orbitSide = love.math.random() < 0.5 and 1 or -1
  end,
  update = function(self, char, dt)
    if not char.target then return end

    if char.attributes.attackCooldown > 0 then
      char.attributes.attackCooldown = char.attributes.attackCooldown - dt
    end

    local tx, ty = char.target.transform.position[1], char.target.transform.position[2]
    local cx, cy = char.transform.position[1], char.transform.position[2]
    local dx, dy = tx - cx, ty - cy

    local camForwardX, camForwardY, camRightX, camRightY = camera.current:getHorizontalAxes()
    local lateralDist = dx * camRightX   + dy * camRightY
    local depthDist   = dx * camForwardX + dy * camForwardY

    local deadCentreThreshold = 0.7
    if math.abs(lateralDist) < deadCentreThreshold then
      lateralDist = lateralDist + self.orbitSide * 0.8
    end

    local steerWeightDepth = 1.5
    local lat = (lateralDist > 0 and 1 or -1) * math.min(math.abs(lateralDist), 1.0)
    local moveCamX = lat * camRightX + depthDist * steerWeightDepth * camForwardX
    local moveCamY = lat * camRightY + depthDist * steerWeightDepth * camForwardY

    local mag = math.sqrt(moveCamX * moveCamX + moveCamY * moveCamY)

    if mag > 1e-4 then
      local ndx, ndy = moveCamX / mag, moveCamY / mag

      local screenFacingDot = ndx * camRightX + ndy * camRightY
      local facingThreshold = 0.25
      if screenFacingDot > facingThreshold then
        char.facing[1], char.facing[2] = camRightX, camRightY
      elseif screenFacingDot < -facingThreshold then
        char.facing[1], char.facing[2] = -camRightX, -camRightY
      end

      local speed = char.attributes.walkSpeed
      if char.attributes.attackCooldown > 0 then
        speed = speed * 0.7 -- speed penalty
      end
      local deltaX = ndx * speed * dt
      local deltaY = ndy * speed * dt
      char:moveTowardsDelta(deltaX, deltaY)
    end
  end,
}

states.attack = {
  sprites = {
    attack = sprite.new("lj26b:characters/wolf/Attack_Side"),
  },
  enter = function(self, char)
    if not self.onFinish then
      self.onFinish = function()
        char.attributes.attackCooldown = 1.2
        char:changeState(char.states.move)
      end
    end
    self.hasBitten = false
    self.motion = "attacking"
    self.sprite = self.sprites.attack:start(self.onFinish)

    if char.target then
      local tx, ty = char.target.transform.position[1], char.target.transform.position[2]
      local cx, cy = char.transform.position[1], char.transform.position[2]
      local dx, dy = tx - cx, ty - cy
      local mag = math.sqrt(dx * dx + dy * dy)

      if mag > 1e-4 then
        char.facing[1], char.facing[2] = dx / mag, dy / mag
      end
    end
  end,
  update = function(self, char, dt)
    if not self.hasBitten and self.sprite.metaUserdata and self.sprite.metaUserdata.attackOn then
      local targetFrameIndex = self.sprite.metaUserdata.attackOn + 1
      if self.sprite.frameIndex == targetFrameIndex then
        self.hasBitten = true

        if char.target then
          local tx, ty = char.target.transform.position[1], char.target.transform.position[2]
          local cx, cy = char.transform.position[1], char.transform.position[2]
          local dx, dy = tx - cx, ty - cy
          local magSq = dx * dx + dy * dy

          local biteRange = char.attributes.biteRange
          if magSq <= (biteRange * biteRange) then
            local coneAngle = 120
            local threshold = math.cos(math.rad(coneAngle * 0.5))
            local mag = math.sqrt(magSq)
            local nx, ny = dx / mag, dy / mag
            local dot = nx * char.facing[1] + ny * char.facing[2]
            if dot >= threshold then
              char.target:takeHit(char.attributes.attackDamage)
            end
          end
        end
      end
    end
  end,
}

states.stagger = {
  sprites = {
    hit = sprite.new("lj26b:characters/wolf/Stagger_Side"),
  },
  enter = function(self, char)
    if not self.onFinish then
      self.onFinish = function()
        char:changeState(char.states.move)
      end
    end
    self.motion = "hit"
    self.sprite = self.sprites.hit:start(self.onFinish)
  end,
  update = function(self, _, _)
    if self.sprite and self.sprite.metaUserdata and self.sprite.metaUserdata.flashFrames then
      local isFlash = false
      local currentIndex = self.sprite.frameIndex - 1
      for _, frameId in ipairs(self.sprite.metaUserdata.flashFrames) do
        if type(frameId) == "number" and currentIndex == frameId then
          isFlash = true
          break
        end
      end

      if isFlash then
        self.sprite:setColor(1, .4, .4)
      else
        self.sprite:setColor(1, 1, 1)
      end
    end
  end,
}

states.death = {
  sprites = {
    death = sprite.new("lj26b:characters/wolf/Death_Side"),
    still = sprite.new("lj26b:characters/wolf/Death_Side_Still"),
  },
  enter = function(self, char)
    if not self.onFinish then
      self.onFinish = function()
        self.motion = "dead"
        self.sprite = self.sprites.still

        itemDefinitions["wolf_tuff"]:spawn(char.currentLevel, char.transform.position)

        char:removeFromLevelWorld()
        self.timer = 5
      end
    end
    self.motion = "dying"
    self.sprite = self.sprites.death:start(self.onFinish)
  end,
  update = function(self, char, dt)
    if self.motion ~= "dead" then return end
    self.timer = self.timer - dt
    if self.timer < 0 then
      char.transform:move(0, 0, -.4 * dt)
      if self.timer < -1.5 then
        char:removeFromLevel() -- stops updates
      end
    end
  end,
}

local wolf = character.new({
  shape = require("libs.slick").newCircleShape(0, 0, .4),
  states = states,
  defaultState = "idle",
  brain = wolfBrain,
  attributes = {
    maxHealth = 100,
    currentHealth = 100,
    invulnerable = false,
    aggroRadius = 4.0,
    attackRadius = 1.0,
    biteRange = 1.5,
    attackDamage = 10,
    walkSpeed = 3.0, -- Fast move speed, but long build up attack! So, player can run away during attack animation
    attackCooldown = 0.0,
  },
})

wolf.takeHit = function(self, damage)
  if self.currentState == self.states.death then return end
  local isDamaged = getmetatable(wolf).takeHit(self, damage)
  if self.attributes.currentHealth <= 0 then
    self:changeState(self.states.death)
  else
    self:changeState(self.states.stagger)
  end
  return isDamaged
end

return wolf