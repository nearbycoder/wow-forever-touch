-- Minimal World of Warcraft client mock for exercising ForeverTouch outside the
-- game. It models frames, scripts, attributes, the secure snippet environment
-- (state drivers, ChildUpdate, frame refs, wrapped clicks) and - importantly -
-- combat lockdown: insecure code touching protected frames in combat raises
-- ADDON_ACTION_BLOCKED, exactly the class of bug that breaks addons in game.

local M = {}
M.log = {}
M.undefined = {}
M.blocked = {}
M.timers = {}
M.combat = false
M.secureDepth = 0
M.cvars = {
    GamePadEnable = "0", autoInteract = "0", interactOnLeftClick = "0", autoLootDefault = "0",
    ActionButtonUseKeyDown = "1", countdownForCooldowns = "0",
}
M.bindings = {}
M.actions = {}    -- slot -> { texture, kind, id }
M.cursor = nil
M.conditions = {} -- macro conditions that are true, e.g. { ["bonusbar:1"] = true }
M.screen = { 2520, 1080 } -- Fold cover screen in landscape

local function log(fmt, ...) table.insert(M.log, string.format(fmt, ...)) end
M.logf = log

-- Frames ------------------------------------------------------------------------
local Object = {}
Object.__index = function(t, k)
    local v = rawget(Object, k)
    if v ~= nil then return v end
    local proto = rawget(t, "_proto")
    if proto and proto[k] ~= nil then return proto[k] end
    -- Plain fields read nil like in game; unknown *methods* (Capitalised) are bugs.
    if type(k) ~= "string" or not k:match("^%u") then return nil end
    error("mock: unknown method or field '" .. tostring(k) .. "' on " .. (rawget(t, "_type") or "?"), 2)
end

local allFrames = {}
local nameCounter = 0

local function isProtected(f)
    if f._secure then return true end
    for _, c in ipairs(f._children or {}) do
        if c._isFrame and isProtected(c) then return true end
    end
    return false
end
M.isProtected = isProtected

local function guard(f, what)
    if M.combat and M.secureDepth == 0 and f._isFrame and isProtected(f) then
        local msg = "ADDON_ACTION_BLOCKED: " .. what .. " on " .. (f._name or "<anon>")
        table.insert(M.blocked, msg)
        error(msg, 3)
    end
end

local function newRegion(kind, parent, proto)
    local r = setmetatable({ _type = kind, _parent = parent, _shown = true, _alpha = 1, _points = {}, _proto = proto }, Object)
    return r
end

local noop = function() end
local function noops(t, names)
    for _, n in ipairs(names) do t[n] = noop end
    return t
end

local TextureProto = noops({}, { "SetTexture", "SetColorTexture", "SetVertexColor", "SetTexCoord", "SetBlendMode",
    "SetSize", "SetWidth", "SetHeight", "SetAllPoints", "ClearAllPoints", "AddMaskTexture", "SetDrawLayer" })
function TextureProto:SetPoint(...) table.insert(self._points, { ... }) end
function TextureProto:Show() self._shown = true end
function TextureProto:Hide() self._shown = false end
function TextureProto:SetShown(v) self._shown = not not v end
function TextureProto:IsShown() return self._shown end
function TextureProto:SetAlpha(a) self._alpha = a end
function TextureProto:GetAlpha() return self._alpha end
function TextureProto:CreateAnimationGroup() return M.NewAnimGroup(self) end
local origSetTexture = TextureProto.SetTexture
function TextureProto:SetTexture(t, ...)
    self._texture = t
    return origSetTexture(self, t, ...)
end
function TextureProto:SetVertexColor(r, g, b, a) self._color = { r, g, b, a } end

local FontProto = noops({}, { "SetFont", "SetTextColor", "SetShadowColor", "SetShadowOffset", "SetWidth", "SetHeight",
    "SetJustifyH", "SetJustifyV", "SetAllPoints", "ClearAllPoints" })
function FontProto:SetPoint(...) table.insert(self._points, { ... }) end
function FontProto:SetText(t) self._text = t end
function FontProto:GetText() return self._text end
function FontProto:Show() self._shown = true end
function FontProto:Hide() self._shown = false end
function FontProto:SetShown(v) self._shown = not not v end
function FontProto:IsShown() return self._shown end

