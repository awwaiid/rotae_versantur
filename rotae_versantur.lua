-- Rotae Versantur
-- The Wheels Turn
--
-- Use the Arc to visualize and
-- control a four-track recording
-- and playback machine
--
-- Button release
--   Toggle Rolling vs Stopped
--
-- Rolling Wheel
--   Set amp for that track
--
-- Button + Rolling Wheel
--   Seek to position on track
--
-- Stopped Wheel
--   Seek to position on track
--
-- Button + Stopped Wheel 1
--   Seek to position all tracks
--
-- Button + Stopped Wheel 2
--   Select unmuted tracks
--
-- Button + Stopped Wheel 3
--   Select recording track
--
-- Button + Stopped Wheel 4
--   Select bounced tracks,
--   they then feed recording
--


local wheel_states = { "stopped", "rolling" }
local wheel_state = 1 -- stopped

local button_pressed = false

local action_modes = { "seek", "amp", "pan", "reverb" }
local stopped_action_mode = 1 -- seek
local rolling_action_mode = 2 -- amp

local shift_mode = "none" -- none, record, bounce, seek

local record_focus_detail = 0
local record_focus = 0

local bounce_select_detail = 0
local bounce_select = 0


local Wheel = {}
Wheel.__index = Wheel
Wheel.next_id = 1

function Wheel.new(options)
  -- local options = options or {}
  local self = {
    id = Wheel.next_id,
    amp = 1.0,
    pan = 0.0,
    reverb = 0.0,
    position = 0,
    record = false,
    bounce = false,
    frames = 1,
    rate = 1.0,
  }
  Wheel.next_id = Wheel.next_id + 1
  setmetatable(self, Wheel)
  return self
end

function Wheel:toString()
  return self.amp ..
         " " .. self.pan ..
         " " .. self.reverb ..
         " " .. self.position ..
         " " .. tostring(self.record) ..
         " " .. tostring(self.bounce)
end

function Wheel:addDeltaAmp(delta)
  print("addDeltaAmp", self.id, delta)
  self.amp = util.clamp(self.amp + (delta / 256), 0, 4)
  engine.setAmp(self.id - 1, self.amp)
end

function Wheel:addDeltaRate(delta)
  print("addDeltaRate", self.id, delta)
  self.rate = util.clamp(self.rate + (delta / 256), 0, 4)
  engine.setRate(self.id - 1, self.rate)
end

function Wheel:addDeltaPosition(d)
  print("addDeltaPosition 2", self.id, d)
  self.position = self.position + d
  -- Seek to this position in the playback
  engine.setPosition(self.id - 1, self.position / 64 * self.frames)
end

function Wheel:draw(arc)
  -- 1/4 = 1 so we can max amp of 4
  local ampLed = math.floor(self.amp * (64/4)) + 1
  if self.amp == 0.0 then
    ampLed = 0
  end
  for ledNum = 1, ampLed do
    arc:led(self.id, ledNum, 4)
  end

  arc:led(self.id, self.position, 15)
end

-- function Editor:redraw()


local wheels = {
  Wheel.new(),
  Wheel.new(),
  Wheel.new(),
  Wheel.new()
}

engine.name = "RotaeVersantur"

local my_arc = arc.connect()
my_arc:all(1)
my_arc:refresh()

print("hello")

button_pressed = false

my_arc.delta = function(wheelNum, delta)

-- Rolling Wheel
--   Set amp for that track
--
-- Button + Rolling Wheel
--   Seek to position on track
--
-- Stopped Wheel
--   Seek to position on track
--
-- Button + Stopped Wheel 1
--   Seek to position all tracks
--
-- Button + Stopped Wheel 2
--   Select unmuted tracks
--
-- Button + Stopped Wheel 3
--   Select recording track
--
-- Button + Stopped Wheel 4
--   Select bounced tracks,
--   they then feed recording

  if wheel_states[wheel_state] == "stopped" then
    if not button_pressed then
      wheels[wheelNum]:addDeltaPosition(delta)
    else

      -- The button is pressed
      if wheelNum == 1 then
        shift_mode = "?"
      elseif wheelNum == 2 then
        shift_mode = "?"
      elseif wheelNum == 3 then
        shift_mode = "record"
        record_focus_detail = util.clamp(record_focus_detail + delta, 0, 300)
        record_focus = record_focus_detail // 75
        print("shift record", shift_mode, record_focus_detail, record_focus)
        for wheel_num = 1, 4 do
          wheels[wheel_num].record = false
        end
        if record_focus > 0 then
          wheels[record_focus].record = true
        end
      end

      if wheelNum == 4 then
        shift_mode = "bounce"
        bounce_select_detail = util.clamp(bounce_select_detail + delta, 0, 255)
        bounce_select = bounce_select_detail // 16
        print("bounce select", bounce_select_detail, bounce_select)
        for wheel_num = 1, 4 do
          wheels[wheel_num].bounce = false
        end
        if bounce_select % 16 > 7 then
          wheels[1].bounce = true
        end
        if bounce_select % 8 > 3 then
          wheels[2].bounce = true
        end
        if bounce_select % 4 > 1 then
          wheels[3].bounce = true
        end
        if bounce_select % 2 > 0 then
          wheels[4].bounce = true
        end
      end

    end

  elseif wheel_states[wheel_state] == "rolling" then

    if button_pressed then
      shift_mode = "seek"
      wheels[wheelNum]:addDeltaPosition(delta)
      -- shift_mode = "rate"
      -- wheels[wheelNum]:addDeltaRate(delta)
    else
      wheels[wheelNum]:addDeltaAmp(delta)
    end

  end

  redraw()

