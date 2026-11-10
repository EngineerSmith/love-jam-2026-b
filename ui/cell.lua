
local inputManager = require("src.core.inputManager")

local inventory = require("lj26b:inventory")

local cell = {
  hoverCursor = "arrow",
  children = false,
  isFocusable = true,
}

cell.canBeHeld = function(node)
  if node.state.equipment then
    local slot = inventory.slots.equipment[node.state.equipment]
    return slot and slot.item
  end
  local slot = inventory.slots.items[node.state.slotIndex]
  return slot and slot.item and slot.count >= 1
end

cell.getCursor = function(node)
  if node.state.isHeld then
    return "handclosed"
  end
  if node.state.equipment then
    local slot = inventory.slots.equipment[node.state.equipment]
    if slot and slot.item then
      return "hand"
    end
  elseif node.state.slotIndex then
    local slot = inventory.slots.items[node.state.slotIndex]
    if slot and slot.item and slot.count >= 1 then
      return "hand"
    end
  end
end

cell.update = function(node)
  if node.state.isHeld then
    inputManager.setCursor("handclosed")
  end
end

cell.releasedOn = function(node, scene)
  local other = scene._heldNode
  if not other then return end

  local fromSlot = other.state.slotIndex
  local toSlot = node.state.slotIndex
  if fromSlot and toSlot then
    inventory.moveInventorySlot(fromSlot, toSlot)
    return
  elseif not fromSlot and not toSlot then
    local fromSlot = other.state.equipment
    local toSlot = node.state.equipment
    if fromSlot and toSlot then
      inventory.moveEquipItem(fromSlot, toSlot)
      return
    end
  end

  if fromSlot then
    local equipSlot = node.state.equipment
    if fromSlot and equipSlot then
      inventory.equipItem(equipSlot, fromSlot)
      return
    end
  end

  if toSlot then
    local equipSlot = other.state.equipment
    if equipSlot and toSlot then
      inventory.unequipItem(equipSlot, toSlot)
    end
  end
end

return cell