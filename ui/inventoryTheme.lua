local lg = love.graphics

local assetManager = require("src.core.assetManager")
local windowManager = require("src.core.windowManager")
local graphicsManager = require("src.core.graphicsManager")
local sprite = require("src.core.graphicsManager.sprite")

local inventory = require("lj26b:inventory")

local fontKey = "lj26b:fonts/Comic_Neue/ComicNeue-Regular"
local fontKeyBold = "lj26b:fonts/Comic_Neue/ComicNeue-Bold"

local cellSize = 48

local equipmentHand = sprite.new("lj26b:ui/hand")
local equipmentJam = sprite.new("lj26b:ui/jam")
local equipmentTrash = sprite.new("lj26b:ui/trash")

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

local updateScrollPhysics = function(node, dt)
  if not node.state.scrollable then return end
  if not node.w or not node.h or not node.contentH then return end

  node.state.scrollY = node.state.scrollY or 0
  if node.h > node.contentH then
    node.state.scrollY = 0
    return
  end

  local innerH = node.h
  local maxScroll = math.max(0, (node.contentH or 0) - innerH)

  if not node.state.isDragging then
    if node.state.scrollY < 0 then
      node.state.scrollY = node.state.scrollY + (0 - node.state.scrollY) * math.min(1, dt * 15)
    elseif node.state.scrollY > maxScroll then
      node.state.scrollY = node.state.scrollY + (maxScroll - node.state.scrollY) * math.min(1, dt * 15)
    end
  end
end

