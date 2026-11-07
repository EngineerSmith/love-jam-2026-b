
local vornmath = require("libs.vornmath")

local sprite = require("src.core.graphicsManager.sprite")

local camera = require("s3d:camera")

local character = require("lj26b:character")
local controller = require("lj26b:player.controls")

local normalize
do
  local temp = vornmath.vec2()
  normalize = function(x, y)
    temp = vornmath.fill(temp, x, y)
    temp = vornmath.normalize(temp, temp)
    return temp[1], temp[2]
  end
end

local states = { }

states.move = {
  sprites = {
    move = sprite.new("lj26b:characters/player/Walk_Side"),
    idle = sprite.new("lj26b:characters/player/Idle_Side"),
    idleFidget = sprite.new("lj26b:characters/player/Idle_Fidget_Side"),
  },
  enter = function(self)
    if not self.onIdleFinish then
      self.onIdleFinish = function()
        self.sprite:seek(1)
        if self.sprite ~= self.sprites.idleFidget and love.math.random() <= 0.05 then
          self.sprite = self.sprites.idleFidget:start(self.onIdleFinish)
        else
          self.sprite = self.sprites.idle:start(self.onIdleFinish)
        end
      end
    end

    local dx, dy = controller:get("move")
    if dx == 0 and dy == 0 then
      self.motion = "idle"
      self.sprite = self.sprites.idle:start(self.onIdleFinish)
    else
      self.motion = "moving"
      self.sprite = self.sprites.move:start()
    end
  end,
  update = function(self, char, dt)
    if controller:pressed("dodge") then
      if char.stamina >= char.attributes.dodgeStaminaCost then
        char:changeState(char.states.dodge)
        return
      -- else -- todo bad noise
      end
    end
    if controller:pressed("attack") then
      if char.stamina >= char.attributes.attackStaminaCost then
        char:changeState(char.states.attack)
        return
      -- else -- todo bad noise
      end
    end

    local dx, dy = char:getMovementInput()
    local isMoving = dx ~= 0 or dy ~= 0

    if isMoving then
      local dirX, dirY = normalize(dx, dy)
      char.facing[1], char.facing[2] = dirX, dirY

      if self.motion ~= "moving" then
        self.motion = "moving"
        self.sprite:stop(true):seek(1)
        self.sprite = self.sprites.move:start()
      end

      local deltaX = dirX * char.attributes.walkSpeed * dt
      local deltaY = dirY * char.attributes.walkSpeed * dt

      char:moveTowardsDelta(deltaX, deltaY)
    else
      if self.motion == "moving" then
        self.motion = "idle"
        self.sprite:stop(true):seek(1)
        self.sprite = self.sprites.idle:start(self.onIdleFinish)
      end
    end
  end,
}

states.dodge = {
  sprites = {
    dodge = sprite.new("lj26b:characters/player/Dodge_Side"),
    dodgeCharge = sprite.new("lj26b:characters/player/Dodge_Charge_Side"),
  },
  enter = function(self, char)
    if not self.onChargeFinish then
      self.onChargeFinish = function()
        if self.sprite.isPlaying then self.sprite:stop(true) end
        self.sprite:seek(1)
        self.motion = "dodging"
        self.sprite = self.sprites.dodge:start()
      end
    end

    self.dodgeTimer = char.attributes.dodgeDuration
    self.elapsed = 0

    char.stamina = char.stamina - char.attributes.dodgeStaminaCost
    char.staminaRegenDelay = char.attributes.dodgeStaminaDelay

    local dx, dy = char:getMovementInput()
    if dx == 0 and dy == 0 then
      self.dodgeDirection = char.facing
    else
      self.dodgeDirection = { normalize(dx, dy) }
      char.facing[1], char.facing[2] = self.dodgeDirection[1], self.dodgeDirection[2]
    end
    self.motion = "charging"

    local chargeSprite = self.sprites.dodgeCharge
    if chargeSprite.frameDuration ~= 0 and chargeSprite.frames then
      local chargeNativeDuration = chargeSprite.frameDuration * #chargeSprite.frames
      local targetChargeDuration = char.attributes.dodgeDuration * 0.35
      if chargeNativeDuration >0 and targetChargeDuration > 0 then
        chargeSprite.timeScale = chargeNativeDuration / targetChargeDuration
      end
    end
    self.sprite = chargeSprite:start(self.onChargeFinish)
  end,
  update = function(self, char, dt)
    self.dodgeTimer = self.dodgeTimer - dt
    self.elapsed = self.elapsed + dt
    if self.dodgeTimer <= 0 then
      char:changeState(char.states.move)
      return
    end

    if self.motion == "charging" and self.elapsed >= char.attributes.dodgeDuration * 0.35 then
      self.onChargeFinish()
    end

    local deltaX = self.dodgeDirection[1] * char.attributes.dodgeSpeed * dt
    local deltaY = self.dodgeDirection[2] * char.attributes.dodgeSpeed * dt

    char:moveTowardsDelta(deltaX, deltaY)
  end,
}

