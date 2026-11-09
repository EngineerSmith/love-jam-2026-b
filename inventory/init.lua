local lg = love.graphics

local assetManager = require("src.core.assetManager")
local windowManager = require("src.core.windowManager")

local inventory = {
  toasts = { },
  slots = {
    equipment = { -- I'm open to changing the layout of these slot definitions
      hand = { slotType = "hand" },
      jam1 = { slotType = "jam" },
      jam2 = { slotType = "jam" },
      jam3 = { slotType = "jam" },
    },
    items = { }
  },
  trash = { count = 0 },
  _modifiersDirty = true,
  _modifiers = { },
  _stackSize = 20,
}
for i = 1, 20 do
  table.insert(inventory.slots.items, { count = 0 })
end

inventory.add = function(item, noToast)
  local inventoryAcceptedItem = false
  local targetSlot = nil

  if item.stackable then
    for _, itemSlot in ipairs(inventory.slots.items) do
      if itemSlot.item and itemSlot.item:eq(item) and itemSlot.count < inventory._stackSize then
        itemSlot.count = itemSlot.count + 1
        targetSlot = itemSlot
        inventoryAcceptedItem = true
        break
      end
    end
  end

  if not inventoryAcceptedItem then
    for _, itemSlot in ipairs(inventory.slots.items) do
      if itemSlot.item == nil then
        itemSlot.item = item
        itemSlot.count = 1
        targetSlot = itemSlot
        inventoryAcceptedItem = true
        break
      end
    end
  end

  if not noToast then
    if inventoryAcceptedItem then
      inventory.addToast({
        id = item.id,
        sprite = item.sprite,
        name = item.name,
      })
    else
      inventory.addToast({
        id = "INV.FULL",
        name = "Inventory Full",
      })
    end
  end

  return inventoryAcceptedItem
end

-- What about unequipping?
inventory.equipItem = function(slotName, inventoryIndex)
  local targetSlot = inventory.slots.equipment[slotName]
  if not targetSlot then return false end

  local itemToEquip, countToEquip = nil, 1

  if inventoryIndex == "trash" then
    if not inventory.trash.item then return false end
    itemToEquip = inventory.trash.item
    countToEquip = inventory.trash.count
  else
    local invSlot = inventory.slots.items[inventoryIndex]
    if not invSlot or not invSlot.item then return false end
    itemToEquip = invSlot.item
    countToEquip = invSlot.count
  end

  if itemToEquip.itemType ~= targetSlot.slotType then return false end

  local actualEquipItem = itemToEquip
  if inventoryIndex ~= "trash" and countToEquip > 1 then
    inventory.slots.items[inventoryIndex].count = countToEquip - 1
  else
    if inventoryIndex == "trash" then
      inventory.trash.item = nil
      inventory.trash.count = 0
    else
      inventory.slots.items[inventoryIndex].item = nil
      inventory.slots.items[inventoryIndex].count = 0
    end
  end

  local prevEquipped = targetSlot.item
  targetSlot.item = itemToEquip

  if prevEquipped then
    if inventoryIndex == "trash"then
      inventory.trash.item = prevEquipped
      inventory.trash.count = 1
    else
      local invSlot = inventory.slots.items[inventoryIndex]
      if invSlot.item then
        if not inventory.add(prevEquipped, true) then -- Drop if it can't fit
          local p = require("player") -- it's a game jam
          prevEquipped:spawn(p.currentLevel, p.transform.position)
        end
      else
        invSlot.item = prevEquipped
        invSlot.count = 1
      end
    end
  end

  inventory._modifiersDirty = true
  return true
end

inventory.unequipItem = function(slotName, inventoryIndex)
  local targetSlot = inventory.slots.equipment[slotName]
  local invSlot = inventory.slots.items[inventoryIndex]
  if not targetSlot or not invSlot or not targetSlot.item or invSlot.item then return false end

  invSlot.item = targetSlot.item
  invSlot.count = 1
  targetSlot.item = nil

  inventory._modifiersDirty = true
  return true
end

