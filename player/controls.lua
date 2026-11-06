local inputManager = require("src.core.inputManager")
local controller = inputManager.getController()

controller:registerControl("up",    { "key:w", "key:up" })
controller:registerControl("left",  { "key:d", "key:left" })
controller:registerControl("down",  { "key:s", "key:down" })
controller:registerControl("right", { "key:a", "key:right" })

controller:registerControl("dodge", { "key:space" })
controller:registerControl("attack", { "mouse:1" })

controller:registerGroup("move", { up = "up", left = "left", down = "down", right = "right" })

return controller