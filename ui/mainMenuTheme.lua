local lg = love.graphics

local flux = require("libs.flux")

local assetManager = require("src.core.assetManager")
local audioManager = require("src.core.audioManager")
local windowManager = require("src.core.windowManager")
local graphicsManager = require("src.core.graphicsManager")

local fontKey = "lj26b:fonts/Comic_Neue/ComicNeue-Regular"
local fontKeyBold = "lj26b:fonts/Comic_Neue/ComicNeue-Bold"

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
  button = {
    default = {
      onInteract = function(_, interaction)
        if interaction == "onEnter" then
          audioManager.play("menu:audio/ui/hover")
        elseif interaction == "onPressed" then
          audioManager.play("menu:audio/ui/switch")
        end
      end,
      measure = function(node)
        local scale = windowManager.scale
        local font = assetManager.getFont(fontKey, 18 * scale)
        local text = node.state.text or "unknown"

        local w = font:getWidth(text) + 10 * scale
        local h = font:getHeight() + 2 * scale
        return w, h
      end,
      draw = function(node)
        local scale = windowManager.scale
        local font = assetManager.getFont(fontKey, 18 * scale)
        local text = node.state.text or "unknown"

        lg.push("all")
        lg.translate(node.x, node.y)

        lg.setColor(.25, .25, .4, 1)
        lg.rectangle("fill", 0, 0, node.w, node.h, 2 * scale)

        lg.setColor(.4, .4, .4, 1)
        lg.setLineWidth(1 * scale)
        lg.rectangle("line", 0, 0, node.w, node.h, 2 * scale)

        lg.setColor(1, 1,1, 1)
        lg.print(text, font, (node.w-font:getWidth(text)) / 2, (node.h-font:getHeight())/2)

        lg.pop()
      end,
    },
    rocker = {
      onInteract = function(node, interaction)
        if interaction == "onEnter" then
          audioManager.play("menu:audio/ui/hover")
        end

        if not node.state.rotation then return end

        if not node.state.start then
          node.state.start = {
            rotation = node.state.rotation,
            antiRotation = node.state.antiRotation,
          }
        end

        if interaction == "onEnter" then -- Hover start
          if node.state.flux then node.state.flux:stop() end
          node.state.flux = flux.to(node.state, 0.4, {
            rotation = node.state.targetRotation or node.state.start.rotation + 10,
            antiRotation = node.state.start.antiRotation - 20
          }):ease("cubicout")
        elseif interaction == "onLeave" then -- Hover end
        if node.state.flux then node.state.flux:stop() end
          node.state.flux = flux.to(node.state, 0.2, node.state.start):ease("cubicin")
        end
      end,

      measure = function(node)
        local scale = (node.state.scale or 1.0) * windowManager.scale
        local font = assetManager.getFont(fontKey, 18 * scale)
        local text = node.state.text or "unknown"
        local rotation = node.state.rotation or 0

        if not font then return 0, 0 end

        local padX, padY = 20 * scale, 10 * scale
        local w = font:getWidth(text) + padX
        local h = font:getHeight() + padY

        if rotation == 0 then return w, h end

        local rad = math.rad(rotation)
        local cosR = math.abs(math.cos(rad))
        local sinR = math.abs(math.sin(rad))

        local boundW = w * cosR + h * sinR
        local boundH = w * sinR + h * cosR

        return boundW, boundH
      end,

      update = function(node, dt)
        node.state.time = (node.state.time or love.math.random(0,10)/10) + dt

        local speed, maxAngle = 2.5, 4.0
        node.state.deltaRotationTime = math.sin(node.state.time * speed) * maxAngle
      end,

      draw = function(node)
        if node.state.hidden then return end

        local scale = (node.state.scale or 1.0) * windowManager.scale
        local font = assetManager.getFont(fontKey, 18 * scale)
        local text = node.state.text or "unknown"
        local rotation = node.state.rotation or 0
        local antiRotation = node.state.antiRotation or 0
        local deltaRotationTime = node.state.deltaRotationTime or 0
        local charge = node.state.charge or 0.0

        -- Easings
        local c = math.min(charge, 0.75) / 0.75
        rotation = rotation + 360 * (3 * c^2 - 2* c^3 )
        antiRotation = antiRotation + -90 * charge
        local swellScale = math.max(1, ((math.max(0, charge-0.5) / 0.5) * 3))

        lg.push("all")
        lg.translate(node.x + node.w / 2, node.y + node.h / 2)

        if node.state.rectangle then
          lg.setColor(.4,0,0,1)
          lg.push()
            lg.rotate(math.rad(rotation + deltaRotationTime))
            lg.rectangle("fill", -node.w/2, -node.h/2, node.w, node.h)
          lg.pop()
        end

        if font then
          local textWidth, textHeight = font:getWidth(text), font:getHeight()

          lg.setColor(.1,.1,.1)
          lg.push()
            lg.rotate(math.rad(antiRotation * -3 + 30 + (node.state.flipRotation and 20 or 0) - deltaRotationTime))
            lg.print(text, font, -textWidth / 2, -textHeight / 2)
          lg.pop()

          lg.setColor(.2,.2,.2,1)
          lg.push()
            lg.rotate(math.rad(antiRotation + (node.state.flipRotation and -10 or 0) - deltaRotationTime))
            lg.print(text, font, -textWidth / 2, -textHeight / 2)
          lg.pop()

          lg.push()
            lg.setColor(1,1,1,1)
            if charge > 0 then lg.setColor(1 - charge/10, 1 - charge/1.3, 1 - charge/1.3, 1) end
            lg.rotate(math.rad(rotation + deltaRotationTime))
            lg.scale(swellScale)
            lg.print(text, font, -textWidth / 2, -textHeight / 2)
          lg.pop()
        end
        lg.pop()
      end,
    },
    setting = {
      onInteract = function(_, interaction)
        if interaction == "onEnter" then
          audioManager.play("menu:audio/ui/hover")
        end
      end,

      measure = function(node)
        local scale = (node.state.scale or 1.0) * windowManager.scale

        local font = assetManager.getFont(fontKey, 16 * scale)
        local text = node.state.text or "unknown"

        if not font then return 0, 0 end

        local padX, padY = 20 * scale, 10 * scale
        local w = font:getWidth(text) + padX
        local h = font:getHeight() + padY

        return w, h
      end,

      update = function(node, dt)
        node.state.time = (node.state.time or 0) + dt
        local speed = node.state.active and 2.5 or 0.0
        node.state.pulse = math.sin(node.state.time * speed)
      end,

      draw = function(node)
        local scale = (node.state.scale or 1.0) * windowManager.scale

        local fontSize = 16 * scale
        if node.state.active then
          fontSize = fontSize + 4 * scale
        end

        local fontKey = node.state.active and fontKeyBold or fontKey
        local font = assetManager.getFont(fontKey, math.floor(fontSize))
        local text = node.state.text or "unknown"

        if not font then return end

        lg.push("all")
        lg.setColor(1,1,1,1)
        lg.translate(node.x + math.floor(node.w / 2), node.y + math.floor(node.h / 2))
        local textWidth, textHeight = font:getWidth(text), font:getHeight()
        lg.translate(-textWidth / 2, -textHeight / 2)

        lg.print(text, font)

        lg.pop()
      end,
    },
    pill = {
      onInteract = function(node, interaction)
        if not node.state.enabled then return end
        if interaction == "onEnter" then
          audioManager.play("menu:audio/ui/hover", { volume = 0.25 })
        elseif interaction == "onPressed" then
          audioManager.play("menu:audio/ui/switch")
        end
      end,
      update = function(node, _)
        if not node.state.targetX then node.state.targetX = node.state.active and 1 or 0 end

        local desiredTarget = node.state.active and 1 or 0

        if node.state.targetX ~= desiredTarget and not (node.state.flux and node.state.flux.progress < 1) then
          node.state.flux = flux.to(node.state, node.state.active and 0.6 or 0.3, { targetX = desiredTarget })
            :ease("expoout")
            :oncomplete(function() -- flux doesn't manually do the `=` on complete, and it could be left decimally not equal to desiredTarget
              node.state.targetX = desiredTarget
            end)
        end
      end,
      measure = function(node)
        local scale = windowManager.scale
        local fontSize = (node.state.size or 14) * scale
        local font = assetManager.getFont(fontKey, fontSize)
        local text = node.state.text or ""
        local padX = 16 * scale
        local w = (font and font:getWidth(text) or 40) + padX
        local h = (font and font:getHeight() or fontSize)
        return w, h
      end,
      draw = function(node)
        if not node.state.targetX then node.state.targetX = node.state.active and 1 or 0 end

        local scale = windowManager.scale
        local lineWidth = math.floor(1 * scale)
        local fontSize = (node.state.size or 14) * scale
        local font = assetManager.getFont(fontKey, fontSize)
        -- local radius = (node.h - lineWidth * 2.5) / 2

        lg.push("all")
        lg.setLineWidth(lineWidth)

        if node.state.enabled then
          local bgColor, activeColor = { .3,.3,.3,1 }, { .4,.8,.6,1 }
          lg.setColor(
            bgColor[1] + (activeColor[1] - bgColor[1]) * node.state.targetX,
            bgColor[2] + (activeColor[2] - bgColor[2]) * node.state.targetX,
            bgColor[3] + (activeColor[3] - bgColor[3]) * node.state.targetX,
            bgColor[4] + (activeColor[4] - bgColor[4]) * node.state.targetX
          )
        else
          lg.setColor(.2,.2,.2,1)
        end
        lg.rectangle("fill", node.x, node.y, node.w, node.h, node.h/2)

        lg.setColor(.5,.5,.5,1)
        if node.state.enabled and node.state.isHovered then
          lg.setColor(.65,.65,.65,1)
        end
        lg.rectangle("line", node.x, node.y, node.w, node.h, node.h/2)

        if font and node.state.text then
          lg.setColor(1,1,1,1)
          if not node.state.enabled then lg.setColor(.6,.6,.6,1) end
          local textWidth, textHeight = font:getWidth(node.state.text), font:getHeight()
          lg.print(node.state.text, font, node.x + (node.w - textWidth)/2, node.y + (node.h - textHeight)/2)
        end

        lg.pop()
      end,
    },
  },
  label = {
    default = {
      measure = function(node)
        local scale = (node.state.scale or 1.0) * windowManager.scale
        local fontSize = (node.state.size or 16) * scale
        local fontKey = node.state.bold and fontKeyBold or fontKey
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
        local scale = (node.state.scale or 1.0) * windowManager.scale
        local fontSize = (node.state.size or 16) * scale
        local fontKey = node.state.bold and fontKeyBold or fontKey
        local font = assetManager.getFont(fontKey, fontSize)
        local text = node.state.text or ""

        if not font then return end 

        lg.push("all")
        lg.translate(node.x + node.w / 2, node.y + node.h / 2)

        lg.setColor(1,1,1,1)
        if not node.state.enabled then
          lg.setColor(.7, .7, .7, 1)
        end

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
    },
  },
  container = {
    default = {
      update = updateScrollPhysics,
      drawAfterChildren = function(node)
        drawThumb(node)
      end,
    },
    row = {
      draw = function(node)
        if not node.state.isHovered then return end

        lg.push("all")
        lg.setColor(.3,.4,.5,.2)
        lg.rectangle("fill", node.x, node.y, node.w, node.h)
        lg.pop()
      end
    },
    outline = {
      draw = function(node)
        local scale = windowManager.scale
        local lineWidth = math.floor(1 * scale)
        local lineWidth2 = lineWidth * 2

        lg.push("all")
        
        graphicsManager.incrementStencilDepth()
        lg.setStencilState("increment", "always")
        
        local margin = 0.7 -- magic number; sue me
        lg.setColor(.3,.4,.5,.4)
        lg.rectangle("fill", node.x + lineWidth - margin, node.y + lineWidth - margin, node.w - (lineWidth - margin) * 2, node.h - (lineWidth - margin) * 2, 3 * scale)
        
        lg.setStencilState("keep", "always")
        lg.setColor(.4,.6,.7,1)
        lg.setLineWidth(lineWidth)
        lg.rectangle("line", node.x - lineWidth2*2, node.y - lineWidth2*2, node.w + lineWidth2*4, node.h + lineWidth2*4, 5 * scale)
        lg.setLineWidth(lineWidth2)
        lg.rectangle("line", node.x, node.y, node.w, node.h, 3 * scale)

        lg.setColor(1,1,1,1)
        lg.push("all")
        lg.setStencilState("keep", "gequal", graphicsManager.stencilDepth)
      end,
      drawAfterChildren = function(node)
        lg.pop()

        local scale = windowManager.scale
        local lineWidth = math.floor(1 * scale)
        local margin = 0.7

        graphicsManager.decrementStencilDepth()
        lg.setStencilState("decrement", "always")
        graphicsManager.setColorMaskRGBA(false)
        lg.rectangle("fill", node.x + lineWidth - margin, node.y + lineWidth - margin, node.w - (lineWidth - margin) * 2, node.h - (lineWidth - margin) * 2, 5 * scale)
        graphicsManager.setColorMaskRGBA(true)

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
    }
  },
  line = {
    vertical = {
      draw = function(node)
        local scale = windowManager.scale
        local lineWidth = math.floor(1 * scale)
        lg.push("all")
        lg.setLineWidth(lineWidth)
        lg.setColor(node.state.color or .4, node.state.color or .6, node.state.color or .7, 1)
        lg.line(node.x, node.y, node.x, node.y + node.h)
        lg.pop()
      end,
    },
    horizontal = {
      draw = function(node)
        local scale = windowManager.scale
        local lineWidth = math.floor(1 * scale)
        lg.push("all")
        lg.setLineWidth(lineWidth)
        lg.setColor(node.state.color or .4, node.state.color or .6, node.state.color or .7, 1)
        lg.line(node.x, node.y, node.x + node.w, node.y)
        lg.pop()
      end,
    }
  },
  slider = {
    audio = {
      update = function(node, dt)
        local state = node.state
        local step = state.step or 0.1
        local currentValue = state.value or 0

        local numberSteps = math.floor(1 / step + 0.5)
        state.stepProgress = state.stepProgress or { }
        state.stepProgressX = state.stepProgressX or { }

        local currentStepIndex = math.floor((currentValue / step) + 0.5)
        if state.lastStepIndex == nil then
          state.lastStepIndex = currentStepIndex
        end

        if currentStepIndex ~= state.lastStepIndex then
          state.lastStepIndex = currentStepIndex
          if love.timer.getTime() - (state.lastPlayed or 0) > 0.035 then -- magic number based on menu:audio/ui/tick duration
            state.lastPlayed = love.timer.getTime()

            local direction = currentStepIndex > state.lastStepIndex and 1 or -1
            local pitch = 1.0 + (direction * 0.15 * (currentStepIndex / numberSteps))
            audioManager.play("menu:audio/ui/tick", { pitch = pitch, bus = state.bus })
          end
        end

        for i = 0, numberSteps do
          local stepValue = i * step
          local active = currentValue > 0 and stepValue <= currentValue + 1e-4
          local target = active and 1 or 0
          local currentProgress = state.stepProgress[i] or 0
          local currentProgressX = state.stepProgressX[i] or 0
          local speedY = 12
          local speedX = speedY * 0.25
          state.stepProgress[i] = currentProgress + (target - currentProgress) * math.min(1, dt * speedY)
          local targetX = currentProgress > 0.2 and target or 0
          state.stepProgressX[i] = currentProgressX + (targetX - currentProgressX) * math.min(1, dt * speedX)
        end
      end,
      measure = function(node)
        local scale = windowManager.scale
        local w = (node.state.width or 180) * scale
        local h = (node.state.height or 30) * scale
        return w, h
      end,
      draw = function(node)
        local scale = windowManager.scale
        local step = node.state.step or 0.1
        local currentValue = node.state.value or 0

        local numberSteps = math.floor(1 / step + 0.5)
        node.state.stepProgress = node.state.stepProgress or { }
        node.state.stepProgressX = node.state.stepProgressX or { }

        lg.push("all")
        lg.translate(node.x, node.y)

        local totalWidth, totalHeight = node.w, node.h
        local barWidth = totalWidth / (numberSteps + 1)
        local pad = 3 * scale

        for i = 0, numberSteps do
          local t = numberSteps > 0 and i / numberSteps or 0
          local progress = node.state.stepProgress[i] or 0
          local progressX = node.state.stepProgress[i] or 0
          local x = i * barWidth + pad / 2
          local width = math.max(2, barWidth - pad)
          local minSize = math.min(width, totalHeight * 0.35)
          local maxHeight = totalHeight * 0.85

          local currentHeight = minSize + (maxHeight - minSize) * progress
          local currentWidth = width * (0.5 + 0.5 * progressX)
          local cx, cy = x + width / 2, totalHeight / 2

          local r1, g1, b1 = .4, .4, .4
          local r2, g2, b2
          if t < 0.5 then
            local f = t * 2
            r2, g2, b2 = 1, 0.2 + 0.7 * f, 0.2
          else
            local f = (t - 0.5) * 2
            r2, g2, b2 = 1 - 0.8 * f, 0.9 + 0.1 * f, 0.2
          end

          lg.setColor(
            r1 + (r2 - r1) * progress,
            g1 + (g2 - g1) * progress,
            b1 + (b2 - b1) * progress,
            0.4 + 0.6 * progress
          )

          local radius = progress > 0.5 and 0.5 * scale or currentWidth * (1 - progress / 0.3) * 0.4
          lg.rectangle("fill", cx - currentWidth / 2, cy - currentHeight / 2, currentWidth, currentHeight, radius)
        end

        lg.pop()
      end,
    }
  },
  keybind = {
    default = {
      onInteract = function(_, interaction)
        if interaction == "onEnter" then
          audioManager.play("menu:audio/ui/hover")
        elseif interaction == "onPressed" or interaction == "onCancel" or interaction == "onComplete" then
          audioManager.play("menu:audio/ui/switch")
        end
      end,
      measure = function(node)
        if node.state.hidden then return 0, 0 end

        local scale = windowManager.scale
        local font = assetManager.getFont(fontKey, 14 * scale)
        local text = node.state.text or "NIL"
        if node.state.isListening then text = " ... " end
        local w = font:getWidth(text) + 16 * scale
        local h = font:getHeight()
        return w, h
      end,
      draw = function(node)
        if node.state.hidden then return end

        local scale = windowManager.scale
        local font = assetManager.getFont(fontKey, 14 * scale)
        local text = node.state.text or "NIL"
        if node.state.isListening then text = "..." end

        lg.push("all")
        lg.translate(node.x, node.y)
        lg.setLineWidth( math.floor(1 * scale))

        if node.state.isListening then
          lg.setColor(.9, .7, .2, .9)
        elseif node.state.isHovered then
          lg.setColor(.4, .4, .4, 1)
        else
          lg.setColor(.25, .25, .25, 1)
        end

        local w, h = node.w, node.h
        lg.rectangle("fill", 0, 0, w, h, 4 * scale)

        if node.state.isListening then
          lg.setColor(0.5, 0.5, 0.5, 1)
        elseif node.state.isConflict then
          lg.setLineWidth(math.floor(2 * scale))
          lg.setColor(1, .25, .25, 1)
        elseif not node.state.isDefault then
          lg.setLineWidth(math.floor(1.5 * scale))
          lg.setColor(.95, .65, .1)
        else
          lg.setColor(0.5, 0.5, 0.5, .5)
        end
        lg.rectangle("line", 0, 0, w, h, 4 * scale)

        lg.setColor(1,1,1,1)
        local textW, textH = font:getWidth(text), font:getHeight()
        lg.print(text, font, (w - textW) / 2, (h - textH ) / 2)

        lg.pop()
      end,
    }
  }
}

return theme