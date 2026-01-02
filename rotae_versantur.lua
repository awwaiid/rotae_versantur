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

local maxFrames = 1

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
    currentFrame = 0,
    rate = 1.0,
  }
  Wheel.next_id = Wheel.next_id + 1
  setmetatable(self, Wheel)
  return self
end

function Wheel:toString()
  return self.amp ..
         -- " " .. self.pan ..
         -- " " .. self.reverb ..
         " " .. self.position ..
         " " .. self.currentFrame ..
         " " .. self.frames
         -- " " .. tostring(self.record) ..
         -- " " .. tostring(self.bounce)
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

-- Relative to own length
-- function Wheel:addDeltaPosition(d)
--   print("addDeltaPosition", self.id, d)
--   self.position = util.clamp(self.position + d, 0, 64)
--   self.currentFrame = util.clamp(self.position / 64 * self.frames, 0, self.frames)
--   -- Seek to this position in the playback
--   engine.setPosition(self.id - 1, self.currentFrame)
-- end

-- Relative to max length
function Wheel:addDeltaPosition(d)
  print("addDeltaPosition", self.id, d)
  self.position = util.clamp(self.position + d, 0, 64)
  self.currentFrame = util.clamp(self.position / 64 * maxFrames, 0, maxFrames)
  -- Seek to this position in the playback
  engine.setPosition(self.id - 1, self.currentFrame)
end

local total_times = 0
function Wheel:draw(arc)
  -- 1/4 = 1 so we can max amp of 4
  local ampLed = math.floor(self.amp * (64/4)) + 1
  if self.amp == 0.0 then
    ampLed = 0
  end
  for ledNum = 1, ampLed do
    arc:led(self.id, ledNum, 4)
  end

  -- Indicate which is currently recording with some stripes
  if self.record then
    for i = 1, 64, 4 do
      arc:led(self.id, i, 2)
    end
  end

  -- if total_times < 100 then
  --   print("arc:led(" .. self.id .. ", math.floor(" .. self.position .. ") + 1, 15)")
  --   total_times = total_times + 1
  -- end
  arc:led(self.id, math.floor(self.position), 15)
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
        shift_mode = "seek_all"
        for wheel_num = 1, 4 do
          wheels[wheel_num]:addDeltaPosition(delta)
        end
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
          engine.bounceStop(wheel_num - 1)
        end
        if bounce_select % 16 > 7 then
          wheels[1].bounce = true
          engine.bounceStart(0)
        end
        if bounce_select % 8 > 3 then
          wheels[2].bounce = true
          engine.bounceStart(1)
        end
        if bounce_select % 4 > 1 then
          wheels[3].bounce = true
          engine.bounceStart(2)
        end
        if bounce_select % 2 > 0 then
          wheels[4].bounce = true
          engine.bounceStart(3)
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
      if record_focus > 0 then
        engine.recordStart(record_focus - 1)
      end
      for wheelNum, wheel in ipairs(wheels) do
        engine.setRate(wheelNum - 1, 1)
      end
    elseif wheel_states[wheel_state] == "stopped" then
      for wheelNum, wheel in ipairs(wheels) do
        engine.setRate(wheelNum - 1, 0)
      end
      if record_focus > 0 then
        engine.recordStop(record_focus - 1)
        for wheelNum, wheel in ipairs(wheels) do
          engine.setPosition(wheelNum - 1, 0)
        end
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
  screen.level(15)

  screen.move(0,5)
  screen.text("maxFrames: " .. maxFrames)

  screen.move(0,10)
  screen.text("Wheels: " .. wheel_states[wheel_state] .. " Shift: " .. shift_mode)

  for i, wheel in ipairs(wheels) do
    screen.move(0, 10 + i * 10)
    screen.text(i ..": " .. wheel:toString())
  end
  screen.update()

  my_arc:all(0)

  if shift_mode == "none" or shift_mode == "seek" or shift_mode == "seek_all" then
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

local total_times2 = 0
function osc.event(path, args, from)
  if path == "/playPosition" then
    local wheelNum = args[1] + 1
    local frames = args[2]
    local startFrame = args[3]
    local endFrame = args[4]
    local pos = args[5]
    if wheels[wheelNum].frames - 1 ~= frames then
      print("osc event set playPosition", wheelNum, frames, startFrame, endFrame, pos)
    end
    wheels[wheelNum].frames = frames + 1
    wheels[wheelNum].currentFrame = pos
    if total_times2 < 10 then
      print("/playPosition ", frames, pos)
      total_times2 = total_times2 + 1
  end
    -- relative position
    -- wheels[wheelNum].position = util.clamp(math.floor((pos / (frames + 1)) * 64), 0, 64)
    -- position based on max frame
    wheels[wheelNum].position = util.clamp(math.floor((math.min(pos, frames) / maxFrames) * 64), 0, 64)
    redraw()
  elseif path == "/fileLoaded" then
    local wheelNum = args[1] + 1
    local numFrames = args[2]
    print("osc fileLoaded wheel " .. wheelNum .. " frames " .. numFrames)
    wheels[wheelNum].frames = numFrames
    -- Resize all wheels to the max frame size
    maxFrames = 1
    for i = 1, 4 do
      print("  wheels[" .. i .. "] frames: " .. wheels[i].frames)
      if wheels[i].frames > maxFrames then
        maxFrames = wheels[i].frames
      end
    end
    print("setting all loops to end at " .. maxFrames)
    for i = 1, 4 do
      engine.setLength(i - 1, maxFrames)
    end
  else
    print("Other OSC path", path)
  end
end

function init()
  print("Inside of init")
  os.execute("mkdir -p /home/we/dust/audio/rotae_versantur")

  -- engine.loadFromFile(0, "/home/we/dust/code/repl-looper/audio/musicbox/Wouldnt-Mind-Workin-From-Sun-To-Sun_2011121108_001_00-01-05.ogg")
  -- engine.loadFromFile(1, "/home/we/dust/code/repl-looper/audio/musicbox/Wouldnt-Mind-Workin-From-Sun-To-Sun_2011121108_002_00-01-32.ogg")
  -- engine.loadFromFile(2, "/home/we/dust/code/repl-looper/audio/musicbox/Wouldnt-Mind-Workin-From-Sun-To-Sun_2011121108_003_00-01-52.ogg")
  -- engine.loadFromFile(3, "/home/we/dust/code/repl-looper/audio/musicbox/William-Gagnon_DR000067_003_00-00-47.ogg")

  -- Load previous recordings
  engine.loadFromFile(0, "/home/we/dust/audio/rotae_versantur/recording_buffer_0.wav")
  engine.loadFromFile(1, "/home/we/dust/audio/rotae_versantur/recording_buffer_1.wav")
  engine.loadFromFile(2, "/home/we/dust/audio/rotae_versantur/recording_buffer_2.wav")
  engine.loadFromFile(3, "/home/we/dust/audio/rotae_versantur/recording_buffer_3.wav")
end

