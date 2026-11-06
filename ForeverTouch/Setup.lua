-- Setup: first-run wizard, controller movement, recommended settings and the
-- optional hiding of Blizzard's default action bars.

local _, ns = ...
local W = ns.W
local C = ns.color

-- Movement --------------------------------------------------------------------------
-- WoW addons cannot move or jump the character (Blizzard protects movement).
-- WoW's own controller support can, and DroidDeck's on-screen stick shows up
-- as a controller - so we switch that on and make A jump.
function ns.ControllerMovementAvailable()
    return ns.CVarExists("GamePadEnable")
end

function ns.ControllerMovementOn()
    return ns.GetCVarBool("GamePadEnable") == true
end

function ns.SetControllerMovement(on)
    if InCombatLockdown() then
        ns.Print("Leave combat first.")
        return false
    end
    if not ns.ControllerMovementAvailable() then
        ns.Print("This client has no controller support. Use tap-to-move, or DroidDeck screen keys for W A S D and Space.")
        return false
    end
    ns.SetCVar("GamePadEnable", on)
    if on and SetBinding then
        -- A / Cross = jump. Other controller buttons keep their defaults.
        if pcall(SetBinding, "PAD1", "JUMP") and SaveBindings and GetCurrentBindingSet then
            SaveBindings(GetCurrentBindingSet())
        end
    end
    return true
end

-- Click-to-move: tap (right-click) the ground to walk there.
function ns.TapToMoveOn() return ns.GetCVarBool("autoInteract") == true end
function ns.SetTapToMove(on) return ns.SetCVar("autoInteract", on) end

-- Recommended client settings ------------------------------------------------------
ns.comfortSettings = {
    { cvar = "interactOnLeftClick", label = "Tap to talk, loot and interact",
      sub = "A single tap on an NPC, corpse or object interacts with it." },
    { cvar = "autoLootDefault", label = "Auto loot",
      sub = "Loot everything without a loot window." },
    { cvar = "ActionButtonUseKeyDown", label = "Cast the moment you touch",
      sub = "Spells fire on touch instead of on release. Feels snappier." },
    { cvar = "countdownForCooldowns", label = "Cooldown numbers",
      sub = "Show seconds remaining on the spell buttons." },
}

function ns.AvailableComfortSettings()
    local list = {}
    for _, s in ipairs(ns.comfortSettings) do
        if ns.CVarExists(s.cvar) then list[#list + 1] = s end
    end
    return list
end

-- Default action bars -------------------------------------------------------------------
local hiddenParent = CreateFrame("Frame")
hiddenParent:Hide()

local HIDE = { "MainMenuBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarLeft", "MultiBarRight",
    "StanceBarFrame", "StanceBar" }
-- Things that live inside the main bar but are still useful on their own.
local KEEP = { "PetActionBarFrame", "PetActionBar", "MainMenuExpBar", "ReputationWatchBar", "MainStatusTrackingBarContainer" }

function ns.HideBlizzardBars()
    ns.RunOOC("hideBars", function()
        for _, name in ipairs(HIDE) do
            local f = _G[name]
            if f and f.SetParent then pcall(f.SetParent, f, hiddenParent) end
        end
        for _, name in ipairs(KEEP) do
            local f = _G[name]
            if f and f.SetParent then pcall(f.SetParent, f, UIParent) end
        end
    end)
end

-- Wizard ------------------------------------------------------------------------------
local wizard

local function bullet(parent, anchor, text, y)
    local fs = W.Font(parent, 14)
    fs:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, y or -10)
    fs:SetPoint("RIGHT", parent, "RIGHT", -26, 0)
    fs:SetJustifyH("LEFT")
    fs:SetText(text)
    return fs
end