local drawThumb = function(node)
  if not node.state.scrollable then return end
  if not node.w or not node.h then return end
  if node.h >= (node.contentH or 0) then return end

  local scale = windowManager.scale
  local padX, padY = -4 * scale, 2 * scale -- Note future me, negative pad could lead to drawing outside of bounds. So, just give the scrollable's parent padding
  local width = 3.5 * scale

  local innerH = node.h
  local contentH = node.contentH
  local trackH = innerH - (padY * 2)

  local ratio = innerH / contentH
  local baseThumbH = math.max(16 * scale, trackH * ratio)

  local maxScroll = math.max(0, contentH - innerH)
  local scrollY = node.state.scrollY or 0

  local thumbH = baseThumbH
  local thumbX = node.x + node.w - padX - width
  local thumbY = node.y + padY

  if scrollY < 0 then
    local overScroll = -scrollY
    local squish = math.min(baseThumbH * 0.6, overScroll * 0.4)
    thumbH = math.max(6 * scale, baseThumbH - squish)
  elseif scrollY > maxScroll then
    local overScroll = scrollY - maxScroll
    local squish = math.min(baseThumbH * 0.6, overScroll * 0.4)
    thumbH = math.max(6 * scale, baseThumbH - squish)
    thumbY = thumbY + trackH - thumbH
  else
    local maxTravel = trackH - baseThumbH
    local scrollFriction = maxScroll > 0 and scrollY / maxScroll or 0
    thumbY = thumbY + (scrollFriction * maxTravel)
  end

  lg.push("all")

  -- track
  lg.setColor(.6,.6,.6, node.state.isHovered and .4 or .2)
  lg.rectangle("fill", thumbX, node.y + padY, width, trackH, width / 2)

  -- thumb
  lg.setColor(.8,.8,.8, node.state.isHovered and .6 or .5)
  lg.rectangle("fill", thumbX, thumbY, width, thumbH, width / 2)

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
    stencil = {
      update = function(node, dt)
        updateScrollPhysics(node, dt)
      end,
      draw = function(node)
        lg.push("all")
        graphicsManager.incrementStencilDepth()
        lg.setStencilState("increment", "always")

        graphicsManager.setColorMaskRGBA(false)
        lg.rectangle("fill", node.x, node.y, node.w, node.h)
        graphicsManager.setColorMaskRGBA(true)

        lg.push("all")
        lg.setStencilState("keep", "gequal", graphicsManager.stencilDepth)
      end,
      drawAfterChildren = function(node)
        lg.pop()

        graphicsManager.decrementStencilDepth()
        lg.setStencilState("decrement", "always")

        graphicsManager.setColorMaskRGBA(false)
        lg.rectangle("fill", node.x, node.y, node.w, node.h)
        graphicsManager.setColorMaskRGBA(true)

        lg.pop()

        drawThumb(node)
      end,
    },
    displayCell = {
      measure = function(node)
        local scale = windowManager.scale
        return cellSize * scale, cellSize * scale
      end,
      draw = function(node, scene)
        local scale = windowManager.scale
        local lineWidth = math.floor(1 * scale)

        lg.push("all")
        lg.setColor(.1,.3,.4,.4)
        if scene._heldNode then
          lg.setColor(.05,.2,.3,.5)
          if node.state.isHovered then
            lg.setColor(.3,.1,.1,.75)
          end
        end
        lg.rectangle("fill", node.x, node.y, node.w, node.h, 3 * scale)

        lg.setColor(.4, .6, .7, 1)
        lg.setLineWidth(lineWidth)
        lg.rectangle("line", node.x, node.y, node.w, node.h, 3 * scale)

        if node.state.item then
          local item = node.state.item
          local count = node.state.itemCount or 1
          if item.sprite then
            local sprite = item.sprite
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
                lg.setColor(1,1,1,1)
                if node.state.isMissing then
                  lg.setColor(0, 0, 0, .4 * (type(node.state.isMissing) == "number" and node.state.isMissing or 1))
                end
                lg.draw(texture, quad, drawX, drawY, 0, spriteScale, spriteScale)
                if count > 1 then
                  lg.setColor(1,1,1,1)
                  local font = assetManager.getFont(fontKeyBold, 12 * scale)
                  local text = tostring(count)
                  lg.print(text, font, drawX, drawY)
                end
              end
            end
          end
        end
        lg.pop()
      end,
    }
  },
  label = {
    button = {
      measure = function(node)
        local scale = windowManager.scale
        local font = assetManager.getFont(fontKey, 14 * scale)
        local text = node.state.text or "unknown"

        local w = font:getWidth(text) + 10 * scale
        local h = font:getHeight() + 2 * scale
        return w, h
      end,
      draw = function(node)
        local scale = windowManager.scale

        local scale = windowManager.scale
        local font = assetManager.getFont(fontKey, 14 * scale)
        local text = node.state.text or "unknown"

        lg.push("all")
        lg.translate(node.x, node.y)

        lg.setColor(.2,.4,.5,1)
        if node.state.color then
          lg.setColor(node.state.color)
        end
        lg.rectangle("fill", 0, 0, node.w, node.h, 3 * scale)

        lg.setColor(1, 1,1, 1)
        lg.print(text, font, (node.w-font:getWidth(text)) / 2, (node.h-font:getHeight())/2)

        lg.pop()
      end,
    },
    inventory = {
      measure = function(node)
        local scale = windowManager.scale
        local fontSize = (node.state.fontSize or 23) * scale
        local key = node.state.bold and fontKeyBold or fontKey
        local font = assetManager.getFont(key, fontSize)
        local text = node.state.text or ""

        if not font or not text or text == "" then return 0, 0 end
        if not node.state.wrap or not node.lastW then
          return font:getWidth(text), font:getHeight()
        else
          local width, wrappedText = font:getWrap(text, node.lastW + 10 * scale)
          return width, #wrappedText * (font:getHeight() + font:getLineHeight())
        end
      end,
      draw = function(node)
        local scale = windowManager.scale
        local fontSize = (node.state.fontSize or 23) * scale
        local key = node.state.bold and fontKeyBold or fontKey
        local font = assetManager.getFont(key, fontSize)
        local text = node.state.text or ""

        if not font or not text or text == "" then return end

        lg.push("all")
        lg.translate(node.x + node.w / 2, node.y + node.h / 2)
        lg.setColor(1,1,1,1)
        if node.state.color then
          lg.setColor(node.state.color)
        end
        if node.state.wrap then
          local _, wrappedText = font:getWrap(text, node.w)
          for i, line in ipairs(wrappedText) do
            lg.print(line, font, -font:getWidth(line)/2, (i - 1) * (font:getHeight() + font:getLineHeight()) - node.h / 2)
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
        if node.state.equipment == "trash" then
          slot = inventory.trash
        end

        if slot then
          local sprite
          if slot.item then
            sprite = slot.item.sprite
          else
            if node.state.equipment == "hand" then
              sprite = equipmentHand
            elseif node.state.equipment == "trash" then
              sprite = equipmentTrash
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
        if node.state.equipment == "trash" then
          slot = inventory.trash
        end
        if not slot or not slot.item then return end
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
  },
  recipe = {
    default = {
      draw = function(node)
        local scale = windowManager.scale
        local lineWidth = math.floor(1 * scale)

        lg.push("all")
        lg.setColor(.2,.4,.5,1)
        if node.state.active == false then
          lg.setColor(.1,.2,.3,1)
        elseif node.state.isHovered then
          lg.setColor(.4, .6, .8, 1)
        end
        lg.setLineWidth(lineWidth)
        lg.rectangle("line", node.x, node.y, node.w, node.h, 3 * scale)
        lg.pop()
      end
    },
  }
}

return theme