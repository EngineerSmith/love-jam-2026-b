
local sprite = require("src.core.graphicsManager.sprite")

local character = require("lj26b:character")

local states = { }

states.idle = {
  sprites = {
    idle = sprite.new("lj26b:characters/dummy/Idle_Side"),
  },
  enter = function(self, char)
    self.motion = "idle"
    self.sprite = self.sprites.idle:start()
  end,
}

states.stagger = {
  sprites = {
    hit = sprite.new("lj26b:characters/dummy/Hit_Side"),
  },
  enter = function(self, char)
    if not self.onFinish then
      self.onFinish = function()
        char:changeState(char.states.idle)
      end
    end
    self.motion = "hit"
    self.sprite = self.sprites.hit:start(self.onFinish)
    -- char.attributes.invulnerable = true
  end,
  exit = function(self, char)
    -- char.attributes.invulnerable = false
  end,
  update = function(self, _, _)
    if self.sprite and self.sprite.metaUserdata and self.sprite.metaUserdata.flashFrames then
      local isFlash = false
      local currentIndex = self.sprite.frameIndex - 1
      for _, frameId in ipairs(self.sprite.metaUserdata.flashFrames) do
        if type(frameId) == "number" and currentIndex == frameId then
          isFlash = true
          break
        end
      end

      if isFlash then
        self.sprite:setColor(1, .4, .4)
      else
        self.sprite:setColor(1, 1, 1)
      end
    end
  end,
}

local trainingDummy = character.new({
  shape = require("libs.slick").newCircleShape(0, 0, .18),
  states = states,
  defaultState = "idle",
  attributes = {
    maxHealth = 100,
    currentHealth = 100,
    invulnerable = false,
  },
})

trainingDummy.takeHit = function(self, damage)
  getmetatable(trainingDummy).takeHit(self, damage)
  self:changeState(self.states.stagger)
  self.attributes.currentHealth = self.attributes.maxHealth -- Dummy cannot die
end

return trainingDummy