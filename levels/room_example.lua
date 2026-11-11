
---[[[ dungeon room def ]]]


local room = {
  width = 10, height = 10,
  flags = {
    entrance = { position = { } },
  },
  sockets = {
    { position = { }, direction = { } },
    { ... }
  },
  rails = { -- camera
   -- relative to room centre
    { -- Question: How would a 3-way junction be handled?
      position = {  },
      target = "player", -- if undefine then player
      targetOffset = { },
      fov = 90, -- if undefined, then whatever it currently is
    },
    {
      -- ...
    }
  },
  build = function(level, transform, randomGenerator)
    local roomInstance = { ... }

    level:addStaticVisual(...)
    level:addBoundary(...) -- TODO add way to add raw physics shapes without models to levels
  end,
  activate = function(roomInstance)
    -- Triggers on level.active 
    addMonsters()
  end,
}

return room