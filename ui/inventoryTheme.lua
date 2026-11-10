local lg = love.graphics

local assetManager = require("src.core.assetManager")
local windowManager = require("src.core.windowManager")
local sprite = require("src.core.graphicsManager.sprite")

local inventory = require("lj26b:inventory")

local fontKey = "lj26b:fonts/Comic_Neue/ComicNeue-Regular"
local fontKeyBold = "lj26b:fonts/Comic_Neue/ComicNeue-Bold"

local cellSize = 48

local equipmentHand = sprite.new("lj26b:ui/hand")
local equipmentJam = sprite.new("lj26b:ui/jam")

local attributeMap = {
  ["walkSpeed"] = "Move Speed",
  ["crawlSpeed"] = "Crawl Speed",
  ["dodgeSpeed"] = "Dodge Speed",
  ["dodgeDuration"] = "Dodge Duration",
  ["dodgeCooldown"] = "Dodge Cooldown",
  ["attackSpeed"] = "Attack Speed",
  ["attackDuration"] = "Attack Duration",
  ["maxStamina"] = "Max Stamina",
  ["staminaRegenRate"] = "Stamina Regen Rate",
  ["dodgeStaminaCost"] = "Dodge Stamina Cost",
  ["dodgeStaminaDelay"] = "Dodge Stamina Delay",
  ["attackStaminaCost"] = "Attack Stamina Cost",
  ["attackStaminaDelay"] = "Attack Stamina Delay",
  ["maxHealth"] = "Max Health",
  ["baseDamage"] = "Damage",
}

local drawTooltip = function(item)
  local scale = windowManager.scale
  local fontTitle = assetManager.getFont(fontKeyBold, 14 * scale)
  local fontBody = assetManager.getFont(fontKey, 12 * scale)
  local fontType = assetManager.getFont(fontKeyBold, 12 * scale)

  if not fontTitle or not fontBody or not fontType then return end

  local padding = 8 * scale
  local maxTextWidth = 180 * scale

  local titleText = item.name or "Unknown Item"
  local titleWidth = fontTitle:getWidth(titleText)

  local descLines = { }
  if item.tooltip and item.tooltip ~= "" then
    _, descLines = fontBody:getWrap(item.tooltip, maxTextWidth)
  end

  local statLines = { }
  if item.stats then
    for stateName, value in pairs(item.stats) do
      local judgeValue = value
      if stateName:lower():match("cost") then judgeValue = judgeValue * -1 end
      local sign = value >= 0 and "+" or ""
      table.insert(statLines, {
        text = ("%s%s %s"):format(sign, tostring(value), attributeMap[stateName] or stateName:sub(1,1):upper() .. stateName:sub(2)),
        positive = judgeValue >= 0,
      })
    end
  end

  local lineHeightTitle = fontTitle:getHeight() + fontTitle:getLineHeight()
  local lineHeightBody = fontBody:getHeight() + fontBody:getLineHeight()
  local lineHeightType = fontType:getHeight() + fontType:getLineHeight()

  local totalH = padding * 2 + lineHeightTitle
  local maxW = math.max(titleWidth, 120 * scale)

  if #descLines > 0 then
    totalH = totalH + 4 * scale
    totalH = totalH + #descLines * lineHeightBody
    for _, line in ipairs(descLines) do
      maxW = math.max(maxW, fontBody:getWidth(line))
    end
  end

  if #statLines > 0 then
    totalH = totalH + 6 * scale
    totalH = totalH + #statLines * lineHeightBody
    for _, stat in ipairs(statLines) do
      maxW = math.max(maxW, fontBody:getWidth(stat.text))
    end
  end

  if item.itemType then
    totalH = totalH + 4 * scale
    totalH = totalH + 1 * lineHeightType
  end

  local boxW = maxW + padding * 2
  local boxH = totalH

  local mx, my = love.mouse.getPosition()
  local screenW, screenH = lg.getDimensions()

  local drawX, drawY = mx + 15 * scale, my + 15 * scale
  if drawX + boxW > screenW then
    drawX = mx - boxW - 15 * scale
  end
  if drawY + boxH > screenH then
    drawY = my - boxH - 15 * scale
  end

  lg.push("all")
  lg.reset()
  lg.translate(drawX, drawY)

  lg.setColor(.1, .25, .3, 1)
  lg.rectangle("fill", 0, 0, boxW, boxH, 3 * scale)

  lg.push()
  lg.translate(padding, padding)
  lg.setColor(1,1,1,1)
  lg.print(titleText, fontTitle, 0, 0)
  lg.translate(0, lineHeightTitle)

  if #descLines > 0 then
    lg.translate(0, 4 * scale)
    lg.setColor(.6, .6, .7, 1)
    for _, line in ipairs(descLines) do
      lg.print(line, fontBody, 0, 0)
      lg.translate(0, lineHeightBody)
    end
  end

  if #statLines > 0 then
    lg.translate(0, 6 * scale)
    for _, stat in ipairs(statLines) do
      if stat.positive then
        lg.setColor(.4, 1, .4, 1)
      else
        lg.setColor(1, .4, .4, 1)
      end
      lg.print(stat.text, fontBody, 0, 0)
      lg.translate(0, lineHeightBody)
    end
  end

  if item.itemType then
    lg.translate(0, 4 * scale)
    lg.setColor(0.01, 0.02, .2, 1)
    lg.print(item.itemType:sub(1,1):upper() .. item.itemType:sub(2), fontType, 0, 0)
    lg.translate(0, lineHeightType)
  end

  lg.pop()

  lg.setColor(.3, .5, 6, 1)
  lg.setLineWidth(1 * scale)
  lg.rectangle("line", 0, 0, boxW, boxH, 3 * scale)

  lg.pop()