end

my_arc.key = function(n, z)
  print("key", n, z)

  if z == 1 and not button_pressed then
    button_pressed = true
  elseif z == 0 and button_pressed and shift_mode == "none" then
    print("button released")
    -- maybe have a timeout eventually
    button_pressed = false
    print("wheel_state", wheel_state)
    wheel_state = ((wheel_state + 2) % 2) + 1
    print("wheel_state", wheel_state)
    if wheel_states[wheel_state] == "rolling" then
      -- engine.play("/home/we/dust/audio/x0x/808/808-RS.wav", 1, 0, 0, 1, 0, 1, 1)
      -- engine.loadFromFile("/home/we/dust/audio/x0x/808/808-RS.wav")
      for wheelNum, wheel in ipairs(wheels) do
        engine.setRate(wheelNum - 1, 1)
      end
    elseif wheel_states[wheel_state] == "stopped" then
      for wheelNum, wheel in ipairs(wheels) do
        engine.setRate(wheelNum - 1, 0)
      end
    end

  else
    -- Release after doing some shift-mode actions
    -- so dont' change the wheel state
    shift_mode = "none"
    button_pressed = false
  end

  redraw()
end


function redraw()
  screen.clear()
  screen.move(0,10)
  screen.level(15)
  screen.text("Wheels: " .. wheel_states[wheel_state] .. " shift " .. shift_mode)

  for i, wheel in ipairs(wheels) do
    screen.move(0, 10 + i * 10)
    screen.text("Wheel " .. i ..": " .. wheel:toString())
  end
  screen.update()

  my_arc:all(0)

  if shift_mode == "none" or shift_mode == "seek" then
    for i, wheel in ipairs(wheels) do
      wheel:draw(my_arc)
    end
  elseif shift_mode == "record" then
    if record_focus < 1 then
      my_arc:all(3)
    else
      for i = 1, 64 do
        my_arc:led(record_focus, i, 15)
      end
    end
  elseif shift_mode == "bounce" then
    for n = 1, 4 do
      if wheels[n].bounce then
        for i = 1, 64 do
          my_arc:led(n, i, 15)
        end
      end
    end
    -- Indicate which is currently recording with some stripes
    if record_focus > 0 then
      for i = 1, 64, 4 do
        my_arc:led(record_focus, i, 4)
      end
    end
  end

  my_arc:refresh()

end

function osc.event(path, args, from)
  if path == "/playPosition" then
    local wheelNum = args[1] + 1
    local frames = args[2]
    local startFrame = args[3]
    local endFrame = args[4]
    local pos = args[5]
    print("osc event set playPosition", wheelNum, frames, startFrame, endFrame, pos)
    wheels[wheelNum].position = math.floor((pos / frames) * 64)
    wheels[wheelNum].frames = frames
    redraw()
  else
    print("Other OSC path", path)
  end
end

function init()
  print("Inside of init")
  engine.loadFromFile(0, "/home/we/dust/code/repl-looper/audio/musicbox/Wouldnt-Mind-Workin-From-Sun-To-Sun_2011121108_001_00-01-05.ogg")
  engine.loadFromFile(1, "/home/we/dust/code/repl-looper/audio/musicbox/Wouldnt-Mind-Workin-From-Sun-To-Sun_2011121108_002_00-01-32.ogg")
  engine.loadFromFile(2, "/home/we/dust/code/repl-looper/audio/musicbox/Wouldnt-Mind-Workin-From-Sun-To-Sun_2011121108_003_00-01-52.ogg")
  engine.loadFromFile(3, "/home/we/dust/code/repl-looper/audio/musicbox/William-Gagnon_DR000067_003_00-00-47.ogg")
end