local function buildWizard()
    local f = W.Panel("ForeverTouchSetup", UIParent, 700, 520, "Welcome to Forever Touch")
    f:SetPoint("CENTER", 0, 20)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:Hide()
    W.CloseButton(f, function() ns.FinishSetup() end)

    f.stepText = W.Font(f, 13, C.accentSoft[1], C.accentSoft[2], C.accentSoft[3])
    f.stepText:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -4)

    f.pages = {}
    local function page()
        local p = CreateFrame("Frame", nil, f)
        p:SetPoint("TOPLEFT", 26, -86)
        p:SetPoint("BOTTOMRIGHT", -26, 76)
        p:Hide()
        f.pages[#f.pages + 1] = p
        return p
    end

    -- Page 1: hand and screen ---------------------------------------------------
    local p1 = page()
    p1.heading = "Your thumbs"
    local intro = W.Font(p1, 14)
    intro:SetPoint("TOPLEFT")
    intro:SetPoint("RIGHT")
    intro:SetJustifyH("LEFT")
    intro:SetText("Spells sit in a big wheel under one thumb. Your other thumb moves your character with DroidDeck's on-screen stick.")

    local handLabel = W.Font(p1, 15, C.gold[1], C.gold[2], C.gold[3])
    handLabel:SetPoint("TOPLEFT", intro, "BOTTOMLEFT", 0, -22)
    handLabel:SetText("Which thumb casts spells?")
    local hand = W.Segmented(p1, 640, 48, {
        { value = "right", label = "Right thumb (stick on the left)" },
        { value = "left", label = "Left thumb (stick on the right)" },
    }, function() return ns.db.handed end, function(v) ns.SetHanded(v) end)
    hand:SetPoint("TOPLEFT", handLabel, "BOTTOMLEFT", 0, -10)

    local screenLabel = W.Font(p1, 15, C.gold[1], C.gold[2], C.gold[3])
    screenLabel:SetPoint("TOPLEFT", hand, "BOTTOMLEFT", 0, -26)
    screenLabel:SetText("Screen")
    local detected = W.Font(p1, 13, C.muted[1], C.muted[2], C.muted[3])
    detected:SetPoint("LEFT", screenLabel, "RIGHT", 12, 0)
    local screen = W.Segmented(p1, 640, 48, {
        { value = "auto", label = "Switch automatically" },
        { value = "cover", label = "Folded" },
        { value = "main", label = "Unfolded" },
    }, function() return ns.db.profileMode end, function(v)
        ns.db.profileMode = v
        ns.CheckProfile()
    end)
    screen:SetPoint("TOPLEFT", screenLabel, "BOTTOMLEFT", 0, -10)
    local screenNote = bullet(p1, screen, "Folded and unfolded each keep their own layout, so you can tune both.", -12)
    screenNote:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
    p1:SetScript("OnShow", function()
        detected:SetText("Detected now: " .. ns.profileLabels[ns.DetectProfile()])
    end)

    -- Page 2: movement ------------------------------------------------------------
    local p2 = page()
    p2.heading = "Running and jumping"
    local why = W.Font(p2, 14)
    why:SetPoint("TOPLEFT")
    why:SetPoint("RIGHT")
    why:SetJustifyH("LEFT")
    why:SetText("Blizzard doesn't let addons move your character, so movement uses WoW's built-in controller support with DroidDeck's on-screen stick. You get smooth analog running, and A jumps.")

    local enable = W.Button(p2, 300, 48, "Turn on controller movement", function(self)
        if ns.SetControllerMovement(true) then p2:Refresh() end
    end, "primary")
    enable:SetPoint("TOPLEFT", why, "BOTTOMLEFT", 0, -16)
    local status = W.Font(p2, 14)
    status:SetPoint("LEFT", enable, "RIGHT", 14, 0)

    local s1 = bullet(p2, enable, "1.  In DroidDeck, swipe in from the right edge and turn on the on-screen controls.", -18)
    local s2 = bullet(p2, s1, "2.  Keep the left stick and the A button. Drag the stick onto the pink circle.")
    local s3 = bullet(p2, s2, "3.  Drag on empty ground with one finger to turn the camera. Pinch or use the + / - buttons to zoom.")
    local s4 = bullet(p2, s3, "If the stick moves the mouse instead of your character, set this game's Steam Input layout to Gamepad.")
    s4:SetTextColor(C.muted[1], C.muted[2], C.muted[3])

    local ctm = W.Toggle(p2, 640, "Also allow tap-to-move", "Tap the ground to walk there (needs DroidDeck's long-press = right click).",
        ns.TapToMoveOn, function(v) ns.SetTapToMove(v) end)
    ctm:SetPoint("TOPLEFT", s4, "BOTTOMLEFT", 0, -14)

    function p2:Refresh()
        if not ns.ControllerMovementAvailable() then
            status:SetText("|cffff6666Not supported by this client|r")
            enable:Hide()
        elseif ns.ControllerMovementOn() then
            status:SetText("|cff4ddb80Controller movement is on|r")
            enable:SetLabel("Controller movement on")
        else
            status:SetText("")
        end
        ctm:SetShown(ns.CVarExists("autoInteract"))
    end
    p2:SetScript("OnShow", function(self)
        self:Refresh()
        ns.ShowStickGuide(true)
    end)
    p2:SetScript("OnHide", function() if not ns.editing then ns.ShowStickGuide(false) end end)

    -- Page 3: comfort settings ----------------------------------------------------
    local p3 = page()
    p3.heading = "Comfort settings"
    local prev
    for _, s in ipairs(ns.AvailableComfortSettings()) do
        local t = W.Toggle(p3, 640, s.label, s.sub,
            function() return ns.GetCVarBool(s.cvar) end,
            function(v) ns.SetCVar(s.cvar, v) end)
        if prev then t:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -8) else t:SetPoint("TOPLEFT") end
        prev = t
    end
    local hide = W.Toggle(p3, 640, "Hide the default action bars", "Forever Touch replaces them. The XP and pet bars stay.",
        function() return ns.db.hideBlizzardBars end,
        function(v)
            ns.db.hideBlizzardBars = v
            if v then ns.HideBlizzardBars() else ns.Print("Type /reload to bring the default bars back.") end
        end)
    if prev then hide:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -8) else hide:SetPoint("TOPLEFT") end

    -- Footer ------------------------------------------------------------------------
    f.back = W.Button(f, 120, 48, "Back", function() f:ShowPage(f.current - 1) end)
    f.back:SetPoint("BOTTOMLEFT", 26, 20)
    f.nextBtn = W.Button(f, 160, 48, "Next", function()
        if f.current < #f.pages then f:ShowPage(f.current + 1) else ns.FinishSetup() end
    end, "primary")
    f.nextBtn:SetPoint("BOTTOMRIGHT", -26, 20)
    f.dots = {}
    for i = 1, #f.pages do
        local d = W.Tex(f, "OVERLAY", ns.media .. "circle", 1, 1, 1, 0.3)
        d:SetSize(10, 10)
        d:SetPoint("BOTTOM", (i - (#f.pages + 1) / 2) * 18, 38)
        f.dots[i] = d
    end

    function f:ShowPage(i)
        i = math.max(1, math.min(#self.pages, i))
        self.current = i
        for k, p in ipairs(self.pages) do p:SetShown(k == i) end
        for k, d in ipairs(self.dots) do
            if k == i then d:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 1) else d:SetVertexColor(1, 1, 1, 0.3) end
        end
        self.stepText:SetText(("Step %d of %d - %s"):format(i, #self.pages, self.pages[i].heading))
        self.back:SetShown(i > 1)
        self.nextBtn:SetLabel(i == #self.pages and "Start playing" or "Next")
    end
    return f
end

function ns.ShowSetup()
    if InCombatLockdown() then
        ns.Print("Setup opens out of combat.")
        return
    end
    wizard = wizard or buildWizard()
    W.FitToScreen(wizard, 1.2)
    wizard:Show()
    wizard:ShowPage(1)
end

function ns.FinishSetup()
    if wizard then wizard:Hide() end
    ns.ShowStickGuide(false)
    local first = not ns.db.setupDone
    ns.db.setupDone = true
    if first then
        ns.Print("Ready! Tap a + button to add a spell. Open the menu (top corner) > Edit layout to move things.")
    end
end
