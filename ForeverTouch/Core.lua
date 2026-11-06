-- ForeverTouch: touch screen controls for World of Warcraft: Forever.
-- Core: namespace, saved variables, events, combat-safe queue, screen profiles.

local ADDON, ns = ...
_G.ForeverTouch = ns

ns.name = ADDON
ns.version = "1.1.0"
ns.media = "Interface\\AddOns\\" .. ADDON .. "\\media\\"

-- Theme -----------------------------------------------------------------------
ns.color = {
    accent = { 0.86, 0.15, 0.47 },  -- matches the project icon (#db2777)
    accentSoft = { 0.95, 0.45, 0.68 },
    panel = { 0.06, 0.07, 0.10, 0.94 },
    panelLight = { 0.13, 0.14, 0.19, 1 },
    line = { 1, 1, 1, 0.10 },
    text = { 0.95, 0.95, 0.97 },
    muted = { 0.66, 0.68, 0.75 },
    good = { 0.30, 0.85, 0.50 },
    gold = { 1.0, 0.82, 0.25 },
}

-- Client capabilities ---------------------------------------------------------
ns.interface = select(4, GetBuildInfo()) or 0
-- Modern secure templates (10.0+ engine) fire on press or release depending on
-- the ActionButtonUseKeyDown CVar, so buttons must listen for both.
ns.dualClick = (SecureActionButtonMixin ~= nil)

-- True when secure buttons act on press (the click with down == true).
function ns.useKeyDownNow()
    if not ns.dualClick then return false end
    return ns.GetCVarBool("ActionButtonUseKeyDown") == true
end

-- Utilities -------------------------------------------------------------------
function ns.Print(fmt, ...)
    local msg = select("#", ...) > 0 and string.format(fmt, ...) or fmt
    DEFAULT_CHAT_FRAME:AddMessage("|cffdb2777Forever Touch|r: " .. tostring(msg))
end

function ns.CVarExists(name)
    if C_CVar and C_CVar.GetCVarInfo then
        return C_CVar.GetCVarInfo(name) ~= nil
    end
    return GetCVar(name) ~= nil
end

function ns.GetCVarBool(name)
    if not ns.CVarExists(name) then return nil end
    local v = (C_CVar and C_CVar.GetCVar or GetCVar)(name)
    return v == "1"
end

function ns.SetCVar(name, value)
    if not ns.CVarExists(name) then return false end
    if type(value) == "boolean" then value = value and "1" or "0" end
    local setter = (C_CVar and C_CVar.SetCVar) or SetCVar
    local ok = pcall(setter, name, tostring(value))
    return ok
end

local function copyDefaults(src, dst)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            copyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
    return dst
end
ns.CopyDefaults = copyDefaults

function ns.DeepCopy(t)
    if type(t) ~= "table" then return t end
    local c = {}
    for k, v in pairs(t) do c[k] = ns.DeepCopy(v) end
    return c
end

-- Saved variables -------------------------------------------------------------
-- Group positions are stored as fractions of the screen (fx, fy = centre) so a
-- layout survives resolution changes, and each Fold screen has its own layout.
ns.defaultLayouts = {
    -- Folded: wide cover screen, small physical size -> bigger controls.
    cover = {
        cluster = { fx = 0.855, fy = 0.30, scale = 0.95, alpha = 1 },
        utility = { fx = 0.62, fy = 0.11, scale = 0.95, alpha = 1 },
        menu = { fx = 0.965, fy = 0.90, scale = 1.0, alpha = 1 },
        camera = { fx = 0.975, fy = 0.62, scale = 0.95, alpha = 1 },
        stick = { fx = 0.13, fy = 0.27, scale = 1.0, alpha = 1 },
    },
    -- Unfolded: near-square inner screen.
    main = {
        cluster = { fx = 0.78, fy = 0.24, scale = 0.78, alpha = 1 },
        utility = { fx = 0.50, fy = 0.08, scale = 0.80, alpha = 1 },
        menu = { fx = 0.935, fy = 0.92, scale = 0.85, alpha = 1 },
        camera = { fx = 0.95, fy = 0.55, scale = 0.80, alpha = 1 },
        stick = { fx = 0.17, fy = 0.25, scale = 0.85, alpha = 1 },
    },
}

ns.defaults = {
    dbVersion = 1,
    setupDone = false,
    handed = "right",          -- "right" | "left"
    profileMode = "auto",      -- "auto" | "cover" | "main"
    numPages = 2,
    pageBars = { "main", 61, 49 }, -- page 1 follows stance; others are fixed slot ranges
    dimOutOfCombat = false,
    hideBlizzardBars = false,
    showUtility = true,
    showCamera = true,
    showEmptyButtons = true,
    pickerAllRanks = false,
    cameraBlock = "around", -- "off" | "around" | "side": touches near the stick don't turn the camera
    layouts = ns.DeepCopy(ns.defaultLayouts),
}

-- Event plumbing --------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
local handlers = {}
ns.eventFrame = eventFrame

function ns.On(event, fn)
    if not handlers[event] then
        handlers[event] = {}
        -- Unknown events raise errors on modern clients; skip them quietly so
        -- the addon keeps working if a client lacks an event.
        if not pcall(eventFrame.RegisterEvent, eventFrame, event) then
            handlers[event] = nil
            return false
        end
    end
    table.insert(handlers[event], fn)
    return true
end

function ns.OnUnit(event, unit, fn)
    local ok = pcall(eventFrame.RegisterUnitEvent or eventFrame.RegisterEvent, eventFrame, event, unit)
    if not ok then return false end
    handlers[event] = handlers[event] or {}
    table.insert(handlers[event], function(...)
        local u = ...
        if u == unit then fn(...) end
    end)
    return true
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    local list = handlers[event]
    if not list then return end
    for i = 1, #list do
        local ok, err = pcall(list[i], ...)
        if not ok then
            geterrorhandler()(err)
        end
    end
end)

