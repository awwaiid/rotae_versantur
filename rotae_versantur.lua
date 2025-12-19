
local reel_states = { "stopped", "rolling" }
local reel_state = 1 -- stopped

local button_pressed = false

local action_modes = { "seek", "amp", "pan", "reverb" }
local stopped_action_mode = 1 -- seek
local rolling_action_mode = 2 -- amp

local shift_mode = "none" -- none, record, bounce

local record_focus_detail = 0
local record_focus = 0

local bounce_select_detail = 0
local bounce_select = 0


local Reel = {}
Reel.__index = Reel
Reel.next_id = 1

function Reel.new(options)
  -- local options = options or {}
  local self = {
    id = Reel.next_id,
    amp = 1,
    pan = 0,
    reverb = 0,
    position = 0,
    record = false,
    bounce = false
  }
  Reel.next_id = Reel.next_id + 1
  setmetatable(self, Reel)
  return self
end

function Reel:toString()
  return self.amp ..
         " " .. self.pan ..
         " " .. self.reverb ..
         " " .. self.position ..
         " " .. tostring(self.record) ..
         " " .. tostring(self.bounce)
end

function Reel:addDeltaAmp(d)
  print("addDeltaAmp", self.id, d)
  self.amp = util.clamp(self.amp + (d / 10), 0, 4)
end

local frames = 100
local startFrame = 0
local endFrame = 99
local pos = 0

function Reel:addDeltaPosition(d)
  print("addDeltaPosition", self.id, d)
  self.position = self.position + d
  engine.setPosition(self.position / 64 * frames)
end

function Reel:draw(arc)
  if reel_state == 1 then
    print("arc led", self.id, self.position)
    arc:led(self.id, self.position, 15)
  elseif reel_state == 2 then
    print("arc led rolling", self.id, self.amp)
    arc:led(self.id, math.floor(self.amp * 16), 15) -- 1/4 = 1 so we can max amp of 4
  end
  
end

-- function Editor:redraw()


local reels = {
  Reel.new(),
  Reel.new(),
  Reel.new(),
  Reel.new()
}

engine.name = "RotaeVersantur"

local my_arc = arc.connect()
my_arc:all(1)
my_arc:refresh()


print("hello")

my_arc.vals = { 0, 0, 0, 0 }

button_pressed = false


my_arc.delta = function(n, d)
  
  if not button_pressed then
    if reel_state == 1 then
      reels[n]:addDeltaPosition(d)
    else
      reels[n]:addDeltaAmp(d)
    end
  else -- button pressed
    
    if n == 1 then
      shift_mode = "record"
      record_focus_detail = util.clamp(record_focus_detail + d, 0, 300)
      record_focus = record_focus_detail // 75
      print("shift record", shift_mode, record_focus_detail, record_focus)
      for reel_num = 1, 4 do
        reels[reel_num].record = false
      end
      if record_focus > 0 then
        reels[record_focus].record = true
      end
    end
    
    if n == 4 then
      shift_mode = "bounce"
      bounce_select_detail = util.clamp(bounce_select_detail + d, 0, 255)
      bounce_select = bounce_select_detail // 16
      print("bounce select", bounce_select_detail, bounce_select)
      for reel_num = 1, 4 do
        reels[reel_num].bounce = false
      end
      if bounce_select % 16 > 7 then
        reels[1].bounce = true
      end
      if bounce_select % 8 > 3 then
        reels[2].bounce = true
      end
      if bounce_select % 4 > 1 then
        reels[3].bounce = true
      end
      if bounce_select % 2 > 0 then
        reels[4].bounce = true
      end
    end
      
  end
  
  redraw()  
  
  
  -- prev_tic = my_arc.vals[n] // 16 + 1
  -- my_arc.vals[n] = (my_arc.vals[n] + d) % 1024
  -- print(n,d,my_arc.vals[n])

  -- new_tic = my_arc.vals[n] // 16 + 1
  -- print("new vs old", new_tic, prev_tic)
  -- if new_tic ~= prev_tic then
  --   -- engine.play(path, amp, amp_lag, sample_start, sample_end, loop, rate, trig)
  --   engine.play("/home/we/dust/audio/x0x/808/808-RS.wav", 1, 0, 0, 1, 0, 1, 1)
  -- else
  --   engine.play("/home/we/dust/audio/x0x/808/808-RS.wav", 0.1, 0, 0, 1, 0, 1, 1)
  -- end
  -- my_arc:all(0)
  -- my_arc:led(n, prev_tic, 12)
  -- my_arc:led(n, new_tic, 15)
  -- my_arc:refresh()
end

my_arc.key = function(n, z)
  print("key", n, z)
  
  if z == 1 and not button_pressed then
    button_pressed = true
  elseif z == 0 and button_pressed and shift_mode == "none" then
    print("button released")
    -- maybe have a timeout eventually
    button_pressed = false
    print("reel_state", reel_state)
    reel_state = ((reel_state + 2) % 2) + 1
    print("reel_state", reel_state)
    if reel_states[reel_state] == "rolling" then
      -- engine.play("/home/we/dust/audio/x0x/808/808-RS.wav", 1, 0, 0, 1, 0, 1, 1)
      -- engine.loadFromFile("/home/we/dust/audio/x0x/808/808-RS.wav")
      engine.loadFromFile("/home/we/dust/code/repl-looper/audio/musicbox/Wouldnt-Mind-Workin-From-Sun-To-Sun_2011121108_001_00-01-05.ogg")
    end

    redraw()
  else
    shift_mode = "none"
    button_pressed = false
    redraw()
  end
  
end


function redraw()
  screen.clear()
  screen.move(0,10)
  screen.level(15)
  screen.text("Reels: " .. reel_states[reel_state])
  
  for i, reel in ipairs(reels) do
    screen.move(0, 10 + i * 10)
    screen.text("Reel " .. i ..": " .. reel:toString())
  end
  screen.update()
  
  my_arc:all(0)
  
  if shift_mode == "none" then
  for i, reel in ipairs(reels) do
    reel:draw(my_arc)
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
      if reels[n].bounce then
        for i = 1, 64 do
          my_arc:led(n, i, 15)
        end
      end
    end
    -- Indicate which is currently recording with some stripes
    for i = 1, 64, 4 do
      my_arc:led(record_focus, i, 4)
    end
  end
  
  my_arc:refresh()
  
end

function osc.event(path, args, from)

  if path == "/playPosition" then
    frames = args[1]
    startFrame = args[2]
    endFrame = args[3]
    pos = args[4]
    print("playPosition", frames, startFrame, endFrame, pos)
    reels[1].position = math.floor((pos / frames) * 64)

    -- playPosition	423408.0	0.0	423408.0	366352.0
    -- playPosition	423408.0	0.0	423408.0	303760.0
    redraw()
  else
    print("Other OSC path", path)
  end

end


