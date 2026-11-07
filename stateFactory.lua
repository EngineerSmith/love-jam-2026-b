local stateFactory = { }

local stateMT = {
  getSpriteResourceKeys = function(self, outKeys, inMap)
    if not self.sprites then return end
    for _, sprite in pairs(self.sprites) do
      local key = sprite._resourceKey
      if key and (not inMap or not inMap[key]) then
        if inMap then inMap[key] = true end
        table.insert(outKeys, key)
      end
    end
  end,
}
stateMT.__index = stateMT

stateFactory.new = function(definition)
  if getmetatable(definition) == stateMT then
    -- we know we got a clone, so don't wrap default functions like below since it's already been done
  end

  local state = { }
  for k, v in pairs(definition) do
    state[k] = v
  end
  setmetatable(state, stateMT)

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

    if userExit then userExit(self, character) end
  end

  local userUpdate = definition.update
  state.update = function(self, character, dt)
    if userUpdate then userUpdate(self, character, dt) end
  end

  return state
end

return stateFactory