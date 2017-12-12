local sampler = {}
sampler.__index = sampler

local efx = require('efx')


function sampler.new(settings)
  local self = setmetatable({}, sampler)
  self.synths = {} -- collection of sources in an array
  self.masterVolume = 1
  self.looped       = settings.looped or false
  self.transpose = settings.transpose or 0
  self.envelope = settings.envelope or { attack  = 0,     -- default envelope best suited for
                                         decay   = 0,     -- one-shot samples, not for loopes
                                         sustain = 1,
                                         release = 0.35 }
  local synthCount  = settings.synthCount or 6

  self.samples = {}
  -- prepare samples that will be used by synths
  for i,sample in ipairs(settings) do
    local decoder = love.sound.newDecoder(sample.path)
    sample.soundData = love.sound.newSoundData(decoder)
    sample.note = sample.note or 0
    sample.velocity  = sample.velocity or 0.8
    table.insert(self.samples, sample)
  end

  -- initialize synths which will take care of playing samples as per notes
  for i=1, synthCount do
    self.synths[i] = {
      source = nil,
      volume = 0,
      active = false,
      duration = math.huge,
      enveloped = 0,
    }
  end
  return self
end

function sampler:update(dt, touches)
  -- hunt for new touches and play them
  for id, touch in pairs(touches) do
    if touch.noteRetrigger then
      -- break connection between existing synth and touch
      for i,synth in ipairs(self.synths) do
        if synth.touchId == id then
          synth.touchId = nil
        end
      end
      self:assignSynth(id, touch)
    end
  end
  -- update sources for existing touches
  for i, synth in ipairs(self.synths) do
    if synth.source then
      synth.enveloped = self:applyEnvelope(dt, synth.enveloped, synth.active, synth.duration)
      local volume = synth.enveloped * self.masterVolume
      synth.source:setVolume(volume)

      local touch = touches[synth.touchId]
      if touch and touch.note then           -- update existing note
        local pitch = self:noteToPitch(touch.note, -synth.note + self.transpose)
        synth.source:setPitch(pitch)
        touch.volume = math.max(volume, touch.volume or 0) -- report max volume for visualization
      else
        synth.active = false                 -- not pressed, let envelope release
      end
    end
    synth.duration = synth.duration + dt
  end
end

function sampler:noteToPitch(note, transpose)
  -- equal temperament
  return math.pow(math.pow(2, 1/12), note + transpose)
end

function sampler:assignSynth(touchId, touch)
  -- find synth with longest duration
  maxDuration = -100
  selected = nil
  for i, synth in ipairs(self.synths) do
    if synth.duration > maxDuration + (synth.active and 10 or 0) then
      maxDuration = synth.duration
      selected = i
    end
  end
  -- move source to correct key
  local synth = self.synths[selected]
  -- init and play
  if synth.source then
    synth.source:stop()
  end
  local sample = self:assignSample(touch.note, touch.pressure)
  synth.source = love.audio.newSource(sample.soundData)
  synth.touchId = touchId
  synth.duration = 0
  synth.enveloped = 0
  synth.active = true
  synth.note = sample.note
  efx.applyFilter(synth.source)
  if touch.location then
    synth.source:setPosition(touch.location[1] or 0, touch.location[2] or 0, 0.5)
  end
  synth.source:setLooping(self.looped)
  synth.source:play()
  return synth
end

function sampler:assignSample(note, velocity)
  -- first look for closest pitch, then for closest sample velocity
  local bestFitness = math.huge
  local selected = nil
  for i, sample in ipairs(self.samples) do
    local fitness = 10 * math.abs(sample.note - note) + math.abs(sample.velocity - velocity)
    if fitness < bestFitness then
      selected = i
      bestFitness = fitness
    end
  end
  --[[
  log('selected' .. self.samples[selected].path,
    'note', note,
    'distance', self.samples[selected].note - note,
    'pitch', self:noteToPitch(note, self.samples[selected].note + self.transpose))
  --]]
  return self.samples[selected]
end

function sampler:applyEnvelope(dt, vol, active, duration)
  if active then
    if self.envelope.attack == 0 and duration < 0.01 then             -- flat
      return self.envelope.sustain
    elseif duration < self.envelope.attack then                       -- attack
      return vol + 1 / self.envelope.attack * dt
    elseif duration < self.envelope.attack + self.envelope.decay then -- decay
      return vol - (1 - self.envelope.sustain) / self.envelope.decay * dt
    else                                                              -- sustain
      return vol
    end
  else                                                                -- release
    return math.max(0, vol - self.envelope.sustain / self.envelope.release * dt)
  end
end

return sampler