--[[ Order can matter:
    Variables defined at the top (globals) must be defined before any functions that call them
    1. Variables/Constants
    2. Initialize function
    3. Update function
    4. Helper functions]]

--[[ Dazai Pet Script
    Sections:
        1. Variables
        2. Initialize/Update/Events
            1) Core/Position/WindowMeasures
            2) Timing/RNG/State Machine Basics
            3) Movement Config (walk)
            4) Idle Config & Inactivity
            5) Fall/Physics Config
            6) Drag/Dangle Core + Swing Physics
            7) Rubber Band Ball Config
            8) Book/Reading Config
            9) Video Game Animation Config & State
            10) Peek Config & State
            11) Drunk System Config & State
            12) Animation Counts & Frame Delays (Idle/Walk/Sleep)
            13) Mood/Needs Init & UI State
            14) First Render/First Move
            15) Rubber Band Ball: state entry
            16) Falling: drop helper
            17) Video Game Mode: toggle helper
            18) Input: Click vs Drag tracking
            19) Update Loop
            20) Hard Ball Lock: if throwing ball, do NOTHING else
            21) Hard Sleep Lock: if asleep, do NOTHING else
            22) PEEK Trigger & Sequence (return early while peeking)
            23) 
        3. Update
        4. Events
            a.]]

-------------------------------------
-- Variables / Constants
-------------------------------------

-- Core
X = 0
Y = 0
GroundY = 0
dir = 1
state = 'idle'
stateTick = 0
nextSwitch = 0
tick = 0
lastClickTick = 0

-- Frame counters
frameTick = 0
idleFrame = 1
walkFrame = 1
ballFrame = 1
readFrame = 1
sleepFrame = 1
drunkFrame = 1
peekFrame = 1
shyFrame = 1
gameFrame = 1
dangleFrame = 3

-- Window tracking / drag detection
lastWinX = 0
lastWinY = 0
mouseDown = false
dragged = false
dragGrace = 0

-- Physics
fallVel = 0.0
gravity = 0.9
angle = 0.0
angVel = 0.0
swingPush = 0.015
gravityK = 0.10
damping = 0.90
maxAngle = 0.8
moveThreshold = 2
pickedUp = false
stillFrames = 0
releaseFrames = 12

-- Game mode
hasPlayedGameIntro = false
gamePhase = 'intro'
fullscreenHold = 0.0

-- Drunk/sleep system
intox = 0
drunk = false
drunkTime = 0.0
intoxDecayPerSec = 1.0 -- THIS WAS 2.0, TOO FAST - UPDATE EVERYWHERE
drunkThreshold = 35
wastedThreshold = 70
sleepLockSeconds = 600.0
sleepTimeLeft = 0.0
swayMax = 6 -- DELETE
swayMaxWasted = 12 -- DELETE
swaySpeed = 6.0 -- DELETE

-- Peek system state
PeekFrames = 10
PeekFrameDelay = 6
peekHideSeconds = 10.0
peekHideLeft = 0.0
peekMonX = 0
peekMonRight = 0
peekMonY = 0
peekSide = 'L'
peekPhase = 0
peekTimer = 0
savedState = nil
savedDir = nil
savedNextSwitch = nil
savedStateTick = nil
peekUsedDate = ""
peekArmed = true

-- Chaos State
chaosFrame = 1
chaosTimer = 0
chaosMaxTimer = 3000

-- Laugh State
laughFrame = 1
laughTimer = 0
laughDuration = 120

-- Splat State
splatTimer = 0
splatDuration = 1200
splatFrame = 2

-- Rope Sequence State
ropePhase = 0
ropeTimer = 0
ropeUsedDate = "" -- stores current date to prevent a repeat (once-daily occurrence)
ropeFrame = 1

-- Panel/mood/menu
needs = { hunger=80, energy=80, clean=80, social=80, health=80 }
mood = { current=50, event=0, label="neutral" }
panelOpen = false
foodMenuOpen = false

-- Bubble state
bubbleTimer = 0
bubbleDuration = 120

-- Config vars read from Rainmeter
    -- GAME
GameIntroFrames = 3
GameLoopFrames = 14
GameIntroDelay = 6
GameLoopDelay = 6
GameX = 0
GameY = 0

    -- STEP
Step = 4
SpriteW = 320

    -- IDLE AND WALK
IdleFrames = 27
WalkFrames = 3
IdleFrameDelay = 6
WalkFrameDelay = 6
IdleMin = 120
IdleMax = 360
WalkMin = 60
WalkMax = 220

    -- BALL
InactiveTicks = 1800
BallFrames = 7
BallFrameDelay = 6
BallDuration = 180.0

    -- READ
ReadFrames = 6
ReadFrameDelay = 20
ReadMin = 1200
ReadMax = 2400
ReadYOffset = 20

    -- DRUNK
DrunkFrames = 5
DrunkFrameDelay = 18
SleepFrames = 15
SleepFrameDelay = 10

-- POTENTIALLY REMOVE THESE:
dragFrames = 0
dragStartFrames = 2
dragOffsetX = 0
dragOffsetY = 0
prevMouseX = nil
prevMouseY = nil

-------------------------------------
-- INITIALIZE/UPDATE/EVENTS
-------------------------------------