-- Combat-safe queue ------------------------------------------------------------
-- Protected frames cannot be moved, resized or reconfigured in combat. Anything
-- that does so goes through RunOOC and is replayed when combat ends.
local pending, pendingOrder = {}, {}

function ns.RunOOC(key, fn)
    if InCombatLockdown() then
        if not pending[key] then table.insert(pendingOrder, key) end
        pending[key] = fn
        return false
    end
    fn()
    return true
end

ns.On("PLAYER_REGEN_ENABLED", function()
    local order = pendingOrder
    pendingOrder = {}
    for _, key in ipairs(order) do
        local fn = pending[key]
        pending[key] = nil
        if fn then fn() end
    end
end)

-- Screen profiles (Galaxy Fold cover vs inner screen) ------------------------
function ns.DetectProfile()
    local w, h
    if GetPhysicalScreenSize then w, h = GetPhysicalScreenSize() end
    if not w or not h or w == 0 or h == 0 then
        w, h = UIParent:GetWidth(), UIParent:GetHeight()
    end
    local ratio = w / h
    if ratio < 1 then ratio = 1 / ratio end
    -- Fold cover screens are ~21:9 or wider; the inner screen is nearly square.
    return ratio >= 1.7 and "cover" or "main"
end

function ns.ActiveProfile()
    local mode = ns.db and ns.db.profileMode or "auto"
    if mode == "cover" or mode == "main" then return mode end
    return ns.DetectProfile()
end

ns.profileLabels = {
    cover = "Folded (cover screen)",
    main = "Unfolded (inner screen)",
}

function ns.Layout(groupName)
    local profile = ns.ActiveProfile()
    local layouts = ns.db.layouts
    layouts[profile] = layouts[profile] or ns.DeepCopy(ns.defaultLayouts[profile])
    local l = layouts[profile][groupName]
    if not l then
        l = ns.DeepCopy(ns.defaultLayouts[profile][groupName] or { fx = 0.5, fy = 0.5, scale = 1, alpha = 1 })
        -- Groups added in later versions must respect an existing left-hand layout.
        if ns.db.handed == "left" then l.fx = 1 - l.fx end
        layouts[profile][groupName] = l
    end
    return l
end

-- Movable groups ----------------------------------------------------------------
ns.layoutListeners = {} -- called after every layout change
ns.groups = {}
ns.groupOrder = {}
ns.groupLabels = {}

function ns.RegisterGroup(name, frame, label)
    ns.groups[name] = frame
    ns.groupLabels[name] = label or name
    table.insert(ns.groupOrder, name)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame.ftGroup = name
end

