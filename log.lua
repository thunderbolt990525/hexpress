local log_entries = {}
local log_lines = 40

local trace_entries = {}


local displayLog = true
local displayTrace = true

local moduleInitialized = false -- log module is initialized lazily
local actualLoveDraw
local font
local fontSize = 16

local function imposterLoveDraw()
  actualLoveDraw()
  local fader = 255
  love.graphics.setFont(font)
  for i = #log_entries, #log_entries - log_lines, -1 do
      love.graphics.setColor(255, 255, 200, fader)
      love.graphics.print(log_entries[i] or '', 5, 5 + (#log_entries - i) * fontSize)
      fader = fader - 255 / log_lines
  end
end

function init()
  moduleInitialized = true
  actualLoveDraw = love.draw
  print(actualLoveDraw)
  love.draw = imposterLoveDraw
  font = love.graphics.newFont("Ubuntu-B.ttf", fontSize)
end

function log(s, ...)
  if not moduleInitialized then
    init()
  end
  local line = string.format(s, ...)
  print(line)
  log_entries[#log_entries + 1] = line
end