function Initialize()

  -------------------------------------------------
  -- 1) CORE / POSITION / WINDOW MEASURES
  -------------------------------------------------
  -- Read variables from the skin
  X = tonumber(SKIN:GetVariable('X')) or 200
  Y = tonumber(SKIN:GetVariable('Y')) or 600

  SpriteW = tonumber(SKIN:GetVariable('SpriteW')) or 320

  -- Track actual window position (for drag / movement detection)
  dragging = false
  lastWinX = tonumber(SKIN:GetMeasure('MeasureWinX'):GetValue()) or X
  lastWinY = tonumber(SKIN:GetMeasure('MeasureWinY'):GetValue()) or Y

  --[[ Ground snap (from variable, with fallback)
  GroundY = tonumber(SKIN:GetVariable('GroundY'))
            or (tonumber(SKIN:GetMeasure('MeasureScreenH'):GetValue()) or 1080) - 200]]

  -- Ground snap (force 880 for now if screen height fails)
  local sH = tonumber(SKIN:GetMeasure('MeasureScreenH'):GetValue()) or 1080
  if sH == 0 then sH = 1080 end
  GroundY = tonumber(SKIN:GetVariable('GroundY')) or 0
  local waH = tonumber(SKIN:GetVariable('WORKAREAHEIGHT')) or 1080
  local petHeight = 190
  local waY = tonumber(SKIN:GetVariable('WORKAREAY')) or 0
  GroundY = (waY + waH) - petHeight

  -------------------------------------------------
  -- 2) TIMING / RNG / STATE MACHINE BASICS
  -------------------------------------------------
  math.randomseed(os.time())

  dir = 1              -- 1 = right, -1 = left
  state = 'idle'       -- 'idle' or 'walk'
  stateTick = 0

  tick = 0
  lastClickTick = 0

  frameTick = 0

  suppressMouseUp = suppressMouseUp or 0

  scriptMoving = false


  -------------------------------------------------
  -- 3) MOVEMENT CONFIG (WALK)
  -------------------------------------------------
  Step = tonumber(SKIN:GetVariable('Step')) or 4

  WalkMin = tonumber(SKIN:GetVariable('WalkMin')) or 60
  WalkMax = tonumber(SKIN:GetVariable('WalkMax')) or 220


  -------------------------------------------------
  -- 4) IDLE CONFIG + INACTIVITY
  -------------------------------------------------
  IdleMin = tonumber(SKIN:GetVariable('IdleMin')) or 120
  IdleMax = tonumber(SKIN:GetVariable('IdleMax')) or 360
  InactiveTicks = tonumber(SKIN:GetVariable('InactiveTicks')) or 1800
  nextSwitch = randRange(IdleMin, IdleMax)


  -------------------------------------------------
  -- 5) FALL / PHYSICS CONFIG
  -------------------------------------------------
  fallVel = 0.0
  gravity = 0.9          -- tweak later


  -------------------------------------------------
  -- 6) DRAG / DANGLE CORE + SWING PHYSICS
  -------------------------------------------------

  -------------------------------------------------
  -- 7) RUBBER BAND BALL CONFIG
  -------------------------------------------------
  BallFrames = tonumber(SKIN:GetVariable('BallFrames')) or 7
  BallFrameDelay = tonumber(SKIN:GetVariable('BallFrameDelay')) or 6
  BallDuration = tonumber(SKIN:GetVariable('BallDuration')) or 180.0  -- seconds
  ballTimeLeft = 0.0
  ballFrame = 1


  -------------------------------------------------
  -- 8) BOOK / READING CONFIG
  -------------------------------------------------
  ReadFrames = tonumber(SKIN:GetVariable('ReadFrames')) or 6
  ReadFrameDelay = tonumber(SKIN:GetVariable('ReadFrameDelay')) or 20
  ReadMin = tonumber(SKIN:GetVariable('ReadMin')) or 300
  ReadMax = tonumber(SKIN:GetVariable('ReadMax')) or 900
  ReadYOffset = tonumber(SKIN:GetVariable('ReadYOffset')) or 20
  readFrame = 1


  -------------------------------------------------
  -- 9) VIDEO GAME ANIMATION CONFIG + STATE
  -------------------------------------------------
  GameIntroFrames = tonumber(SKIN:GetVariable('GameIntroFrames')) or 3
  GameLoopFrames  = tonumber(SKIN:GetVariable('GameLoopFrames')) or 14
  GameIntroDelay  = tonumber(SKIN:GetVariable('GameIntroDelay')) or 6
  GameLoopDelay   = tonumber(SKIN:GetVariable('GameLoopDelay')) or 6

  GameX = tonumber(SKIN:GetVariable('GameX')) or 200
  GameY = tonumber(SKIN:GetVariable('GameY')) or 600

  hasPlayedGameIntro = false
  gamePhase = 'intro'        -- 'intro' or 'loop' (only used when state == 'game')
  gameFrame = 1
  fullscreenHold = 0.0       -- seconds


  -------------------------------------------------
  -- 10) PEEK CONFIG + STATE
  -------------------------------------------------
  PeekFrames = 10
  PeekFrameDelay = 6 -- speed of peak animation
  peekHideSeconds = 10.0
  peekHideLeft = 0.0
  peekEntered = false

  peekMonX = 0
  peekMonRight = 0
  peekMonY = 0

  peekSide = 'L'
  peekFrame = 1
  peekPhase = 0 -- 0=off, 1=peek in, 2=hold, 4=exit
  peekTimer = 0

  savedState = nil
  savedDir = nil
  savedNextSwitch = nil
  savedStateTick = nil

  --random + once-per-day gating
  peekUsedDate = ""
  peekArmed = true


  -------------------------------------------------
  -- 11) DRUNK SYSTEM CONFIG + STATE
  -------------------------------------------------
  -- DRUNK IDLE ANIMATION
  DrunkFrames = tonumber(SKIN:GetVariable('DrunkFrames')) or 5
  DrunkFrameDelay = tonumber(SKIN:GetVariable('DrunkFrameDelay')) or 6
  drunkFrame = 1
  wasDrunk = false

  intox = 0            -- 0..100
  drunk = false
  drunkTime = 0        -- seconds running timer for sway math
  intoxDecayPerSec = 2.0   -- how fast he sobers up (tweak)
  drunkThreshold = 35      -- becomes "drunk" above this
  wastedThreshold = 70     -- extra-drunk above this

  -- SLEEP (drunk pass-out)
  sleepLockSeconds = 600.0   -- 10 minutes
  sleepTimeLeft = 0.0

  swayMax = 6              -- degrees (normal drunk sway)
  swayMaxWasted = 12       -- degrees (wasted sway)
  swaySpeed = 6.0          -- radians/sec (how fast he sways)

  -------------------------------------------------
  -- 12) ANIMATION COUNTS + FRAME DELAYS (IDLE/WALK/SLEEP)
  -------------------------------------------------
  IdleFrames = tonumber(SKIN:GetVariable('IdleFrames')) or 27
  IdleFrameDelay = tonumber(SKIN:GetVariable('IdleFrameDelay')) or 6
  idleFrame = 1

  WalkFrames = tonumber(SKIN:GetVariable('WalkFrames')) or 3
  WalkFrameDelay = tonumber(SKIN:GetVariable('WalkFrameDelay')) or 8
  walkFrame = 1

  -- SLEEP ANIMATION
  SleepFrames = tonumber(SKIN:GetVariable('SleepFrames')) or 15
  SleepFrameDelay = tonumber(SKIN:GetVariable('SleepFrameDelay')) or 10
  sleepFrame = 1

  -------------------------------------------------
  -- 13) MOOD / NEEDS INIT + UI STATE
  -------------------------------------------------
  needs = { hunger=30, energy=30, clean=30, social=30, health=30 }
  mood  = { current=30, event=0, label="neutral" }
  panelOpen = false
  SKIN:Bang('!HideMeterGroup', 'PetPanel')
  SKIN:Bang('!HideMeterGroup', 'FoodMenu')

  -------------------------------------------------
  -- 14) FIRST RENDER / FIRST MOVE
  -------------------------------------------------
  applyImage()         -- set initial image
  scriptMoving = true
  SKIN:Bang('!Move', X, Y)
  scriptMoving = false

end

-------------------------------------
-- 15) RUBBER BAND BALL: state entry
-------------------------------------
function StartBall()
  state = 'ball'
  stateTick = 0
  frameTick = 0
  ballFrame = 1
  ballTimeLeft = 600
  applyImage()
end

function StartChaos()
  state = 'chaos'
  chaosFrame = 1
  chaosTimer = 0
  chaosMaxTimer = 600
  nextSwitch = chaosMaxTimer
  panelOpen = false
  foodMenuOpen = false
  SKIN:Bang('!HideMeterGroup', 'PetPanel')
  SKIN:Bang('!HideMeterGroup', 'PetPanelButtons')
  SKIN:Bang('!HideMeterGroup', 'FoodMenu')
  applyImage()
end

-------------------------------------
-- 16) FALLING: drop helper
-------------------------------------
function Drop()
  if pickedUp or state == 'dangle' then
    X = tonumber(SKIN:GetMeasure('MeasureWinX'):GetValue()) or X
    Y = tonumber(SKIN:GetMeasure('MeasureWinY'):GetValue()) or Y

    pickedUp = false
    state = 'fall'
    frameTick = 0
    fallVel = 0.0
  end
end

-------------------------------------
-- 17) VIDEO GAME MODE: toggle helper
-------------------------------------
function ToggleGaming()
  if state ~= 'game' then
    -- enter gaming
    state = 'game'
    panelOpen = false
    SKIN:SetVariable('PreGameX',X)
    SKIN:SetVariable('PreGameY',Y)
    frameTick = 0
    gameFrame = 1

    if hasPlayedGameIntro then
      gamePhase = 'loop'
    else
      gamePhase = 'intro'
    end

    local monX = tonumber(SKIN:GetMeasure('MeasureMonX'):GetValue()) or 0
    local monY = tonumber(SKIN:GetMeasure('MeasureMonY'):GetValue()) or 0

    X = monX + GameX
    Y = GroundY
    scriptMoving = true
    SKIN:Bang('!Move', X, Y)
    scriptMoving = false

    frameTick = 0
    gameFrame = 1
    applyImage()

  else
    -- exit gaming
    state = 'idle'
    panelOpen = false
    stateTick = 0
    nextSwitch = randRange(IdleMin, IdleMax)
    frameTick = 0
    idleFrame = 1

    X = tonumber(SKIN:GetVariable('PreGameX')) or X
    Y = tonumber(SKIN:GetVariable('PreGameY')) or Y
    scriptMoving = true
    SKIN:Bang('!Move', X, Y)
    scriptMoving = false
    applyImage()
  end
end

-------------------------------------
-- 18) INPUT: click vs drag tracking
-------------------------------------
suppressMouseUp = suppressMouseUp or 0

function OnMouseDown()
  isDragging = true
  state = 'dangle'  -- FORCE HIM INTO DANGLE MODE
  -- reset velocity so he doesn't fly away when released
  velX = 0
  velY = 0
end

