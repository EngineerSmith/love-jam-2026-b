local lg = love.graphics

local vornmath = require("libs.vornmath")
local slick = require("libs.slick")

local hook = require("src.core.hook")
local graphicsManager = require("src.core.graphicsManager")
local sprite = require("src.core.graphicsManager.sprite")

local gm = graphicsManager

local transform = require("s3d:transform")
local characterPlane = require("s3d:characterPlane")
local camera = require("s3d:camera")

local normalize
do
  local temp = vornmath.vec2()
  normalize = function(x, y)
    temp = vornmath.fill(temp, x, y)
    temp = vornmath.normalize(temp, temp)
    return temp[1], temp[2]
  end
end

local controller = require(":player.controls")

local player = {
  transform = transform.new(),
  levelInfo = { },
  facing = { 0, 1 },
  attributes = {
    walkSpeed = 3,
    dodgeSpeed = 6,
    dodgeDuration = 0.4,
    dodgeCooldown = 0.5,
    attackSpeed = 1,
    attackDuration = 0.4,
    -- Stamina
    maxStamina = 100,
    staminaRegenRate= 45,
    dodgeStaminaCost = 30,
    dodgeStaminaDelay = 0.6,
    attackStaminaCost = 15,
    attackStaminaDelay = 0.4,

  },
  equipment = {
    hand = nil,
  },
  _lastFacingSign = 1,
  _stamina = 0,
  _staminaRegenDelay = .3,
}

---

player.changeState = function(newState)
  if player.currentState and player.currentState.exit then
    player.currentState:exit()
  end
  player.currentState = newState
  if player.currentState and player.currentState.enter then
    player.currentState:enter()
  end
end

local getMovementInput = function()
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

local states = { }

states.move = {
  sprites = {
    move = sprite.new("lj26b:characters/player/Walk_Side"),
    idle = sprite.new("lj26b:characters/player/Idle_Side"),
    idleFidget = sprite.new("lj26b:characters/player/Idle_Fidget_Side"),
  },
  onIdleFinish = function()
    local state = states.move
    state.sprite:seek(1)
    if state.sprite ~= state.sprites.idleFidget and love.math.random() <= 0.05 then
      state.sprite = state.sprites.idleFidget:start(state.onIdleFinish)
    else
      state.sprite = state.sprites.idle:start(state.onIdleFinish)
    end
  end,
  enter = function(state)
    local dx, dy = controller:get("move")
    if dx == 0 and dy == 0 then
      state.motion = "idle"
      state.sprite = state.sprites.idle:start(state.onIdleFinish)
    else
      state.motion = "moving"
      state.sprite = state.sprites.move:start()
    end
  end,
  exit = function(state)
    for _, sprite in pairs(state.sprites) do
      sprite:stop(true):seek(1) -- stop and reset
    end
    state.sprite = nil
  end,
  update = function(state, dt)
    if controller:pressed("dodge") then
      if player._stamina >= player.attributes.dodgeStaminaCost then
        player.changeState(states.dodge)
        return
      else
        -- todo bad noise
      end
    end
    if controller:pressed("attack") then
      if player._stamina >= player.attributes.attackStaminaCost then
        player.changeState(states.attack)
        return
      else
        -- todo bad noise
      end
    end

    local dx, dy = getMovementInput()
    local isMoving = dx ~= 0 or dy ~= 0

    if isMoving then
      local dirX, dirY = normalize(dx, dy)
      player.facing[1], player.facing[2] = dirX, dirY

      if state.motion ~= "moving" then
        state.motion = "moving"
        state.sprite:stop(true):seek(1)
        state.sprite = state.sprites.move:start()
      end

      local goalX = player.transform.position[1] + dirX * player.attributes.walkSpeed * dt
      local goalY = player.transform.position[2] + dirY * player.attributes.walkSpeed * dt

      if player.levelInfo.world then
        local actualX, actualY = player.levelInfo.world:update(player, goalX, goalY)
        player.transform:set(actualX, actualY, player.transform.position[3])
      end
    else
      if state.motion == "moving" then
        state.motion = "idle"
        state.sprite:stop(true):seek(1)
        state.sprite = state.sprites.idle:start(state.onIdleFinish)
      end
    end
  end,
}

