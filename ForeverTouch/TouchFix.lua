-- TouchFix: client settings that make touch-emulated mouse input land where the
-- finger is, plus a diagnostic screen (/ft touchtest) that shows where taps land.
--
-- Why: DroidDeck (and similar Wine/Proton launchers) can only place the cursor
-- under your finger if the game reads absolute cursor positions and does not
-- hold (lock/clip) the pointer. While the pointer is held, DroidDeck builds
-- before PR #2133 send touches as touchpad motion, so taps click wherever the
-- cursor already was. Raw mouse input reads relative motion only, which also
-- ignores the jump to your finger.
-- Controller-cursor CVars are deliberately left alone: changing them can leave
-- the stick steering the cursor instead of the character.

local _, ns = ...
local W = ns.W
local C = ns.color
local M = ns.media

ns.touchFixes = {
    { cvar = "rawMouseEnable", value = "0", why = "raw mouse input off, so the cursor jumps to your finger" },
    { cvar = "ClipCursor", value = "0", why = "cursor no longer locked to the window" },
    { cvar = "gxCursor", value = "1", why = "hardware cursor (after a game restart)" },
}
local FIX_VERSION = 1

local function getCVar(name)
    return (C_CVar and C_CVar.GetCVar or GetCVar)(name)
end

-- Returns the list of settings that changed.
function ns.ApplyTouchFixes()
    if InCombatLockdown() then return {} end
    ns.db.touchFixBackup = ns.db.touchFixBackup or {}
    local changed = {}
    for _, fix in ipairs(ns.touchFixes) do
        if ns.CVarExists(fix.cvar) then
            local old = getCVar(fix.cvar)
            if old ~= fix.value and ns.SetCVar(fix.cvar, fix.value) then
                if ns.db.touchFixBackup[fix.cvar] == nil then ns.db.touchFixBackup[fix.cvar] = old end
                changed[#changed + 1] = fix
            end
        end
    end
    ns.db.touchFixVersion = FIX_VERSION
    ns.db.touchFixOff = false
    return changed
end

function ns.RevertTouchFixes()
    local n = 0
    for cvar, old in pairs(ns.db.touchFixBackup or {}) do
        if ns.SetCVar(cvar, old) then n = n + 1 end
    end
    ns.db.touchFixBackup = {}
    ns.db.touchFixOff = true
    return n
end

local function announce(changed)
    if #changed == 0 then return end
    ns.Print("Adjusted %d game settings so taps land where you touch:", #changed)
    for _, fix in ipairs(changed) do
        DEFAULT_CHAT_FRAME:AddMessage("   - " .. fix.why .. " (" .. fix.cvar .. ")")
    end
    DEFAULT_CHAT_FRAME:AddMessage("   Undo with /ft touchfix off. Still not working? Type /ft touchtest")
end

-- Applied automatically once (and again when this list grows), because a
-- player whose touches don't work can't tap a settings button to fix it.
ns.OnInit(function()
    if not ns.db.touchFixOff and (ns.db.touchFixVersion or 0) < FIX_VERSION then
        announce(ns.ApplyTouchFixes())
    end
end)

-- Touch test ---------------------------------------------------------------------------
local test

local function cursorPos()
    local x, y = GetCursorPosition()
    local s = UIParent:GetEffectiveScale()
    return x / s, y / s
end

local VERDICT_OK = "|cff4ddb80Taps land where you touch.|r If buttons still don't respond, check that DroidDeck's tap gesture is mapped to left click."
local VERDICT_CURSOR = "|cffff6666Taps land where the cursor was, not under your finger.|r\n"
    .. "In DroidDeck: set Touch mode to Direct. If it already is, update DroidDeck (fix #2133) or use stable 0.6.9.\n"
    .. "Then restart the game so the cursor settings from /ft touchfix take effect."
local VERDICT_NONE = "|cffff6666No taps reached the game.|r\n"
    .. "DroidDeck isn't sending touches as clicks: check its touch mode (Direct) and that tap = left click."

local function buildTest()
    local f = CreateFrame("Button", "ForeverTouchTouchTest", UIParent)
    f:SetAllPoints(UIParent)
    f:SetFrameStrata("TOOLTIP")
    f:RegisterForClicks("AnyDown")
    f:Hide()
    table.insert(UISpecialFrames, "ForeverTouchTouchTest")
    local bg = W.Color(f, "BACKGROUND", 0, 0, 0, 0.72)
    bg:SetAllPoints()

    local head = W.Card(f, 940, 96)
    head:SetPoint("TOP", 0, -24)
    f.title = W.Font(head, 22)
    f.title:SetPoint("TOP", 0, -16)
    f.title:SetText("Touch test")
    f.info = W.Font(head, 14, C.muted[1], C.muted[2], C.muted[3])
    f.info:SetPoint("TOP", f.title, "BOTTOM", 0, -8)
    f.info:SetWidth(900)
    f.info:SetJustifyH("CENTER")
    f.resultCard = W.Card(f, 1040, 100)
    f.resultCard:SetPoint("BOTTOM", 0, 36)
    f.result = W.Font(f.resultCard, 16)
    f.result:SetPoint("CENTER")
    f.result:SetWidth(1000)
    f.result:SetJustifyH("CENTER")

    -- Three targets to tap, left to right.
    f.targets = {}
    for i = 1, 3 do
        local t = CreateFrame("Frame", nil, f)
        t:SetSize(120, 120)
        local ring = W.Tex(t, "ARTWORK", M .. "ring", C.accent[1], C.accent[2], C.accent[3], 1)
        ring:SetAllPoints()
        local dot = W.Tex(t, "ARTWORK", M .. "circle", 1, 1, 1, 0.9, 1)
        dot:SetSize(14, 14)
        dot:SetPoint("CENTER")
        t.label = W.Font(t, 18, nil, nil, nil, "OUTLINE")
        t.label:SetPoint("TOP", t, "BOTTOM", 0, -6)
        t.label:SetText(tostring(i))
        t.ring = ring
        f.targets[i] = t
    end

    -- Where the game registered each tap.
    f.marks = {}
    for i = 1, 3 do
        local m = W.Tex(f, "OVERLAY", M .. "circle", C.gold[1], C.gold[2], C.gold[3], 0.95)
        m:SetSize(22, 22)
        m:Hide()
        f.marks[i] = m
    end
    -- Live game cursor.
    f.cursor = W.Tex(f, "OVERLAY", M .. "thinring", 0.3, 0.85, 1, 1, 2)
    f.cursor:SetSize(40, 40)
    f.cursorLabel = W.Font(f, 12, 0.3, 0.85, 1)
    f.cursorLabel:SetText("game cursor")

    function f:Begin()
        local Wd, H = UIParent:GetWidth(), UIParent:GetHeight()
        for i, t in ipairs(self.targets) do
            t:ClearAllPoints()
            t:SetPoint("CENTER", UIParent, "BOTTOMLEFT", Wd * (0.2 + 0.3 * (i - 1)), H * (i == 2 and 0.42 or 0.55))
            t.ring:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 1)
        end
        for _, m in ipairs(self.marks) do m:Hide() end
        self.step, self.errors, self.done, self.elapsed = 1, {}, false, 0
        self.info:SetText("Tap the centre of circle 1, then 2, then 3 with your finger.\n"
            .. "Gold dots show where the game felt each tap. Press Escape or tap after the result to close.")
        self.result:SetText("")
        self.resultCard:Hide()
        self:Show()
    end

    function f:Finish(verdict)
        self.done = true
        self.result:SetText(verdict)
        self.resultCard:Show()
        ns.db.lastTouchTest = verdict == VERDICT_OK and "ok" or (verdict == VERDICT_CURSOR and "cursor" or "none")
        -- Also log it, in case the overlay itself is hard to read on a small screen.
        ns.Print("Touch test: %s", (verdict:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("\n", " ")))
    end

    f:SetScript("OnClick", function(self)
        if self.done then self:Hide() return end
        local x, y = cursorPos()
        local t = self.targets[self.step]
        local tx, ty = t:GetCenter()
        local err = math.sqrt((x - tx) ^ 2 + (y - ty) ^ 2)
        self.errors[self.step] = err
        local m = self.marks[self.step]
        m:ClearAllPoints()
        m:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
        m:Show()
        t.ring:SetVertexColor(err < 70 and C.good[1] or 1, err < 70 and C.good[2] or 0.35, err < 70 and C.good[3] or 0.35, 1)
        self.step = self.step + 1
        if self.step > 3 then
            local worst = math.max(self.errors[1], self.errors[2], self.errors[3])
            self:Finish(worst < 70 and VERDICT_OK or VERDICT_CURSOR)
        end
    end)

    f:SetScript("OnUpdate", function(self, elapsed)
        local x, y = cursorPos()
        self.cursor:ClearAllPoints()
        self.cursor:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
        self.cursorLabel:ClearAllPoints()
        self.cursorLabel:SetPoint("TOP", self.cursor, "BOTTOM", 0, -2)
        if not self.done and self.step == 1 then
            self.elapsed = self.elapsed + elapsed
            if self.elapsed > 25 then self:Finish(VERDICT_NONE) end
        end
    end)
    return f
end

function ns.ShowTouchTest()
    test = test or buildTest()
    test:Begin()
end