local AnimProto = noops({}, { "SetScaleFrom", "SetScaleTo", "SetFromAlpha", "SetToAlpha", "SetDuration", "SetSmoothing" })
local AnimGroupProto = {}
function AnimGroupProto:CreateAnimation() return newRegion("Animation", self, AnimProto) end
function AnimGroupProto:SetScript(k, fn) self._scripts = self._scripts or {} self._scripts[k] = fn end
function AnimGroupProto:Play() self._playing = true end
function AnimGroupProto:Stop() self._playing = false end
function AnimGroupProto:SetLooping() end
function M.NewAnimGroup(owner) return newRegion("AnimationGroup", owner, AnimGroupProto) end

local Frame = {}
M.FrameProto = Frame

local function fire(f, script, ...)
    local s = f._scripts[script]
    if s then s(f, ...) end
    for _, h in ipairs(f._hooks[script] or {}) do h(f, ...) end
end
M.fire = fire

function Frame:GetName() return self._name end
function Frame:GetParent() return self._parent end
function Frame:SetParent(p)
    guard(self, "SetParent")
    if self._parent and self._parent._children then
        for i, c in ipairs(self._parent._children) do
            if c == self then table.remove(self._parent._children, i) break end
        end
    end
    self._parent = p
    if p then p._children = p._children or {} table.insert(p._children, self) end
end
function Frame:SetSize(w, h) guard(self, "SetSize") self._w, self._h = w, h end
function Frame:SetWidth(w) guard(self, "SetWidth") self._w = w end
function Frame:SetHeight(h) guard(self, "SetHeight") self._h = h end
function Frame:GetWidth() return self._w or 0 end
function Frame:GetHeight() return self._h or 0 end
function Frame:SetPoint(...) guard(self, "SetPoint") self._points = { { ... } } end
function Frame:ClearAllPoints() guard(self, "ClearAllPoints") self._points = {} end
function Frame:SetAllPoints(rel) guard(self, "SetAllPoints") self._points = { { "ALL", rel } } end
function Frame:GetCenter()
    local p = self._points[1]
    if p and p[1] == "CENTER" and p[2] == M.UIParent and p[3] == "BOTTOMLEFT" then
        return p[4], p[5]
    end
    return 100, 100
end
function Frame:Show()
    guard(self, "Show")
    if not self._shown then self._shown = true fire(self, "OnShow") end
end
function Frame:Hide()
    guard(self, "Hide")
    if self._shown then self._shown = false fire(self, "OnHide") end
end
function Frame:SetShown(v) if v then self:Show() else self:Hide() end end
function Frame:IsShown() return self._shown end
function Frame:IsVisible()
    local f = self
    while f do
        if not f._shown then return false end
        f = f._parent
    end
    return true
end
function Frame:SetAlpha(a) self._alpha = a end
function Frame:GetAlpha() return self._alpha end
function Frame:SetScale(s) guard(self, "SetScale") self._scale = s end
function Frame:GetScale() return self._scale or 1 end
function Frame:SetFrameStrata(s) self._strata = s end
function Frame:SetFrameLevel(l) self._level = l end
function Frame:GetFrameLevel() return self._level or 1 end
function Frame:EnableMouse(v) guard(self, "EnableMouse") self._mouse = v end
function Frame:SetMovable(v) self._movable = v end
function Frame:SetClampedToScreen() end
function Frame:SetUserPlaced() end
function Frame:StartMoving()
    guard(self, "StartMoving")
    assert(self._movable, "StartMoving on non-movable frame")
    self._moving = true
end
function Frame:StopMovingOrSizing()
    if self._moving then
        self._moving = false
        -- pretend the user dragged it to (400, 300)
        self._points = { { "CENTER", M.UIParent, "BOTTOMLEFT", 400, 300 } }
    end
end
function Frame:SetHitRectInsets() end
function Frame:SetScript(k, fn) self._scripts[k] = fn end
function Frame:GetScript(k) return self._scripts[k] end
function Frame:HookScript(k, fn)
    if not self._scripts[k] then self._scripts[k] = fn return end
    self._hooks[k] = self._hooks[k] or {}
    table.insert(self._hooks[k], fn)
