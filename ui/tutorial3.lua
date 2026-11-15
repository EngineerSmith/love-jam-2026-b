local hook = require("src.core.hook")

local player = require("lj26b:player")
local itemDefinitions = require("lj26b:inventory.itemDefinitions")

return function(scene, uiManager)
  scene:setTheme("lj26b:themes.inventoryTheme")

  local targetText = {
    "Tip!\nYou can equip your jam in your inventory\nwhen outside of the kitchen!",
    function()
      player.isInCutscene = false
      uiManager.pop("game:menu.tutorial3")
    end,
  }

  local ui = uiManager.getUIBuilder()

  player.isInCutscene = true
  scene:addDestroyHook(function()
    player.isInCutscene = false -- prevent soft lock possibility if it doesn't reach quest
    hook.remove("engine:mouse.pressed", "tutorial3")
  end)

  scene:setRoot(ui.container("root", {
    spacing = 0,
    direction = "horizontal",
  }, {
    ui.container({ flex = 1.0 }),
    ui.container({ flex = 0.5 }),
    ui.container({
      alignment = "center",
      flex = 1,
    }, {
      ui.container("text_window", {
        class = "inventory_window",
        padding = 20,
        spacing = 20,
        timer = .8, -- reset progress to .2 to "reopen"
        progress = 0,
        update = function(node, dt)
          if node.state.timer > 0 then
            node.state.timer = node.state.timer - dt
            if node.state.timer < 0.2 then
              node.state.progress = math.min(1, 1 - node.state.timer / .2)
            end
          end
          node.state.drawChildren = node.state.timer <= 0
        end,
      }, {
        ui.label("text", {
          class = "message",
          wrap = true,
          timer = -1,
          targetText = targetText[1],
        })
      })
    })
  }))

  local _time = 0
  local _index = 1
  hook.remove("engine:mouse.pressed", "tutorial3")
  hook.add("engine:mouse.pressed", "tutorial3", function(_, _, button)
    if love.timer.getTime() - .5 > _time then
      _time = love.timer.getTime() -- simple solution to prevent accidental skipping
      
      if button == 1 then
        local messageElement = scene:getNode("text")
        if messageElement then
          if messageElement.state.text ~= messageElement.state.targetText then
            messageElement.state.text = messageElement.state.targetText
          else
            _index = _index + 1
            local nextTarget = targetText[_index]
            if type(nextTarget) == "string" then
              messageElement.state.targetText = nextTarget
              messageElement.state.text = nil
              messageElement.state.charIndex = 0
              messageElement.state.timer = -1
              local tw = scene:getNode("text_window")
              tw.state.timer = .2
              tw.state.progress = 0
            elseif type(nextTarget) == "function" then
              nextTarget()
            end
          end
        end
      end
    end
  end)
end