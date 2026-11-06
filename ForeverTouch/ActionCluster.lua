-- ActionCluster: the thumb wheel of secure action buttons (mobile-MMO style).
--
--   One big button, an inner arc of 4, an outer arc of 5 and two minis = 12,
--   i.e. one full action bar per page. Page 1 follows the main bar (including
--   stance/form/stealth bars); further pages show other action bars.
--   Spells come from the player's real action slots, so everything the client
--   already knows (cooldowns, ranges, macros, items) just works.

local _, ns = ...
local W = ns.W
local M = ns.media
local C = ns.color

local BIG, INNER, OUTER, MINI = 96, 66, 60, 50
local HEADER_SIZE = 400
local ORIGIN = 62 -- big button centre, inset from the header's corner

-- index -> { size, radius, angle in degrees (90 = straight up, 180 = left) }
local GEOMETRY = {
    { BIG, 0, 0 },
    { INNER, 150, 95 }, { INNER, 150, 121.7 }, { INNER, 150, 148.3 }, { INNER, 150, 175 },
    { OUTER, 232, 93 }, { OUTER, 232, 114 }, { OUTER, 232, 135 }, { OUTER, 232, 156 }, { OUTER, 232, 177 },
    { MINI, 310, 100 }, { MINI, 310, 170 },
}
local PILL = { 38, 86, 135 }

-- Action bar choices for pages 2 and 3 (slot ranges are fixed by the client).
ns.barChoices = {
    { value = "main", label = "Main bar" },
    { value = 61, label = "Bottom left bar" },
    { value = 49, label = "Bottom right bar" },
    { value = 25, label = "Right bar" },
    { value = 37, label = "Right bar 2" },
    { value = 13, label = "Action bar 2" },
}
function ns.BarLabel(v)
    for _, c in ipairs(ns.barChoices) do if c.value == v then return c.label end end
    return tostring(v)
end

-- Main bar paging: manual bar pages first, then stance/form bonus bars.
local PAGE_DRIVER = "[bar:2]2;[bar:3]3;[bar:4]4;[bar:5]5;[bar:6]6;"
    .. "[bonusbar:1]7;[bonusbar:2]8;[bonusbar:3]9;[bonusbar:4]10;1"

