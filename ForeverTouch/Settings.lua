-- Settings: the touch-friendly settings panel, Blizzard options entry and
-- slash commands.

local _, ns = ...
local W = ns.W
local C = ns.color

local panel

local function sectionLabel(parent, text)
    local fs = W.Font(parent, 15, C.gold[1], C.gold[2], C.gold[3])
    fs:SetText(text)
    return fs
end

local function nextBar(current)
    local choices = {}
    for _, c in ipairs(ns.barChoices) do
        if c.value ~= "main" then choices[#choices + 1] = c.value end
    end
    for i, v in ipairs(choices) do
        if v == current then return choices[i % #choices + 1] end
    end
    return choices[1]
end

local function buildPanel()
    local f = W.Panel("ForeverTouchSettings", UIParent, 860, 600, "Forever Touch")
    f:SetPoint("CENTER")
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:Hide()
    W.CloseButton(f)
    table.insert(UISpecialFrames, "ForeverTouchSettings")

    local version = W.Font(f, 12, C.muted[1], C.muted[2], C.muted[3])
    version:SetPoint("LEFT", f.title, "RIGHT", 10, -2)
    version:SetText("v" .. ns.version)

    local refreshers = {}
    local function track(w) refreshers[#refreshers + 1] = w return w end

    -- Left column -----------------------------------------------------------------
    local left = CreateFrame("Frame", nil, f)
    left:SetPoint("TOPLEFT", 24, -64)
    left:SetSize(390, 440)

    local screenL = sectionLabel(left, "Screen layout")
    screenL:SetPoint("TOPLEFT")
    local detected = W.Font(left, 12, C.muted[1], C.muted[2], C.muted[3])
    detected:SetPoint("LEFT", screenL, "RIGHT", 10, 0)
    local screen = track(W.Segmented(left, 390, 44, {
        { value = "auto", label = "Auto" },
        { value = "cover", label = "Folded" },
        { value = "main", label = "Unfolded" },
    }, function() return ns.db.profileMode end, function(v)
        ns.db.profileMode = v
        ns.CheckProfile()
    end))
    screen:SetPoint("TOPLEFT", screenL, "BOTTOMLEFT", 0, -8)

    local handL = sectionLabel(left, "Spell thumb")
    handL:SetPoint("TOPLEFT", screen, "BOTTOMLEFT", 0, -18)
    local hand = track(W.Segmented(left, 390, 44, {
        { value = "right", label = "Right" },
        { value = "left", label = "Left" },
    }, function() return ns.db.handed end, function(v) ns.SetHanded(v) end))
    hand:SetPoint("TOPLEFT", handL, "BOTTOMLEFT", 0, -8)

    local pagesL = sectionLabel(left, "Spell wheel pages")
    pagesL:SetPoint("TOPLEFT", hand, "BOTTOMLEFT", 0, -18)
    local pageHint = W.Font(left, 12, C.muted[1], C.muted[2], C.muted[3])
    pageHint:SetPoint("LEFT", pagesL, "RIGHT", 10, 0)
    pageHint:SetText("Tap the small number on the wheel to flip pages.")

    local pages = track(W.Stepper(left, 390, "Number of pages", function() return ns.db.numPages end, function(v)
        ns.db.numPages = v
        ns.ApplyPages()
        f:Refresh()
    end, 1, 3, 1))
    pages:SetPoint("TOPLEFT", pagesL, "BOTTOMLEFT", 0, -6)

    local page1 = W.Font(left, 14)
    page1:SetPoint("TOPLEFT", pages, "BOTTOMLEFT", 0, -10)
    page1:SetText("Page 1:  Main bar (follows stance and forms)")

    f.pageRows = {}
    local prev = page1
    for p = 2, 3 do
        local row = CreateFrame("Frame", nil, left)
        row:SetSize(390, 44)
        row:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, p == 2 and -10 or -6)
        local label = W.Font(row, 14)
        label:SetPoint("LEFT")
        label:SetText("Page " .. p .. ":")
        local cycle = W.Button(row, 300, 40, "", function(self)
            if InCombatLockdown() then return end
            ns.db.pageBars[p] = nextBar(ns.db.pageBars[p])
            ns.ApplyPages()
            self:SetLabel(ns.BarLabel(ns.db.pageBars[p]) .. "   >")
        end)
        cycle:SetPoint("RIGHT")
        row.cycle = cycle
        row.page = p
        f.pageRows[p] = row
        prev = row
    end

    -- Right column -------------------------------------------------------------------
    local right = CreateFrame("Frame", nil, f)
    right:SetPoint("TOPRIGHT", -24, -64)
    right:SetSize(400, 440)
    local showL = sectionLabel(right, "Controls")
    showL:SetPoint("TOPLEFT")

    local toggles = {
        { "Target buttons", nil, function() return ns.db.showUtility end, function(v)
            ns.db.showUtility = v ns.UpdateGroupVisibility() end },
        { "Camera zoom buttons", nil, function() return ns.db.showCamera end, function(v)
            ns.db.showCamera = v ns.UpdateGroupVisibility() end },
        { "Show empty buttons", "Empty slots show a + you can tap.", function() return ns.db.showEmptyButtons end, function(v)
            ns.db.showEmptyButtons = v ns.RunOOC("empty", ns.cluster.UpdateAll) end },
        { "Dim out of combat", "Controls fade a little while you're not fighting.", function() return ns.db.dimOutOfCombat end, function(v)
            ns.db.dimOutOfCombat = v ns.ApplyGroupAlpha() end },
        { "Hide default action bars", nil, function() return ns.db.hideBlizzardBars end, function(v)
            ns.db.hideBlizzardBars = v
            if v then ns.HideBlizzardBars() else ns.Print("Type /reload to bring the default bars back.") end
        end },
    }
    if ns.ControllerMovementAvailable() then
        toggles[#toggles + 1] = { "Controller movement", "DroidDeck's stick runs, A jumps.", ns.ControllerMovementOn,
            function(v) ns.SetControllerMovement(v) end }
    end
    if ns.CVarExists("interactOnLeftClick") then
        toggles[#toggles + 1] = { "Tap to interact", "Talk, loot and use objects with one tap.",
            function() return ns.GetCVarBool("interactOnLeftClick") end,
            function(v) ns.SetCVar("interactOnLeftClick", v) end }
    end
    local last = showL
    for i, t in ipairs(toggles) do
        local w = track(W.Toggle(right, 400, t[1], t[2], t[3], t[4]))
        w:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, i == 1 and -6 or -2)
        last = w
    end

    -- Footer ---------------------------------------------------------------------------
    local close = W.Button(f, 120, 48, "Close", function() f:Hide() end, "primary")
    close:SetPoint("BOTTOMRIGHT", -24, 20)
    local edit = W.Button(f, 150, 48, "Edit layout", function()
        f:Hide()
        ns.EnterEditMode()
    end)
    edit:SetPoint("BOTTOMLEFT", 24, 20)
    local setup = W.Button(f, 150, 48, "Run setup again", function()
        f:Hide()
        ns.ShowSetup()
    end)
    setup:SetPoint("LEFT", edit, "RIGHT", 8, 0)
    local reset = W.Button(f, 170, 48, "Reset this layout", function()
        if InCombatLockdown() then return end
        ns.ResetLayout()
        ns.Print("Layout reset for the %s.", ns.profileLabels[ns.ActiveProfile()])
    end)
    reset:SetPoint("LEFT", setup, "RIGHT", 8, 0)

    function f:Refresh()
        detected:SetText("Now: " .. ns.profileLabels[ns.ActiveProfile()])
        for p, row in pairs(self.pageRows) do
            row:SetShown(p <= ns.db.numPages)
            row.cycle:SetLabel(ns.BarLabel(ns.db.pageBars[p]) .. "   >")
        end
        for _, w in ipairs(refreshers) do if w.Refresh then w.Refresh() end end
    end
    f:HookScript("OnShow", function(self) self:Refresh() end)
    return f
end

function ns.ShowSettings()
    panel = panel or buildPanel()
    W.FitToScreen(panel, 1.2)
    panel:Show()
end

-- Blizzard options entry ---------------------------------------------------------------
ns.OnInit(function()
    local canvas = CreateFrame("Frame")
    canvas.name = "Forever Touch"
    local open = W.Button(canvas, 300, 48, "Open Forever Touch settings", function()
        if SettingsPanel and SettingsPanel:IsShown() then pcall(HideUIPanel, SettingsPanel) end
        if InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() then pcall(HideUIPanel, InterfaceOptionsFrame) end
        ns.ShowSettings()
    end, "primary")
    open:SetPoint("TOPLEFT", 16, -16)
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(canvas, "Forever Touch")
        Settings.RegisterAddOnCategory(category)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(canvas)
    end
end)

-- Slash commands ----------------------------------------------------------------------
SLASH_FOREVERTOUCH1 = "/ft"
SLASH_FOREVERTOUCH2 = "/forevertouch"
SlashCmdList.FOREVERTOUCH = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if msg == "edit" then
        ns.EnterEditMode()
    elseif msg == "setup" then
        ns.ShowSetup()
    elseif msg == "reset" then
        if InCombatLockdown() then ns.Print("Leave combat first.") return end
        ns.ResetLayout()
        ns.Print("Layout reset.")
    elseif msg == "help" then
        ns.Print("/ft - settings, /ft edit - move and assign buttons, /ft setup - setup guide, /ft reset - reset layout")
    else
        ns.ShowSettings()
    end
end