end

local theme = {
  container = {
    inventory_window = {
      draw = function(node)
        local scale = windowManager.scale
        local lineWidth = math.floor(1 * scale)
        local lineWidth2 = lineWidth * 2

        local height = node.state.drawChildren  == false and node.h * node.state.progress or node.h
        local drawY = node.y + (node.h - height) * 0.5

        lg.push("all")
        lg.setColor(.3,.4,.5,.4)
        lg.rectangle("fill", node.x - lineWidth, drawY - lineWidth, node.w + lineWidth * 2, height + lineWidth * 2, 3 * scale)

        lg.setColor(.4, .6, .7)
        lg.setLineWidth(lineWidth)
        lg.rectangle("line", node.x - lineWidth2 * 2, drawY - lineWidth2 * 2, node.w + lineWidth2 * 4, height + lineWidth2 * 4, 5 * scale)
        lg.setLineWidth(lineWidth2)
        lg.rectangle("line", node.x, drawY, node.w, height, 3 * scale)
        lg.pop()
      end,
    },
  },
  label = {
    inventory = {
      measure = function(node)
        local scale = windowManager.scale
        local fontSize = 23 * scale
        local font = assetManager.getFont(fontKey, fontSize)
        local text = node.state.text or ""

        if not font then return 0, 0 end
        if not node.state.wrap or not node.lastW then
          return font:getWidth(text), font:getHeight()
        else
          local width, wrappedText = font:getWrap(text, node.lastW)
          return width, #wrappedText * (font:getHeight() + font:getLineHeight())
        end
      end,
      draw = function(node)
        local scale = windowManager.scale
        local fontSize = 23 * scale
        local font = assetManager.getFont(fontKey, fontSize)
        local text = node.state.text or ""

        if not font then return end

        lg.push("all")
        lg.translate(node.x + node.w / 2, node.y + node.h / 2)
        lg.setColor(1,1,1,1)
        if node.state.wrap then
          local _, wrappedText = font:getWrap(text, node.w)
          for i, text in ipairs(wrappedText) do
            lg.print(text, font, -node.w /2 , (i - 1) * (font:getHeight() + font:getLineHeight()) - node.h / 2)
          end
        else
          lg.print(text, font, -font:getWidth(text)/2, -font:getHeight()/2)
        end
        lg.pop()
      end,
    }
  },
  cell = {
    default = {
      measure = function(node)
        local scale = windowManager.scale
        return cellSize * scale, cellSize * scale
      end,
      draw = function(node)
        local scale = windowManager.scale
        local lineWidth = math.floor(1 * scale)

        lg.push("all")
        lg.setColor(.1,.3,.4,.4)
        if node.state.isHeld then
          lg.setColor(.2, .4, .5, 1)
        elseif node.state.isHovered then
          lg.setColor(.25, .45, .55, .4)
        end
        lg.rectangle("fill", node.x, node.y, node.w, node.h, 3 * scale)

        lg.setColor(.4, .6, .7, 1)
        lg.setLineWidth(lineWidth)
        lg.rectangle("line", node.x, node.y, node.w, node.h, 3 * scale)

        local slot = inventory.slots.items[node.state.slotIndex]
        if slot and slot.item and slot.count >= 1 and slot.item.sprite then
          local sprite = slot.item.sprite
          local texture, quad = sprite:get()
          if texture and quad then
            local w, h = sprite:getDimensions() -- scale
            if w > 0 and h > 0 then
              local padding = 6 * scale
              local maxW = node.w - (padding * 2)
              local maxH = node.h - (padding * 2)
              local spriteScale = math.min(maxW / w, maxH / h)
              local scaledW = w * spriteScale
              local scaledH = h * spriteScale
              local drawX = node.x + (node.w - scaledW) / 2
              local drawY = node.y + (node.h - scaledH) / 2
              if not node.state.isHeld then
                lg.setColor(sprite:getColor())
                lg.draw(texture, quad, drawX, drawY, 0, spriteScale, spriteScale)
                if slot.count > 1 then
                  lg.setColor(1,1,1,1)
                  local font = assetManager.getFont(fontKeyBold, 12 * scale)
                  local text = tostring(slot.count)
                  lg.print(text, font, drawX, drawY)
                end
              end
            end
          end
        end
        lg.pop()
      end,
      drawAfterEverything = function(node)
        local slot = inventory.slots.items[node.state.slotIndex]
        if not slot or not slot.item and slot.count >= 1 then return end
        if not node.state.isHeld then
          if node.state.isHovered and slot.item then
            drawTooltip(slot.item)
          end
          return
        end
        if not slot.item.sprite then return end
        local scale = windowManager.scale
        lg.push("all")
        local sprite = slot.item.sprite
        local texture, quad = sprite:get()
        if texture and quad then
          local w, h = sprite:getDimensions()
          if w > 0 and h > 0 then
            local padding = 6 * scale
            local maxW = node.w - (padding * 2)
            local maxH = node.h - (padding * 2)
            local spriteScale = math.min(maxW / w, maxH / h)
            local scaledW = w * spriteScale
            local scaledH = h * spriteScale
            local mx, my = love.mouse.getPosition()
            local drawX = mx - scaledW / 2
            local drawY = my - scaledH / 2
            lg.setColor(sprite:getColor())
            lg.draw(texture, quad, drawX, drawY, 0, spriteScale, spriteScale)
            if slot.count > 1 then
              lg.setColor(1,1,1,1)
              local font = assetManager.getFont(fontKeyBold, 12 * scale)
              local text = tostring(slot.count)
              lg.print(text, font, drawX, drawY)
            end
          end
        end
        lg.pop()
      end
    },
    equipment = {
      measure = function(node)
        local scale = windowManager.scale
        return cellSize * scale, cellSize * scale
      end,
      draw = function(node)
        local scale = windowManager.scale
        local lineWidth = math.floor(1 * scale)

        lg.push("all")
        lg.setColor(.1,.3,.4,.4)
        if node.state.isHeld then
          lg.setColor(.2, .4, .5, 1)
        elseif node.state.isHovered then
          lg.setColor(.25, .45, .55, .4)
        end
        lg.rectangle("fill", node.x, node.y, node.w, node.h, 3 * scale)

        lg.setColor(.4, .6, .7, 1)
        lg.setLineWidth(lineWidth)
        lg.rectangle("line", node.x, node.y, node.w, node.h, 3 * scale)

        local slot = inventory.slots.equipment[node.state.equipment]

        if slot then
          local sprite
          if slot.item then
            sprite = slot.item.sprite
          else
            if node.state.equipment == "hand" then
              sprite = equipmentHand
            elseif node.state.equipment:match("^jam") then
              sprite = equipmentJam
            end
          end
          if sprite then
            local texture, quad = sprite:get()
            if texture and quad then
              local w, h = sprite:getDimensions()
              if w > 0 and h > 0 then
                local padding = 6 * scale
                local maxW = node.w - (padding * 2)
                local maxH = node.h - (padding * 2)
                local spriteScale = math.min(maxW / w, maxH / h)
                local scaledW = w * spriteScale
                local scaledH = h * spriteScale
                local drawX = node.x + (node.w - scaledW) / 2
                local drawY = node.y + (node.h - scaledH) / 2
                if not node.state.isHeld then
                  local r, g, b = sprite:getColor()
                  lg.setColor(r, g, b, slot.item and sprite == slot.item.sprite and 1 or .6)
                  lg.draw(texture, quad, drawX, drawY, 0, spriteScale, spriteScale)
                end
              end
            end
          end
        end
        lg.pop()
      end,
      drawAfterEverything = function(node)
        local slot = inventory.slots.equipment[node.state.equipment]
        if not slot and not slot.item then return end
        if not node.state.isHeld then
          if node.state.isHovered and slot.item then
            drawTooltip(slot.item)
          end
          return
        end
        if not slot.item.sprite then return end
        local scale = windowManager.scale
        lg.push("all")
        local sprite = slot.item.sprite
        local texture, quad = sprite:get()
        if texture and quad then
          local w, h = sprite:getDimensions()
          if w > 0 and h > 0 then
            local padding = 6 * scale
            local maxW = node.w - (padding * 2)
            local maxH = node.h - (padding * 2)
            local spriteScale = math.min(maxW / w, maxH / h)
            local scaledW = w * spriteScale
            local scaledH = h * spriteScale
            local mx, my = love.mouse.getPosition()
            local drawX = mx - scaledW / 2
            local drawY = my - scaledH / 2
            lg.setColor(sprite:getColor())
            lg.draw(texture, quad, drawX, drawY, 0, spriteScale, spriteScale)
          end
        end
        lg.pop()
      end
    },
  }
}

return theme