inventory.moveInventorySlot = function(fromIndex, toIndex)
  local toSlot = inventory.slots.items[toIndex]
  if not toSlot then return false end

  if fromIndex == "trash" then
    if not inventory.trash.item then return false end

    if toSlot.item == nil then
      toSlot.item = inventory.trash.item
      toSlot.count = inventory.trash.count
      inventory.trash.item = nil
      inventory.trash.count = 0
    elseif toSlot.item:eq(inventory.trash.item) and toSlot.item.stackable then
      local spaceLeft = inventory._stackSize - toSlot.count
      local moveCount = math.min(inventory.trash.count, spaceLeft)
      toSlot.count = toSlot.count + moveCount
      inventory.trash.count = inventory.trash.count - moveCount
      if inventory.trash.count <= 0 then
        inventory.trash.item = nil
        inventory.trash.count = 0
      end
    else
      local tempItem = toSlot.item
      local tempCount = toSlot.count
      toSlot.item = inventory.trash.item
      toSlot.count = inventory.trash.count
      inventory.trash.item = tempItem
      inventory.trash.count = tempCount
    end
    return true
  end

  local fromSlot = inventory.slots.items[fromIndex]
  if not fromSlot or not toSlot or fromSlot == toSlot then return false end

  if toSlot.item and fromSlot.item and toSlot.item:eq(fromSlot.item) and toSlot.item.stackable then
    local spaceLeft = inventory._stackSize - toSlot.count
    local moveCount = math.min(fromSlot.count, spaceLeft)
    toSlot.count = toSlot.count + moveCount
    fromSlot.count = fromSlot.count - moveCount
    if fromSlot.count <= 0 then
      fromSlot.item = nil
      fromSlot.count = 0
    end
    return true
  end

  local tempItem = toSlot.item
  local tempCount = toSlot.count

  toSlot.item = fromSlot.item
  toSlot.count = fromSlot.count

  fromSlot.item = tempItem
  fromSlot.count = tempCount

  return true
end

inventory.trashInventorySlot = function(index)
  local slot = inventory.slots.items[index]
  if not slot or not slot.item then return false end

  inventory.trash.item = slot.item
  inventory.trash.count = slot.count

  slot.item = nil
  slot.count = 0
  return true
end

inventory.trashEquipmentSlot = function(slotName)
  local slot = inventory.slots.equipment[slotName]
  if not slot or not slot.item then return false end

  inventory.trash.item = slot.item
  inventory.trash.count = 1

  slot.item = nil
  inventory._modifiersDirty = true
  return true
end

inventory.getStatModifiers = function()
  if inventory._modifiersDirty then
    inventory._modifiersDirty = false
    local mods = { }
    for _, slot in pairs(inventory.slots.equipment) do
      if slot.item and slot.item.stats then
        for statName, value in pairs(slot.item.stats) do
          mods[statName] = (mods[statName] or 0) + value
        end
      end
    end
    inventory._modifiers = mods
  end
  return inventory._modifiers
end

do
  local toastInEnd = 1
  local toastFadeStart = 4
  local toastKill = 6

  inventory.addToast = function(newToast)
    for i, toast in ipairs(inventory.toasts) do
      if toast.id and toast.id == newToast.id then
        if newToast.id == "INV.FULL" then
          toast.time = toastInEnd
          return -- prevent spam of full message
        end

        toast.pickupCount = toast.pickupCount + 1
        toast.text = toast.name .. " x" .. toast.pickupCount
        toast.time = toastInEnd

        table.remove(inventory.toasts, i)
        table.insert(inventory.toasts, 1, toast)
        return
      end
    end

    newToast.pickupCount = 1
    newToast.text = newToast.name
    newToast.time = 0
    table.insert(inventory.toasts, 1, newToast)
  end

  inventory.update = function(dt)
    for i = #inventory.toasts, 1, -1 do
      local toast = inventory.toasts[i]
      toast.time = toast.time + dt
      if toast.time >= toastKill then
        table.remove(inventory.toasts, i)
      end
    end
  end

  local padding = 10
  inventory.drawToasts = function()
    local font = assetManager.getFont("menu:fonts/RobotoMono-Medium", 15 * windowManager.scale)
    local toastHeight = font:getHeight() + 5 * windowManager.scale * 2

    lg.push("all")
    lg.translate(padding * windowManager.scale, lg.getHeight() - padding * windowManager.scale)
    for _, toast in ipairs(inventory.toasts) do
      lg.translate(0, -toastHeight)
      lg.push()

      local alpha = 1
      if toast.time < toastInEnd then
        alpha = toast.time / toastInEnd
      elseif toast.time > toastFadeStart then
        alpha = 1 - ((toast.time - toastFadeStart) / (toastKill - toastFadeStart))
      end
      lg.setColor(1,1,1,alpha)

      if toast.sprite then
        local texture, quad = toast.sprite:get()
        if texture and quad then
          local width, height = toast.sprite:getDimensions()
          local scale = math.floor(font:getHeight() / height + 0.5)
          lg.draw(texture, quad, 0, (toastHeight - (height * scale))/2, 0, scale)
          lg.translate(width * scale + (padding/2) * windowManager.scale, 0)
        end
      end

      lg.print(toast.text, font, 0, (toastHeight - font:getHeight()) / 2)

      lg.pop()
      lg.translate(0, -padding*windowManager.scale)
    end
    lg.pop()
  end
end

return inventory