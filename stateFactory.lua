local stateFactory = { }

local stateMT = {
  getSpriteResourceKeys = function(self, outKeys, inMap)
    if not self.sprites then return end
    for _, sprite in pairs(self.sprites) do
      if not inMap or not inMap[sprite._resourceKey] then
        table.insert(outKeys, sprite._resourceKey)
      end
    end
  end,
}
stateMT.__index = stateMT

stateFactory.new = function(definition)
  -- local state = setmetatable({ }, stateMT)
  local state = { }
  for k, v in pairs(definition) do
    state[k] = v
  end

  local userEnter = definition.enter
  state.enter = function(self, character)
    if userEnter then userEnter(self, character) end
  end

  local userExit = definition.exit
  state.exit = function(self, character)
    self.sprite = nil
    if self.sprites then
      for _, sprite in pairs(self.sprites) do
        sprite:stop(true):seek(1)
      end
    end

    if userExit then userEnter(self, character) end
  end

  local userUpdate = definition.update
  state.update = function(self, character, dt)
    if userUpdate then userUpdate(self, character, dt) end
  end

  return state
end

return stateFactory