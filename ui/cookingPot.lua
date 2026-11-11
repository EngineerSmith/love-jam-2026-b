local buildInventory = require("lj26b:ui.buildInventory")

local inventory = require("lj26b:inventory")

local itemDefinitions = require("lj26b:inventory.itemDefinitions")

local cookingPot = require("lj26b:cookingPot")

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

local canRollAttribute = function(statName)
  if statName == "walkSpeed" then return false end
  return true
end

local formatNumber = function(n)
  local s = ("%.1f"):format(n)
  if s:match("%.0$") then
    return s:sub(1, -3)
  end
  return s
end

return function(scene, uiManager)
  scene:setTheme("lj26b:themes.inventoryTheme")

  local ui = uiManager.getUIBuilder()

  local buildUnlockedRecipe = function(recipe)
    local resultItem = itemDefinitions[recipe.to]

    local statText
    if resultItem and resultItem.stats then
      local lines = { }
      for statName, baseVal in pairs(resultItem.stats) do
        if canRollAttribute(statName) then
          local displayVal = math.abs(baseVal)
          local sign = baseVal >= 0 and "+" or "-"
          local minVal = math.max(1, displayVal - 2)
          local maxVal = displayVal * 1.7
          table.insert(lines, ("%s: %s%s to %s%s"):format(attributeMap[statName] or stateName:sub(1,1):upper() .. stateName:sub(2), sign, formatNumber(minVal), sign, formatNumber(maxVal)))
        else
          local sign = baseVal >= 0 and "+" or ""
          table.insert(lines, ("%s: %s%s"):format(attributeMap[statName] or stateName:sub(1,1):upper() .. stateName:sub(2), sign, baseVal))
        end
      end
      statText = table.concat(lines, "\n")
    end

    local id = "btn_cook_" .. recipe.to
    return ui.recipe(id, {
      direction = "vertical",
      alignment = "center",
      padding = 5,
      onPressed = function(node)
        if not node.state.active then return end
        local success = inventory.consumeItems(recipe.from)
        if not success then return end
        if recipe.to then
          local itemId, itemCount = nil, 1
          if type(recipe.to) == "string" then
            itemId = recipe.to
          elseif type(recipe.to) == "table" then
            itemId = recipe.to[1]
            itemCount = recipe.to.count or 1
          end
          if itemId then
            local def = itemDefinitions[itemId]
            if not def then return end
            local stats = { }
            for statName, baseVal in pairs(def.stats) do
              if canRollAttribute(statName) then
                local v = math.abs(baseVal)
                local sign = baseVal >= 0 and 1 or -1
                -- 'good' rolls always (make the player feel better)
                local rolled = (love.math.random(v * 1.1 * 10, v * 1.7 * 10) / 10) * sign
                stats[statName] = rolled
              end
            end
            cookingPot.cook(def, stats) -- itemCount (not supported)
          end
        end
      end,
    },{
      ui.container({ }, {
        ui.label({
          text = resultItem and resultItem.name or recipe.to,
          class = "inventory",
          fontSize = 16, bold = true,
        }),
        ui.label({
          class = "button",
          text = "Missing ingredients",
          update = function(btn, dt)
            local node = scene:getNode(id)
            local result = inventory.hasItems(recipe.from)
            local hasEverything = true
            for i, b in ipairs(result) do
              if not b then
                hasEverything = false
                break
              end
            end
            node.state.active = hasEverything
            if node.state.active then
              btn.state.text = "Cook!"
              btn.state.color = nil
            else
              btn.state.text = "Missing ingredients"
              btn.state.color = { .1,.2,.3,1 }
            end
            if node.state.isHovered then
              local input_1 = scene:getNode("input_1")
              local input_2 = scene:getNode("input_2")
              local outcome = scene:getNode("outcome")
              local requirement1 = recipe.from[1]
              if requirement1 then
                local itemId, itemCount = nil, 1
                if type(requirement1) == "string" then
                  itemId = requirement1
                elseif type(requirement1) == "table" then
                  itemId = requirement1[1]
                  itemCount = requirement1.count or 1
                end
                if itemId then
                  input_1.state.item = itemDefinitions[itemId]
                  input_1.state.itemCount = itemCount
                  input_1.state.isMissing = not result[1]
                end
              end
              local requirement2 = recipe.from[2]
              if requirement2 then
                local itemId, itemCount = nil, 1
                if type(requirement2) == "string" then
                  itemId = requirement2
                elseif type(requirement2) == "table" then
                  itemId = requirement2[1]
                  itemCount = requirement2.count or 1
                end
                if itemId then
                  input_2.state.item = itemDefinitions[itemId]
                  input_2.state.itemCount = itemCount
                  input_2.state.isMissing = not result[2]
                end
              end
              if recipe.to then
                local itemId, itemCount = nil, 1
                if type(recipe.to) == "string" then
                  itemId = recipe.to
                elseif type(recipe.to) == "table" then
                  itemId = recipe.to[1]
                  itemCount = recipe.to.count or 1
                end
                if itemId then
                  outcome.state.item = itemDefinitions[itemId]
                  outcome.state.itemCount = itemCount
                  outcome.state.isMissing = .5
                end
              end
            end
            if node.state.wasHovered then
              local input_1 = scene:getNode("input_1")
              local input_2 = scene:getNode("input_2")
              local outcome = scene:getNode("outcome")
              input_1.item, input_2.item = nil, nil
              outcome.item = nil
            end
          end,
        }),
        ui.container({ alignment = "start" }, {
          ui.label({
            text = statText,
            class = "inventory",
            fontSize = 10,
            wrap = true,
            -- color = { .8, .8, .8, 1 },
          }),
        }),
      }),
    })
  end

  local getRecipes = function()

    local scrollable = ui.container({ scrollable = true, class = "stencil", spacing = 20, flex = 1 }, { })

    for _, recipe in ipairs(itemDefinitions.recipes) do
      if recipe.unlocked or recipe.unlocked == nil then
        table.insert(scrollable.children, buildUnlockedRecipe(recipe))
      end
    end

    return ui.container("recipe_book", {
      class = "inventory_window",
      padding = 20,
      timer = .2,
      progress = 0,
      alignment = "start",
      update = function(node, dt)
        if node.state.timer > 0 then
          node.state.timer = node.state.timer - dt
          node.state.progress = math.min(1, 1 - node.state.timer / .2)
        end
        node.state.drawChildren = node.state.timer <= 0
      end,
    }, {
      ui.label({
        text = "Recipe Book",
        class = "inventory",
      }),
      scrollable,
    })
  end

  local getCookingPot = function()
    return ui.container("Cooking_Pot", {
      class = "inventory_window",
      padding = 20, spacing = 20,
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
      ui.label({
        text = "Cooking Pot",
        class = "inventory",
      }),
      ui.container({
        direction = "horizontal",
        spacing = 10,
      }, {
        ui.container("input_1", {
          class = "displayCell",
          -- item = foobar, shows item foobar
          -- disabled state grays out item
        }),
        ui.label({ text = "+", class = "inventory" }),
        ui.container("input_2", {
          class = "displayCell",
        }),
      }),
      ui.container("outcome", {
        class = "displayCell",
      })
    })
  end

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
    ui.container("center_side", {
      alignment = "center",
      flex = 1, paddingY = 100, paddingX = 50,
    }, {
      getRecipes(),
    }),
    ui.container("right_side", {
      alignment = "center",
      flex = 1,
    }, {
      getCookingPot(),
    }),
  }))
end