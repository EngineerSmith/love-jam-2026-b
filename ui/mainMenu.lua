
local hook = require("src.core.hook")

return function(scene, uiManager)
  local playButton = scene:getNode("btn_play")
  playButton.state.onPressed = function()
    hook.moveScene("game")
  end
end