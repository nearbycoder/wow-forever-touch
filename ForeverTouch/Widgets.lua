-- Widgets: round touch buttons, panels, toggles and steppers sized for fingers.

local _, ns = ...
local C = ns.color
local M = ns.media

local W = {}
ns.W = W

-- Animations -------------------------------------------------------------------
local function setScaleAnim(anim, from, to)
    if anim.SetScaleFrom then
        anim:SetScaleFrom(from, from)
        anim:SetScaleTo(to, to)
    else
        anim:SetScale(to / from, to / from)
    end
end

local function setAlphaAnim(anim, from, to)
    if anim.SetFromAlpha then
        anim:SetFromAlpha(from)
        anim:SetToAlpha(to)
    else
        anim:SetChange(to - from)
    end
end

function W.Ripple(parent, texture, size)
    local t = parent:CreateTexture(nil, "OVERLAY", nil, 6)
    t:SetTexture(texture or (M .. "thinring"))
    t:SetSize(size, size)
    t:SetPoint("CENTER")
    t:SetBlendMode("ADD")
    t:SetAlpha(0)
    local ag = t:CreateAnimationGroup()
    local sc = ag:CreateAnimation("Scale")
    setScaleAnim(sc, 1, 1.45)
    sc:SetDuration(0.32)
    if sc.SetSmoothing then sc:SetSmoothing("OUT") end
    local al = ag:CreateAnimation("Alpha")
    setAlphaAnim(al, 0.9, 0)
    al:SetDuration(0.32)
    ag:SetScript("OnFinished", function() t:SetAlpha(0) end)
    t.anim = ag
    return t
end

function W.FadeIn(frame, duration)
    if not frame.ftFade then
        local ag = frame:CreateAnimationGroup()
        local a = ag:CreateAnimation("Alpha")
        setAlphaAnim(a, 0, 1)
        a:SetDuration(duration or 0.15)
        if a.SetSmoothing then a:SetSmoothing("OUT") end
        frame.ftFade = ag
    end
    frame.ftFade:Stop()
    frame.ftFade:Play()
end

-- Basic drawing -------------------------------------------------------------------
function W.Tex(parent, layer, file, r, g, b, a, sub)
    local t = parent:CreateTexture(nil, layer or "ARTWORK", nil, sub or 0)
    if file then t:SetTexture(file) end
    if r then t:SetVertexColor(r, g, b, a or 1) end
    return t
end

function W.Color(parent, layer, r, g, b, a, sub)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sub or 0)
    t:SetColorTexture(r, g, b, a or 1)
    return t
end

function W.Font(parent, size, r, g, b, flags, layer)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY")
    fs:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", size or 14, flags or "")
    fs:SetTextColor(r or C.text[1], g or C.text[2], b or C.text[3])
    if flags ~= "OUTLINE" and flags ~= "THICKOUTLINE" then
        fs:SetShadowColor(0, 0, 0, 0.85)
        fs:SetShadowOffset(1, -1)
    end
    return fs
end