local createAttackFilter = function(attackDirection, attackRange, coneAngle)
  coneAngle = coneAngle or 120
  local threshold = math.cos(math.rad(coneAngle * 0.5))
  local attackRangeSq = attackRange * attackRange

  return function(possibleTarget, dx, dy, magSq)
    if not possibleTarget.attributes or possibleTarget.attributes.currentHealth == nil then
      return false
    end
    if magSq > attackRangeSq then return false end

    if magSq < 1e-4 then return true end
    local mag = math.sqrt(magSq)
    local nx, ny = dx / mag, dy / mag
    local dot = nx * attackDirection[1] + ny * attackDirection[2]
    return dot >= threshold
  end
end

states.attack = {
  sprites = {
    attack = sprite.new("lj26b:characters/player/Lunge_Side"),
  },
  enter = function(self, char)
    self.attackTimer = char.attributes.attackDuration
    self.hasHit = false

    -- local weapon = char.equipment and char.equipment.hand or { damage = 15, range = 2.5 }

    char.stamina = char.stamina - char.attributes.attackStaminaCost
    char.staminaRegenDelay = char.attributes.attackStaminaDelay

    local dx, dy = char:getMovementInput()
    if dx == 0 and dy == 0 then
      self.attackDirection = { char.facing[1],  char.facing[2] }
    else
      self.attackDirection = { normalize(dx, dy) }
      char.facing[1], char.facing[2] = self.attackDirection[1], self.attackDirection[2]
    end

    self.motion = "attacking"
    self.sprite = self.sprites.attack:start()
    if self.sprite.frameDuration ~= 0 and self.sprite.frames then
      self.sprite.timeScale = (self.sprite.frameDuration * #self.sprite.frames) / char.attributes.attackDuration
    end
  end,
  update = function(self, char, dt)
    self.attackTimer = self.attackTimer - dt
    if self.attackTimer <= 0 then
      char:changeState(char.states.move)
      return
    end

    if not self.hasHit and self.sprite.metaUserdata and self.sprite.metaUserdata.attackOn then
      local targetFrameIndex = self.sprite.metaUserdata.attackOn + 1
      if self.sprite.frameIndex >= targetFrameIndex then
        self.hasHit = true

        local weapon = char.equipment and char.equipment.hand or nil
        if weapon and char.currentLevel then
          local closestList = char.currentLevel:getClosestCharacters(char, 1,
              createAttackFilter(self.attackDirection, weapon.range or 1.3, weapon.coneAngle or 120))
          local target = closestList[1]
          if target then
            if target.char:takeHit(weapon.damage) then
              -- success
            else
              -- failed, e.g. invulnerable tag
            end
          end
        end
      end
    end

    local deltaX = self.attackDirection[1] * char.attributes.attackSpeed * dt
    local deltaY = self.attackDirection[2] * char.attributes.attackSpeed * dt

    char:moveTowardsDelta(deltaX, deltaY, "touch")
  end,
}

local player = character.new({
  facing = { 0, 1 },
  shape = require("libs.slick").newCircleShape(0, 0, 0.25),
  states = states,
  defaultState = "move",
  attributes = {
    walkSpeed          = 3,
    dodgeSpeed         = 6,
    dodgeDuration      = 0.4,
    dodgeCooldown      = 0.5,
    attackSpeed        = 1,
    attackDuration     = 0.4,
    maxStamina         = 100,
    staminaRegenRate   = 45,
    dodgeStaminaCost   = 30,
    dodgeStaminaDelay  = 0.6,
    attackStaminaCost  = 15, -- Move checks to equipment? I guess attacking should have a base cost!
    attackStaminaDelay = 0.4,
    maxHealth          = 100,
    currentHealth      = 100,
  },
})

local equipment = {
  hands = {
    fists = {
      name = "Fists",
      damage = 15,
      range = 1.3,
      coneAngle = 110,
      staminaCost = 10, -- maybe?
      attacksStaminaDelay = 0.4,
    }
  }
}

player.equipment = {
  hand = equipment.hands.fists, -- default equipment
}

player.getMovementInput = function(self) -- [Out of scope] TODO define controller within player
  local rawDx, rawDy = controller:get("move")
  if rawDx == 0 and rawDy == 0 then
    return 0, 0
  end

  local camForwardX, camForwardY, camRightX, camRightY = camera.current:getHorizontalAxes()

  dx = camRightX * rawDx + camForwardX * rawDy
  dy = camRightY * rawDx + camForwardY * rawDy

  if math.abs(rawDx) < 0.1 or math.abs(rawDy) < 0.1 then
    if math.abs(dx) > math.abs(dy) then
      dx, dy = dx > 0 and 1 or -1, 0
    else
      dx, dy = 0, dy > 0 and 1 or -1
    end
  end

  return dx, dy
end

player.addToLevel = function(self, level, position)
  getmetatable(player).addToLevel(self, level, position)
  self.stamina = 0 -- Prevent stamina use during level transition
  self.staminaRegenDelay = 0.3
end

player.update = function(self, dt)
  getmetatable(player).update(self, dt)

  -- Should delay decrease while state ~= move?
  if self.staminaRegenDelay > 0 then
    self.staminaRegenDelay = self.staminaRegenDelay - dt
  else
    if self.stamina < self.attributes.maxStamina then
      self.stamina = math.min(self.attributes.maxStamina, self.stamina + self.attributes.staminaRegenRate * dt)
    end
  end
end

return player