local logger = LOGGER:extend("player")

local vornmath = require("libs.vornmath")

local sprite = require("src.core.graphicsManager.sprite")

local uiManager = require("menu:uiManager")

local camera = require("s3d:camera")
local levelManager = require("s3d:levelManager")

local character = require("lj26b:character")
local controller = require("lj26b:player.controls")
local inventory = require("lj26b:inventory")

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
    if controller:pressed("inventory") then
      if uiManager.isInStack("game:menu.inventory") then
        uiManager.pop("game:menu.inventory")
        -- logger:info("Closed inventory")
      else
        uiManager.push("game:menu.inventory")
        -- logger:info("Opened inventory")
      end
    end
    local isInventoryOpen = uiManager.isInStack("game:menu.inventory")
    if isInventoryOpen and controller:pressed("closeInventory") then -- Extra controls, so ecs closes open inventory, but not open it
      uiManager.pop("game:menu.inventory")
      -- logger:info("Closed inventory")
      isInventoryOpen = false
    end

    if not isInventoryOpen then
      if controller:pressed("dodge") then
        if char.attributes.stamina >= char.attributes.dodgeStaminaCost then
          char:changeState(char.states.dodge)
          return
        -- else -- todo bad noise
        end
      end
      if controller:pressed("attack") then
        if char.attributes.stamina >= char.attributes.attackStaminaCost then
          char:changeState(char.states.attack)
          return
        -- else -- todo bad noise
        end
      end
      if controller:pressed("kitchen") then
        if char.currentLevel then
          if char.currentLevel.id == "game:city" then
            local x, y, z = char.transform.position[1], char.transform.position[2], char.transform.position[3]
            local screenX, screenY = camera.current:project(x, y, z + .5)
            levelManager.setActiveLevel("game:kitchen", screenX / love.graphics.getWidth(), screenY / love.graphics.getHeight(), "spawn")
          else
            levelManager.setActiveLevel("game:city", .5, .5, "spawn")
          end
        end
      end
    end

    local dx, dy = char:getMovementInput()
    local isMoving = (dx ~= 0 or dy ~= 0) and not isInventoryOpen

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
        self.motion = "rolling"
        self.sprite = self.sprites.dodge:start()
      end
    end

    self.dodgeTimer = char.attributes.dodgeDuration
    self.elapsed = 0

    char.attributes.stamina = char.attributes.stamina - char.attributes.dodgeStaminaCost
    char.attributes.staminaRegenDelay = char.attributes.dodgeStaminaDelay
    char.attributes.invulnerable = true

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
  collisionResponse = function(_, other, _, _)
    -- Can't check getmetatable, as `character:clone` can change it
    if type(other) == "table" and other.type == "character" then
      return "cross"
    end
    return "slide"
  end,
  exit = function(_, char)
    char.attributes.invulnerable = false -- prevent bugs
  end,
  update = function(self, char, dt)
    self.dodgeTimer = self.dodgeTimer - dt
    self.elapsed = self.elapsed + dt
    if self.dodgeTimer <= 0 then
      if char.currentLevel then
        local px, py = char.transform.position[1], char.transform.position[2]
        local collisions, count = char.currentLevel.world:test(char, px, py)
        if count > 0 then
          char.attributes.invulnerable = true -- as the character is technically stuck, we don't want the player to feel it is unfair

          local pushX, pushY = 0, 0
          for i = 1, count do
            local collision = collisions[i]
            pushX = pushX + collision.normal.x * collision.depth
            pushY = pushY + collision.normal.y * collision.depth
          end
          local mag = math.sqrt(pushX * pushX + pushY * pushY)
          local x, y = 0, 0
          if mag > 1e-4 then
            local dx, dy = pushX / mag, pushY / mag
            x, y = char.currentLevel.world:update(char, px + dx * char.attributes.dodgeSpeed * dt, py + dy * char.attributes.dodgeSpeed * dt)
          else
            x, y = char.currentLevel.world:update(char, px + pushX, py + pushY)
          end
          char.transform.position[1], char.transform.position[2] = x, y
          return
        else
          char.attributes.invulnerable = false
          char:changeState(char.states.move)
          return
        end
      else
        char.attributes.invulnerable = false
        char:changeState(char.states.move)
        return
      end
    end

    if self.motion == "charging" and self.elapsed >= char.attributes.dodgeDuration * 0.35 then
      self.onChargeFinish()
    elseif self.motion == "rolling" and self.elapsed >= char.attributes.dodgeDuration * 0.8 then
      char.attributes.invulnerable = false
    end

    local deltaX = self.dodgeDirection[1] * char.attributes.dodgeSpeed * dt
    local deltaY = self.dodgeDirection[2] * char.attributes.dodgeSpeed * dt

    char:moveTowardsDelta(deltaX, deltaY, self.collisionResponse)
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

    -- local handSlot = inventory.slots.equipment.hand
    -- local weapon = handSlot and handSlot.item and handSlot.item.stats or {
    --   damage = 10,
    --   range = 1.3,
    --   coneAngle = 110,
    -- }

    char.attributes.stamina = char.attributes.stamina - char.attributes.attackStaminaCost
    char.attributes.staminaRegenDelay = char.attributes.attackStaminaDelay

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

    -- if char.currentLevel then
    --   local itemDefinitions = require(":inventory.itemDefinitions")
    --   itemDefinitions["wolf_tuff"]:spawn(char.currentLevel, { char.transform.position[1] + 2, char.transform.position[2], 0 } )
    -- end
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

        local handSlot = inventory.slots.equipment.hand
        local weapon = handSlot and handSlot.item and handSlot.item.stats or {
          damage = 10,
          range = 1.3,
          coneAngle = 110,
        }

        if char.currentLevel then
          local closestList = char.currentLevel:getClosestCharacters(char, 1,
              createAttackFilter(self.attackDirection, weapon.range or 1.3, weapon.coneAngle or 120))
          local target = closestList[1]
          if target then
            local damage = char.attributes.baseDamage + weapon.damage
            if target.char:takeHit(damage) then
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