-- Restricted snippets (run inside Blizzard's secure environment) ------------
local HEADER_ONSTATE_BAR = [[
    self:SetAttribute("barpage", tonumber(newstate) or 1)
    control:ChildUpdate("refresh")
]]

local HEADER_ONSTATE_PAGE = [[
    local n = self:GetAttribute("numpages") or 1
    local p = tonumber(newstate) or 1
    if p < 1 or p > n then p = 1 end
    self:SetAttribute("ftpage", p)
    control:ChildUpdate("refresh")
]]

local BUTTON_REFRESH = [[
    local header = self:GetParent()
    local page = header:GetAttribute("ftpage") or 1
    local base = header:GetAttribute("base" .. page) or 0
    local index = self:GetAttribute("index")
    local slot
    if base == 0 then
        local barpage = header:GetAttribute("barpage") or 1
        slot = (barpage - 1) * 12 + index
    else
        slot = base + index - 1
    end
    self:SetAttribute("action", slot)
]]

local PILL_ONCLICK = [[
    local header = self:GetFrameRef("header")
    local n = header:GetAttribute("numpages") or 1
    local p = (header:GetAttribute("ftpage") or 1) + 1
    if p > n then p = 1 end
    header:SetAttribute("state-ftpage", p)
]]

ns.snippets = {
    HEADER_ONSTATE_BAR = HEADER_ONSTATE_BAR,
    HEADER_ONSTATE_PAGE = HEADER_ONSTATE_PAGE,
    BUTTON_REFRESH = BUTTON_REFRESH,
    PILL_ONCLICK = PILL_ONCLICK,
}

-- Visual state --------------------------------------------------------------------
local cluster = {}
ns.cluster = cluster
cluster.buttons = {}
local overlayed = {} -- spellID -> true while the client highlights it (procs)

local function setCooldown(cd, start, duration, enable, modRate)
    if CooldownFrame_Set then
        CooldownFrame_Set(cd, start, duration, enable, false, modRate)
    elseif enable and enable ~= 0 and duration and duration > 0 then
        cd:SetCooldown(start, duration)
    else
        cd:SetCooldown(0, 0)
    end
end

local function actionSpellID(slot)
    local kind, id = GetActionInfo(slot)
    if kind == "spell" then return id end
    if kind == "macro" and GetMacroSpell then return GetMacroSpell(id) end
end

local function updateCooldown(b)
    local slot = b.slot
    if slot and HasAction(slot) then
        local start, duration, enable, modRate = GetActionCooldown(slot)
        setCooldown(b.cooldown, start, duration, enable, modRate)
    else
        setCooldown(b.cooldown, 0, 0, 0)
    end
end

local function updateUsable(b)
    local slot = b.slot
    if not slot or not HasAction(slot) then return end
    local usable, noMana = IsUsableAction(slot)
    local inRange = IsActionInRange(slot)
    if inRange == false or inRange == 0 then
        b.icon:SetVertexColor(1, 0.32, 0.32)
    elseif usable then
        b.icon:SetVertexColor(1, 1, 1)
    elseif noMana then
        b.icon:SetVertexColor(0.45, 0.55, 1)
    else
        b.icon:SetVertexColor(0.4, 0.4, 0.4)
    end
end

local function updateState(b)
    local slot = b.slot
    local on = false
    local proc = false
    if slot and HasAction(slot) then
        on = IsCurrentAction(slot) or (IsAutoRepeatAction and IsAutoRepeatAction(slot)) or false
        local spellID = actionSpellID(slot)
        proc = spellID and overlayed[spellID] or false
    end
    if proc then
        b.glow:SetVertexColor(C.accentSoft[1], C.accentSoft[2], C.accentSoft[3], 1)
        b.glow:Show()
    elseif on then
        b.glow:SetVertexColor(C.gold[1], C.gold[2], C.gold[3], 0.95)
        b.glow:Show()
    else
        b.glow:Hide()
    end
end

local function updateCount(b)
    local slot = b.slot
    if slot and HasAction(slot) and (IsConsumableAction(slot) or (IsStackableAction and IsStackableAction(slot))) then
        local n = GetActionCount(slot) or 0
        b.count:SetText(n > 999 and "*" or tostring(n))
    else
        b.count:SetText("")
    end
end

local function updateButton(b)
    b.slot = b:GetAttribute("action")
    local slot = b.slot
    if slot and HasAction(slot) then
        b.icon:SetTexture(GetActionTexture(slot))
        b.icon:Show()
        b.glyph:SetText("")
        b.plate:SetVertexColor(0.08, 0.09, 0.12, 0.92)
        b.rim:SetVertexColor(1, 1, 1, 0.22)
        b:SetAlpha(1)
    else
        b.icon:Hide()
        b.glyph:SetText("+")
        b.glyph:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
        b.plate:SetVertexColor(0.08, 0.09, 0.12, 0.55)
        b.rim:SetVertexColor(1, 1, 1, 0.12)
        local show = ns.editing or (ns.db and ns.db.showEmptyButtons)
        b:SetAlpha(show and 0.75 or 0)
    end
    if ns.editing then
        b.rim:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 0.9)
    end
    updateCooldown(b)
    updateUsable(b)
    updateState(b)
    updateCount(b)
end
cluster.UpdateButton = updateButton

local function forEach(fn)
    for _, b in ipairs(cluster.buttons) do fn(b) end
end

function cluster.UpdateAll() forEach(updateButton) end

function cluster.SetDragEnabled(on)
    ns.RunOOC("clusterDrag", function()
        forEach(function(b)
            if on then b:RegisterForDrag("LeftButton") else b:RegisterForDrag() end
        end)
    end)
end

-- Construction ---------------------------------------------------------------------
local function buttonOffset(radius, angle)
    local rad = math.rad(angle)
    local dx, dy = radius * math.cos(rad), radius * math.sin(rad)
    -- Right hand: wheel opens up and to the left of the big button.
    if ns.db and ns.db.handed == "left" then
        return "BOTTOMLEFT", ORIGIN - dx, ORIGIN + dy
    end
    return "BOTTOMRIGHT", -ORIGIN + dx, ORIGIN + dy
end

function ns.RebuildClusterGeometry()
    if not cluster.header then return end
    ns.RunOOC("clusterGeometry", function()
        for i, b in ipairs(cluster.buttons) do
            local g = GEOMETRY[i]
            local point, x, y = buttonOffset(g[2], g[3])
            b:ClearAllPoints()
            b:SetPoint("CENTER", cluster.header, point, x, y)
        end
        local point, x, y = buttonOffset(PILL[2], PILL[3])
        cluster.pill:ClearAllPoints()
        cluster.pill:SetPoint("CENTER", cluster.header, point, x, y)
    end)
