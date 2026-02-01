-- Rotae Versantur
-- The Wheels Turn
--
-- Use the Arc to visualize and
-- control a four-track recording
-- and playback machine
--
-- Button release
--   Toggle Rolling (play/record)
--       or Stopped
--
-- Wheel
--   Set [MODE] for that track
--   Amp, Pan, Reverb, Freq
--
-- Button + Wheel 1
--   Seek all
--   Amp, Pan, Reverb, Freq
--
-- Button + Wheel 2
--   Select current MODE
--   Amp, Pan, Reverb, Freq
--
-- Button + Wheel 3
--   Select recording track
--
-- Button + Wheel 4
--   Select bounced tracks,
--   they then feed recording
--


local wheel_states = { "stopped", "rolling" }
local wheel_state = 1 -- stopped

local button_pressed = false

local shift_mode = "none" -- none, record, bounce, seek_all, wheel_mode

local record_focus_detail = 0
local record_focus = 0

local bounce_select_detail = 0
local bounce_select = 0

local maxFrames = 1 -- How long is the longest track

local mode_select_detail = 0
local mode_select = 0
local wheel_mode = "amp" -- amp, pan, reverb, freq_cutoff

local Wheel = {}
Wheel.__index = Wheel
Wheel.next_id = 1

function Wheel.new(options)
  -- local options = options or {}
  local self = {
    id = Wheel.next_id,
    amp = 1.0,
    ampDetail = 256,
    pan = 0.0,
    reverb = 0.0,
    freqCutoff = 0.0,
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

function Wheel:setupParams()
  params:add_group("wheel_" .. self.id, "Wheel " .. self.id, 4)
  params:add{
    type = "number",
    id = "amp_" .. self.id,
    name = "amp",
    min = 0,
    max = 30,
    default = self.amp,
    action = function(n)
      print("Wheel " .. self.id .. " amp action")
      self.amp = n
      local base = self.amp - 1
      self.ampDetail = math.floor((math.abs(base) ^ (1/3) * (base >= 0 and 1 or -1) + 1) * 256 + 0.5)
      engine.setAmp(self.id - 1, self.amp)
    end
  }
  -- params:add{
  --   type = "number",
  --   id = "ampDetail_" .. self.id,
  --   name = "amp detail",
  --   min = 1,
  --   max = 1024,
  --   default = self.ampDetail
  --   -- No callback since it is hidden anyway
  -- }
  -- params:hide("ampDetail_" .. self.id)

  params:add{
    type = "number",
    id = "pan_" .. self.id,
    name = "pan",
    min = -1,
    max = 1,
    default = self.pan,
    action = function(n)
      self.pan = n
      engine.setPan(self.id - 1, self.pan)
    end
  }

  params:add{
    type = "number",
    id = "reverb_" .. self.id,
    name = "reverb",
    min = 0,
    max = 1,
    default = self.reverb,
    action = function(n)
      self.reverb = n
      engine.setReverbMix(self.id - 1, self.reverb)
    end
  }

  params:add{
    type = "number",
    id = "freqCutoff_" .. self.id,
    name = "freqCutoff",
    min = -1,
    max = 1,
    default = self.freqCutoff,
    action = function(n)
      self.freqCutoff = n
      -- engine.setFreqCutoff(self.id - 1, self.freqCutoff)
    end
  }
end

function Wheel:toString()
  return        string.format("%.2f", self.amp) ..
         " " .. string.format("%.2f", self.pan) ..
         " " .. string.format("%.2f", self.reverb) ..
         " " .. self.position ..
         " " .. self.currentFrame ..
         " " .. self.frames
         -- " " .. tostring(self.record) ..
         -- " " .. tostring(self.bounce)
end


function Wheel:drawScreen()
  base_x = 15
  y = 32
  x = base_x + ((self.id - 1) * 32)

  -- Wheel outline
  screen.level(16)
  screen.line_width(1)
  screen.circle(x, y, 15)
  screen.stroke()

  -- Indicate if we are recording
  if self.record then
    screen.move(x, y - 16)
    screen.text_center("rec")
    screen.stroke()
  end

  -- Indicate if we are bouncing
  if self.bounce then
    screen.move(x, y + 20)
    screen.text_center("bounce")
    screen.stroke()
  end

  -- level for the current mode
  screen.line_width(3)
  screen.level(4)

  local wheelLabel = self.id


  -- elseif wheel_mode == "pan" then
  --   local panLed = math.floor(self.pan * 16) + 1
  --   if panLed > 0 then
  --     for ledNum = 1, panLed do
  --       arc:led(self.id, ledNum, 4)
  --     end
  --   else
  --     for ledNum = panLed, 1 do
  --       arc:led(self.id, ledNum, 4)
  --     end
  --   end
  -- elseif wheel_mode == "reverb" then
  --   local reverbLed = math.floor(self.reverb * 64) + 1
  --   for ledNum = 1, reverbLed do
  --     arc:led(self.id, ledNum, 4)
  --   end
  -- elseif wheel_mode == "freq_cutoff" then
  --   local freqCutoffLed = math.floor(self.freqCutoff * 16) + 1
  --   if freqCutoffLed > 0 then
  --     for ledNum = 1, freqCutoffLed do
  --       arc:led(self.id, ledNum, 4)
  --     end
  --   end


  -- screen.arc(x, y, 13, 0, 2)




  if not button_pressed then
    wheelLabel = self.id

    if wheel_mode == "amp" then
      local arcStart = -1 * (math.pi / 2)
      local arcLength = (self.ampDetail / 1024) * 2 * math.pi
      screen.arc(x, y, 13, arcStart, arcStart + arcLength)
    elseif wheel_mode == "pan" then
      if self.pan < 0 then
        local arcLength = (-1 * self.pan) * math.pi / 2
        local arcStart = 1.5 * math.pi - arcLength
        screen.arc(x, y, 13, arcStart, arcStart + arcLength)
      else
        local arcStart = -1 * (math.pi / 2)
        local arcLength = self.pan * math.pi / 2
        screen.arc(x, y, 13, arcStart, arcStart + arcLength)
      end
    elseif wheel_mode == "reverb" then
      local arcStart = -1 * (math.pi / 2)
      local arcLength = self.reverb * 2 * math.pi
      screen.arc(x, y, 13, arcStart, arcStart + arcLength)
    end

    screen.stroke() -- Draw the arc

    -- Or do we label it with a numeric value?
  else
    if self.id == 1 then
      wheelLabel = "seek"
    elseif self.id == 2 then
      wheelLabel = "mode"
    elseif self.id == 3 then
      wheelLabel = "rec"
    elseif self.id == 4 then
      wheelLabel = "bounce"
    end

  -- elseif shift_mode == "wheel_mode" then
  --   if self.id == 1 then
  --     wheelLabel = "amp"
  --   elseif self.id == 2 then
  --     wheelLabel = "pan"
  --   elseif self.id == 3 then
  --     wheelLabel = "rev"
  --   elseif self.id == 4 then
  --     wheelLabel = "tone"
  --   end
  end

  screen.move(x, y+3)
  screen.text_center(wheelLabel)
  screen.stroke()


    if shift_mode == "seek_all" and self.id == 1 then
      screen.level(8)
      screen.blend_mode("xor")
      screen.circle(x, y, 12)
      screen.fill()
      screen.blend_mode("over")
    elseif shift_mode == "wheel_mode" and self.id == 2 then
      screen.level(8)
      screen.blend_mode("xor")
      screen.circle(x, y, 12)
      screen.fill()
      screen.blend_mode("over")
    elseif shift_mode == "record" and self.id == 3 then
      screen.level(8)
      screen.blend_mode("xor")
      screen.circle(x, y, 12)
      screen.fill()
      screen.blend_mode("over")
    elseif shift_mode == "bounce" and self.id == 4 then
      screen.level(8)
      screen.blend_mode("xor")
      screen.circle(x, y, 12)
      screen.fill()
      screen.blend_mode("over")
    end

end

-- function Wheel:setAmp(amp)
--   self.amp = amp
-- end
--
-- function Wheel:setAmpDetail(ampDetail)
--   self.ampDetail = ampDetail
-- end

function Wheel:addDeltaAmp(delta)
  print("addDeltaAmp", self.id, delta)
  -- If x is 0..1 (in 1/1024'th increments)
  -- (x*4 - 1)^3 + 1
  -- this gives us an amp of 1 at 1/4 turn, 2 at 1/2 turn, and exponential thereafter up to 28
  self.ampDetail = util.clamp(self.ampDetail + delta, 0, 1023)
  self.amp = (((self.ampDetail / 1024) * 4) - 1) ^ 3 + 1
  print("  amp", self.amp)
  -- self.amp = util.clamp(self.amp + ((delta / 1024) * 4), 0, 4)
  engine.setAmp(self.id - 1, self.amp)
  params:set("amp_" .. self.id, self.amp)
  -- params:set("ampDetail_" .. self.id, self.ampDetail)
end

function Wheel:addDeltaReverb(delta)
  print("addDeltaReverb", self.id, delta)
  self.reverb = util.clamp(self.reverb + ((delta / 1024) * 4), 0, 1)
  engine.setReverbMix(self.id - 1, self.reverb)
  params:set("reverb_" .. self.id, self.reverb)
end

function Wheel:addDeltaPan(delta)
  print("addDeltaPan", self.id, delta)
  self.pan = util.clamp(self.pan + ((delta / 1024) * 4), -1, 1)
  engine.setPan(self.id - 1, self.pan)
  params:set("pan_" .. self.id, self.pan)
end

function Wheel:addDeltaFreqCutoff(delta)
  print("addDeltaFreqCutoff", self.id, delta)
  -- The idea here is to go from -1 .. 1
  -- When it is negative we do a low-pass cutoff filter
  -- When it is positive we do a high-pass cutoff filter
  self.freqCutoff = util.clamp(self.freqCutoff + ((delta / 1024) * 4), -1, 1)
  -- engine.setFreqCutoff(self.id - 1, self.freqCutoff)
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
function Wheel:drawArc(arc)

  if wheel_mode == "amp" then
    local ampLed = math.floor(self.ampDetail / 16) + 1
    for ledNum = 1, ampLed do
      arc:led(self.id, ledNum, 4)
    end
  elseif wheel_mode == "pan" then
    local panLed = math.floor(self.pan * 16) + 1
    if panLed > 0 then
      for ledNum = 1, panLed do
        arc:led(self.id, ledNum, 4)
      end
    else
      for ledNum = panLed, 1 do
        arc:led(self.id, ledNum, 4)
      end
    end
  elseif wheel_mode == "reverb" then
    local reverbLed = math.floor(self.reverb * 64) + 1
    for ledNum = 1, reverbLed do
      arc:led(self.id, ledNum, 4)
    end
  elseif wheel_mode == "freq_cutoff" then
    local freqCutoffLed = math.floor(self.freqCutoff * 16) + 1
    if freqCutoffLed > 0 then
      for ledNum = 1, freqCutoffLed do
        arc:led(self.id, ledNum, 4)
      end
    end
  end

  -- Indicate which is currently recording with some stripes
  if self.record then
    for i = 1, 64, 4 do
      arc:led(self.id, i, 2)
    end
  end

  -- Make the current position the brightest
  arc:led(self.id, math.floor(self.position) + 1, 15)
end


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


-- Wheel
--   Set [MODIFIER] for that track
--   Amp, Pan, Reverb
--
-- Button + Wheel 1
--   Select current MODIFIER
--   Amp, Pan, Reverb, Low/High pass
--
-- Button + Wheel 2
--   Seek
--
-- Button + Wheel 3
--   Select recording track
--
-- Button + Wheel 4
--   Select bounced tracks,
--   they then feed recording
  -- if wheel_states[wheel_state] == "stopped" then
    if not button_pressed then
      if wheel_mode == "amp" then
        wheels[wheelNum]:addDeltaAmp(delta)
      elseif wheel_mode == "pan" then
        wheels[wheelNum]:addDeltaPan(delta)
      elseif wheel_mode == "reverb" then
        wheels[wheelNum]:addDeltaReverb(delta)
      elseif wheel_mode == "freq_cutoff" then
        wheels[wheelNum]:addDeltaFreqCutoff(delta)
      end
    else

      -- The button is pressed
      if wheelNum == 1 then
        shift_mode = "seek_all"
        for wheel_num = 1, 4 do
          wheels[wheel_num]:addDeltaPosition(delta)
        end
      elseif wheelNum == 2 then
        shift_mode = "wheel_mode"
        mode_select_detail = util.clamp(mode_select_detail + delta, 0, 300)
        mode_select = mode_select_detail // 75
        print("shift wheel mode select", shift_mode, mode_select_detail, mode_select)
        if mode_select == 0 then
          wheel_mode = "amp"
        elseif mode_select == 1 then
          wheel_mode = "pan"
        elseif mode_select == 2 then
          wheel_mode = "reverb"
        elseif mode_select == 3 then
          wheel_mode = "freq_cutoff"
        end
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
          wheels[4].bounce = true
          engine.bounceStart(3)
        end
        if bounce_select % 8 > 3 then
          wheels[3].bounce = true
          engine.bounceStart(2)
        end
        if bounce_select % 4 > 1 then
          wheels[2].bounce = true
          engine.bounceStart(1)
        end
        if bounce_select % 2 > 0 then
          wheels[1].bounce = true
          engine.bounceStart(0)
        end
      end

    end

  -- elseif wheel_states[wheel_state] == "rolling" then
  --
  --   if button_pressed then
  --     shift_mode = "seek"
  --     wheels[wheelNum]:addDeltaPosition(delta)
  --     -- shift_mode = "rate"
  --     -- wheels[wheelNum]:addDeltaRate(delta)
  --   else
  --     wheels[wheelNum]:addDeltaAmp(delta)
  --   end
  --
  -- end

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

        -- Rewind everything to the beginning
        for wheelNum, wheel in ipairs(wheels) do
          engine.setPosition(wheelNum - 1, 0)
        end

        -- Also de-select (disarm) recording, it is to dangerous to leave
        wheels[record_focus].record = false
        record_focus = 0
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

  --------------------
  -- Screen drawing --
  --------------------

  screen.clear()
  screen.stroke()

  screen.level(15)
  screen.rect(0, 0, 128, 7)
  screen.fill()

  screen.level(0)

  screen.move(127, 6)
  screen.text_right("ROTAE VERSANTUR")

  screen.move(1, 6)
  if wheel_states[wheel_state] == "rolling" then
    if record_focus > 0 then
      screen.text("RECORDING")
    else
      screen.text("PLAYING")
    end
  else
    screen.text("STOPPED")
  end

  screen.level(15)

  screen.move(15 + 32 * 0, 63)
  screen.text_center("amp")
  screen.move(15 + 32 * 1, 63)
  screen.text_center("pan")
  screen.move(15 + 32 * 2, 63)
  screen.text_center("rev")
  screen.move(15 + 32 * 3, 63)
  screen.text_center("tone")

  if wheel_mode == "amp" then
    screen.blend_mode("xor")
    screen.rect(0 + 32 * 0, 56, 32, 8)
    screen.fill()
    screen.blend_mode("over")
  elseif wheel_mode == "pan" then
    screen.blend_mode("xor")
    screen.rect(0 + 32 * 1, 56, 32, 8)
    screen.fill()
    screen.blend_mode("over")
  elseif wheel_mode == "reverb" then
    screen.blend_mode("xor")
    screen.rect(0 + 32 * 2, 56, 32, 8)
    screen.fill()
    screen.blend_mode("over")
  elseif wheel_mode == "freq_cutoff" then
    screen.blend_mode("xor")
    screen.rect(0 + 32 * 3, 56, 32, 8)
    screen.fill()
    screen.blend_mode("over")
  end

  -- screen.text("Mode: " .. wheel_mode)
  screen.stroke()

  -- if button_pressed then
  --   screen.move(64, 5)
  --   if shift_mode == "none" then
  --     screen.text_center("shift")
  --   elseif shift_mode == "seek" then
  --     screen.text_center("seek")
  --   elseif shift_mode == "wheel_mode" then
  --     screen.text_center("select mode")
  --   elseif shift_mode == "record" then
  --     screen.text_center("select rec")
  --   elseif shift_mode == "bounce" then
  --     screen.text_center("select bounce")
  --   end
  --   screen.stroke()
  -- end

  -- screen.move(0,5)
  -- screen.text("maxFrames: " .. maxFrames .. " Mode: " .. wheel_mode)
  --
  -- screen.move(0,11)
  -- screen.text("Wheels: " .. wheel_states[wheel_state] .. " Shift: " .. shift_mode)
  --
  -- for i, wheel in ipairs(wheels) do
  --   screen.move(0, 11 + i * 8)
  --   screen.text(i ..": " .. wheel:toString())
  -- end

  -- if shift_mode == "none" or shift_mode == "seek" or shift_mode == "seek_all" then
  --   for i, wheel in ipairs(wheels) do
  --     wheel:drawScreen()
  --   end
  -- end

  -- screen.update()

  for i, wheel in ipairs(wheels) do
    wheel:drawScreen()
  end

  -----------------
  -- Arc drawing --
  -----------------

  my_arc:all(0)

  if shift_mode == "none" or shift_mode == "seek" or shift_mode == "seek_all" then
    for i, wheel in ipairs(wheels) do
      wheel:drawArc(my_arc)
      -- wheel:drawScreen()
    end
  elseif shift_mode == "wheel_mode" then
    local wheel_focus = 0
    if wheel_mode == "amp" then
      wheel_focus = 1
    elseif wheel_mode == "pan" then
      wheel_focus = 2
    elseif wheel_mode == "reverb" then
      wheel_focus = 3
    elseif wheel_mode == "freq_cutoff" then
      wheel_focus = 4
    end

    if wheel_focus < 1 then
      my_arc:all(3)
    else
      for i = 1, 64 do
        my_arc:led(wheel_focus, i, 15)
      end
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

  screen.update()
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

function setup_global_params()
  params:add{type = "number", id = "test1", name = "Test 1", min = 1, max = 10, default = 3}
end

function cleanup()
  params:write()
end

function init()

  setup_global_params()

  wheels[1]:setupParams()
  wheels[2]:setupParams()
  wheels[3]:setupParams()
  wheels[4]:setupParams()

  params:default()
  params:bang()

  print("Inside of init")
  os.execute("mkdir -p /home/we/dust/audio/rotae_versantur")

  -- engine.loadFromFile(0, "/home/we/dust/code/repl-looper/audio/musicbox/Wouldnt-Mind-Workin-From-Sun-To-Sun_2011121108_001_00-01-05.ogg")
  -- engine.loadFromFile(1, "/home/we/dust/code/repl-looper/audio/musicbox/Wouldnt-Mind-Workin-From-Sun-To-Sun_2011121108_002_00-01-32.ogg")
  -- engine.loadFromFile(2, "/home/we/dust/code/repl-looper/audio/musicbox/Wouldnt-Mind-Workin-From-Sun-To-Sun_2011121108_003_00-01-52.ogg")
  -- engine.loadFromFile(3, "/home/we/dust/code/repl-looper/audio/musicbox/William-Gagnon_DR000067_003_00-00-47.ogg")

  -- Load previous recordings
  clock.run(function()
    engine.loadFromFile(0, "/home/we/dust/audio/rotae_versantur/recording_buffer_0.wav")
    clock.sleep(0.5)
    engine.loadFromFile(1, "/home/we/dust/audio/rotae_versantur/recording_buffer_1.wav")
    clock.sleep(0.5)
    engine.loadFromFile(2, "/home/we/dust/audio/rotae_versantur/recording_buffer_2.wav")
    clock.sleep(0.5)
    engine.loadFromFile(3, "/home/we/dust/audio/rotae_versantur/recording_buffer_3.wav")
  end)
end