local function positionGroup(name)
    local f = ns.groups[name]
    if not f then return end
    local l = ns.Layout(name)
    local s = l.scale or 1
    f:SetScale(s)
    f:ClearAllPoints()
    local W, H = UIParent:GetWidth(), UIParent:GetHeight()
    f:SetPoint("CENTER", UIParent, "BOTTOMLEFT", (l.fx * W) / s, (l.fy * H) / s)
end

function ns.ApplyGroupAlpha()
    local inCombat = InCombatLockdown() or UnitAffectingCombat("player")
    for name, f in pairs(ns.groups) do
        local a = ns.Layout(name).alpha or 1
        if ns.db.dimOutOfCombat and not inCombat and not ns.editing then a = a * 0.55 end
        f:SetAlpha(a)
    end
end

function ns.ApplyLayout()
    ns.RunOOC("layout", function()
        for _, name in ipairs(ns.groupOrder) do positionGroup(name) end
        ns.ApplyGroupAlpha()
        if ns.UpdateGroupVisibility then ns.UpdateGroupVisibility() end
        for _, fn in ipairs(ns.layoutListeners) do fn() end
    end)
end

-- Called after a group was dragged: store its centre as screen fractions.
function ns.SaveGroupPosition(name)
    local f = ns.groups[name]
    if not f then return end
    local x, y = f:GetCenter()
    if not x then return end
    local s = f:GetScale()
    local W, H = UIParent:GetWidth(), UIParent:GetHeight()
    local l = ns.Layout(name)
    l.fx = math.max(0, math.min(1, (x * s) / W))
    l.fy = math.max(0, math.min(1, (y * s) / H))
    positionGroup(name)
end

function ns.ResetLayout(profile)
    profile = profile or ns.ActiveProfile()
    ns.db.layouts[profile] = ns.DeepCopy(ns.defaultLayouts[profile])
    if ns.db.handed == "left" then ns.MirrorLayout(profile) end
    ns.ApplyLayout()
end

function ns.MirrorLayout(profile)
    local layout = ns.db.layouts[profile or ns.ActiveProfile()]
    if not layout then return end
    for _, l in pairs(layout) do l.fx = 1 - l.fx end
end

function ns.SetHanded(hand)
    if hand == ns.db.handed then return end
    if InCombatLockdown() then ns.Print("Leave combat to switch hands.") return end
    ns.db.handed = hand
    for profile in pairs(ns.db.layouts) do ns.MirrorLayout(profile) end
    if ns.RebuildClusterGeometry then ns.RebuildClusterGeometry() end
    ns.ApplyLayout()
end

-- Startup -------------------------------------------------------------------------
local lastProfile

local function checkProfile()
    local p = ns.ActiveProfile()
    if p ~= lastProfile then
        local announce = lastProfile ~= nil
        lastProfile = p
        ns.ApplyLayout()
        if announce and ns.W then ns.W.Toast("Switched to the " .. ns.profileLabels[p]:lower() .. " layout") end
    end
end
ns.CheckProfile = checkProfile

ns.On("ADDON_LOADED", function(name)
    if name ~= ADDON then return end
    ForeverTouchDB = ForeverTouchDB or {}
    ns.db = copyDefaults(ns.defaults, ForeverTouchDB)
end)

ns.On("PLAYER_LOGIN", function()
    if ns.HideBlizzardBars and ns.db.hideBlizzardBars then ns.HideBlizzardBars() end
    for _, init in ipairs(ns.initializers or {}) do init() end
    checkProfile()
    ns.ApplyLayout()
end)

ns.On("PLAYER_ENTERING_WORLD", function()
    ns.ApplyGroupAlpha()
    if not ns.db.setupDone and ns.ShowSetup then
        C_Timer.After(2, function()
            if not ns.db.setupDone and not InCombatLockdown() then ns.ShowSetup() end
        end)
    end
end)

-- The Fold changes resolution when it is opened or closed.
local function onResize()
    C_Timer.After(0.3, checkProfile)
end
ns.On("DISPLAY_SIZE_CHANGED", onResize)
ns.On("UI_SCALE_CHANGED", onResize)
ns.On("PLAYER_REGEN_DISABLED", function() ns.ApplyGroupAlpha() end)
ns.On("PLAYER_REGEN_ENABLED", function() ns.ApplyGroupAlpha() end)

-- Modules add their setup functions here; they run at PLAYER_LOGIN.
ns.initializers = {}
function ns.OnInit(fn) table.insert(ns.initializers, fn) end