function OnMouseDrag()
  if state == 'sleep' and sleepTimeLeft and sleepTimeLeft > 0 then return end
  isDragging = true
  didDrag = true
end

function OnMouseUp()
  isDragging = false

  -- 1. Keep your Sleep Check
  if state == 'sleep' and sleepTimeLeft and sleepTimeLeft > 0 then return end

  -- 2. Keep your Double-Click Suppression
  if suppressMouseUp and suppressMouseUp > 0 then
    suppressMouseUp = suppressMouseUp - 1
    return
  end

  -- 3. THE FIX: Instead of checking "didDrag", we check if he's in the air!
  -- Since Update() automatically sets state='dangle' when moving, we check that.
  local isAirborne = (Y < GroundY - 10)

  if state == 'dangle' or isAirborne then
    -- We are dropping him!
    state = 'fall'
    frameTick = 0
    fallVel = 0.0

    -- Sync position one last time to be safe
    X = tonumber(SKIN:GetMeasure('MeasureWinX'):GetValue()) or X
    Y = tonumber(SKIN:GetMeasure('MeasureWinY'):GetValue()) or Y
    return
  end

  -- 4. If we aren't in the air/dangling, it's a click.
  OnPetClick()
end

function OnDoubleClick()
  if state == 'sleep' and sleepTimeLeft and sleepTimeLeft > 0 then return end
  -- Force close panel if it's open
  if panelOpen then
    TogglePanel()
  end

  suppressMouseUp = 1
  ToggleGaming()
end

function OnPetClick()
  if state == 'sleep' and sleepTimeLeft and sleepTimeLeft > 0 then
    return
  end

  lastClickTick = tick
  -- If he was throwing the ball, clicking stops it and returns to idle
  if state == 'ball' then
    state = 'idle'
    stateTick = 0
    nextSwitch = randRange(IdleMin, IdleMax)
    frameTick = 0
    idleFrame = 1
    applyImage()
  end

  -- If he was reading, clicking stops it and returns to idle
  if state == 'read' then
    state = 'idle'
    stateTick = 0
    nextSwitch = randRange(IdleMin, IdleMax)
    frameTick = 0
    idleFrame = 1
    applyImage()
  end

  if state ~= 'game' then
    TogglePanel()
  end

end

-------------------------------------
-- 19) UPDATE LOOP (do not reorder logic)
-------------------------------------
function Update()
  local today = os.date("%Y-%m-%d") -- today's date

  local dt = 0.016
  tick = (tick or 0) + 1

  -------------------------------------------------
  -- 1) SYNC POSITION (The "Eyes")
  -------------------------------------------------
  -- Read actual window position from Rainmeter
  local wx = tonumber(SKIN:GetMeasure('MeasureWinX'):GetValue()) or X
  local wy = tonumber(SKIN:GetMeasure('MeasureWinY'):GetValue()) or Y

  -- Calculate velocity (how fast you dragged him)
  local dx = wx - lastWinX
  local dy = wy - lastWinY
  lastWinX = wx
  lastWinY = wy

  -- SYNC: Update Lua variables to match window position
  X = wx
  -- Only sync Y if we aren't using a menu or throwing ball
  if (not panelOpen) and (not foodMenuOpen) and state ~= 'ball' then
    Y = wy
  end

  -------------------------------------------------
  -- 2) HARD BALL LOCK
  -------------------------------------------------
  if state == 'ball' then
    if ballTimeLeft == nil then ballTimeLeft = 300
    end

    ballTimeLeft = ballTimeLeft - dt

    stepFrame()

    if ballTimeLeft <= 0 then
      ballTimeLeft = nil
      state = 'idle'
      lastClickTick = tick
      stateTick = 0
      nextSwitch = randRange(IdleMin, IdleMax)
      frameTick = 0
      idleFrame = 1
      applyImage()
    end
    SKIN:Bang('!UpdateMeter', 'MeterDazai')
    SKIN:Bang('!Redraw')
    return 1
  end

  -------------------------------------------------
  -- 3) HARD SLEEP LOCK
  -------------------------------------------------
  if state == 'sleep' and sleepTimeLeft and sleepTimeLeft > 0 then
    sleepTimeLeft = sleepTimeLeft - dt
    stepFrame()
    if sleepTimeLeft <= 0 then
      sleepTimeLeft = 0
      state = 'idle'
      stateTick = 0
      nextSwitch = randRange(IdleMin, IdleMax)
      frameTick = 0
      idleFrame = 1
      applyImage()
    end
    SKIN:Bang('!UpdateMeter', 'MeterDazai')
    SKIN:Bang('!Redraw')
    return 1
  end

  -------------------------------------------------
  -- 4) START BALL (Idle timeout)
  -------------------------------------------------
  if state ~= 'game' and state ~= 'ball' and state ~= 'sleep' and peekPhase == 0 and ropePhase == 0 and (tick - lastClickTick) >= InactiveTicks then
    StartBall()
    SKIN:Bang('!UpdateMeter', 'MeterDazai')
    SKIN:Bang('!Redraw')
    return 1
  end

  -------------------------------------------------
  -- 5) DRUNK CHECK
  -------------------------------------------------
  if intox and intox > 0 then
    intox = intox - (intoxDecayPerSec * dt)
    if intox < 0 then intox = 0 end
  end
  drunk = (intox >= drunkThreshold)

  -- Pass out check
  if state ~= 'sleep' and intox and intox >= wastedThreshold then
    state = 'sleep'
    sleepTimeLeft = sleepLockSeconds
    pickedUp = false
    fallVel = 0
    Y = GroundY
    scriptMoving = true
    SKIN:Bang('!Move', X, Y)
    scriptMoving = false
    sleepFrame = 1
    frameTick = 0
    panelOpen = false
    foodMenuOpen = false
    SKIN:Bang('!HideMeterGroup', 'PetPanel')
    SKIN:Bang('!HideMeterGroup', 'FoodMenu')
    applyImage()
    SKIN:Bang('!UpdateMeter', 'MeterDazai')
    SKIN:Bang('!Redraw')
    return 1
  end

  -------------------------------------------------
  -- 6) AIRBORNE / DRAG / FALL PHYSICS
  -------------------------------------------------
  -- Check if moving fast OR simply "isDragging" (from mouse down)
  local moveThreshold = 2
  local movingNow = (math.abs(dx) + math.abs(dy)) >= moveThreshold or isDragging
  local onGround = (Y >= GroundY)

  -- If in air (or user is dragging him on the ground)
  if not onGround or isDragging then
    if movingNow then
      state = 'dangle'

      -- Swing physics
      angVel = (angVel or 0) + (dx * swingPush)
      angVel = angVel - ((angle or 0) * gravityK)
      angVel = angVel * damping
      angle = (angle or 0) + angVel

      -- Clamp angle
      if angle > maxAngle then angle = maxAngle; angVel = 0 end
      if angle < -maxAngle then angle = -maxAngle; angVel = 0 end

      -- Map angle to frame
      local t = (angle + maxAngle) / (2 * maxAngle)
      local idx = math.floor(t * 5 + 1)
      if idx < 1 then idx = 1 end
      if idx > 6 then idx = 6 end
      dangleFrame = idx

      applyImage()
      SKIN:Bang('!UpdateMeter', 'MeterDazai')
      SKIN:Bang('!Redraw')
      return 1
    else
      -- Not moving? FALL.
      state = 'fall'
      fallVel = (fallVel or 0) + gravity
      Y = Y + fallVel

      if Y >= GroundY then
        Y = GroundY
        fallVel = 0
        state = 'idle'
        frameTick = 0
        idleFrame = 1
        applyImage()
      end

      SKIN:Bang('!Move', X, Y)
      SKIN:Bang('!UpdateMeter', 'MeterDazai')
      SKIN:Bang('!Redraw')
      return 1
    end
  end

  -------------------------------------------------
  -- 7) NORMAL GROUND BEHAVIOR
  -------------------------------------------------
  if state == 'fall' then
    -- Landing logic (backup)
    fallVel = (fallVel or 0) + gravity
    Y = Y + fallVel
    if Y >= GroundY then
      Y = GroundY
      fallVel = 0
      state = 'idle'
      frameTick = 0
      idleFrame = 1
      applyImage()
    end
    SKIN:Bang('!Move', X, Y)
    SKIN:Bang('!UpdateMeter', 'MeterDazai')
    SKIN:Bang('!Redraw')
    return 1
  end

   -------------------------------------
   -- PEEK TRIGGER & SEQUENCE
   -------------------------------------
  if peekPhase == 0 and (state == 'idle' or state == 'walk') and (Y >= GroundY) then
    if math.random(200000) == 1 then -- rarity tuning lower = more common
      peekPhase = 1
      peekMonX = tonumber(SKIN:GetMeasure('MeasureMonX'):GetValue()) or 0
        peekMonRight = peekMonX + (tonumber(SKIN:GetMeasure('MeasureMonW'):GetValue())) or 0

          savedState = state
          savedDir = dir
          savedNextSwitch = nextSwitch
          savedStateTick = stateTick

          peekTimer = 0
          frameTick = 0
          peekFrame = 1
    end
  end

  -- sequence: runs while peekPhase is active
  if peekPhase ~= 0 then
    peekTimer = peekTimer + 1

    -- Phase 1 (walk to LEFT edge)
    if peekPhase == 1 then
      state = 'walk'
      dir = -1
      X = X - Step
      Y = GroundY

      local margin = 40
      if X <= (peekMonX + margin) then
        X = peekMonX + margin
        peekPhase = 2
        frameTick = 0
      end

      scriptMoving = true
      SKIN:Bang('!Move', X, Y)
      scriptMoving = false
      stepFrame()
      applyImage()
      SKIN:Bang('!UpdateMeter', 'MeterDazai')
      SKIN:Bang('!Redraw')
      return 1
    end

    -- Phase 2 ( walk off screen LEFT)
    if peekPhase == 2 then
      state = 'walk'
      dir = -1
      X = X - Step
      Y = GroundY

      if X <= (peekMonX - 80) then
        peekPhase = 3
        peekHideLeft = 10.0 -- hide for 10 seconds
        frameTick = 0
      end

      scriptMoving = true
      SKIN:Bang('!Move', X, Y)
      scriptMoving = false
      stepFrame()
      applyImage()
      SKIN:Bang('!UpdateMeter', 'MeterDazai')
      SKIN:Bang('!Redraw')
      return 1
    end

    -- Phase 3 (Hide off screen, then come back in and peek)
    if peekPhase == 3 then
      state = 'peek'
      peekHideLeft = (peekHideLeft or 5.0) - dt

      if peekHideLeft <= 0 then
        peekHideLeft = 0
        peekPhase = 4
        peekFrame = 1
        frameTick = 0
      end

      SKIN:Bang('!HideMeter', 'MeterDazai')
      SKIN:Bang('!Redraw')
      return 1
    end

    -- Phase 4 (peek in)
    if peekPhase == 4 then
      state = 'peek'
      X = peekMonX
      Y = GroundY

      stepFrame()

      if peekFrame >= PeekFrames then
        peekPhase = 5
        peekTimer = 0
        frameTick = 0
      end

      SKIN:Bang('!ShowMeter', 'MeterDazai')
      applyImage()
      scriptMoving = true
      SKIN:Bang('!Move', X, Y)
      scriptMoving = false
      SKIN:Bang('!UpdateMeter', 'MeterDazai')
      SKIN:Bang('!Redraw')
      return 1
    end

    -- Phase 5 (hold peek)
    if peekPhase == 5 then
      state = 'peek'
      applyImage()

      if peekTimer >= 120 then
        peekPhase = 6
        peekTimer = 0
      end

      SKIN:Bang('!UpdateMeter', 'MeterDazai')
      SKIN:Bang('!Redraw')
      return 1
    end

    -- Phase 6 (exit)
    if peekPhase == 6 then
      peekPhase = 0
      peekTimer = 0
      frameTick = 0

      state = savedState or 'idle'
      dir = savedDir or dir
      nextSwitch = savedNextSwitch or randRange(IdleMin, IdleMax)
      stateTick = savedStateTick or 0

      applyImage()
      SKIN:Bang('!UpdateMeter', 'MeterDazai')
      SKIN:Bang('!Redraw')
      return 1
    end
    end