states.dodge = {
  sprites = {
    dodge = sprite.new("lj26b:characters/player/Dodge_Side"),
    dodgeCharge = sprite.new("lj26b:characters/player/Dodge_Charge_Side"),
  },
  onChargeFinish = function()
    local state = states.dodge
    if state.sprite.isPlaying then state.sprite:stop(true) end
    state.sprite:seek(1)
    state.motion = "dodging"
    state.sprite = state.sprites.dodge:start() -- loops
  end,
  enter = function(state)
    state.dodgeTimer = player.attributes.dodgeDuration
    state.elapsed = 0

    player._stamina = player._stamina - player.attributes.dodgeStaminaCost
    player._staminaRegenDelay = player.attributes.dodgeStaminaDelay

    local dx, dy = getMovementInput()
    if dx == 0 and dy == 0 then
      state.dodgeDirection = player.facing
    else
      state.dodgeDirection = { normalize(dx, dy) }
      player.facing[1], player.facing[2] = state.dodgeDirection[1], state.dodgeDirection[2]
    end
    state.motion = "charging"

    local chargeSprite = state.sprites.dodgeCharge
    if chargeSprite.frameDuration ~= 0 and chargeSprite.frames then
      local chargeNativeDuration = chargeSprite.frameDuration * #chargeSprite.frames
      local targetChargeDuration = player.attributes.dodgeDuration * 0.35
      if chargeNativeDuration >0 and targetChargeDuration > 0 then
        chargeSprite.timeScale = chargeNativeDuration / targetChargeDuration
      end
    end

    state.sprite = chargeSprite:start(state.onChargeFinish)
  end,
  exit = function(state)
    for _, sprite in pairs(state.sprites) do
      sprite:stop(true):seek(1) -- stop and reset
    end
    state.sprite = nil
  end,
  update = function(state, dt)
    state.dodgeTimer = state.dodgeTimer - dt
    state.elapsed = state.elapsed + dt

    if state.dodgeTimer <= 0 then
      player.changeState(states.move)
      return
    end

    if state.motion == "charging" and state.elapsed >= player.attributes.dodgeDuration * 0.35 then
      state.onChargeFinish()
    end

    local goalX = player.transform.position[1] + state.dodgeDirection[1] * player.attributes.dodgeSpeed * dt
    local goalY = player.transform.position[2] + state.dodgeDirection[2] * player.attributes.dodgeSpeed * dt

    if player.levelInfo.world then
      local actualX, actualY = player.levelInfo.world:update(player, goalX, goalY)
      player.transform:set(actualX, actualY, player.transform.position[3])
    end
  end,
}

states.attack = {
  sprites = {
    attack = sprite.new("engine:textures/lava_still"),
  },
  enter = function(state)
    state.attackTimer = player.attributes.attackDuration

    player._stamina = player._stamina - player.attributes.attackStaminaCost
    player._staminaRegenDelay = player.attributes.attackStaminaDelay

    local dx, dy = getMovementInput()
    if dx == 0 and dy == 0 then
      state.attackDirection = { player.facing[1],  player.facing[2] }
    else
      state.attackDirection = { normalize(dx, dy) }
      player.facing[1], player.facing[2] = state.attackDirection[1], state.attackDirection[2]
    end

    state.motion = "attacking"
    state.sprite = state.sprites.attack:start()
    if state.sprite.frameDuration ~= 0 and state.sprite.frames then
      state.sprite.timeScale = (state.sprite.frameDuration * #state.sprite.frames) / player.attributes.attackDuration
    end
  end,
  exit = function(state)
    for _, sprite in pairs(state.sprites) do
      sprite:stop(true):seek(1) -- stop and reset
    end
    state.sprite = nil
  end,
  update = function(state, dt)
    state.attackTimer = state.attackTimer - dt
    if state.attackTimer <= 0 then
      player.changeState(states.move)
      return
    end

    local goalX = player.transform.position[1] + state.attackDirection[1] * player.attributes.attackSpeed * dt
    local goalY = player.transform.position[2] + state.attackDirection[2] * player.attributes.attackSpeed * dt

    if player.levelInfo.world then
      local actualX, actualY = player.levelInfo.world:update(player, goalX, goalY)
      player.transform:set(actualX, actualY, player.transform.position[3])
    end
  end,
}

---

player.addToLevel = function(level, position)
  if type(position) == "table" then
    player.transform:set(unpack(position))
  end
  -- Add physics body
  level.world:add(player, player.transform.position[1], player.transform.position[2], slick.newCircleShape(0, 0, .25))
  player.levelInfo.world = level.world
  player.changeState(states.move)
end

player.removeFromLevel = function(level)
  level.world:remove(player)
end

player.update = function(dt)
  if player._staminaRegenDelay > 0 then
    player._staminaRegenDelay = player._staminaRegenDelay - dt
  else
    if player._stamina < player.attributes.maxStamina then
      player._stamina = math.min(player.attributes.maxStamina, player._stamina + player.attributes.staminaRegenRate * dt)
    end
  end

  if player.currentState and player.currentState.update then
    player.currentState:update(dt)
  end
end

local getCharacterPlaneDirection = function()
  local pp = player.transform.position
  local ce = camera.current.eye
  local toCamX = ce[1] - pp[1]
  local toCamY = ce[2] - pp[2]

  local _, _, camRightX, camRightY = camera.current:getHorizontalAxes()
  local screenFacing = player.facing[1] * camRightX + player.facing[2] * camRightY
  
  if math.abs(screenFacing) > 1e-2 then
    player._lastFacingSign = screenFacing > 0 and 1 or -1
  end

  if math.abs(toCamX) >= math.abs(toCamY) then
    return player._lastFacingSign > 0 and "x-" or "x+"
  else
    return player._lastFacingSign > 0 and "y+" or "y-"
  end
end

local shaderKey = "s3d:characterPlane"
graphicsManager.loadShader(shaderKey)
player.draw = function()
  local shader = gm.getShader(shaderKey)
  if not shader then return end
  local state = player.currentState
  if not state or not state.sprite then return end
  local texture, quad = state.sprite:get()
  if not texture or not quad then return end
  lg.push("all")
  lg.setDepthMode("lequal", true)
  lg.setMeshCullMode("none")
  gm.setUniform(shader, "u_ModelMatrix", player.transform:getMatrix())
  camera.setUniforms(shader)
  characterPlane.drawQuad(texture, quad, shader, getCharacterPlaneDirection())
  lg.pop()
  lg.draw(texture, quad, 0, 0, 0, 5)
end

return player