end
function Frame:SetAttribute(k, v)
    guard(self, "SetAttribute")
    self._attrs[k] = v
    if self._onAttr then self._onAttr(self, k, v) end
    fire(self, "OnAttributeChanged", k, v)
end
function Frame:GetAttribute(k) return self._attrs[k] end
function Frame:RegisterForClicks(...) guard(self, "RegisterForClicks") self._clicks = { ... } end
function Frame:RegisterForDrag(...) guard(self, "RegisterForDrag") self._drag = { ... } end
function Frame:CreateTexture() local t = newRegion("Texture", self, TextureProto) return t end
function Frame:CreateMaskTexture() return newRegion("MaskTexture", self, TextureProto) end
function Frame:CreateFontString() return newRegion("FontString", self, FontProto) end
function Frame:CreateAnimationGroup() return M.NewAnimGroup(self) end
function Frame:RegisterEvent(e)
    if M.knownEvents and not M.knownEvents[e] then error("unknown event " .. e) end
    M.eventFrames[self] = M.eventFrames[self] or {}
    M.eventFrames[self][e] = true
end
function Frame:RegisterUnitEvent(e) return self:RegisterEvent(e) end
function Frame:UnregisterEvent(e) if M.eventFrames[self] then M.eventFrames[self][e] = nil end end
function Frame:SetFrameRef(label, ref) self._refs[label] = ref end
-- Cooldown
function Frame:SetCooldown(s, d) self._cd = { s, d } end
function Frame:Clear() self._cd = nil end
noops(Frame, { "SetSwipeTexture", "SetSwipeColor", "SetDrawEdge", "SetUseCircularEdge", "SetHideCountdownNumbers" })

-- Click pipeline: PreClick, (wrapped pre), OnClick, (wrapped post), PostClick.
function Frame:Click(button, down)
    button = button or "LeftButton"
    -- Hardware clicks are only delivered for registered directions.
    if self._clicks and down ~= nil then
        local want = down and "Down" or "Up"
        local ok = false
        for _, r in ipairs(self._clicks) do
            if r == "Any" .. want or r == button .. want then ok = true end
        end
        if not ok then return end
    end
    fire(self, "PreClick", button, down)
    local msg
    local wrap = self._wrap and self._wrap.OnClick
    if wrap then
        local newButton, message = M.RunSnippet(wrap.header, wrap.pre, self, { button = button, down = down })
        if newButton == false then return end
        if newButton then button = newButton end
        msg = message
    end
    fire(self, "OnClick", button, down)
    if wrap and msg ~= nil then
        M.RunSnippet(wrap.header, wrap.post, self, { message = msg, button = button, down = down })
    end
    fire(self, "PostClick", button, down)
end

-- Restricted environment -----------------------------------------------------------
local handles = setmetatable({}, { __mode = "k" })
local function handle(f)
    if not f then return nil end
    if handles[f] then return handles[f] end
    local h = {}
    function h:GetAttribute(k) return f._attrs[k] end
    function h:SetAttribute(k, v) f:SetAttribute(k, v) end
    function h:GetFrameRef(label) return handle(f._refs[label]) end
    function h:GetParent() return handle(f._parent) end
    function h:Show() f:Show() end
    function h:Hide() f:Hide() end
    function h:IsShown() return f._shown end
    function h:GetName() return f._name end
    handles[f] = h
    M.frameOfHandle = M.frameOfHandle or setmetatable({}, { __mode = "k" })
    M.frameOfHandle[h] = f
    return h
end
M.handle = handle

function M.RunSnippet(owner, body, selfFrame, vars)
    local fn = assert(loadstring(body, "snippet"))
    local control = {}
    function control:ChildUpdate(name, message)
        for _, c in ipairs(owner._children or {}) do
            local s = c._attrs and c._attrs["_childupdate-" .. name]
            if s then M.RunSnippet(c, s, c, { message = message }) end
        end
    end
    local env = setmetatable({
        self = handle(selfFrame), owner = handle(owner), control = control,
        tonumber = tonumber, tostring = tostring, math = math, string = string,
    }, { __index = function(_, k) error("restricted env: no global '" .. tostring(k) .. "'", 2) end })
    for k, v in pairs(vars or {}) do rawset(env, k, v) end
    setfenv(fn, env)
    M.secureDepth = M.secureDepth + 1
    local ok, a, b = pcall(fn)
    M.secureDepth = M.secureDepth - 1
    if not ok then error(a, 0) end
    return a, b