-------------------------------------
-- ROPE SEQUENCE STATES
-------------------------------------
  if ropePhase == 0 and ropeUsedDate ~= today and (state == 'idle' or state == 'walk') and (Y >= GroundY - 5) then
    if math.random(100000) == 1 then
      lastClickTick = tick
      ropePhase = 1
      ropeUsedDate = today
      ropeMonX = tonumber(SKIN:GetMeasure('MeasureMonX'):GetValue()) or 0
      savedState = state
      savedDir = dir
      savedNextSwitch = nextSwitch
      frameTick = 0
    end
  end

  if ropePhase ~= 0 then
    -- Phase 1: Walk OFF screen
    if ropePhase == 1 then
      state = 'walk'
      dir = -1
      X = X - Step
      Y = GroundY
      if X <= (ropeMonX - 150) then
        ropePhase = 2
        ropeTimer = 60
      end
      scriptMoving = true
      SKIN:Bang('!Move', X, Y)
      scriptMoving = false
      stepFrame()
      applyImage()
      SKIN:Bang('!UpdateMeter', 'MeterDazai')
      SKIN:Bang('!Redraw')
      return 1
    end

    -- Phase 2: Wait off-screen
    if ropePhase == 2 then
      ropeTimer = ropeTimer - 1
      if ropeTimer <= 0 then
        ropePhase = 3
        frameTick = 0
        ropeFrame = 1
        X = ropeMonX - 100
      end
      return 1
    end

    -- Phase 3: Walk IN with rope (walkNL_1-4)
    if ropePhase == 3 then
      state = 'rope_in'
      X = X + (Step * 0.5)
      frameTick = frameTick + 1
      if frameTick >= 8 then
        frameTick = 0
        ropeFrame = ropeFrame + 1
        if ropeFrame > 2 then
          ropeFrame = 1 end
        applyImage()
      end
      if X >= (ropeMonX + 0) then
        ropePhase = 4
        ropeTimer = 60
      end
      scriptMoving = true
      SKIN:Bang('!Move', X, Y)
      scriptMoving = false
      SKIN:Bang('!UpdateMeter', 'MeterDazai')
      SKIN:Bang('!Redraw')
      return 1
    end

    -- Phase 4: Freeze/Realize
    if ropePhase == 4 then
      state = 'rope_in'
      ropeFrame = 4
      applyImage()
      ropeTimer = ropeTimer - 1
      if ropeTimer <= 0 then
        ropePhase = 5
        ropeFrame = 5
        frameTick = 0
      end
      SKIN:Bang('!UpdateMeter', 'MeterDazai')
      SKIN:Bang('!Redraw')
      return 1
    end

    -- Phase 5: Back up (walkNL_5-8)
    if ropePhase == 5 then
      state = 'rope_out'
      X = X - (Step * 0.8)
      frameTick = frameTick + 1
      if frameTick >= 10 then
        frameTick = 0
        ropeFrame = ropeFrame + 1
        if ropeFrame > 4 then
          ropeFrame = 1 end
        applyImage()
      end
      if X <= (ropeMonX - 200) then
        ropePhase = 6
        ropeTimer = 120
      end
      scriptMoving = true
      SKIN:Bang('!Move', X, Y)
      scriptMoving = false
      SKIN:Bang('!UpdateMeter', 'MeterDazai')
      SKIN:Bang('!Redraw')
      return 1
    end

    -- Phase 6: Wait off-screen (drop rope)
    if ropePhase == 6 then
      ropeTimer = ropeTimer - 1
      if ropeTimer <= 0 then
        ropePhase = 7
        frameTick = 0
        walkFrame = 1
      end
      return 1
    end

    -- Phase 7: Walk back IN (normal)
    if ropePhase == 7 then
      state = 'walk'
      dir = 1
      X = X + Step
      stepFrame()
      if X >= (ropeMonX + 200) then
        ropePhase = 8
        ropeFrame = 1
        frameTick = 0
      end
      scriptMoving = true
      SKIN:Bang('!Move', X, Y)
      scriptMoving = false
      SKIN:Bang('!UpdateMeter', 'MeterDazai')
      SKIN:Bang('!Redraw')
      return 1
    end

    -- Phase 8: Act embarrassed (shyL_1-8)
    if ropePhase == 8 then
      state = 'rope_shy'
      frameTick = frameTick + 1
      if frameTick >= 8 then
        frameTick = 0
        ropeFrame = ropeFrame + 1
        if ropeFrame > 8 then
          ropePhase = 9
          ropeTimer = 60
        else
          applyImage()
        end
      end
      SKIN:Bang('!UpdateMeter', 'MeterDazai')
      SKIN:Bang('!Redraw')
      return 1
    end

    -- Phase 9: Exit
    if ropePhase == 9 then
      ropeTimer = ropeTimer - 1
      if ropeTimer <= 0 then
        ropePhase = 0
        state = 'idle'
        nextSwitch = randRange(IdleMin, IdleMax)
        lastClickTick = tick
        peekPhase = 0
        peekTimer = 0
        applyImage()
      end
      SKIN:Bang('!UpdateMeter', 'MeterDazai')
      SKIN:Bang('!Redraw')
      return 1
    end
  end

  if bubbleTimer >0 then
    bubbleTimer = bubbleTimer - 1
    if bubbleTimer <= 0 then
      SKIN:Bang('!HideMeter', 'MeterBubble')
    end
  end
  -- Bubble Logic
  if state == 'idle' and bubbleTimer <= 0 then
    if math.random(400) == 1 then showBubble() end
  end

  -- Mood & Animation Steps
  updateMood(dt)
  updatePanelMeters()

  if state ~= 'ball' then
    stepState()
    stepMove()
  end
  stepFrame()

  SKIN:Bang('!SetOption', 'MeterDazai', 'ImageRotate', '0')
  SKIN:Bang('!UpdateMeter', 'MeterDazai')
  SKIN:Bang('!Redraw')

  -- Chaos Logic
  if state == 'chaos' then
    chaosTimer = chaosTimer + 1

    if dir == 1 then
      X = X - (Step * 2)
    else
      X = X + (Step * 2)
    end

    if chaosTimer % 4 == 0 then
      chaosFrame = chaosFrame + 1
      if chaosFrame > 10 then chaosFrame = 1 end
    end

    local monX = tonumber(SKIN:GetMeasure('MeasureMonX'):GetValue()) or 0
    local monW = tonumber(SKIN:GetMeasure('MeasureMonW'):GetValue()) or 1920
    local monRight = monX + monW
    local skinW = tonumber(SKIN:GetVariable('CURRENTCONFIGWIDTH')) or 200

    if X >= (monRight - skinW) then
      X = monRight - skinW
      dir = 1
    elseif X <= monX then
      X = monX
      dir = -1
    end

    -- Random laugh interrupt (1/100 chance per frame)
    if chaosTimer > 300 and math.random(100) == 1 then
      state = 'laugh'
      laughFrame = 1
      laughTimer = 0
      laughDuration = 60  -- laugh for 1 second
      frameTick = 0
    elseif chaosTimer >= chaosMaxTimer then
      state = 'splat'
      splatFrame = 1
      splatTimer = 0
      splatDuration = 1200

      chaosFrame = 1
      chaosTimer = 0
      frameTick = 0
      if X > (monX + monW / 2) then
        dir = -1
      else
        dir = 1
      end
    end

    applyImage()
    scriptMoving = true
    SKIN:Bang('!Move', X, Y)
    scriptMoving = false
  end

  return 1

