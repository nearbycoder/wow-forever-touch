-- ControllerTest: /ft padtest shows whether WoW can see a controller and live
-- left-stick input, then says what to fix. Movement itself is done by WoW's
-- controller support (addons can't move the character), so when the stick
-- does nothing, the problem is almost always that the stick never reaches WoW
-- as a controller.

local _, ns = ...
local W = ns.W
local C = ns.color
local M = ns.media

local GP = C_GamePad

local function safe(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a = pcall(fn, ...)
    if ok then return a end
end

-- Snapshot of what the client knows about controllers.
function ns.ControllerStatus()
    local s = { api = GP ~= nil, cvar = ns.GetCVarBool("GamePadEnable"), devices = {} }
    if not GP then return s end
    s.enabled = safe(GP.IsEnabled)
    local ids = safe(GP.GetAllDeviceIDs) or {}
    for _, id in ipairs(ids) do
        local mapped = safe(GP.GetDeviceMappedState, id)
        local raw = safe(GP.GetDeviceRawState, id)
        s.devices[#s.devices + 1] = { id = id, name = (raw and raw.name) or (mapped and mapped.name) or ("Controller " .. id) }
    end
    s.active = safe(GP.GetActiveDeviceID)
    return s
end

-- Left stick of the combined/active device: x, y in -1..1 (nil if unknown).
local function leftStick()
    if not GP then return end
    local id = safe(GP.GetCombinedDeviceID) or safe(GP.GetActiveDeviceID)
    if not id or id < 0 then
        local ids = safe(GP.GetAllDeviceIDs)
        id = ids and ids[1]
    end
    if not id then return end
    local st = safe(GP.GetDeviceMappedState, id)
    local stick = st and st.sticks and st.sticks[1]
    if stick then return stick.x or 0, stick.y or 0 end
end

local TEXT = {
    noapi = "|cffff6666This client has no controller support.|r\n"
        .. "Map DroidDeck's stick to keys instead: Steam Input layout 'Keyboard (WASD) and Mouse', with A = Space.",
    off = "|cffff6666Controller support is off.|r Tap 'Turn it on' below, then restart the game once.",
    none = "|cffff6666WoW doesn't see any controller.|r\n"
        .. "1) If you just turned controller support on, restart the game once.\n"
        .. "2) In DroidDeck, make sure the on-screen controller (not just touch) is on.\n"
        .. "3) In Steam, set this game's controller layout to 'Gamepad'.\n"
        .. "Still nothing? Use the key fallback: Steam Input layout 'Keyboard (WASD) and Mouse', A = Space.",
    still = "|cffffd140WoW sees a controller, but the left stick isn't moving it.|r\n"
        .. "DroidDeck's stick may be feeding a different device. Set Steam Input to 'Gamepad', or use the key fallback\n"
        .. "(Steam Input layout 'Keyboard (WASD) and Mouse', A = Space).",
    ok = "|cff4ddb80WoW receives your left stick.|r Close this and walk around.\n"
        .. "If you still don't move, close any open game windows: while one is open the stick may drive the cursor instead.",
}

local test

local function buildTest()
    local f = CreateFrame("Button", "ForeverTouchPadTest", UIParent)
    f:SetAllPoints(UIParent)
    f:SetFrameStrata("TOOLTIP")
    f:RegisterForClicks("AnyUp")
    f:Hide()
    table.insert(UISpecialFrames, "ForeverTouchPadTest")
    local bg = W.Color(f, "BACKGROUND", 0, 0, 0, 0.75)
    bg:SetAllPoints()

    f.title = W.Font(f, 22)
    f.title:SetPoint("TOP", 0, -36)
    f.title:SetText("Controller test")
    f.status = W.Font(f, 14, C.muted[1], C.muted[2], C.muted[3])
    f.status:SetPoint("TOP", f.title, "BOTTOM", 0, -10)
    f.status:SetWidth(1000)
    f.status:SetJustifyH("CENTER")

    -- Live stick view.
    local pad = CreateFrame("Frame", nil, f)
    pad:SetSize(200, 200)
    pad:SetPoint("CENTER", 0, 20)
    local ring = W.Tex(pad, "ARTWORK", M .. "ring", C.accent[1], C.accent[2], C.accent[3], 0.9)
    ring:SetAllPoints()
    local cross1 = W.Color(pad, "BACKGROUND", 1, 1, 1, 0.12)
    cross1:SetSize(2, 180) cross1:SetPoint("CENTER")
    local cross2 = W.Color(pad, "BACKGROUND", 1, 1, 1, 0.12)
    cross2:SetSize(180, 2) cross2:SetPoint("CENTER")
    f.dot = W.Tex(pad, "OVERLAY", M .. "circle", 1, 1, 1, 0.95)
    f.dot:SetSize(36, 36)
    f.dot:SetPoint("CENTER")
    f.readout = W.Font(pad, 13)
    f.readout:SetPoint("TOP", pad, "BOTTOM", 0, -8)
    f.prompt = W.Font(f, 16)
    f.prompt:SetPoint("BOTTOM", pad, "TOP", 0, 16)

    f.result = W.Font(f, 15)
    f.result:SetPoint("BOTTOM", 0, 110)
    f.result:SetWidth(1100)
    f.result:SetJustifyH("CENTER")

    f.enable = W.Button(f, 220, 48, "Turn it on", function()
        ns.SetControllerMovement(true)
        f:Begin()
    end, "primary")
    f.enable:SetPoint("BOTTOM", -120, 40)
    f.close = W.Button(f, 160, 48, "Close", function() f:Hide() end)
    f.close:SetPoint("BOTTOM", 110, 40)

    function f:Begin()
        -- Hand the stick back to movement if the controller cursor had it.
        safe(SetGamePadCursorControl, false)
        local s = ns.ControllerStatus()
        local names = {}
        for _, d in ipairs(s.devices) do names[#names + 1] = d.name end
        self.status:SetText(("Controller support: %s     Controllers WoW can see: %s"):format(
            s.cvar and "|cff4ddb80on|r" or "|cffff6666off|r",
            #names > 0 and table.concat(names, ", ") or "|cffff6666none|r"))
        self.moved, self.elapsed, self.done = 0, 0, false
        self.result:SetText("")
        self.enable:SetShown(s.api and not s.cvar)
        if not s.api then
            self:Finish("noapi")
        elseif not s.cvar then
            self:Finish("off")
        elseif #s.devices == 0 then
            self:Finish("none")
        else
            self.prompt:SetText("Move DroidDeck's left stick in a circle")
        end
        self:Show()
    end

    function f:Finish(key)
        self.done = true
        self.prompt:SetText("")
        self.result:SetText(TEXT[key])
        ns.db.lastPadTest = key
        ns.Print("Controller test: %s", (TEXT[key]:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("\n", " ")))
    end

    f:SetScript("OnUpdate", function(self, elapsed)
        local x, y = leftStick()
        if x then
            self.dot:ClearAllPoints()
            self.dot:SetPoint("CENTER", x * 82, y * 82)
            self.readout:SetText(("x %.2f   y %.2f"):format(x, y))
            if math.sqrt(x * x + y * y) > 0.35 then self.moved = self.moved + elapsed end
        else
            self.readout:SetText("no stick data")
        end
        if self.done then return end
        self.elapsed = self.elapsed + elapsed
        if self.moved > 0.4 then
            self:Finish("ok")
        elseif self.elapsed > 12 then
            self:Finish("still")
        end
    end)
    return f
end

function ns.ShowPadTest()
    test = test or buildTest()
    test:Begin()
end
