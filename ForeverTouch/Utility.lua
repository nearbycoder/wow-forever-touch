-- Utility: targeting row and camera zoom buttons.

local _, ns = ...
local W = ns.W
local C = ns.color

local SIZE, GAP = 58, 16

-- { label, glyph or nil, icon, macro }
local TARGET_ACTIONS = {
    { "Target", nil, "Interface\\Icons\\Ability_Hunter_SniperShot", "/targetenemy" },
    { "Assist", nil, "Interface\\Icons\\Ability_Warrior_BattleShout", "/assist" },
    { "Clear", "X", nil, "/cleartarget" },
}
local PET_CLASSES = { HUNTER = true, WARLOCK = true }

local function labelUnder(b, text)
    local fs = W.Font(b, 12, C.muted[1], C.muted[2], C.muted[3])
    fs:SetPoint("TOP", b, "BOTTOM", 0, -4)
    fs:SetText(text)
    return fs
end

local function createUtility()
    local actions = {}
    for _, a in ipairs(TARGET_ACTIONS) do actions[#actions + 1] = a end
    local _, class = UnitClass("player")
    if PET_CLASSES[class] then
        actions[#actions + 1] = { "Pet attack", nil, "Interface\\Icons\\Ability_GhoulFrenzy", "/petattack" }
    end

    local f = CreateFrame("Frame", "ForeverTouchUtility", UIParent)
    f:SetSize(#actions * SIZE + (#actions - 1) * GAP, SIZE + 22)
    f:SetFrameStrata("MEDIUM")

    for i, a in ipairs(actions) do
        local b = CreateFrame("Button", "ForeverTouchUtility" .. i, f, "SecureActionButtonTemplate")
        b:SetAttribute("type", "macro")
        b:SetAttribute("macrotext", a[4])
        if ns.dualClick then b:RegisterForClicks("AnyUp", "AnyDown") else b:RegisterForClicks("AnyUp") end
        W.DecorateRound(b, SIZE)
        if a[3] then
            b.icon:SetTexture(a[3])
        else
            b.icon:Hide()
            b.glyph:SetText(a[2])
        end
        b:SetPoint("TOPLEFT", (i - 1) * (SIZE + GAP), 0)
        labelUnder(b, a[1])
    end
    ns.RegisterGroup("utility", f, "Target buttons")
end

local function createCamera()
    local f = CreateFrame("Frame", "ForeverTouchCamera", UIParent)
    local size = 48
    f:SetSize(size, size * 2 + 14)
    f:SetFrameStrata("MEDIUM")

    local function zoomButton(glyph, fn, point, y)
        local b = CreateFrame("Button", nil, f)
        W.DecorateRound(b, size, { glyphSize = 24 })
        b.icon:Hide()
        b.glyph:SetText(glyph)
        b:SetPoint(point, 0, y)
        -- Hold to keep zooming.
        local ticker
        b:HookScript("OnMouseDown", function()
            pcall(fn, 1)
            if ticker then ticker:Cancel() end
            ticker = C_Timer.NewTicker(0.08, function() pcall(fn, 0.6) end)
        end)
        local function stop()
            if ticker then ticker:Cancel() ticker = nil end
        end
        b:HookScript("OnMouseUp", stop)
        b:HookScript("OnHide", stop)
        return b
    end
    zoomButton("+", CameraZoomIn, "TOP", 0)
    zoomButton("-", CameraZoomOut, "BOTTOM", 0)
    ns.RegisterGroup("camera", f, "Camera zoom")
end

function ns.UpdateGroupVisibility()
    ns.RunOOC("groupVisibility", function()
        local u, c = ns.groups.utility, ns.groups.camera
        if u then u:SetShown(ns.db.showUtility or ns.editing) end
        if c then c:SetShown(ns.db.showCamera or ns.editing) end
    end)
end

ns.OnInit(function()
    createUtility()
    createCamera()
end)
