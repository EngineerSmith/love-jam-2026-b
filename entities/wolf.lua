local sprite = require("src.core.graphicsManager.sprite")

local character = require("lj26b:character")

local wolfBrain = function(char, dt)
  if char.currentState == char.states.stagger then return end
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
    if magSq <= (attackRadius * attackRadius) then
      char:changeState(char.states.attack)
    elseif magSq > (aggroRadius * aggroRadius * 1.5) then
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
  end,
  update = function(self, char, dt)
    if not char.target then return end

    local tx, ty = char.target.transform.position[1], char.target.transform.position[2]
    local cx, cy = char.transform.position[1], char.transform.position[2]
    local dx, dy = tx - cx, ty - cy
    local mag = math.sqrt(dx * dx + dy * dy)

    if mag > 1e-4 then
      local ndx, ndy = dx / mag, dy / mag
      char.facing[1], char.facing[2] = ndx, ndy

      local speed = char.attributes.walkSpeed
      local deltaX = ndx * speed * dt
      local deltaY = ndy * speed * dt
      char:moveTowardsDelta(deltaX, deltaY)
    end
  end,
}

states.attack = {
  sprites = {
    attack = sprite.new("lj26b:characters/player/Lunge_Side"),
  },
  enter = function(self, char)
    if not self.onFinish then
      self.onFinish = function()
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
      if self.sprite.frameIndex then
        self.hasBitten = true

        if char.target then
          local tx, ty = char.target.transform.position[1], char.target.transform.position[2]
          local cx, cy = char.transform.position[1], char.transform.position[2]
          local dx, dy = tx - cx, ty - cy
          local magSq = dx * dx + dy * dy

          local biteRange = char.attributes.biteRange
          if magSq <= (biteRange * biteRange) then
            char.target:takeHit(char.attributes.attackDamage)
          end
        end
      end
    end
  end,
}

states.stagger = {
  sprites = {
    hit = sprite.new("lj26b:characters/dummy/Hit_Side"),
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

local wolf = character.new({
  shape = require("libs.slick").newCircleShape(0, 0, .35),
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
    walkSpeed = 3.0,
  },
})

wolf.takeHit = function(self, damage)
  getmetatable(wolf).takeHit(self, damage)
  self:changeState(self.states.stagger)
end

return wolf