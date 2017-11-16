sampler = {}
sampler.__index = sampler

function sampler.new(settings)
  local self = setmetatable({}, sampler)


  self.synths = {} -- collection of sources in a map indexed by touch ID
  self.transpose    = settings.transpose or 0
  local sourceCount = settings.sourceCount or 6
  local path        = settings.path
  local looped      = settings.looped or false

  self.envelope = settings.envelope or {
    attack  = 0,
    decay   = 0,
    sustain = 1,
    release = 0.35,
  }
  self.slopes = self:getSlopes(self.envelope)

  -- self.synths is filled as array, but it's a map with touchId as keys
  for i=1, sourceCount do
    local decoder     = love.sound.newDecoder(path)
    self.synths[i] = {
      source = love.audio.newSource(decoder),
      volume = 0,
      active = false,
      duration = 0,
    }
    self.synths[i].source:setLooping(looped)
    self.synths[i].source:stop()
  end
  return self
end

function sampler:update(dt, touches)
  -- hunt for new touches and play them
  for id, touch in pairs(touches) do
    if touch.noteRetrigger then
      local synth = self.synths[id]
      if not synth then
        synth = self:assignSynth(id)
      end
      synth.duration = 0
      synth.volume = 0
      synth.active = true
      synth.source:stop()
      synth.source:play()
    end
  end
  -- update sources for existing touches
  for id, synth in pairs(self.synths) do
    touch = touches[id]
    if touch then                          -- update existing notes
      local pitch = math.pow(math.pow(2, 1/12), touch.note + self.transpose)
      synth.source:setPitch(pitch)
    else
      synth.active = false                 -- not pressed, let envelope release
    end
    synth.volume = self:applyEnvelope(synth, dt)
    synth.source:setVolume(synth.volume)
    synth.duration = synth.duration + dt
  end
end

function sampler:assignSynth(touchId)
  -- find synth with longest duration
  maxDuration = -1
  selectedId = nil
  for id, synth in pairs(self.synths) do
    if type(id) == 'number' then        -- not yet assigned
      selectedId = id
      break
    elseif synth.duration > maxDuration then
      maxDuration = synth.duration
      selectedId = id
    end
  end
  -- move source to correct key
  self.synths[touchId] = self.synths[selectedId]
  self.synths[selectedId] = nil
  return self.synths[touchId]
end

function sampler:getSlopes(envelope)
  return {
    attack  = 1 / envelope.attack,
    decay   = -(1 - envelope.sustain) / envelope.decay,
    sustain = 0,
    release = - envelope.sustain / envelope.release,
  }
end

function sampler:applyEnvelope(synth, dt)
  if not synth.active then                                                -- release
    return math.max(0, synth.volume + self.slopes.release * dt)
  else
    if self.envelope.attack == 0 and synth.duration == 0 then
      return self.envelope.sustain
  elseif synth.duration < self.envelope.attack then                       -- attack
      return synth.volume + self.slopes.attack * dt
  elseif synth.duration < self.envelope.attack + self.envelope.decay then -- decay
      return synth.volume + self.slopes.decay * dt
  else                                                                    -- sustain
      return synth.volume
    end
  end
end

return sampler