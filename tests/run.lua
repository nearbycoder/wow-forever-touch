-- Run with:  lua5.1 tests/run.lua   (from the repository root)
package.path = "./tests/?.lua;" .. package.path
local M = require("mock_wow")

local failures, passes = 0, 0
local function check(cond, label)
    if cond then
        passes = passes + 1
    else
        failures = failures + 1
        print("FAIL: " .. label)
    end
end
local function step(label, fn)
    local ok, err = pcall(fn)
    if not ok then
        failures = failures + 1
        print("ERROR in '" .. label .. "': " .. tostring(err))
    end
end
local function logHas(pattern)
    for _, l in ipairs(M.log) do if l:find(pattern, 1, true) then return true end end
    return false
end
local function clearLog() M.log = {} end

local legacy = arg and arg[1] == "legacy"
M.install({ legacyClicks = legacy })
local ns = {}
M.LoadToc("ForeverTouch", "ForeverTouch", ns)

-- Player has a few actions on the main bar and the bottom-left bar.
M.actions[1] = { texture = "attack", kind = "spell", id = 6603 }
M.actions[2] = { texture = "hs", kind = "spell", id = 78 }
M.actions[61] = { texture = "rend", kind = "spell", id = 772 }
M.actions[73] = { texture = "battle-stance-1", kind = "spell", id = 1 }

step("login", function()
    M.FireEvent("ADDON_LOADED", "ForeverTouch")
    M.FireEvent("PLAYER_LOGIN")
    M.FireEvent("PLAYER_ENTERING_WORLD")
end)

local B = function(i) return _G["ForeverTouchButton" .. i] end
local header = _G.ForeverTouchCluster

step("initial state", function()
    check(header ~= nil, "cluster header exists")
    check(B(1):GetAttribute("action") == 1, "button 1 -> slot 1 (got " .. tostring(B(1):GetAttribute("action")) .. ")")
    check(B(12):GetAttribute("action") == 12, "button 12 -> slot 12")
    check(B(1).icon._texture == "attack", "button 1 shows its icon")
    check(B(3).glyph:GetText() == "+", "empty button shows +")
    check(ns.ActiveProfile() == "cover", "Fold cover screen detected as 'cover'")
    check(header:GetAttribute("numpages") == 2, "two pages by default")
    check(_G.ForeverTouchPagePill.glyph:GetText() == "1", "page pill shows 1")
    check(M.optionsCategory ~= nil, "registered in Interface Options")
end)

step("tap casts", function()
    clearLog()
    B(1):Click("LeftButton", true)
    B(1):Click("LeftButton", false)
    local casts = 0
    for _, l in ipairs(M.log) do if l == "UseAction(1)" then casts = casts + 1 end end
    check(casts == 1, "one tap casts exactly once (got " .. casts .. ")")
end)

step("page flip (secure)", function()
    M.combat = true -- must work in combat
    _G.ForeverTouchPagePill:Click("LeftButton", false)
    check(B(1):GetAttribute("action") == 61, "page 2 -> bottom-left bar slot 61 (got " .. tostring(B(1):GetAttribute("action")) .. ")")
    check(B(1).icon._texture == "rend", "page 2 icon updated")
    check(_G.ForeverTouchPagePill.glyph:GetText() == "2", "pill shows 2")
    _G.ForeverTouchPagePill:Click("LeftButton", false)
    check(B(1):GetAttribute("action") == 1, "wraps back to page 1")
    M.combat = false
end)

step("stance paging", function()
    M.combat = true
    M.conditions["bonusbar:1"] = true
    M.UpdateStateDrivers()
    check(B(1):GetAttribute("action") == 73, "battle stance -> slot 73 (got " .. tostring(B(1):GetAttribute("action")) .. ")")
    check(B(1).icon._texture == "battle-stance-1", "stance icon shown")
    M.conditions["bonusbar:1"] = nil
    M.UpdateStateDrivers()
    check(B(1):GetAttribute("action") == 1, "back to slot 1")
    M.combat = false
end)