end

-- Secure templates -------------------------------------------------------------------
local function applyTemplate(f, template)
    if not template then return end
    if template:find("Secure") then f._secure = true end
    if template:find("SecureHandlerStateTemplate") then
        f._onAttr = function(self, k, v)
            local state = k:match("^state%-(.+)$")
            if state and self._attrs["_onstate-" .. state] then
                M.RunSnippet(self, self._attrs["_onstate-" .. state], self, { newstate = v, stateid = state })
            end
        end
    end
    if template:find("SecureHandlerClickTemplate") then
        f._scripts.OnClick = function(self, button, down)
            local body = self._attrs._onclick
            if body then M.RunSnippet(self, body, self, { button = button, down = down }) end
        end
    end
    if template:find("SecureActionButtonTemplate") then
        f._scripts.OnClick = function(self, button, down)
            if M.dualClick then
                local useDown = M.cvars.ActionButtonUseKeyDown == "1"
                if (down and not useDown) or (not down and useDown) then return end
            end
            local t = self._attrs.type
            M.secureDepth = M.secureDepth + 1
            if t == "action" then
                log("UseAction(%s)", tostring(self._attrs.action))
            elseif t == "click" then
                local target = self._attrs.clickbutton
                log("click %s", target and target._name or "nil")
                if target then target:Click("LeftButton", false) end
            elseif t == "macro" then
                log("macro %s", tostring(self._attrs.macrotext))
            end
            M.secureDepth = M.secureDepth - 1
        end
    end
end

function M.CreateFrame(kind, name, parent, template)
    nameCounter = nameCounter + 1
    local f = newRegion(kind, parent, Frame)
    f._isFrame = true
    f._name = name
    f._scripts, f._hooks, f._attrs, f._refs, f._children = {}, {}, {}, {}, {}
    f._shown = true
    if parent then parent._children = parent._children or {} table.insert(parent._children, f) end
    applyTemplate(f, template)
    if name then _G[name] = f end
    table.insert(allFrames, f)
    return f
end

M.eventFrames = {}
function M.FireEvent(event, ...)
    for f, events in pairs(M.eventFrames) do
        if events[event] then fire(f, "OnEvent", event, ...) end
    end
end

function M.RunTimers(times)
    for _ = 1, times or 1 do
        local list = M.timers
        M.timers = {}
        for _, t in ipairs(list) do
            if not t.cancelled then
                t.fn()
                if t.repeating then table.insert(M.timers, t) end
            end
        end
    end
end

-- State drivers: evaluate "[cond]value;...;default" against M.conditions.
M.stateDrivers = {}
function M.EvaluateDriver(driver)
    for clause in (driver .. ";"):gmatch("([^;]*);") do
        local cond, value = clause:match("^%[(.-)%](.*)$")
        if cond then
            if M.conditions[cond] then return value end
        elseif clause ~= "" then
            return clause
        end
    end
end
function M.UpdateStateDrivers()
    for _, d in ipairs(M.stateDrivers) do
        local v = M.EvaluateDriver(d.driver)
        M.secureDepth = M.secureDepth + 1
        d.frame:SetAttribute("state-" .. d.state, v)
        M.secureDepth = M.secureDepth - 1
    end
end