end

local function updatePill()
    local header = cluster.header
    local page = header:GetAttribute("ftpage") or 1
    local n = header:GetAttribute("numpages") or 1
    cluster.pill.glyph:SetText(tostring(page))
    cluster.pill:SetAlpha(n > 1 and 1 or 0)
    for i, dot in ipairs(cluster.pill.dots) do
        dot:SetShown(i <= n and n > 1)
        local active = (i == page)
        dot:SetVertexColor(active and C.accent[1] or 1, active and C.accent[2] or 1, active and C.accent[3] or 1, active and 1 or 0.35)
    end
end

-- Push page settings into the secure header (out of combat only).
function ns.ApplyPages()
    if not cluster.header then return end
    ns.RunOOC("pages", function()
        local header = cluster.header
        local n = math.max(1, math.min(3, ns.db.numPages or 1))
        header:SetAttribute("numpages", n)
        for p = 1, 3 do
            local v = ns.db.pageBars[p]
            if p == 1 then v = "main" end
            header:SetAttribute("base" .. p, (v == "main" or v == nil) and 0 or v)
        end
        local current = header:GetAttribute("ftpage") or 1
        if current > n then current = 1 end
        header:SetAttribute("state-ftpage", current)
        updatePill()
    end)
end

local function createButton(i, header)
    local g = GEOMETRY[i]
    local b = CreateFrame("Button", "ForeverTouchButton" .. i, header, "SecureActionButtonTemplate")
    b:SetAttribute("type", "action")
    b:SetAttribute("index", i)
    b:SetAttribute("_childupdate-refresh", BUTTON_REFRESH)
    if ns.dualClick then b:RegisterForClicks("AnyUp", "AnyDown") else b:RegisterForClicks("AnyUp") end
    -- Dragging *from* a button is only enabled in edit mode: a wobbling finger
    -- would otherwise start a drag and swallow the tap.
    W.DecorateRound(b, g[1])
    b.index = i

    local cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
    cd:SetAllPoints(b.icon)
    if cd.SetSwipeTexture then cd:SetSwipeTexture(M .. "circle") end
    if cd.SetSwipeColor then cd:SetSwipeColor(0, 0, 0, 0.72) end
    if cd.SetDrawEdge then cd:SetDrawEdge(false) end
    if cd.SetUseCircularEdge then cd:SetUseCircularEdge(true) end
    if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(false) end
    b.cooldown = cd

    local over = CreateFrame("Frame", nil, b)
    over:SetAllPoints()
    over:SetFrameLevel(cd:GetFrameLevel() + 2)
    b.count = W.Font(over, math.max(12, math.floor(g[1] * 0.2)), 1, 1, 1, "OUTLINE")
    b.count:SetPoint("BOTTOM", 0, g[1] * 0.1)
    b.slotLabel = W.Font(over, 11, C.gold[1], C.gold[2], C.gold[3], "OUTLINE")
    b.slotLabel:SetPoint("TOP", 0, -2)
    b.slotLabel:Hide()

    b:HookScript("OnAttributeChanged", function(self, name)
        if name == "action" then updateButton(self) end
    end)

    -- Taps on empty buttons (or any button in edit mode) open the spell picker.
    b:HookScript("PostClick", function(self, _, down)
        if down then return end
        if InCombatLockdown() then return end
        if ns.editing or not (self.slot and HasAction(self.slot)) then
            if ns.OpenPicker then ns.OpenPicker(self.slot, self) end
        end
        -- casting may have changed the state; refresh promptly
        updateState(self)
    end)

    -- Dragging from the spellbook/bags straight onto a touch button also works.
    -- Dragging one touch button onto another swaps them (edit mode).
    b:SetScript("OnReceiveDrag", function(self)
        if InCombatLockdown() or not self.slot then return end
        local origin = cluster.dragOrigin
        cluster.dragOrigin = nil
        PlaceAction(self.slot)
        if origin and origin ~= self.slot and GetCursorInfo() then
            PlaceAction(origin) -- the displaced action goes where the drag began
        end
        ClearCursor()
    end)
    b:SetScript("OnDragStart", function(self)
        if InCombatLockdown() or not self.slot or not ns.editing then return end
        cluster.dragOrigin = self.slot
        PickupAction(self.slot)
    end)
    b:SetScript("OnDragStop", function(self)
        -- Released over nothing: put the action back instead of leaving it
        -- stuck to an invisible cursor.
        local origin = self.slot
        C_Timer.After(0, function()
            if cluster.dragOrigin == origin and GetCursorInfo() and not InCombatLockdown() then
                PlaceAction(origin)
                ClearCursor()
            end
            cluster.dragOrigin = nil
        end)
    end)
    return b
