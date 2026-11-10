local inputManager = require("src.core.inputManager")
local controller = inputManager.getController()

controller:registerControl("up",    { "key:w", "key:up", "axis:lefty-" })
controller:registerControl("left",  { "key:a", "key:left", "axis:leftx-" })
controller:registerControl("down",  { "key:s", "key:down", "axis:lefty+" })
controller:registerControl("right", { "key:d", "key:right", "axis:leftx+" })

controller:registerControl("dodge", { "key:space", "button:a" })
controller:registerControl("attack", { "mouse:1", "axis:triggerright+" })
controller:registerControl("inventory", { "key:e", "key:i", "button:back" })
controller:registerControl("closeInventory", { "key:escape" })

controller:registerControl("kitchen", { "key:tab", "button:y" })

controller:registerGroup("move", { up = "up", left = "left", down = "down", right = "right" })

return controller