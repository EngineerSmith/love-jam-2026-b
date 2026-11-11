
local buildInventory = require("lj26b:ui.buildInventory")

return function(scene, uiManager)
  scene:setTheme("lj26b:themes.inventoryTheme")

  local ui = uiManager.getUIBuilder()

  scene:setRoot(ui.container("root", {
    spacing = 0,
    direction = "horizontal",
  }, {
    ui.container("left_side", {
      alignment = "center",
      flex = 1,
    }, {
      buildInventory(ui),
    }),
    ui.container("center_side", { flex = 0.2 }), -- spacing
    ui.container("right_side", {
      alignment = "center",
      flex = 1,
    }, {
      ui.container("equipment_window", {
        class = "inventory_window",
        padding = 20,
        spacing = 20,
        timer = .2,
        progress = 0,
        update = function(node, dt)
          if node.state.timer > 0 then
            node.state.timer = node.state.timer - dt
            node.state.progress = math.min(1, 1 - node.state.timer / .2)
          end
          node.state.drawChildren = node.state.timer <= 0
        end,
      }, {
        ui.cell({ padding = 5, equipment = "hand", class = "equipment" }),
        ui.container(),
        ui.container({
          direction = "horizontal",
          spacing = 5,
          padding = 2.5,
        }, {
          ui.cell({ equipment = "jam1", class = "equipment" }),
          ui.cell({ padding = 5, equipment = "jam2", class = "equipment" }),
          ui.cell({ padding = 5, equipment = "jam3", class = "equipment" }),
        })
      })
    }),
  }))

  table.insert(scene:getNode("equipment_window").children, 1, ui.container({
    paddingBottom = 15 - 20,
  }, {
    ui.label({ text = "Equipment", class = "inventory" })
  }))
  
end