end

-------------------------------------
-- CHOICES (STATE SWITCHING)
-------------------------------------

-------------------------------------------------
-- 1) Choice helper: after 5pm behavior preference
-------------------------------------------------
function pickAfter5pmIdle()
  -- DRUNK: prefers resting
  if drunk then
    return 'idle'
  end

  local h = os.date("*t").hour
  if h < 17 then
    return 'idle'
  end

  -- 50/50 after 5pm
  if math.random(2) == 1 then
    return 'read'
  else
    return 'ball'
  end
end

-------------------------------------------------
-- 2) Main state switcher: idle/read <-> walk and after-walk choice
-------------------------------------------------
function stepState()
  if state == 'game' then return end
  if state == 'ball' then return end
  if state == 'sleep' then return end
  if state == 'splat' then
    splatTimer = splatTimer + 1

    -- Transition frame

    if splatTimer < 10 then
      splatFrame = 1

      -- continue movement

      X = X + (dir * Step * 0.5)

      local monX = tonumber(SKIN:GetMeasure('MeasureMonX'):GetValue()) or 0
      local monW = tonumber(SKIN:GetMeasure('MeasureMonW'):GetValue()) or 1920
      local monRight = monX + monW
      local skinW = tonumber(SKIN:GetVariable('CURRENTCONFIGWIDTH')) or 200
      local maxX = monRight - skinW

      if X > maxX then X = maxX end
      if X < monX then X = monX end

      scriptMoving = true
      SKIN:Bang('!Move', X, Y)
      scriptMoving = false
    else
      splatFrame = 2
    end

    applyImage()

    if splatTimer >= splatDuration then
      state = 'idle'
      idleFrame = 1
      nextSwitch = randRange(IdleMin, IdleMax)
      splatTimer = 0
      frameTick = 0
      applyImage()
    end
    return
  end

  if state == 'chaos' then return end
  if state == 'laugh' then
    laughTimer = laughTimer + 1
    if laughTimer >= laughDuration then
      state = 'chaos'
      chaosFrame = 1
      frameTick = 0
      laughTimer = 0
    end
    applyImage()
    return
  end


  stateTick = stateTick + 1

  if stateTick >= nextSwitch then
    stateTick = 0
    frameTick = 0

    if state == 'idle' or state == 'read' then

      -- DRUNK: often refuses to walk
      if drunk and math.random(3) ~= 1 then
        state = 'idle'
        idleFrame = 1
        nextSwitch = randRange(IdleMin, IdleMax) * 2  -- longer idle = sleepier
        applyImage()
        return
      end

      -- Normal behavior
      state = 'walk'
      walkFrame = 1
      nextSwitch = randRange(WalkMin, WalkMax)
      scriptMoving = true
      SKIN:Bang('!Move', X, Y)
      scriptMoving = false
      SKIN:Bang('!SetVariable', 'BaseOffsetY', '0')
      applyImage()

    else
      local choice = pickAfter5pmIdle()

      stateTick = 0
      frameTick = 0

      if choice == 'read' then
        state = 'read'
        readFrame = 1
        nextSwitch = randRange(ReadMin, ReadMax)

        -- lower ONLY the picture, not the window
        SKIN:Bang('!SetVariable', 'BaseOffsetY', SKIN:GetVariable('ReadOffsetY'))

      elseif choice == 'ball' then
        StartBall()

      else
        state = 'idle'
        idleFrame = 1
        nextSwitch = randRange(IdleMin, IdleMax)
      end

    end
  end
end

-------------------------------------
-- TEXT BOXES
-------------------------------------

-------------------------------------------------
-- 1) Bubble text pools (ordered by mood/use)
-------------------------------------------------

-- 1.1 Ecstatic (too-good mood)
bubbleTextsEcstatic = {
  "Ahahaha-how suspicious. I feel *wonderful*.",
  "Everything's painfully vivid today. I might regret this later.",
  "This level of joy feels illegal. Should I report myself?",
  "Careful... my thoughts are running ahead without supervision.",
  "What delightful energy. Let's apply it irresponsibly.",
  "I feel unstoppable. That never ends well.",
  "Isn't it charming how alive everything feels right before disaster?",
  "Please don't trust me while I'm like this.",
  "Ah~ this feeling is intoxicating. The aftermath never is.",
  "I'm sharp today. Brilliant. Mildly catastrophic.",
  "This much happiness feels like a terrible decision.",
  "If I start laughing too hard, kindly restrain me.",
  "Everything is going far too well.",
  "I could conquer the world... or destroy it accidentally.",
  "Ah~ I feel inspired to make *excellent* mistakes!",
}