-- Global API ----------------------------------------------------------------------------
function M.install(opts)
    opts = opts or {}
    local G = _G
    G.CreateFrame = M.CreateFrame
    G.UIParent = M.CreateFrame("Frame", "UIParent")
    G.UIParent._w, G.UIParent._h = 1792, 768
    M.UIParent = G.UIParent
    G.GetBuildInfo = function() return "1.60.1", "99999", "Nov 4 2026", 16001 end
    if not opts.legacyClicks then G.SecureActionButtonMixin = {} end
    M.dualClick = not opts.legacyClicks
    G.InCombatLockdown = function() return M.combat end
    G.UnitAffectingCombat = function() return M.combat end
    G.GetCVar = function(k) return M.cvars[k] end
    G.SetCVar = function(k, v) if M.cvars[k] == nil then error("no cvar " .. k) end M.cvars[k] = tostring(v) end
    G.C_CVar = {
        GetCVar = G.GetCVar,
        SetCVar = G.SetCVar,
        GetCVarInfo = function(k) return M.cvars[k] end,
    }
    G.GetPhysicalScreenSize = function() return M.screen[1], M.screen[2] end
    G.DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) log("chat: %s", m) end }
    G.geterrorhandler = function() return function(e) error(e, 0) end end
    G.C_Timer = {
        After = function(_, fn) table.insert(M.timers, { fn = fn }) end,
        NewTicker = function(_, fn)
            local t = { fn = fn, repeating = true }
            function t:Cancel() self.cancelled = true end
            table.insert(M.timers, t)
            return t
        end,
    }
    G.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
    G.UISpecialFrames = {}
    G.SlashCmdList = {}
    G.RegisterStateDriver = function(frame, state, driver)
        table.insert(M.stateDrivers, { frame = frame, state = state, driver = driver })
        M.secureDepth = M.secureDepth + 1
        frame:SetAttribute("state-" .. state, M.EvaluateDriver(driver))
        M.secureDepth = M.secureDepth - 1
    end
    G.SecureHandlerWrapScript = function(frame, script, header, pre, post)
        assert(loadstring(pre)) assert(loadstring(post))
        frame._wrap = frame._wrap or {}
        frame._wrap[script] = { header = header, pre = pre, post = post }
    end
    -- actions & cursor
    G.HasAction = function(s) return M.actions[s] ~= nil end
    G.GetActionTexture = function(s) return M.actions[s] and M.actions[s].texture end
    G.GetActionInfo = function(s) local a = M.actions[s] if a then return a.kind, a.id end end
    G.GetActionCooldown = function() return 0, 0, 1, 1 end
    G.IsUsableAction = function() return true, false end
    G.IsActionInRange = function() return nil end
    G.IsCurrentAction = function() return false end
    G.IsAutoRepeatAction = function() return false end
    G.IsConsumableAction = function() return false end
    G.IsStackableAction = function() return false end
    G.GetActionCount = function() return 0 end
    G.GetMacroSpell = function() return nil end
    G.GetCursorInfo = function() if M.cursor then return M.cursor.kind, M.cursor.id end end
    G.ClearCursor = function() M.cursor = nil end
    G.PickupAction = function(s)
        local old = M.actions[s]
        M.actions[s] = nil
        M.cursor = old
    end
    G.PlaceAction = function(s)
        local old = M.actions[s]
        M.actions[s] = M.cursor
        M.cursor = old
        log("PlaceAction(%d)", s)
        M.FireEvent("ACTIONBAR_SLOT_CHANGED", s)
    end
    -- spellbook (classic-style API)
    G.BOOKTYPE_SPELL = "spell"
    M.book = {
        tabs = { { "General", 0, 2 }, { "Arms", 2, 4 } },
        spells = {
            { "Attack", "", "SPELL", 6603 }, { "Hearthstone", "", "PASSIVE", 0 },
            { "Heroic Strike", "Rank 1", "SPELL", 78 }, { "Heroic Strike", "Rank 2", "SPELL", 284 },
            { "Rend", "Rank 1", "SPELL", 772 }, { "Charge", "Rank 1", "FUTURESPELL", 100 },
        },
    }
    G.GetNumSpellTabs = function() return #M.book.tabs end
    G.GetSpellTabInfo = function(i) local t = M.book.tabs[i] return t[1], "icon", t[2], t[3] end
    G.GetSpellBookItemInfo = function(i) local s = M.book.spells[i] return s and (s[3] == "PASSIVE" and "SPELL" or s[3]), s and s[4] end
    G.IsPassiveSpell = function(i) return M.book.spells[i][3] == "PASSIVE" end
    G.GetSpellBookItemName = function(i) local s = M.book.spells[i] return s[1], s[2] end
    G.GetSpellBookItemTexture = function(i) return "tex" .. i end
    G.PickupSpellBookItem = function(i) local s = M.book.spells[i] M.cursor = { kind = "spell", id = s[4], texture = "tex" .. i } end
    G.GetNumMacros = function() return 1, 1 end
    G.MAX_ACCOUNT_MACROS = 120
    G.GetMacroInfo = function(i) if i == 1 or i == 121 then return "Macro" .. i, "micon" end end
    G.PickupMacro = function(i) M.cursor = { kind = "macro", id = i, texture = "micon" } end
    G.NUM_BAG_SLOTS = 4
    G.C_Container = {
        GetContainerNumSlots = function(bag) return bag == 0 and 2 or 0 end,
        GetContainerItemInfo = function(bag, slot)
            if bag == 0 and slot == 1 then return { itemID = 6948, iconFileID = 1 } end
            if bag == 0 and slot == 2 then return { itemID = 2589, iconFileID = 2 } end
        end,
        PickupContainerItem = function(bag, slot) M.cursor = { kind = "item", id = slot } end,
    }
    G.GetItemSpell = function(id) if id == 6948 then return "Hearthstone", 8690 end end
    G.GetItemInfo = function(id) return "Item" .. id end
    -- misc
    G.UnitClass = function() return "Warrior", "WARRIOR" end
    G.UnitExists = function() return true end
    G.CameraZoomIn = function() log("zoom in") end
    G.CameraZoomOut = function() log("zoom out") end
    G.ToggleAllBags = function() log("ToggleAllBags") end
    G.CloseAllWindows = function() log("CloseAllWindows") end
    G.ChatFrame_OpenChat = function() log("open chat") end
    G.SetBinding = function(k, v) M.bindings[k] = v return true end
    G.SaveBindings = function() log("SaveBindings") end
    G.GetCurrentBindingSet = function() return 1 end
    G.IsShiftKeyDown = function() return false end
    G.HideUIPanel = function() end
    G.InterfaceOptions_AddCategory = function(f) M.optionsCategory = f end
    -- Micro buttons the menu clicks
    for _, n in ipairs({ "CharacterMicroButton", "SpellbookMicroButton", "TalentMicroButton", "QuestLogMicroButton",
        "WorldMapMicroButton", "SocialsMicroButton", "MainMenuMicroButton" }) do
        local b = M.CreateFrame("Button", n, G.UIParent)
        b:SetScript("OnClick", function() log("%s clicked", n) end)
    end
    for _, n in ipairs({ "MainMenuBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarLeft", "MultiBarRight", "PetActionBarFrame" }) do
        M.CreateFrame("Frame", n, G.UIParent)
    end
    M.knownEvents = {}
    for _, e in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED",
        "PLAYER_REGEN_DISABLED", "DISPLAY_SIZE_CHANGED", "UI_SCALE_CHANGED", "ACTIONBAR_SLOT_CHANGED",
        "ACTIONBAR_UPDATE_COOLDOWN", "SPELL_UPDATE_COOLDOWN", "ACTIONBAR_UPDATE_USABLE", "SPELL_UPDATE_USABLE",
        "PLAYER_TARGET_CHANGED", "UNIT_POWER_FREQUENT", "ACTIONBAR_UPDATE_STATE", "PLAYER_ENTER_COMBAT",
        "PLAYER_LEAVE_COMBAT", "START_AUTOREPEAT_SPELL", "STOP_AUTOREPEAT_SPELL", "TRADE_SKILL_SHOW",
        "TRADE_SKILL_CLOSE", "BAG_UPDATE_DELAYED", "BAG_UPDATE", "UPDATE_SHAPESHIFT_FORM" }) do
        M.knownEvents[e] = true
    end
    -- SPELL_ACTIVATION_OVERLAY_GLOW_* deliberately unknown: the addon must cope.

    -- Strict globals: record reads of undefined names so typos surface.
    setmetatable(G, { __index = function(_, k)
        M.undefined[k] = (M.undefined[k] or 0) + 1
        return nil
    end })
end

function M.LoadToc(dir, addonName, ns)
    local toc = assert(io.open(dir .. "/" .. addonName .. ".toc")):read("*a")
    for line in toc:gmatch("[^\r\n]+") do
        if not line:match("^##") and line:match("%.lua$") then
            local chunk = assert(loadfile(dir .. "/" .. line))
            chunk(addonName, ns)
        end
    end
end

return M