step("tap empty button opens picker and assigns", function()
    clearLog()
    B(3):Click("LeftButton", true)
    B(3):Click("LeftButton", false)
    local picker = _G.ForeverTouchPicker
    check(picker and picker:IsShown(), "picker opened")
    check(picker.slot == 3, "picker targets slot 3")
    -- Default tab is the class tab: Heroic Strike (best rank only), Rend.
    local cells = {}
    for _, c in ipairs(picker.cells) do if c:IsShown() then cells[#cells + 1] = c.name:GetText() end end
    check(#cells == 2, "class tab lists 2 spells, future/duplicate ranks hidden (got " .. table.concat(cells, ",") .. ")")
    picker.cells[1]:Click()
    check(M.actions[3] and M.actions[3].id == 284, "Heroic Strike rank 2 placed on slot 3")
    check(not picker:IsShown(), "picker closes after choosing")
    check(M.cursor == nil, "cursor is empty afterwards")
    check(B(3).icon._texture ~= nil and B(3).glyph:GetText() == "", "button 3 now shows an icon")
end)

step("picker items + macros tabs", function()
    ns.OpenPicker(5, B(5))
    local picker = _G.ForeverTouchPicker
    local items, macros
    for i, def in ipairs(picker.tabDefs) do
        if def.label == "Items" then items = i end
        if def.label == "Macros" then macros = i end
    end
    picker:SelectTab(items)
    check(#picker.list == 1 and picker.list[1].name == "Item6948", "items tab lists usable items only")
    picker:SelectTab(macros)
    check(#picker.list == 2, "macros tab lists account + character macros")
    picker.clear:Click()
    check(not picker:IsShown(), "clear closes picker")
end)

step("picker refuses in combat", function()
    M.combat = true
    clearLog()
    ns.OpenPicker(4, B(4))
    check(logHas("can't be changed during combat"), "combat message shown")
    M.combat = false
end)

step("menu works in combat", function()
    M.combat = true
    clearLog()
    _G.ForeverTouchMenuButton:Click("LeftButton", false)
    check(_G.ForeverTouchMenu:IsShown(), "menu opens in combat")
    _G.ForeverTouchMenuTile1:Click("LeftButton", true)
    _G.ForeverTouchMenuTile1:Click("LeftButton", false)
    check(logHas("CharacterMicroButton clicked"), "Character tile clicks the micro button")
    check(not _G.ForeverTouchMenu:IsShown(), "menu closes after a tile, in combat")
    _G.ForeverTouchMenuButton:Click("LeftButton", false)
    clearLog()
    _G.ForeverTouchMenuTile2:Click("LeftButton", true)
    _G.ForeverTouchMenuTile2:Click("LeftButton", false)
    local n = 0
    for _, l in ipairs(M.log) do if l == "ToggleAllBags" then n = n + 1 end end
    check(n == 1, "Bags tile toggles bags exactly once (got " .. n .. ")")
    check(not _G.ForeverTouchMenu:IsShown(), "menu closed after bags")
    _G.ForeverTouchMenuButton:Click("LeftButton", false)
    _G.ForeverTouchMenuCatcher:Click("LeftButton", false)
    check(not _G.ForeverTouchMenu:IsShown(), "tapping outside closes the menu")
    M.combat = false
end)

step("utility buttons", function()
    clearLog()
    _G.ForeverTouchUtility1:Click("LeftButton", true)
    _G.ForeverTouchUtility1:Click("LeftButton", false)
    check(logHas("macro /targetenemy"), "Target button runs /targetenemy")
end)

step("edit mode", function()
    ns.EnterEditMode()
    check(ns.editing, "edit mode on")
    check(_G.ForeverTouchEditBar:IsShown(), "toolbar shown")
    check(B(1):GetAttribute("type") == "", "buttons don't cast in edit mode")
    clearLog()
    B(1):Click("LeftButton", false)
    check(not logHas("UseAction"), "tap in edit mode does not cast")
    check(_G.ForeverTouchPicker:IsShown(), "tap in edit mode opens picker")
    _G.ForeverTouchPicker:Hide()

    -- drag the cluster handle
    local cluster = ns.groups.cluster
    local before = ns.Layout("cluster").fx
    local handle
    for _, c in ipairs(_G.UIParent._children) do
        if c == ns.editHandles.cluster then handle = c end
    end
    check(handle ~= nil, "cluster has a drag handle")
    local mp = ns.editHandles.menu._points[1]
    check(mp and mp[1] == "RIGHT" and mp[3] == "LEFT", "menu handle sits beside the menu button, not on it")
    M.fire(handle, "OnMouseDown", "LeftButton")
    M.fire(handle, "OnMouseUp", "LeftButton")
    check(ns.Layout("cluster").fx ~= before, "dragging updates the saved position")

    -- size stepper
    local bar = _G.ForeverTouchEditBar
    local s0 = ns.Layout("cluster").scale
    bar.size.Refresh()
    -- find the "+" button of the size stepper
    for _, c in ipairs(bar.size._children) do
        if c.text and c.text._text == "+" then c:Click() end
    end
    check(math.abs(ns.Layout("cluster").scale - (s0 + 0.05)) < 1e-6, "size + grows the group")

    -- swap via drag between buttons
    M.actions[1] = { texture = "attack", kind = "spell", id = 6603 }
    M.actions[2] = { texture = "hs", kind = "spell", id = 78 }
    M.fire(B(1), "OnDragStart", "LeftButton")
    M.fire(B(2), "OnReceiveDrag")
    check(M.actions[2] and M.actions[2].id == 6603 and M.actions[1] and M.actions[1].id == 78, "dragging button 1 onto 2 swaps them")

    -- entering combat closes edit mode cleanly
    M.FireEvent("PLAYER_REGEN_DISABLED")
    check(not ns.editing, "combat ends edit mode")
    check(B(1):GetAttribute("type") == "action", "buttons cast again after edit mode")
end)

step("left handed mirror", function()
    local fx = ns.Layout("cluster").fx
    ns.SetHanded("left")
    check(math.abs(ns.Layout("cluster").fx - (1 - fx)) < 1e-6, "left hand mirrors the layout")
    local p = B(2)._points[1]
    check(p[3] == "BOTTOMLEFT" and p[4] > 0, "wheel opens to the right for left hand")
    ns.SetHanded("right")
end)

step("fold/unfold switches layout", function()
    clearLog()
    M.screen = { 2184, 1968 } -- inner screen
    M.FireEvent("DISPLAY_SIZE_CHANGED")
    M.RunTimers(1)
    check(ns.ActiveProfile() == "main", "unfolded -> main profile")
    check(logHas("Unfolded"), "player told about the switch")
    check(ns.groups.cluster:GetScale() == ns.db.layouts.main.cluster.scale, "main profile scale applied")
end)

step("combat layout change is deferred", function()
    M.combat = true
    M.screen = { 2520, 1080 }
    M.FireEvent("DISPLAY_SIZE_CHANGED")
    M.RunTimers(1)
    check(ns.groups.cluster:GetScale() == ns.db.layouts.main.cluster.scale, "no protected change during combat")
    M.combat = false
    M.FireEvent("PLAYER_REGEN_ENABLED")
    check(ns.groups.cluster:GetScale() == ns.db.layouts.cover.cluster.scale, "applied after combat")
end)

step("settings + setup", function()
    ns.ShowSettings()
    check(_G.ForeverTouchSettings:IsShown(), "settings open")
    _G.ForeverTouchSettings:Hide()
    ns.ShowSetup()
    local w = _G.ForeverTouchSetup
    check(w:IsShown(), "setup opens")
    w:ShowPage(2)
    -- press "Turn on controller movement"
    for _, c in ipairs(w.pages[2]._children) do
        if c.text and c.text._text == "Turn on controller movement" then c:Click() end
    end
    check(M.cvars.GamePadEnable == "1", "controller support enabled")
    check(M.bindings.PAD1 == "JUMP", "A button jumps")
    w:ShowPage(3)
    w.nextBtn:Click()
    check(not w:IsShown() and ns.db.setupDone, "finish closes setup")
end)

step("hide default bars", function()
    ns.db.hideBlizzardBars = true
    ns.HideBlizzardBars()
    check(not _G.MainMenuBar:GetParent():IsShown(), "main bar hidden")
    check(_G.PetActionBarFrame:GetParent() == _G.UIParent, "pet bar kept")
end)

step("touch fixes applied at login", function()
    check(M.cvars.rawMouseEnable == "0", "raw mouse input turned off")
    check(M.cvars.ClipCursor == "0", "cursor no longer clipped")
    check(M.cvars.gxCursor == "1", "hardware cursor on")
    check(ns.db.touchFixBackup.rawMouseEnable == "1", "original value kept for undo")
    _G.SlashCmdList.FOREVERTOUCH("touchfix off")
    check(M.cvars.rawMouseEnable == "1" and M.cvars.ClipCursor == "1", "/ft touchfix off restores settings")
    _G.SlashCmdList.FOREVERTOUCH("touchfix")
    check(M.cvars.rawMouseEnable == "0", "/ft touchfix re-applies")
end)

step("touch test: taps on target", function()
    _G.SlashCmdList.FOREVERTOUCH("touchtest")
    local f = _G.ForeverTouchTouchTest
    check(f:IsShown(), "touch test opens")
    for i = 1, 3 do
        local x, y = f.targets[i]:GetCenter()
        M.cursorPos = { x + 5, y - 5 }
        f:Click("LeftButton", true)
    end
    check(ns.db.lastTouchTest == "ok", "accurate taps -> ok verdict (got " .. tostring(ns.db.lastTouchTest) .. ")")
    f:Click("LeftButton", true)
    check(not f:IsShown(), "tap after result closes")
end)

step("touch test: taps stuck at cursor", function()
    ns.ShowTouchTest()
    local f = _G.ForeverTouchTouchTest
    M.cursorPos = { 896, 384 } -- cursor never moves to the finger
    for _ = 1, 3 do f:Click("LeftButton", true) end
    check(ns.db.lastTouchTest == "cursor", "stale cursor taps -> cursor verdict")
    f:Hide()
end)

step("controller test", function()
    M.cvars.GamePadEnable = "1"
    M.pad.devices = {}
    _G.SlashCmdList.FOREVERTOUCH("padtest")
    local f = _G.ForeverTouchPadTest
    check(f:IsShown(), "pad test opens")
    check(ns.db.lastPadTest == "none", "no controller -> 'none' verdict")
    check(M.padCursor == false, "stick handed back to movement")

    M.pad.devices = { "DroidDeck Virtual Pad" }
    M.pad.stick = { x = 0, y = 0 }
    f:Begin()
    for _ = 1, 30 do M.fire(f, "OnUpdate", 0.5) end
    check(ns.db.lastPadTest == "still", "controller but no stick motion -> 'still'")

    f:Begin()
    M.pad.stick = { x = 0.1, y = 0.9 }
    for _ = 1, 10 do M.fire(f, "OnUpdate", 0.1) end
    check(ns.db.lastPadTest == "ok", "stick moving -> 'ok' (got " .. tostring(ns.db.lastPadTest) .. ")")

    M.cvars.GamePadEnable = "0"
    f:Begin()
    check(ns.db.lastPadTest == "off" and f.enable:IsShown(), "support off -> offers to turn it on")
    f.enable:Click()
    check(M.cvars.GamePadEnable == "1", "'Turn it on' enables controller support")
    f:Hide()
end)

step("slash", function()
    _G.SlashCmdList.FOREVERTOUCH("edit")
    check(ns.editing, "/ft edit")
    ns.ExitEditMode()
    _G.SlashCmdList.FOREVERTOUCH("help")
end)

step("timers", function()
    M.RunTimers(3) -- range ticker, menu fades etc.
end)

-- Any protected call from insecure code in combat would be listed here.
check(#M.blocked == 0, "no ADDON_ACTION_BLOCKED (" .. table.concat(M.blocked, "; ") .. ")")

-- Undefined globals read (expected: optional APIs the addon probes for).
local names = {}
for k in pairs(M.undefined) do names[#names + 1] = k end
table.sort(names)
print("optional globals probed: " .. table.concat(names, ", "))

print(string.format("%d passed, %d failed%s", passes, failures, legacy and " (legacy click mode)" or ""))
os.exit(failures == 0 and 0 or 1)
