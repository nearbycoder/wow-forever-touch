-- StickArea: the part of the screen reserved for DroidDeck's movement stick.
--
-- * It's a layout group like the others, so Edit layout can move and resize it
--   to match the stick (the stick itself belongs to DroidDeck - addons can't
--   draw or resize it).
-- * It can swallow touches that miss the stick, so a thumb sliding off the
--   stick doesn't spin the camera or click the world. The blocker sits in the
--   BACKGROUND strata: every game window and button is above it and keeps
--   working; only the 3D world underneath stops receiving those touches.

local _, ns = ...
local W = ns.W
local C = ns.color
local M = ns.media

local AREA = 230      -- base diameter, scaled by the layout
local PAD = 1.3       -- "around the stick" blocks a bit beyond the stick area

ns.cameraBlockChoices = {
    { value = "off", label = "Off" },
    { value = "around", label = "Near stick" },
    { value = "side", label = "Stick side" },
}

local area, sideBlock

local function buildArea()
    area = CreateFrame("Frame", "ForeverTouchStickArea", UIParent)
    area:SetSize(AREA, AREA)
    area:SetFrameStrata("BACKGROUND")
    area:SetFrameLevel(1)

    -- Placement visuals, only shown while editing / during setup.
    local visual = CreateFrame("Frame", nil, area)
    visual:SetAllPoints()
    visual:Hide()
    local fill = W.Tex(visual, "BACKGROUND", M .. "circle", C.accent[1], C.accent[2], C.accent[3], 0.10)
    fill:SetAllPoints()
    local ring = W.Tex(visual, "ARTWORK", M .. "ring", C.accent[1], C.accent[2], C.accent[3], 0.85)
    ring:SetAllPoints()
    local nub = W.Tex(visual, "ARTWORK", M .. "circle", 1, 1, 1, 0.25, 1)
    nub:SetSize(AREA * 0.35, AREA * 0.35)
    nub:SetPoint("CENTER")
    local text = W.Font(visual, 14)
    text:SetPoint("TOP", visual, "BOTTOM", 0, -8) -- below: the edit handle sits above
    text:SetWidth(280)
    text:SetText("Put DroidDeck's left stick here")
    local pulse = visual:CreateAnimationGroup()
    pulse:SetLooping("BOUNCE")
    local a = pulse:CreateAnimation("Alpha")
    if a.SetFromAlpha then a:SetFromAlpha(1) a:SetToAlpha(0.45) else a:SetChange(-0.55) end
    a:SetDuration(0.9)
    visual.pulse = pulse
    area.visual = visual

    -- Shows the blocked region while editing so it's clear what it covers.
    area.blockTint = W.Color(area, "BACKGROUND", 1, 1, 1, 0.05)
    area.blockTint:Hide()

    sideBlock = CreateFrame("Frame", "ForeverTouchStickSide", UIParent)
    sideBlock:SetFrameStrata("BACKGROUND")
    sideBlock:SetFrameLevel(0)
    sideBlock.tint = W.Color(sideBlock, "BACKGROUND", 1, 1, 1, 0.04)
    sideBlock.tint:SetAllPoints()
    sideBlock.tint:Hide()
    sideBlock:Hide()

    ns.RegisterGroup("stick", area, "Stick area")
end

-- Re-applies the touch blocker for the current mode and stick position.
function ns.UpdateCameraBlock()
    if not area then return end
    local mode = ns.db.cameraBlock or "around"
    local editing = ns.editing
    area:EnableMouse(mode == "around")
    -- Pad the hit area beyond the drawn circle (insets are in area units).
    local pad = -AREA * (PAD - 1) / 2
    area:SetHitRectInsets(pad, pad, pad, pad)
    area.blockTint:ClearAllPoints()
    area.blockTint:SetPoint("TOPLEFT", pad, -pad)
    area.blockTint:SetPoint("BOTTOMRIGHT", -pad, pad)
    area.blockTint:SetShown(editing and mode == "around")

    if mode == "side" then
        local onLeft = ns.Layout("stick").fx < 0.5
        sideBlock:ClearAllPoints()
        if onLeft then
            sideBlock:SetPoint("TOPLEFT", UIParent, "TOPLEFT")
            sideBlock:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOM")
        else
            sideBlock:SetPoint("TOPLEFT", UIParent, "TOP")
            sideBlock:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT")
        end
        sideBlock:EnableMouse(true)
        sideBlock.tint:SetShown(editing)
        sideBlock:Show()
    else
        sideBlock:EnableMouse(false)
        sideBlock:Hide()
    end
end

function ns.SetCameraBlock(mode)
    ns.db.cameraBlock = mode
    ns.UpdateCameraBlock()
end

function ns.ShowStickGuide(show)
    if not area then return end
    local v = area.visual
    if show then
        v:Show()
        v.pulse:Play()
    else
        v:Hide()
        v.pulse:Stop()
    end
    ns.UpdateCameraBlock()
end

ns.OnInit(function()
    buildArea()
    ns.UpdateCameraBlock()
end)

table.insert(ns.layoutListeners, function() ns.UpdateCameraBlock() end)