end

function cluster.Create()
    local header = CreateFrame("Frame", "ForeverTouchCluster", UIParent, "SecureHandlerStateTemplate")
    header:SetSize(HEADER_SIZE, HEADER_SIZE)
    header:SetFrameStrata("MEDIUM")
    header:SetAttribute("ftpage", 1)
    header:SetAttribute("barpage", 1)
    header:SetAttribute("numpages", 1)
    header:SetAttribute("_onstate-bar", HEADER_ONSTATE_BAR)
    header:SetAttribute("_onstate-ftpage", HEADER_ONSTATE_PAGE)
    cluster.header = header

    for i = 1, #GEOMETRY do
        cluster.buttons[i] = createButton(i, header)
    end

    -- Page pill: tap to flip between pages, works in combat.
    local pill = CreateFrame("Button", "ForeverTouchPagePill", header, "SecureHandlerClickTemplate")
    W.DecorateRound(pill, PILL[1], { glyphSize = 16 })
    pill.plate:SetVertexColor(C.accent[1] * 0.55, C.accent[2] * 0.55, C.accent[3] * 0.55, 0.95)
    pill:RegisterForClicks("AnyUp")
    pill:SetFrameRef("header", header)
    pill:SetAttribute("_onclick", PILL_ONCLICK)
    pill.dots = {}
    for i = 1, 3 do
        local dot = W.Tex(pill, "OVERLAY", M .. "circle", 1, 1, 1, 0.4, 3)
        dot:SetSize(6, 6)
        dot:SetPoint("TOP", pill, "BOTTOM", (i - 2) * 9, -2)
        pill.dots[i] = dot
    end
    cluster.pill = pill

    header:HookScript("OnAttributeChanged", function(_, name)
        if name == "ftpage" or name == "numpages" then updatePill() end
    end)

    ns.RegisterGroup("cluster", header, "Spell wheel")
    ns.RebuildClusterGeometry()
    RegisterStateDriver(header, "bar", PAGE_DRIVER)
    ns.ApplyPages()
    cluster.UpdateAll()
end

-- Events ------------------------------------------------------------------------------
ns.OnInit(function()
    cluster.Create()

    ns.On("ACTIONBAR_SLOT_CHANGED", function(slot)
        forEach(function(b)
            if slot == 0 or b.slot == slot then updateButton(b) end
        end)
    end)
    local function cooldowns() forEach(updateCooldown) end
    ns.On("ACTIONBAR_UPDATE_COOLDOWN", cooldowns)
    ns.On("SPELL_UPDATE_COOLDOWN", cooldowns)

    local function usable() forEach(updateUsable) end
    ns.On("ACTIONBAR_UPDATE_USABLE", usable)
    ns.On("SPELL_UPDATE_USABLE", usable)
    ns.On("PLAYER_TARGET_CHANGED", usable)
    ns.OnUnit("UNIT_POWER_FREQUENT", "player", usable)

    local function states() forEach(updateState) end
    for _, e in ipairs({ "ACTIONBAR_UPDATE_STATE", "PLAYER_ENTER_COMBAT", "PLAYER_LEAVE_COMBAT",
        "START_AUTOREPEAT_SPELL", "STOP_AUTOREPEAT_SPELL", "TRADE_SKILL_SHOW", "TRADE_SKILL_CLOSE" }) do
        ns.On(e, states)
    end
    ns.On("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", function(id) overlayed[id] = true; states() end)
    ns.On("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", function(id) overlayed[id] = nil; states() end)

    local function counts() forEach(updateCount) end
    ns.On("BAG_UPDATE_DELAYED", counts)
    ns.On("BAG_UPDATE", counts)

    ns.On("PLAYER_ENTERING_WORLD", cluster.UpdateAll)
    ns.On("UPDATE_SHAPESHIFT_FORM", cluster.UpdateAll)

    -- Range tinting needs polling; 5 times a second is plenty and cheap.
    C_Timer.NewTicker(0.2, function()
        if UnitExists("target") then usable() end
    end)
end)
