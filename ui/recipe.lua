
local recipe = {
  children = true,
}

recipe.getCursor = function(node)
  if node.state.active then
    return "hand"
  end
  return "arrow"
end

return recipe