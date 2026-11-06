-- Settings: the touch-friendly settings panel, Blizzard options entry and
-- slash commands.

local _, ns = ...
local W = ns.W
local C = ns.color

local panel

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

local PANEL_W, PANEL_H = 820, 610
local COL_W, GAP = 376, 20
local TABS = {
    { value = "layout", label = "Layout" },
    { value = "controls", label = "Controls" },
    { value = "movement", label = "Movement" },
    { value = "help", label = "Help" },
}

local function hint(parent, text, anchor, y)
    local fs = W.Font(parent, 12, C.muted[1], C.muted[2], C.muted[3])
    fs:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, y or -6)
    fs:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
    fs:SetJustifyH("LEFT")
    fs:SetText(text)
    return fs
end

-- Stacks widgets vertically inside a card.
local function stacker(card, startY)
    local y = startY or -40
    return function(widget, height, gapAfter)
        widget:SetPoint("TOPLEFT", card, "TOPLEFT", 16, y)
        y = y - (height or widget:GetHeight()) - (gapAfter or 8)
        return widget
    end
end

local function buildPanel()
    local f = W.Panel("ForeverTouchSettings", UIParent, PANEL_W, PANEL_H, "Forever Touch")
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

    f.pages = {}
    local function page(key)
        local p = CreateFrame("Frame", nil, f)
        p:SetPoint("TOPLEFT", 24, -128)
        p:SetPoint("BOTTOMRIGHT", -24, 84)
        p:Hide()
        f.pages[key] = p
        return p
    end
    local function cards(p)
        local left = W.Card(p, COL_W, 10)
        local right = W.Card(p, COL_W, 10)
        return left, right
    end
    local inner = COL_W - 32

    -- Layout tab ------------------------------------------------------------------------
    local pl = page("layout")
    local screenCard = W.Card(pl, COL_W, 122, "Screen")
    screenCard:SetPoint("TOPLEFT")
    local add = stacker(screenCard)
    local screen = track(W.Segmented(screenCard, inner, 42, {
        { value = "auto", label = "Auto" },
        { value = "cover", label = "Folded" },
        { value = "main", label = "Unfolded" },
    }, function() return ns.db.profileMode end, function(v)
        ns.db.profileMode = v
        ns.CheckProfile()
        f:Refresh()
    end))
    add(screen, 42, 8)
    local detected = W.Font(screenCard, 12, C.muted[1], C.muted[2], C.muted[3])
    add(detected, 14)

    local handCard = W.Card(pl, COL_W, 106, "Spell thumb")
    handCard:SetPoint("TOPLEFT", screenCard, "BOTTOMLEFT", 0, -GAP)
    local hand = track(W.Segmented(handCard, inner, 42, {
        { value = "right", label = "Right thumb" },
        { value = "left", label = "Left thumb" },
    }, function() return ns.db.handed end, function(v) ns.SetHanded(v) end))
    stacker(handCard)(hand, 42)

    local arrangeCard = W.Card(pl, COL_W, 106, "Arrange")
    arrangeCard:SetPoint("TOPLEFT", handCard, "BOTTOMLEFT", 0, -GAP)
    local edit = W.Button(arrangeCard, (inner - 8) / 2, 44, "Edit layout", function()
        f:Hide()
        ns.EnterEditMode()
    end, "primary")
    edit:SetPoint("TOPLEFT", 16, -40)
    local reset = W.Button(arrangeCard, (inner - 8) / 2, 44, "Reset layout", function()
        if InCombatLockdown() then return end
        ns.ResetLayout()
        W.Toast("Layout reset for the " .. ns.profileLabels[ns.ActiveProfile()])
    end)
    reset:SetPoint("LEFT", edit, "RIGHT", 8, 0)

    local pagesCard = W.Card(pl, COL_W, 370, "Spell wheel pages")
    pagesCard:SetPoint("TOPRIGHT")
    local addP = stacker(pagesCard)
    local pages = track(W.Stepper(pagesCard, inner, "Pages", function() return ns.db.numPages end, function(v)
        ns.db.numPages = v
        ns.ApplyPages()
        f:Refresh()
    end, 1, 3, 1))
    addP(pages, 44, 6)
    addP(hint(pagesCard, "Tap the small number beside the big button to flip pages - works in combat.", pages, -2), 30, 10)
    local page1 = W.Font(pagesCard, 14)
    page1:SetJustifyH("LEFT")
    page1:SetText("Page 1  |cffa8adbfMain bar - follows stance and forms|r")
    addP(page1, 18, 14)
    f.pageRows = {}
    for pnum = 2, 3 do
        local row = CreateFrame("Frame", nil, pagesCard)
        row:SetSize(inner, 44)
        local label = W.Font(row, 14)
        label:SetPoint("LEFT")
        label:SetText("Page " .. pnum)
        local cycle = W.Button(row, inner - 80, 42, "", function(self)
            if InCombatLockdown() then return end
            ns.db.pageBars[pnum] = nextBar(ns.db.pageBars[pnum])
            ns.ApplyPages()
            self:SetLabel(ns.BarLabel(ns.db.pageBars[pnum]) .. "  >")
        end)
        cycle:SetPoint("RIGHT")
        row.cycle = cycle
        f.pageRows[pnum] = row
        addP(row, 44, 8)
    end

    -- Controls tab ---------------------------------------------------------------------
    local pc = page("controls")
    local onScreen = W.Card(pc, COL_W, 370, "On screen")
    onScreen:SetPoint("TOPLEFT")
    local addS = stacker(onScreen, -34)
    for _, t in ipairs({
        { "Target buttons", "Target, Assist and Clear.", function() return ns.db.showUtility end,
            function(v) ns.db.showUtility = v ns.UpdateGroupVisibility() end },
        { "Camera zoom buttons", "Hold + or - to keep zooming.", function() return ns.db.showCamera end,
            function(v) ns.db.showCamera = v ns.UpdateGroupVisibility() end },
        { "Show empty buttons", "Empty slots show a + you can tap.", function() return ns.db.showEmptyButtons end,
            function(v) ns.db.showEmptyButtons = v ns.RunOOC("empty", ns.cluster.UpdateAll) end },
        { "Dim out of combat", "Controls fade a little between fights.", function() return ns.db.dimOutOfCombat end,
            function(v) ns.db.dimOutOfCombat = v ns.ApplyGroupAlpha() end },
        { "Hide default action bars", "XP and pet bars stay. Undo needs /reload.", function() return ns.db.hideBlizzardBars end,
            function(v)
                ns.db.hideBlizzardBars = v
                if v then ns.HideBlizzardBars() else W.Toast("Type /reload to bring the default bars back") end
            end },
    }) do
        addS(track(W.Toggle(onScreen, inner, t[1], t[2], t[3], t[4])), 56, 4)
    end

    local game = W.Card(pc, COL_W, 370, "Game settings")
    game:SetPoint("TOPRIGHT")
    local addG = stacker(game, -34)
    for _, sdef in ipairs(ns.AvailableComfortSettings()) do
        addG(track(W.Toggle(game, inner, sdef.label, sdef.sub,
            function() return ns.GetCVarBool(sdef.cvar) end,
            function(v) ns.SetCVar(sdef.cvar, v) end)), 56, 4)
    end

    -- Movement tab ----------------------------------------------------------------------
    local pm = page("movement")
    local stickCard = W.Card(pm, COL_W, 370, "Stick area")
    stickCard:SetPoint("TOPLEFT")
    local addM = stacker(stickCard)
    local about = W.Font(stickCard, 13, C.muted[1], C.muted[2], C.muted[3])
    about:SetWidth(inner)
    about:SetJustifyH("LEFT")
    about:SetText("DroidDeck draws the stick. Size this area to match it - the pink circle on screen shows it while this tab is open.")
    addM(about, 46, 10)
    local stickSize = track(W.Stepper(stickCard, inner, "Size", function()
        return math.floor((ns.Layout("stick").scale or 1) * 100 + 0.5)
    end, function(v)
        if InCombatLockdown() then return end
        ns.Layout("stick").scale = v / 100
        ns.ApplyLayout()
    end, 50, 200, 10, function(v) return v .. "%" end))
    addM(stickSize, 44, 18)
    f.stickSize = stickSize
    local blockL = W.Font(stickCard, 15)
    blockL:SetText("Touches here don't turn the camera")
    addM(blockL, 18, 8)
    local block = track(W.Segmented(stickCard, inner, 42, ns.cameraBlockChoices,
        function() return ns.db.cameraBlock end,
        function(v) ns.SetCameraBlock(v) end))
    addM(block, 42, 8)
    f.cameraBlock = block
    addM(hint(stickCard, "A thumb sliding off the stick won't spin the camera. Game windows and buttons there still work.", block, 0), 30, 12)
    local moveIt = W.Button(stickCard, inner, 44, "Move it in Edit layout", function()
        f:Hide()
        ns.EnterEditMode()
    end)
    addM(moveIt, 44)

    local padCard = W.Card(pm, COL_W, 370, "Running and jumping")
    padCard:SetPoint("TOPRIGHT")
    local addC = stacker(padCard, -34)
    if ns.ControllerMovementAvailable() then
        addC(track(W.Toggle(padCard, inner, "Controller movement", "DroidDeck's stick runs, A jumps.",
            ns.ControllerMovementOn, function(v) ns.SetControllerMovement(v) end)), 56, 4)
    end
    if ns.CVarExists("autoInteract") then
        addC(track(W.Toggle(padCard, inner, "Tap-to-move", "Long-press the ground to walk there.",
            ns.TapToMoveOn, function(v) ns.SetTapToMove(v) end)), 56, 12)
    end
    local padTest = W.Button(padCard, inner, 44, "Test the stick", function()
        f:Hide()
        ns.ShowPadTest()
    end, "primary")
    addC(padTest, 44, 8)
    f.padTestButton = padTest
    addC(hint(padCard, "Shows whether WoW sees DroidDeck's stick and what to change if it doesn't.", padTest, 0), 30)

    -- Help tab --------------------------------------------------------------------------
    local ph = page("help")
    local fixCard = W.Card(ph, COL_W, 370, "Troubleshooting")
    fixCard:SetPoint("TOPLEFT")
    local addH = stacker(fixCard)
    local touchTest = W.Button(fixCard, inner, 44, "Test touch", function()
        f:Hide()
        ns.ShowTouchTest()
    end, "primary")
    addH(touchTest, 44, 4)
    f.touchTestButton = touchTest
    addH(hint(fixCard, "Taps not pressing buttons? This shows where the game feels your taps.", touchTest, 0), 30, 12)
    local padTest2 = W.Button(fixCard, inner, 44, "Test the stick", function()
        f:Hide()
        ns.ShowPadTest()
    end)
    addH(padTest2, 44, 4)
    addH(hint(fixCard, "Character not moving? Checks that WoW sees the stick.", padTest2, 0), 18, 14)
    addH(track(W.Toggle(fixCard, inner, "Touch input fixes", "Raw mouse off, cursor not locked, hardware cursor.",
        function() return not ns.db.touchFixOff end,
        function(v) if v then ns.ApplyTouchFixes() else ns.RevertTouchFixes() end end)), 56)

    local aboutCard = W.Card(ph, COL_W, 370, "Setup")
    aboutCard:SetPoint("TOPRIGHT")
    local addA = stacker(aboutCard)
    local setupBtn = W.Button(aboutCard, inner, 44, "Run the setup guide again", function()
        f:Hide()
        ns.ShowSetup()
    end)
    addA(setupBtn, 44, 16)
    local keys = W.Font(aboutCard, 13, C.muted[1], C.muted[2], C.muted[3])
    keys:SetWidth(inner)
    keys:SetJustifyH("LEFT")
    keys:SetText("Prefer typing? With DroidDeck's keyboard:\n\n"
        .. "|cffffffff/ft|r  settings\n|cffffffff/ft edit|r  edit layout\n|cffffffff/ft setup|r  setup guide\n"
        .. "|cffffffff/ft touchtest|r  test touch\n|cffffffff/ft padtest|r  test the stick\n|cffffffff/ft reset|r  reset layout")
    addA(keys, 150)

    -- Tabs + footer ---------------------------------------------------------------------
    f.tab = "layout"
    local tabs = W.Segmented(f, PANEL_W - 48, 44, TABS, function() return f.tab end, function(v) f:SelectTab(v) end)
    tabs:SetPoint("TOPLEFT", 24, -68)
    f.tabs = tabs

    local close = W.Button(f, 140, 48, "Done", function() f:Hide() end, "primary")
    close:SetPoint("BOTTOMRIGHT", -24, 22)
    local profile = W.Font(f, 12, C.muted[1], C.muted[2], C.muted[3])
    profile:SetPoint("BOTTOMLEFT", 26, 38)

    function f:SelectTab(key)
        self.tab = key
        for k, p in pairs(self.pages) do p:SetShown(k == key) end
        self.tabs.Refresh()
        if not ns.editing then ns.ShowStickGuide(key == "movement") end
    end

    function f:Refresh()
        local label = ns.profileLabels[ns.ActiveProfile()]
        detected:SetText("Using the " .. label:lower() .. " layout right now.")
        profile:SetText("Changes apply to the " .. label:lower() .. " layout.")
        for pnum, row in pairs(self.pageRows) do
            row:SetShown(pnum <= ns.db.numPages)
            row.cycle:SetLabel(ns.BarLabel(ns.db.pageBars[pnum]) .. "  >")
        end
        for _, w in ipairs(refreshers) do if w.Refresh then w.Refresh() end end
    end
    f:HookScript("OnShow", function(self)
        self:Refresh()
        self:SelectTab(self.tab)
    end)
    f:HookScript("OnHide", function()
        if not ns.editing then ns.ShowStickGuide(false) end
    end)
    return f
end

function ns.ShowSettings(tab)
    panel = panel or buildPanel()
    if tab then panel.tab = tab end
    W.FitToScreen(panel, 1.2)
    if panel:IsShown() and tab then panel:SelectTab(tab) end
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
        W.Toast("Layout reset")
    elseif msg == "padtest" or msg == "controller" or msg == "stick" then
        ns.ShowPadTest()
    elseif msg == "touchtest" or msg == "test" then
        ns.ShowTouchTest()
    elseif msg == "touchfix" or msg == "touchfix on" then
        local changed = ns.ApplyTouchFixes()
        ns.Print("Touch fixes on (%d setting%s changed). Restart the game for the cursor change to apply.", #changed, #changed == 1 and "" or "s")
    elseif msg == "touchfix off" then
        ns.Print("Touch fixes undone (%d setting%s restored).", ns.RevertTouchFixes(), "s")
    elseif msg == "help" then
        ns.Print("/ft - settings, /ft edit - move and assign buttons, /ft setup - setup guide, /ft reset - reset layout,"
            .. " /ft touchtest - check where taps land, /ft padtest - check the movement stick, /ft touchfix [off] - touch input settings")
    else
        ns.ShowSettings()
    end
end