-- TODO player should be able to crawl away during stagger
states.stagger = {
  sprites = {
    hit = sprite.new("lj26b:characters/dummy/Hit_Side"),
  },
  enter = function(self, char)
    self.staggerTimer = 0.35
    self.motion = "stagger"
    self.sprite = self.sprites.hit:start()
    if self.sprite.frameDuration ~= 0 and self.sprite.frames then
      self.sprite.timeScale = (self.sprite.frameDuration * #self.sprite.frames) / self.staggerTimer
    end
    char.attributes.invulnerable = true
  end,
  exit = function(self, char)
    char.attributes.invulnerable = false
    char.attributes.staggerImmunity = 0.25
  end,
  update = function(self, char, dt)
    self.staggerTimer = self.staggerTimer - dt

    if controller:pressed("dodge") then
      if char.attributes.stamina >= char.attributes.dodgeStaminaCost then
        char:changeState(char.states.dodge)
        return
      end
    end

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

    local dx, dy = char:getMovementInput()
    local isMoving = dx ~= 0 or dy ~= 0
    if isMoving then
      local dirX, dirY = normalize(dx, dy)
      char.facing[1], char.facing[2] = dirX, dirY
      local deltaX = dirX * char.attributes.crawlSpeed * dt
      local deltaY = dirY * char.attributes.crawlSpeed * dt
      char:moveTowardsDelta(deltaX, deltaY)
    end

    -- Prevent possible future invul bugs if the animation stops somehow
    if self.staggerTimer <= 0 or not self.sprite.isPlaying then
      char:changeState(char.states.move)
    end
  end,
}

local baseAttributes = {
  walkSpeed          = 3,
  crawlSpeed         = 2,
  dodgeSpeed         = 5,
  dodgeDuration      = 0.4,
  dodgeCooldown      = 0.5,
  attackSpeed        = 1,
  attackDuration     = 0.25,
  maxStamina         = 100,
  staminaRegenRate   = 45,
  dodgeStaminaCost   = 20,
  dodgeStaminaDelay  = 0.6,
  baseDamage         = 0,
  attackStaminaCost  = 15, -- Move checks to equipment? I guess attacking should have a base cost!
  attackStaminaDelay = 0.4,
  maxHealth          = 100,
  currentHealth      = 100,
  staggerImmunity    = 0,
}
local attributes = setmetatable({ }, {
  __index = function(_, modifier)
    if baseAttributes[modifier] then
      local base = baseAttributes[modifier] or 0
      if type(base) ~= "number" then return base end
      local mod = inventory.getStatModifiers()[modifier] or 0
      return base + mod
    end
  end,
  __newindex = baseAttributes,
})

local player = character.new({
  facing = { 0, 1 },
  shape = require("libs.slick").newCircleShape(0, 0, 0.2),
  states = states,
  defaultState = "move",
  attributes = attributes,
})

player.getMovementInput = function(self) -- [Out of scope] TODO define controller within player
  local rawDx, rawDy = controller:get("move")
  if rawDx == 0 and rawDy == 0 then
    self._snapAxis = nil
    return 0, 0
  end
  rawDx = rawDx * -1

  local camForwardX, camForwardY, camRightX, camRightY = camera.current:getHorizontalAxes()

  dx = camRightX * rawDx + camForwardX * rawDy
  dy = camRightY * rawDx + camForwardY * rawDy

  if math.abs(rawDx) < 0.1 or math.abs(rawDy) < 0.1 then
    if not self._snapAxis then
      self._snapAxis = math.abs(dx) >= math.abs(dy) and "x" or "y"
    end

    local threshold = 0.2
    if self._snapAxis == "x" then
      if math.abs(dy) > math.abs(dx) + threshold then
        self._snapAxis = "y"
      end
    else
      if math.abs(dx) > math.abs(dy) + threshold then
        self._snapAxis = "x"
      end
    end
    
    if self._snapAxis == "x" then
      dx, dy = dx > 0 and 1 or -1, 0
    else
      dx, dy = 0, dy > 0 and 1 or -1
    end
  else
    self._snapAxis = nil
  end

  return dx, dy
end

player.addToLevel = function(self, level, position)
  getmetatable(player).addToLevel(self, level, position)
  self.attributes.stamina = 0 -- Prevent stamina use during level transition
  self.attributes.staminaRegenDelay = 0.3
end

player.update = function(self, dt)
  getmetatable(player).update(self, dt)

  if self.attributes.staggerImmunity > 0 then
    self.attributes.staggerImmunity = self.attributes.staggerImmunity - dt
  end

  -- Should delay decrease while state ~= move?
  if self.attributes.staminaRegenDelay > 0 then
    self.attributes.staminaRegenDelay = self.attributes.staminaRegenDelay - dt
  else
    if self.attributes.stamina < self.attributes.maxStamina then
      self.attributes.stamina = math.min(self.attributes.maxStamina, self.attributes.stamina + self.attributes.staminaRegenRate * dt)
    end
  end
end

player.takeHit = function(self, damage)
  if self.attributes.staggerImmunity > 0 then return false end
  local isDamaged = getmetatable(player).takeHit(self, damage)
  self:changeState(self.states.stagger)
  return isDamaged
end

return player