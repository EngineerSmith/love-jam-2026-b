local sprite = require("src.core.graphicsManager.sprite")

local camera = require("s3d:camera")

local character = require("lj26b:character")
local itemDefinitions = require(":inventory.itemDefinitions")

local slimeBrain  = function(char, dt)
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
    if magSq <= (attackRadius * attackRadius) and char.attributes.attackCooldown <= 0 then
      char.target = player
      char:changeState(char.states.attack)
    elseif magSq > (aggroRadius * aggroRadius * 1.6) then
      char.target = nil
      char:changeState(char.states.idle)
    end
  end
end

local states = { }

states.idle = {
  sprites = {
    idle = sprite.new("lj26b:characters/slime/Idle_Side"),
  },
  enter = function(self, char)
    self.motion = "idle"
    self.sprite = self.sprites.idle:start()
  end,
}

states.move = {
  sprites = {
    move = sprite.new("lj26b:characters/slime/Walk_Side"),
  },
  enter = function(self, char)
    self.motion = "crawling"
    self.sprite = self.sprites.move:start()
  end,
  update = function(self, char, dt)
    if not char.target then return end
    if char.attributes.attackCooldown > 0 then
      char.attributes.attackCooldown = char.attributes.attackCooldown - dt
    end

    local tx, ty = char.target.transform.position[1], char.target.transform.position[2]
    local cx, cy = char.transform.position[1], char.transform.position[2]
    local dx, dy = tx - cx, ty - cy
    local mag = math.sqrt(dx * dx+ dy * dy)
    if mag > 1e-4 then
      local ndx, ndy = dx / mag, dy / mag

      local _, _, camRightX, camRightY = camera.current:getHorizontalAxes()
      local screenFacingDot = ndx * camRightX + ndy * camRightY
      local facingThreshold = 0.25
      if screenFacingDot > facingThreshold then
        char.facing[1], char.facing[2] = camRightX, camRightY
      elseif screenFacingDot < -facingThreshold then
        char.facing[1], char.facing[2] = -camRightX, -camRightY
      end

      local speed = char.attributes.walkSpeed
      local deltaX = ndx * speed * dt
      local deltaY = ndy * speed * dt
      char:moveTowardsDelta(deltaX, deltaY)
    end
  end,
}

states.attack = {
  sprites = {
    lunge = sprite.new("lj26b:characters/slime/Attack_Side"),
  },
  enter = function(self, char)
    if not self.onFinish then
      self.onFinish = function()
        char.attributes.attackCooldown = 0.7
        char:changeState(char.states.move)
      end
    end
    self.hasHit = false
    self.motion = "attacking"
    self.sprite = self.sprites.lunge:start(self.onFinish)

    if char.target then
      local tx, ty = char.target.transform.position[1], char.target.transform.position[2]
      local cx, cy = char.transform.position[1], char.transform.position[2]
      local dx, dy = tx - cx, ty - cy
      local mag = math.sqrt(dx * dx + dy * dy)
      if mag > 1e-4 then
        char.facing[1], char.facing[2]  = dx / mag, dy / mag
        self.lungeDirX, self.lungeDirY = dx / mag, dy / mag
      end
    end
  end,
  update = function(self, char, dt)
    if not self.sprite.metaUserdata then return end

    local currentFrame = self.sprite.frameIndex

    local mud = self.sprite.metaUserdata
    if mud.lungeStart and mud.lungeEnd then
      local startFrame = mud.lungeStart + 1
      local endFrame = mud.lungeEnd + 1

      if currentFrame >= startFrame and currentFrame <= endFrame then
        local lungeSpeed = char.attributes.lungeSpeed
        char:moveTowardsDelta(self.lungeDirX * lungeSpeed * dt, self.lungeDirY * lungeSpeed * dt)
      end
    end

    if not self.hasHit and mud.attackOn then
      local targetFrameIndex = mud.attackOn + 1
      print("hit", currentFrame, targetFrameIndex)
      if currentFrame >= targetFrameIndex then
        print("PASSED!")
        self.hasHit = true
        if char.target then
          local tx, ty = char.target.transform.position[1], char.target.transform.position[2]
          local cx, cy = char.transform.position[1], char.transform.position[2]
          local dx, dy = tx - cx, ty - cy
          local magSq = dx * dx + dy * dy
          local slamRange = char.attributes.slamRange
          if magSq <= (slamRange * slamRange) then
            char.target:takeHit(char.attributes.attackDamage)
          end
        end
      end
    end
  end,
}

states.stagger = {
  sprites = {
    hit = sprite.new("lj26b:characters/slime/Stagger_Side"),
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
    death = sprite.new("lj26b:characters/slime/Death_Side"),
    still = sprite.new("lj26b:characters/slime/Death_Side_Still"),
  },
  enter = function(self, char)
    if not self.onFinish then
      self.onFinish = function()
        self.motion = "dead"
        self.sprite = self.sprites.still

        if love.math.random() < .7 then
          itemDefinitions["slime_jelly"]:spawn(char.currentLevel, char.transform.position)
        end

        char:removeFromLevelWorld()
        self.timer = 4
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
      if self.timer < -0.75 then
        char:removeFromLevel() -- stops updates
      end
    end
  end,
}

local slime = character.new({
  shape = require("libs.slick").newCircleShape(0, 0, .2),
  states = states,
  defaultState = "idle",
  brain = slimeBrain,
  attributes = {
    maxHealth = 90,
    currentHealth = 90,
    invulnerable = false,
    aggroRadius = 6.0,
    attackRadius = 2.0,
    slamRange = 1.0,
    attackDamage = 12,
    walkSpeed = 1.5,
    lungeSpeed = 7.5,
    attackCooldown = 0.0,
   },
})

slime.takeHit = function(self, damage)
  if self.currentState == self.states.death then return end
  local isDamaged = getmetatable(slime).takeHit(self, damage)
  if self.attributes.currentHealth <= 0 then
    self:changeState(self.states.death)
  else
    self:changeState(self.states.stagger)
  end
  return isDamaged
end

return slime