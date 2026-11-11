
local inventory = require("lj26b:inventory")

return function(ui)
  local getInventoryRow = function(rowLength, indexOffset)
    local cells = { }
    for i = 1, rowLength do
      table.insert(cells, ui.cell({
        padding = 5,
        slotIndex = indexOffset + i, -- Attempted to perform math on nil value
      }))
    end
    return ui.container({
      direction = "horizontal",
      spacing = 5,
      padding = 2.5,
    }, cells)
  end

  local getInventoryRows = function(rowLength)
    local slotCount = #inventory.slots.items
    local rows = { }
    for i = 0, math.ceil(slotCount / rowLength) - 1 do
      table.insert(rows, getInventoryRow(math.min(rowLength, slotCount), i * rowLength))
      slotCount = slotCount - rowLength
    end
    return rows
  end

  local inventoryWindow = ui.container("inventory_window", {
    class = "inventory_window",
    padding = 20,
    timer = .2,
    progress = 0,
    update = function(node, dt)
      if node.state.timer > 0 then
        node.state.timer = node.state.timer - dt
        node.state.progress = math.min(1, 1 - node.state.timer / .2)
      end
      node.state.drawChildren = node.state.timer <= 0
    end,
  }, getInventoryRows(4))

  table.insert(inventoryWindow.children, 1, ui.container({
    paddingBottom = 15, paddingTop = -5,
  }, {
    ui.label({ text = "Inventory", class = "inventory" }),
  }))
  table.insert(inventoryWindow.children, ui.container({
    paddingTop = 15, paddingBottom = -5,
  }, {
    ui.cell({ padding = 5, equipment = "trash", class = "equipment" })
  }))

  return inventoryWindow
end