-- A round button face: shadow, plate, masked icon, rim, glow, press flash, ripple.
-- `button` can be any Button (secure or not); visuals never touch protected state.
function W.DecorateRound(button, size, opts)
    opts = opts or {}
    button:SetSize(size, size)
    local hit = math.floor(size * 0.08)
    if button.SetHitRectInsets then button:SetHitRectInsets(-hit, -hit, -hit, -hit) end

    local shadow = W.Tex(button, "BACKGROUND", M .. "soft", 0, 0, 0, 0.55, -2)
    shadow:SetSize(size * 1.35, size * 1.35)
    shadow:SetPoint("CENTER", 0, -size * 0.05)

    local plate = W.Tex(button, "BACKGROUND", M .. "circle", 0.08, 0.09, 0.12, 0.92, 0)
    plate:SetAllPoints()
    button.plate = plate

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", size * 0.07, -size * 0.07)
    icon:SetPoint("BOTTOMRIGHT", -size * 0.07, size * 0.07)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    if button.CreateMaskTexture then
        local mask = button:CreateMaskTexture()
        mask:SetTexture(M .. "circle", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(icon)
        icon:AddMaskTexture(mask)
        button.iconMask = mask
    end
    button.icon = icon

    local label = W.Font(button, opts.glyphSize or math.floor(size * 0.36), 1, 1, 1, "OUTLINE", "ARTWORK")
    label:SetPoint("CENTER", 0, 1)
    button.glyph = label

    local rim = W.Tex(button, "OVERLAY", M .. "ring", 1, 1, 1, 0.22, 0)
    rim:SetAllPoints()
    button.rim = rim

    local glow = W.Tex(button, "OVERLAY", M .. "glow", C.gold[1], C.gold[2], C.gold[3], 0.95, 1)
    glow:SetSize(size * 1.5, size * 1.5)
    glow:SetPoint("CENTER")
    glow:SetBlendMode("ADD")
    glow:Hide()
    button.glow = glow

    local flash = W.Tex(button, "OVERLAY", M .. "circle", 1, 1, 1, 0, 2)
    flash:SetAllPoints()
    flash:SetBlendMode("ADD")
    button.flash = flash

    button.ripple = W.Ripple(button, M .. "thinring", size)

    -- Press feedback: the face sinks and brightens while a finger is down.
    -- (Only texture properties change here, never anchors, so this stays safe
    -- on secure buttons during combat.)
    button:HookScript("OnMouseDown", function(self)
        self.flash:SetAlpha(0.18)
        self.icon:SetTexCoord(0.14, 0.86, 0.14, 0.86)
    end)
    button:HookScript("OnMouseUp", function(self)
        self.flash:SetAlpha(0)
        self.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        self.ripple.anim:Stop()
        self.ripple.anim:Play()
    end)
    button:HookScript("OnHide", function(self)
        self.flash:SetAlpha(0)
    end)
    return button
end

-- Panels --------------------------------------------------------------------------
function W.Panel(name, parent, width, height, title, template)
    local f = CreateFrame("Frame", name, parent or UIParent, template)
    f:SetSize(width, height)
    f:SetFrameStrata("DIALOG")
    f:EnableMouse(true)
    f:SetClampedToScreen(true)

    local bg = W.Color(f, "BACKGROUND", C.panel[1], C.panel[2], C.panel[3], C.panel[4])
    bg:SetAllPoints()
    -- 1px hairline border
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local line = W.Color(f, "BORDER", C.line[1], C.line[2], C.line[3], C.line[4])
        if side == "TOP" or side == "BOTTOM" then
            line:SetHeight(1)
            line:SetPoint(side .. "LEFT")
            line:SetPoint(side .. "RIGHT")
        else
            line:SetWidth(1)
            line:SetPoint("TOP" .. side)
            line:SetPoint("BOTTOM" .. side)
        end
    end
    local accent = W.Color(f, "BORDER", C.accent[1], C.accent[2], C.accent[3], 1, 1)
    accent:SetHeight(3)
    accent:SetPoint("TOPLEFT")
    accent:SetPoint("TOPRIGHT")

    if title then
        f.title = W.Font(f, 20, nil, nil, nil, nil)
        f.title:SetPoint("TOPLEFT", 22, -20)
        f.title:SetText(title)
    end
    f:HookScript("OnShow", function(self) W.FadeIn(self, 0.14) end)
    return f
end

-- Fits a panel on screen: never larger than 92% of the UI in either axis.
function W.FitToScreen(f, maxScale)
    local W_, H = UIParent:GetWidth(), UIParent:GetHeight()
    local s = math.min(maxScale or 1.15, (W_ * 0.94) / f:GetWidth(), (H * 0.92) / f:GetHeight())
    f:SetScale(s)
end

-- Flat touch button ---------------------------------------------------------------
function W.Button(parent, width, height, text, onClick, style)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width, height)
    local primary = style == "primary"
    local bg = W.Color(b, "BACKGROUND",
        primary and C.accent[1] or C.panelLight[1],
        primary and C.accent[2] or C.panelLight[2],
        primary and C.accent[3] or C.panelLight[3], 1)
    bg:SetAllPoints()
    b.bg = bg
    local hl = W.Color(b, "HIGHLIGHT", 1, 1, 1, 0.08)
    hl:SetAllPoints()
    local press = W.Color(b, "ARTWORK", 1, 1, 1, 0)
    press:SetAllPoints()
    b.text = W.Font(b, 15)
    b.text:SetPoint("CENTER")
    b.text:SetText(text or "")
    b:SetScript("OnMouseDown", function() press:SetAlpha(0.12) end)
    b:SetScript("OnMouseUp", function() press:SetAlpha(0) end)
    b:SetScript("OnClick", function(self, ...) if onClick then onClick(self, ...) end end)
    function b:SetLabel(t) self.text:SetText(t) end
    function b:SetSelected(on)
        if on then
            self.bg:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
        elseif primary then
            self.bg:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
        else
            self.bg:SetColorTexture(C.panelLight[1], C.panelLight[2], C.panelLight[3], 1)
        end
    end
    return b
end