-- 1.2 Happy (day vs night variants)
bubbleTextsHappyDay = {
  "It's brighter than usual. How bold of the sun.",
  "Daytime is tolerable. I can pretend I'm functional.",
  "Another morning survived. Truly heroic.",
  "The world is awake. How inconsiderate.",
  "I feel... oddly competent today. Let's not dwell on it.",
  "Ah~ daylight. Motivating. Briefly.",
}

bubbleTextsHappyNight = {
  "It's quieter now. The world improves when it shuts up.",
  "I like the night. Fewer expectations. Fewer lies.",
  "It's calm. I can exist like this.",
  "Night makes everything feel less demanding.",
  "Less watching. Less judging.",
  "I'm closer to myself after dark.",
}

bubbleTextsHappy = {
  "Ah~ today isn't unbearable. What a treat.",
  "Look at me-alive *and* productive. Shocking.",
  "I feel strangely light. That's usually a warning sign.",
  "This is pleasant. Let's not analyze it.",
  "I might even say I'm enjoying myself.",
  "Things are going well. I assume this is temporary.",
  "See? I'm smiling. Very authentic.",
  "I feel like causing a *manageable* amount of trouble.",
  "How rare. I don't resent this moment.",
  "I almost forgot this feeling existed.",
  "Careful-if this continues, I may develop hope.",
  "Ah yes... functioning. A forgotten skill.",
  "I could get used to this mood. That worries me.",
  "Is this what people mean by 'fine'?",
  "Today feels... survivable. Maybe even kind.",
  "I'm alert. Focused. Dangerous in a charming way.",
  "I'm in a good mood. Don't panic-it'll fade.",
  "Maintaining this version of myself is exhausting.",
  "Perhaps I deserve a little praise today.",
  "Strange... I don't mind being here right now.",
}

-- 1.3 Direct-address (rare, any mood)
bubbleTextsDirect = {
  "Ah. You're still here.",
  "There you are.",
  "You've been watching quietly, haven't you?",
  "Don't worry. I noticed you too.",
  "You're different from most people.",
  "...Thank you. For not leaving.",
  "You don't look disappointed. How unusual.",
  "If you're here, I suppose I can stay a little longer.",
}

-- 1.4 Sad / Fake-happy / Miserable
bubbleTextsSad = {
  "I need a nap. Preferably a dramatic one.",
  "Ah... I appear to be functioning again. How tragic.",
  "It's quiet. That usually means something's wrong.",
  "I wouldn't call this pain. It's more... constant.",
  "I'm tired in a way sleep doesn't fix.",
  "Do you ever feel like you missed the moment you mattered?",
  "I can smile, if that helps everyone else.",
  "I wonder how long I've felt like this.",
  "It's fine. I know this part well.",
  "Some days are lighter. Today declined.",
  "I don't need help. I just don't need *this*.",
  "Loneliness is impressive-it hides in plain sight.",
  "I thought I'd feel different by now.",
  "I keep going. Out of habit, I suppose.",
  "This mood will pass. Eventually. I think.",
  "I don't feel terrible. I just don't feel good.",
  "Please don't worry. I've mastered pretending.",
  "Who would I be if I weren't so tired?",
  "I laughed earlier. It was ineffective.",
  "This isn't despair. It's quieter than that.",
  "I'll be fine. I usually am. Allegedly.",
}


bubbleTextsFakeHappy = {
  "Ahaha! I'm fine-see? Perfectly convincing.",
  "Wow~ what a lovely day! I am absolutely okay.",
  "Look at this smile. Very human.",
  "Everything's fine! Please accept this answer.",
  "I'm doing *great*. No follow-up questions.",
  "Isn't life wonderful? Haha...",
  "No no, really-I'm cheerful today.",
  "This happiness is completely genuine behavior.",
  "See? I can joke. That means nothing's wrong.",
  "I feel amazing! Anyway-",
  "Is my smile believable enough?",
  "Let's all agree this happiness is real.",
}

bubbleTextsMiserable = {
  "Something inside me went very quiet today.",
  "Ah... this feeling again.",
  "Please don't confuse this with peace.",
  "I'm here. That seems to be the issue.",
  "Everything feels distant.",
  "I don't remember when it started hurting. That concerns me.",
  "If I stop smiling, people worry. So I won't.",
  "This is the part where I endure.",
  "I wonder if anyone would notice if I disappeared.",
  "There's no crisis. Just emptiness.",
  "I've survived worse. Probably.",
  "I'm not broken. Just worn thin.",
  "This isn't a bad day. It's a familiar one.",
  "I wish I could explain this without alarming anyone.",
  "Don't worry. I'm still useful.",
  "It would be easier if this hurt more.",
  "I don't feel like myself. Then again, do I ever?",
  "Another day survived. Regrettably.",
}

-- 1.5 Drunk override lines
bubbleTextsDrunk = {
  "Ah~ I feel unreasonably brave about existence.",
  "Shhh... the world is spinning very politely.",
  "I'm not drunk. I'm introspective.",
  "If I fall over, it's intentional.",
  "Everything feels softer. That's suspicious.",
  "I could sleep for a year. Or five minutes.",
  "I love you. I mean-this room. The room is wonderful.",
  "Please don't look at me like that. I'm perfectly fine.",
  "My balance is more of a suggestion.",
  "These are the happiest bad decisions I've made today.",
}

-------------------------------------------------
-- 2) Bubble timing / state
-------------------------------------------------
bubbleTimer = 0
bubbleDuration = 120

