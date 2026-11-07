local lg = love.graphics

local hook = require("src.core.hook")
local assetManager = require("src.core.assetManager")
local windowManager = require("src.core.windowManager")

local camera = require("s3d:camera")

local manager = {
  numbers = { },
}

local _white = { 1, 1, 1, 1 }
manager.spawn = function(worldX, worldY, worldZ, amount, isCrit)
  table.insert(manager.numbers, {
    x = worldX,
    y = worldY,
    z = worldZ,
    text = tostring(amount),
    timer = 0.6,
    maxTimer = 0.6,
    color = isCrit and { 1, .8, .2, 1 } or _white,
    scale = isCrit and 1.3 or 1.0,
  })
end

manager.update = function(dt)
  for i = #manager.numbers, 1, -1 do
    local n = manager.numbers[i]
    n.timer = n.timer - dt
    n.z = n.z + dt * 0.8
    if n.timer <= 0 then
      table.remove(manager.numbers, i)
    end
  end
end
hook.add("engine:update", "lj26b:damageNumbers", manager.update, nil, { scene = "game" })

manager.draw = function()
  for _, n in ipairs(manager.numbers) do
    local screenX, screenY = camera.current:project(n.x, n.y, n.z)
    if screenX and screenY then
      local alpha = n.timer / n.maxTimer
      lg.setColor(n.color[1], n.color[2], n.color[3], alpha)

      -- TODO [scope questionable] Two tone font (assetManager doesn't support image fonts right now)
      local font = assetManager.getFont("menu:fonts/RobotoMono-Medium", 10 * windowManager.scale * n.scale)
      lg.print(n.text, font, screenX - font:getWidth(n.text) / 2, screenY)
    end
  end
end
hook.add("engine:draw", "lj26b:damageNumbers", manager.draw, nil, { scene = "game" })

return manager