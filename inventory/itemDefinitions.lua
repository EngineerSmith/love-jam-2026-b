
local sprite = require("src.core.graphicsManager.sprite")

local item = require(":inventory.item")

local itemDefinitions = { }

local newItem = function(id, config)
  itemDefinitions[id] = item.new(id, config)
  return itemDefinitions[id]
end

local newJamRecipe = function(from, to)
  -- TODO
end

newItem("void_peach", {
  name = "Void Peach",
  itemType = "ingredient",
  sprite = sprite.new("lj26b:items/void_peach"),
  pickupRadius = 0,
})

newItem("wolf_tuff", {
  name = "Wolf Fur Tuff",
  itemType = "ingredient",
  sprite = sprite.new("lj26b:items/wolf_tuff"),
})

newItem("slime_jelly", {
  name = "Slime Jelly",
  itemType = "ingredients",
  sprite = sprite.new("lj26b:items/slime_jelly"),
})

newItem("empty_jar", {
  name = "Empty Jam Jar",
  itemType = "jam",
  sprite = sprite.new("lj26b:items/empty_jar"),
})

newItem("void_jam", {
  name = "Void Jam",
  itemType = "jam",
  sprite = sprite.new("lj26b:items/void_jam"),
  stats = {
    damage = 5,
    walkSpeed = 0.1,
  },
})

newItem("stringy_jam", {
  name = "Stringy Jam",
  itemType = "jam",
  tooltip = "Is that a hair?",
  sprite = sprite.new("lj26b:items/stringy_jam"),
  stats = {
    walkSpeed = 0.8,
    dodgeStaminaCost = -2,
  },
})

newItem("stick", {
  name = "Wooden Stick",
  itemType = "sword",
  -- sprite, -- todo not sure how sword equipment renders right now
  stats = {
    damage = 15,
    range = 1.5,
    coneAngle = 130,
    staminaCost = 15,
    attacksStaminaDelay = 0.4,
  },
  stackable = false,
})

newJamRecipe({ "void_peach", "slime_jelly" }, "void_jam")
newJamRecipe({ "wolf_tuff", "slime_jelly" }, "stringy_jam")

return itemDefinitions