-------------------------------------------------
-- 3) Bubble selection logic
-------------------------------------------------
function pickBubbleText()
  local m = (mood and mood.current) or 50
  local hour = os.date("*t").hour

  -- Rare direct-address lines (any mood)
  if bubbleTextsDirect and math.random(20) == 1 then
    return bubbleTextsDirect[math.random(#bubbleTextsDirect)]
  end

  -- Drunk lines override most moods (but still allow rare direct lines above)
  if intox and intox >= drunkThreshold and bubbleTextsDrunk then
    return bubbleTextsDrunk[math.random(#bubbleTextsDrunk)]
  end

  -- Fake Happy
  if m <=10 then
    return bubbleTextsFakeHappy[math.random(#bubbleTextsFakeHappy)]
  end

  -- Miserable
  if m <= 20 then
    return bubbleTextsMiserable[math.random(#bubbleTextsMiserable)]
  end

  -- Sad
  if m <= 40 then
    -- Sometimes fake-happy instead of sad
    if bubbleTextsFakeHappy and math.random(3) == 1 then
      return bubbleTextsFakeHappy[math.random(#bubbleTextsFakeHappy)]
    end
    return bubbleTextsSad[math.random(#bubbleTextsSad)]
  end

  -- Ecstatic (too good)
  if m >= 90 and bubbleTextsEcstatic then
    return bubbleTextsEcstatic[math.random(#bubbleTextsEcstatic)]
  end

  -- Happy (contextual)
  if m >= 60 then
    if hour >= 20 or hour < 6 then
      return bubbleTextsHappyNight[math.random(#bubbleTextsHappyNight)]
    else
      return bubbleTextsHappyDay[math.random(#bubbleTextsHappyDay)]
    end
  end

  -- Default neutral
  return bubbleTexts[math.random(#bubbleTexts)]
end

-------------------------------------------------
-- 4) Bubble display helper
-------------------------------------------------
function showBubble()
  local text = pickBubbleText()
  SKIN:Bang('!SetOption', 'MeterBubble', 'Text', text)
  SKIN:Bang('!ShowMeter', 'MeterBubble')
  bubbleTimer = bubbleDuration
end

-------------------------------------
-- UTILITY
-------------------------------------

-------------------------------------------------
-- 1) Random helper
-------------------------------------------------
function randRange(a, b)
  if b < a then b = a end
  return math.random(a, b)
end

-------------------------------------------------
-- 2) Clamp helper
-------------------------------------------------
function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

-------------------------------------------------
-- 3) Airborne helper
-------------------------------------------------
function isAirborne()
  return Y < (GroundY - 1)
end

-------------------------------------
-- MOOD + PET PANEL (Rainmeter)
-------------------------------------

-------------------------------------------------
-- 1) Persistent state (tables + UI flags)
-------------------------------------------------
needs = needs or { hunger=80, energy=80, clean=80, social=80, health=80 }
mood  = mood  or { current=50, event=0, label="neutral" }
panelOpen = panelOpen or false
foodMenuOpen = foodMenuOpen or false

-------------------------------------------------
-- 2) Configuration readers / helpers
-------------------------------------------------
local function getMoodCfg()
  return {
    weight_hunger = tonumber(SKIN:GetVariable('MoodWeightHunger')) or 0.25,
    weight_energy = tonumber(SKIN:GetVariable('MoodWeightEnergy')) or 0.20,
    weight_clean  = tonumber(SKIN:GetVariable('MoodWeightClean'))  or 0.15,
    weight_social = tonumber(SKIN:GetVariable('MoodWeightSocial')) or 0.20,
    weight_health = tonumber(SKIN:GetVariable('MoodWeightHealth')) or 0.20,

    inertia = tonumber(SKIN:GetVariable('MoodInertia')) or 0.10,
    event_decay_per_sec = tonumber(SKIN:GetVariable('MoodEventDecayPerSec')) or 0.995,

    min = tonumber(SKIN:GetVariable('MoodMin')) or 0,
    max = tonumber(SKIN:GetVariable('MoodMax')) or 100,

    miserable_max = tonumber(SKIN:GetVariable('MoodMiserableMax')) or 19,
    sad_max       = tonumber(SKIN:GetVariable('MoodSadMax')) or 39,
    neutral_max   = tonumber(SKIN:GetVariable('MoodNeutralMax')) or 59,
    happy_max     = tonumber(SKIN:GetVariable('MoodHappyMax')) or 79,
  }
end

local function moodLabelFromValue(val, cfg)
  if val <= cfg.miserable_max then return "miserable" end
  if val <= cfg.sad_max       then return "sad" end
  if val <= cfg.neutral_max   then return "neutral" end
  if val <= cfg.happy_max     then return "happy" end
  return "ecstatic"
end

local function calcNeedScore(cfg)
  return
    (needs.hunger * cfg.weight_hunger) +
    (needs.energy * cfg.weight_energy) +
    (needs.clean  * cfg.weight_clean)  +
    (needs.social * cfg.weight_social) +
    (needs.health * cfg.weight_health)
end

-------------------------------------------------
-- 3) Mood math (needs -> mood)
-------------------------------------------------
function updateMood(dtSeconds)
  local cfg = getMoodCfg()
  mood.event = mood.event * (cfg.event_decay_per_sec ^ dtSeconds)

  local target = calcNeedScore(cfg) + mood.event
  target = clamp(target, cfg.min, cfg.max)

  mood.current = mood.current + (target - mood.current) * cfg.inertia
  mood.label = moodLabelFromValue(mood.current, cfg)
end

-------------------------------------------------
-- 4) Panel rendering (meters)
-------------------------------------------------
function updatePanelMeters()
  if not panelOpen then return end

  SKIN:Bang('!SetOption', 'MeterMoodLabel', 'Text',
    'Mood: ' .. mood.label .. ' (' .. tostring(math.floor(mood.current + 0.5)) .. ')'
  )

  local w = math.floor((clamp(mood.current, 0, 100) / 100) * 180)
  if w < 1 then w = 1 end

  SKIN:Bang('!SetOption', 'MeterMoodBarFill', 'Shape',
    'Rectangle 0,0,' .. w .. ',12,3 | Fill Color 255,255,255,180'
  )

  SKIN:Bang('!UpdateMeter', 'MeterMoodLabel')
  SKIN:Bang('!UpdateMeter', 'MeterMoodBarFill')
end

-------------------------------------------------
-- 5) Panel open/close (main UI)
-------------------------------------------------
function TogglePanel()
  panelOpen = not panelOpen

  if panelOpen then
    SKIN:Bang('!ShowMeterGroup', 'PetPanel')
    updatePanelMeters()
  else
    SKIN:Bang('!HideMeterGroup', 'PetPanel')

    -- close food menu if panel closes
    if foodMenuOpen then
      foodMenuOpen = false
      SKIN:Bang('!HideMeterGroup', 'FoodMenu')
    end
  end

scriptMoving = true
SKIN:Bang('!Move', X, Y)
scriptMoving = false

  SKIN:Bang('!Redraw')
end

-------------------------------------------------
-- 6) Food submenu open/close
-------------------------------------------------
function ToggleFoodMenu()
  foodMenuOpen = not foodMenuOpen

  if foodMenuOpen then
    -- show submenu
    SKIN:Bang('!ShowMeterGroup', 'FoodMenu')

    -- hide main buttons so they can't "ghost" behind the submenu
    SKIN:Bang('!HideMeterGroup', 'PetPanelButtons')
  else
    -- hide submenu
    SKIN:Bang('!HideMeterGroup', 'FoodMenu')

    -- bring main buttons back (only if panel is still open)
    if panelOpen then
      SKIN:Bang('!ShowMeterGroup', 'PetPanelButtons')
    end
  end

scriptMoving = true
SKIN:Bang('!Move', X, Y)
scriptMoving = false

  SKIN:Bang('!Redraw')
end

-------------------------------------------------
-- 7) Actions: Feed / Play / Clean
-------------------------------------------------
function FeedFood(foodName)
  local hungerGain = 10
  local moodBoost = 6

  if foodName == "Onigiri" then
    hungerGain = 25
    moodBoost = 10

  elseif foodName == "Tea" then
    hungerGain = 8
    moodBoost = 8
    needs.energy = clamp(needs.energy + 6, 0, 100)

  elseif foodName == "Sake" then
    hungerGain = 5
    moodBoost = 14
    intox = clamp((intox or 0) + 22, 0, 100)
    needs.energy = clamp(needs.energy - 8, 0, 100)
  end

  needs.hunger = clamp(needs.hunger + hungerGain, 0, 100)
  mood.event = clamp(mood.event + moodBoost, -100, 100)

  updateMood(0.016)
  updatePanelMeters()

  -- Close Food menu
  foodMenuOpen = false
  SKIN:Bang('!HideMeterGroup', 'FoodMenu')
  SKIN:Bang('!ShowMeterGroup', 'PetPanelButtons')

  if panelOpen then
    SKIN:Bang('!ShowMeterGroup', 'PetPanelButtons')
  end

  SKIN:Bang('!Redraw')
end

function Play()
  needs.social = clamp(needs.social + 20, 0, 100)
  needs.energy = clamp(needs.energy - 10, 0, 100)
  mood.event   = clamp(mood.event + 12, -100, 100)
  updatePanelMeters()
  SKIN:Bang('!Redraw')
end

function Clean()
  needs.clean = clamp(needs.clean + 30, 0, 100)
  mood.event  = clamp(mood.event + 6, -100, 100)
  updatePanelMeters()
  SKIN:Bang('!Redraw')
end

-------------------------------------
-- RENDER HELPER
-------------------------------------

-------------------------------------------------
-- 1 Image selection + render
-------------------------------------------------
function applyImage()

  local meter = SKIN:GetMeter('MeterDazai')
  if not meter then
    print('DEBUG: ERROR! MeterDazai not found!')
    return
  end

  local img

  -------------------------------------------------
  -- 1.1 Idle / Drunk idle
  -------------------------------------------------
  if state == 'idle' then
    if drunk then
      img = 'images\\drunk_' .. tostring(drunkFrame) .. '.png'
    else
      img = 'images\\idle_' .. tostring(idleFrame) .. '.png'
    end

  -------------------------------------------------
  -- 1.2 Walk
  -------------------------------------------------
  elseif state == 'walk' then
    local d = (dir == 1) and 'R' or 'L'
    img = 'images\\walk' .. d .. '_' .. tostring(walkFrame) .. '.png'

  -------------------------------------------------
  -- 1.3 Game
  -------------------------------------------------
  elseif state == 'game' then
    if gamePhase == 'intro' then
      img = 'images\\gameIntro_' .. tostring(gameFrame) .. '.png'
    else
      img = 'images\\gameLoop_' .. tostring(gameFrame) .. '.png'
    end

  -------------------------------------------------
  -- 1.4 Ball
  -------------------------------------------------
  elseif state == 'ball' then
    img = 'images\\ball_' .. tostring(ballFrame) .. '.png'

  -------------------------------------------------
  -- Chaos
  -------------------------------------------------
  elseif state == 'chaos' then
    local d = (dir == 1) and 'R' or 'L'
    img = 'images\\chaos'..d..'_'..tostring(chaosFrame)..'.png'

  -------------------------------------------------
  -- Splat
  -------------------------------------------------

  elseif state == 'splat' then
    local d = (dir == 1) and 'R' or 'L'
    img = 'images\\fall'..d..'_'..tostring(splatFrame)..'.png'

  -------------------------------------------------
  -- laugh
  -------------------------------------------------
  elseif state == 'laugh' then
    local d = (dir == 1) and 'R' or 'L'
    img = 'images\\laugh'..d..'_'..tostring(laughFrame)..'.png'

  -------------------------------------------------
  -- 1.5 Dangle
  -------------------------------------------------
  elseif state == 'dangle' then
    img = 'images\\dangle_' .. tostring(dangleFrame) .. '.png'

  -------------------------------------------------
  -- 1.6 Read
  -------------------------------------------------
  elseif state == 'read' then
    img = 'images\\read_' .. tostring(readFrame) .. '.png'

  -------------------------------------------------
  -- 1.7 Sleep
  -------------------------------------------------
  elseif state == 'sleep' then
    img = 'images\\sleep_' .. tostring(sleepFrame) .. '.png'

  -------------------------------------------------
  -- 1.8 Peek
  -------------------------------------------------
  elseif state == 'peek' then
    img = 'images\\peek' .. peekSide.. '_' .. tostring(peekFrame) .. '.png'

  -------------------------------------------------
  -- 1.9 Rope
  -------------------------------------------------

  elseif state == 'rope_in' then -- walking in with rope (frames 1-4)
    img = 'images\\walkNL_' .. tostring(ropeFrame) .. '.png'

  elseif state == 'rope_out' then -- backing up, walking out of screen with rope (frames 5-8)
    img = 'images\\walkOL_' .. tostring(ropeFrame) .. '.png'

  elseif state == 'rope_shy' then -- embarrassed frames
    img = 'images\\shyL_' .. tostring(ropeFrame) .. '.png'

  -------------------------------------------------
  -- 1.10 Fallback
  -------------------------------------------------
  else
    -- fallback
    img = 'images\\idle_' .. tostring(idleFrame) .. '.png'
  end

  if not img then
      -- force something so we see him
      img = 'images\\idle_1.png'
  end

  SKIN:Bang('!SetOption', 'MeterDazai', 'ImageName', img)
end

-------------------------------------
-- IDLE ANIMATION
-------------------------------------
-- (Idle image selection is in applyImage; idle frame stepping is in stepFrame)

-------------------------------------
-- WALKING ANIMATION
-------------------------------------

-------------------------------------------------
-- 2) Walk movement
-------------------------------------------------
function stepMove()
  if state ~= 'walk' then return end

  -- Work area of the monitor the skin is CURRENTLY on
  local monX = tonumber(SKIN:GetMeasure('MeasureMonX'):GetValue()) or 0
  local monW = tonumber(SKIN:GetMeasure('MeasureMonW'):GetValue()) or 1920
  local monRight = monX + monW

  -- Use the skin window width (your meter is W=200)
  local skinW = tonumber(SKIN:GetVariable('CURRENTCONFIGWIDTH')) or 200

  local minX = monX
  local maxX = monRight - skinW
  if maxX < minX then maxX = minX end

  X = X + (dir * Step)

  if X >= maxX then
    X = maxX
    dir = -1
    walkFrame = 1
    applyImage()
  elseif X <= minX then
    X = minX
    dir = 1
    walkFrame = 1
    applyImage()
  end

scriptMoving = true
SKIN:Bang('!Move', X, Y)
scriptMoving = false
end
-------------------------------------
-- READING ANIMATION
-------------------------------------
-- (Read image selection is in applyImage; read frame stepping is in stepFrame;
--  read entry logic is inside stepState.)

-------------------------------------
-- RUBBER BAND BALL ANIMATION
-------------------------------------
-- (Ball image selection is in applyImage; ball frame stepping is in stepFrame;
--  ball entry logic is in Update and stepState.)

-------------------------------------
-- VIDEO GAME ANIMATION
-------------------------------------
-- (Game image selection is in applyImage; game frame stepping is in stepFrame;
--  toggle logic is in ToggleGaming.)

-------------------------------------
-- FALLING ANIMATION
-------------------------------------
-- (Fall physics/landing logic is in Update and Drop.)

-------------------------------------
-- DANGLE ANIMATION
-------------------------------------
-- (Dangle image selection is in applyImage; dangle physics/frame mapping is in Update.)

-------------------------------------
-- FRAME STEPPER (Mixed states: idle/walk/read/game/ball)
-------------------------------------

-------------------------------------------------
-- 3) Frame stepping (all animated states)
-------------------------------------------------
function stepFrame()
  frameTick = frameTick + 1

  -------------------------------------------------
  -- 3.1) Idle / Drunk idle
  -------------------------------------------------
  if state == 'idle' then
    if drunk then
      if frameTick >= DrunkFrameDelay then
        frameTick = 0
        drunkFrame = drunkFrame + 1
        if drunkFrame > DrunkFrames then drunkFrame = 1 end
        applyImage()
      end
    else
      if frameTick >= IdleFrameDelay then
        frameTick = 0
        idleFrame = idleFrame + 1
        if idleFrame > IdleFrames then idleFrame = 1 end
        applyImage()
      end
    end

  ---------------------------------------------------
  -- 3.9) laugh
  ---------------------------------------------------
elseif state == 'laugh' then
  if frameTick >= 8 then
    frameTick = 0
    laughFrame = laughFrame + 1
    if laughFrame > 2 then
      laughFrame = 1
    end
    applyImage()
 end

  -------------------------------------------------
  -- 3.2) Sleep
  -------------------------------------------------
  elseif state == 'sleep' then
    if frameTick >= SleepFrameDelay then
      frameTick = 0
      sleepFrame = sleepFrame + 1
      if sleepFrame > SleepFrames then sleepFrame = 1 end
      applyImage()
    end

  -------------------------------------------------
  -- 3.3) Peek
  -------------------------------------------------
  elseif state == 'peek' then
    if frameTick >= PeekFrameDelay then
      frameTick = 0
      peekFrame = peekFrame + 1
      if peekFrame > PeekFrames then peekFrame = PeekFrames end
      applyImage()
    end

  -------------------------------------------------
  -- Splat (no animation, just hold)
  -------------------------------------------------
  elseif state == 'splat' then
    -- do nothing (handled in stepState)
    return

  -------------------------------------------------
  -- 3.5) Walk
  -------------------------------------------------
  elseif state == 'walk' then
    if frameTick >= WalkFrameDelay then
      frameTick = 0
      walkFrame = walkFrame + 1
      if walkFrame > WalkFrames then walkFrame = 1 end
      applyImage()
    end

  -------------------------------------------------
  -- 3.6) Read
  -------------------------------------------------
  elseif state == 'read' then
    if frameTick >= ReadFrameDelay then
      frameTick = 0
      readFrame = readFrame + 1
      if readFrame > ReadFrames then readFrame = 1 end
      applyImage()
    end

  -------------------------------------------------
  -- 3.7) Game
  -------------------------------------------------
  elseif state == 'game' then
    local delay = (gamePhase == 'intro') and GameIntroDelay or GameLoopDelay
    if frameTick >= delay then
      frameTick = 0
      gameFrame = gameFrame + 1

      if gamePhase == 'intro' then
        if gameFrame > GameIntroFrames then
          hasPlayedGameIntro = true
          gamePhase = 'loop'
          gameFrame = 1
        end
      else
        if gameFrame > GameLoopFrames then
          gameFrame = 1
        end
      end

      applyImage()
    end

  -------------------------------------------------
  -- 3.8) Ball
  -------------------------------------------------
  elseif state == 'ball' then
    if frameTick >= BallFrameDelay then
      frameTick = 0
      ballFrame = ballFrame + 1
      if ballFrame > BallFrames then ballFrame = 1 end
      applyImage()
    end
  end

end
