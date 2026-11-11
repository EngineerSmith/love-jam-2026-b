
local levelManager = require("s3d:levelManager")

local cookingPot = {
  bubbleTimer = 0,
  openTimer = 0,
  timeToOpen = 1.5,
  jumpTimer = 0,
  timeToJump = 0.75,
  spawnPoint = { 0, 0, 1, 0, 0, 0 },
}

cookingPot.isBusy = function()
  return cookingPot.outcome ~= nil or cookingPot.item ~= nil
end

cookingPot.setSpawnPoint = function(...)
  if select('#', ...) ~= 6 then error() end
  cookingPot.spawnPoint = { ... }
end

cookingPot.cook = function(outcome, stats)
  cookingPot.outcome = outcome
  cookingPot.outcomeStats = stats
  cookingPot.bubbleTimer = 7
end

cookingPot.update = function(dt)
  if cookingPot.bubbleTimer > 0 then
    cookingPot.bubbleTimer = cookingPot.bubbleTimer - dt
    if cookingPot.bubbleTimer <= 0 then
      cookingPot.bubbleTimer = 0
      cookingPot.openTimer = cookingPot.timeToOpen
    end
  elseif cookingPot.openTimer > 0 then
    cookingPot.openTimer = cookingPot.openTimer - dt
    if cookingPot.outcome and cookingPot.openTimer <= cookingPot.timeToOpen * .4 then
      local level = levelManager.getActiveLevel()
      cookingPot.item = cookingPot.outcome:spawn(level, {unpack(cookingPot.spawnPoint, 1, 3)}, {
        freezeTime = cookingPot.timeToJump + 0.2, -- prevents pickup for n seconds
        isJumping = true,
        stats = cookingPot.outcomeStats,
      })
      cookingPot.jumpTimer = cookingPot.timeToJump
      cookingPot.openTimer =  cookingPot.openTimer * .3
      cookingPot.outcome = nil
      cookingPot.outcomeStats = nil
    elseif cookingPot.openTimer <= 0 then
      cookingPot.openTimer = 0
    end
  end

  if cookingPot.jumpTimer > 0 then
    cookingPot.jumpTimer = cookingPot.jumpTimer - dt
    local progress = 1 - (cookingPot.jumpTimer / cookingPot.timeToJump)
    progress = math.min(1, math.max(0, progress)) -- prevent weird frame glitches at end and start

    local ease = 1 - (1 - progress) * (1 - progress)
    local startX, startY, startZ = unpack(cookingPot.spawnPoint, 1, 3)
    local targetX, targetY, targetZ = unpack(cookingPot.spawnPoint, 4, 6)

    local currentX = startX + (targetX - startX) * ease
    local currentY = startY + (targetY - startY) * ease

    local peakZ = 1.7
    local linearZ = startZ + (targetZ - startZ) * progress
    local linearMidZ = startZ + (targetZ - startZ) * 0.5
    local heightAbove = peakZ - linearMidZ
    local currentZ = linearZ + math.sin(progress * math.pi) * heightAbove

    cookingPot.item.transform:set(currentX, currentY, currentZ)
    if cookingPot.jumpTimer <= 0 then
      cookingPot.jumpTimer = 0
      cookingPot.item.isJumping = false
      cookingPot.item = nil
    end
  else
    cookingPot.jumpTimer = 0
  end
end


return cookingPot