-- EditMode: drag groups by their handles, resize them, and tap any spell
-- button to change what's on it. Only available out of combat.

local _, ns = ...
local W = ns.W
local C = ns.color
local M = ns.media

local handles = {}
ns.editHandles = handles
local toolbar
local selected = "cluster"

-- Handles ---------------------------------------------------------------------------
local function outline(parent, r, g, b, a)
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local line = W.Color(parent, "OVERLAY", r, g, b, a)
        if side == "TOP" or side == "BOTTOM" then
            line:SetHeight(2) line:SetPoint(side .. "LEFT") line:SetPoint(side .. "RIGHT")
        else
            line:SetWidth(2) line:SetPoint("TOP" .. side) line:SetPoint("BOTTOM" .. side)
        end
    end
end

-- Big groups get their handle just above them; small ones (menu,
-- camera) get it beside them, on the side facing the middle of the screen,
-- so the handle never covers the button you're moving.
local function placeHandle(name, h)
    local group = ns.groups[name]
    h:ClearAllPoints()
    if group:GetWidth() * group:GetScale() < 120 then
        if ns.Layout(name).fx > 0.5 then
            h:SetPoint("RIGHT", group, "LEFT", -10, 0)
        else
            h:SetPoint("LEFT", group, "RIGHT", 10, 0)
        end
    else
        h:SetPoint("BOTTOM", group, "TOP", 0, 6)
    end
end

local function refreshSelection()
    for name, h in pairs(handles) do
        placeHandle(name, h)
        local on = (name == selected)
        h.box.fill:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], on and 0.12 or 0.04)
        h:SetAlpha(on and 1 or 0.75)
    end
    if toolbar then
        toolbar.groupPicker.Refresh()
        toolbar.size.Refresh()
        toolbar.opacity.Refresh()
    end
end

local function createHandle(name)
    local group = ns.groups[name]
    local box = CreateFrame("Frame", nil, UIParent)
    box:SetFrameStrata("HIGH")
    box:SetAllPoints(group)
    box.fill = W.Color(box, "BACKGROUND", C.accent[1], C.accent[2], C.accent[3], 0.05)
    box.fill:SetAllPoints()
    outline(box, C.accent[1], C.accent[2], C.accent[3], 0.7)

    local h = CreateFrame("Button", nil, UIParent)
    h:SetFrameStrata("TOOLTIP")
    W.DecorateRound(h, 46)
    h.icon:SetTexture("Interface\\CURSOR\\UI-Cursor-Move")
    h.icon:SetTexCoord(0, 1, 0, 1)
    h.plate:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 1)
    local label = W.Font(h, 12)
    label:SetPoint("BOTTOM", h, "TOP", 0, 4)
    label:SetText(ns.groupLabels[name])

    h:HookScript("OnMouseDown", function()
        if InCombatLockdown() then return end
        selected = name
        refreshSelection()
        group:StartMoving()
    end)
    h:HookScript("OnMouseUp", function()
        group:StopMovingOrSizing()
        if group.SetUserPlaced then group:SetUserPlaced(false) end
        ns.SaveGroupPosition(name)
    end)
    h.box = box
    handles[name] = h
    return h
end

-- Toolbar ---------------------------------------------------------------------------
local function buildToolbar()
    local f = W.Panel("ForeverTouchEditBar", UIParent, 840, 196, "Edit layout")
    f:SetPoint("TOP", 0, -12)
    f:SetFrameStrata("FULLSCREEN_DIALOG")

    local hint = W.Font(f, 13, C.muted[1], C.muted[2], C.muted[3])
    hint:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -4)
    hint:SetText("Drag a pink handle to move a group. Tap a spell button to change it, or drag one onto another to swap.")

    local options = {}
    for _, name in ipairs(ns.groupOrder) do options[#options + 1] = { value = name, label = ns.groupLabels[name] } end
    f.groupPicker = W.Segmented(f, 792, 42, options, function() return selected end, function(v)
        selected = v
        refreshSelection()
    end)
    f.groupPicker:SetPoint("TOPLEFT", 24, -82)

    f.size = W.Stepper(f, 250, "Size", function()
        return math.floor((ns.Layout(selected).scale or 1) * 100 + 0.5)
    end, function(v)
        ns.Layout(selected).scale = v / 100
        ns.ApplyLayout()
    end, 50, 200, 5, function(v) return v .. "%" end)
    f.size:SetPoint("TOPLEFT", 24, -136)

    f.opacity = W.Stepper(f, 250, "Opacity", function()
        return math.floor((ns.Layout(selected).alpha or 1) * 100 + 0.5)
    end, function(v)
        ns.Layout(selected).alpha = v / 100
        ns.ApplyGroupAlpha()
    end, 25, 100, 5, function(v) return v .. "%" end)
    f.opacity:SetPoint("LEFT", f.size, "RIGHT", 24, 0)

    local done = W.Button(f, 110, 44, "Done", function() ns.ExitEditMode() end, "primary")
    done:SetPoint("BOTTOMRIGHT", -24, 16)
    local reset = W.Button(f, 120, 44, "Reset layout", function()
        ns.ResetLayout()
        refreshSelection()
    end)
    reset:SetPoint("RIGHT", done, "LEFT", -8, 0)
    return f
end

-- Enter / exit -----------------------------------------------------------------------
local function setClusterEditing(on)
    for _, b in ipairs(ns.cluster.buttons) do
        -- In edit mode taps open the picker instead of casting.
        b:SetAttribute("type", on and "" or "action")
        b.slotLabel:SetShown(on)
        b.slotLabel:SetText(on and tostring(b.index) or "")
    end
    ns.cluster.SetDragEnabled(on)
end

function ns.EnterEditMode()
    if InCombatLockdown() then
        ns.Print("Edit mode is available out of combat.")
        return
    end
    if ns.editing then return end
    ns.editing = true
    if ns.menuPanel and ns.menuPanel:IsShown() then ns.menuPanel:Hide() end
    for _, name in ipairs(ns.groupOrder) do
        local h = handles[name] or createHandle(name)
        h:Show()
        h.box:Show()
    end
    toolbar = toolbar or buildToolbar()
    W.FitToScreen(toolbar, 1.0)
    toolbar:Show()
    setClusterEditing(true)
    ns.UpdateGroupVisibility()
    ns.ApplyGroupAlpha()
    ns.cluster.UpdateAll()
    ns.ShowStickGuide(true)
    refreshSelection()
end

function ns.ExitEditMode()
    if not ns.editing then return end
    ns.editing = false
    for _, h in pairs(handles) do
        h:Hide()
        h.box:Hide()
    end
    if toolbar then toolbar:Hide() end
    ns.ShowStickGuide(false)
    ns.RunOOC("exitEdit", function()
        setClusterEditing(false)
        ns.UpdateGroupVisibility()
        ns.cluster.UpdateAll()
    end)
    ns.ApplyGroupAlpha()
end

-- Combat always ends edit mode (PLAYER_REGEN_DISABLED fires just before lockdown).
ns.On("PLAYER_REGEN_DISABLED", function()
    if ns.editing then
        ns.ExitEditMode()
        ns.Print("Edit mode closed - you entered combat.")
    end
end)

table.insert(ns.layoutListeners, function()
    if toolbar and toolbar:IsShown() then refreshSelection() end
end)