-- A row of mutually exclusive choices: options = { {value=, label=}, ... }
function W.Segmented(parent, width, height, options, getter, setter)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(width, height)
    f.buttons = {}
    local gap = 6
    local bw = (width - gap * (#options - 1)) / #options
    local function refresh()
        local current = getter()
        for _, b in ipairs(f.buttons) do b:SetSelected(b.value == current) end
    end
    for i, opt in ipairs(options) do
        local b = W.Button(f, bw, height, opt.label, function(self)
            setter(self.value)
            refresh()
        end)
        b.value = opt.value
        b:SetPoint("LEFT", (i - 1) * (bw + gap), 0)
        f.buttons[i] = b
    end
    f.Refresh = refresh
    f:SetScript("OnShow", refresh)
    refresh()
    return f
end

-- Pill switch with a label to its left.
function W.Toggle(parent, width, label, sublabel, getter, setter)
    local f = CreateFrame("Button", nil, parent)
    f:SetSize(width, sublabel and 54 or 44)
    f.label = W.Font(f, 15)
    f.label:SetPoint("TOPLEFT", 0, sublabel and -8 or -14)
    f.label:SetText(label)
    if sublabel then
        f.sub = W.Font(f, 12, C.muted[1], C.muted[2], C.muted[3])
        f.sub:SetPoint("TOPLEFT", f.label, "BOTTOMLEFT", 0, -4)
        f.sub:SetPoint("RIGHT", -80, 0)
        f.sub:SetJustifyH("LEFT")
        f.sub:SetText(sublabel)
    end
    local track = CreateFrame("Frame", nil, f)
    track:SetSize(58, 32)
    track:SetPoint("RIGHT")
    local trackBg = W.Tex(track, "BACKGROUND", M .. "circle", 1, 1, 1, 1)
    -- a pill made of two circles and a bar
    trackBg:SetSize(32, 32)
    trackBg:SetPoint("LEFT")
    local trackBg2 = W.Tex(track, "BACKGROUND", M .. "circle", 1, 1, 1, 1)
    trackBg2:SetSize(32, 32)
    trackBg2:SetPoint("RIGHT")
    local bar = W.Color(track, "BACKGROUND", 1, 1, 1, 1)
    bar:SetPoint("TOPLEFT", 16, 0)
    bar:SetPoint("BOTTOMRIGHT", -16, 0)
    local knob = W.Tex(track, "ARTWORK", M .. "circle", 1, 1, 1, 1)
    knob:SetSize(26, 26)
    local function paint(on)
        local r, g, b = 0.25, 0.26, 0.32
        if on then r, g, b = C.accent[1], C.accent[2], C.accent[3] end
        trackBg:SetVertexColor(r, g, b)
        trackBg2:SetVertexColor(r, g, b)
        bar:SetColorTexture(r, g, b, 1)
        knob:ClearAllPoints()
        if on then knob:SetPoint("RIGHT", -3, 0) else knob:SetPoint("LEFT", 3, 0) end
    end
    f.Refresh = function() paint(getter() and true or false) end
    f:SetScript("OnClick", function()
        setter(not getter())
        f.Refresh()
    end)
    f:SetScript("OnShow", f.Refresh)
    f.Refresh()
    return f
end

-- [-] value [+] stepper. format(value) returns display text.
function W.Stepper(parent, width, label, getter, setter, minV, maxV, step, format)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(width, 44)
    f.label = W.Font(f, 15)
    f.label:SetPoint("LEFT")
    f.label:SetText(label)
    local value = W.Font(f, 15, C.gold[1], C.gold[2], C.gold[3])
    local function show() value:SetText(format and format(getter()) or tostring(getter())) end
    local function change(delta)
        local v = getter() + delta
        v = math.max(minV, math.min(maxV, math.floor(v / step + 0.5) * step))
        setter(v)
        show()
    end
    local plus = W.Button(f, 44, 40, "+", function() change(step) end)
    plus:SetPoint("RIGHT")
    value:SetPoint("RIGHT", plus, "LEFT", -10, 0)
    value:SetWidth(60)
    value:SetJustifyH("CENTER")
    local minus = W.Button(f, 44, 40, "-", function() change(-step) end)
    minus:SetPoint("RIGHT", value, "LEFT", -10, 0)
    f.Refresh = show
    f:SetScript("OnShow", show)
    show()
    return f
end

-- Close "X" button for panels.
function W.CloseButton(parent, onClick)
    local b = W.Button(parent, 44, 44, "X", onClick or function() parent:Hide() end)
    b:SetPoint("TOPRIGHT", -10, -10)
    return b
end
