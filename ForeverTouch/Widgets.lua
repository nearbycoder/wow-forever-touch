-- Widgets: the Forever Touch look - round touch buttons, rounded panels with soft
-- shadows, pill switches, steppers, cards and toasts, all sized for fingers.

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

-- Rounded rectangles --------------------------------------------------------------
-- Four quarter-circle corners (quadrants of circle.tga) plus three solid strips.
-- The pieces never overlap, so translucent fills stay even.
local QUADS = {
    TOPLEFT = { 0, 0.5, 0, 0.5 }, TOPRIGHT = { 0.5, 1, 0, 0.5 },
    BOTTOMLEFT = { 0, 0.5, 0.5, 1 }, BOTTOMRIGHT = { 0.5, 1, 0.5, 1 },
}
local CORNER_OFFSET = { TOPLEFT = { 1, -1 }, TOPRIGHT = { -1, -1 }, BOTTOMLEFT = { 1, 1 }, BOTTOMRIGHT = { -1, 1 } }

function W.RoundRect(parent, layer, radius, r, g, b, a, sub, inset)
    local rr = { parts = {} }
    local i = inset or 0
    local function piece(isCorner)
        local t = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sub or 0)
        t.isCorner = isCorner
        table.insert(rr.parts, t)
        return t
    end
    for corner, tc in pairs(QUADS) do
        local t = piece(true)
        t:SetTexture(M .. "circle")
        t:SetTexCoord(tc[1], tc[2], tc[3], tc[4])
        t:SetSize(radius, radius)
        local o = CORNER_OFFSET[corner]
        t:SetPoint(corner, o[1] * i, o[2] * i)
    end
    local top = piece(false)
    top:SetPoint("TOPLEFT", i + radius, -i)
    top:SetPoint("BOTTOMRIGHT", parent, "TOPRIGHT", -i - radius, -i - radius)
    local bottom = piece(false)
    bottom:SetPoint("BOTTOMLEFT", i + radius, i)
    bottom:SetPoint("TOPRIGHT", parent, "BOTTOMRIGHT", -i - radius, i + radius)
    local mid = piece(false)
    mid:SetPoint("TOPLEFT", i, -i - radius)
    mid:SetPoint("BOTTOMRIGHT", -i, i + radius)

    function rr:SetColor(cr, cg, cb, ca)
        for _, t in ipairs(self.parts) do
            if t.isCorner then t:SetVertexColor(cr, cg, cb, ca or 1) else t:SetColorTexture(cr, cg, cb, ca or 1) end
        end
    end
    function rr:SetShown(v) for _, t in ipairs(self.parts) do t:SetShown(v) end end
    function rr:Show() self:SetShown(true) end
    function rr:Hide() self:SetShown(false) end
    rr:SetColor(r, g, b, a)
    return rr
end

-- Soft drop shadow around a frame (drawn on the frame, below its background).
function W.Shadow(frame, spread, alpha, drop)
    spread = spread or 20
    drop = drop or 4
    local soft = M .. "soft"
    local a = alpha or 0.5
    local function piece()
        local t = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
        t:SetTexture(soft)
        t:SetVertexColor(0, 0, 0, a)
        return t
    end
    for corner, tc in pairs(QUADS) do
        local t = piece()
        t:SetTexCoord(tc[1], tc[2], tc[3], tc[4])
        t:SetSize(spread * 2, spread * 2)
        local o = CORNER_OFFSET[corner]
        t:SetPoint(corner, -o[1] * spread, -o[2] * spread - drop)
    end
    -- edges: a thin slice through the middle of soft.tga fades outwards
    local top = piece()
    top:SetTexCoord(0.49, 0.51, 0, 0.5)
    top:SetPoint("TOPLEFT", spread, spread - drop)
    top:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", -spread, -spread - drop)
    local bottom = piece()
    bottom:SetTexCoord(0.49, 0.51, 0.5, 1)
    bottom:SetPoint("BOTTOMLEFT", spread, -spread - drop)
    bottom:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", -spread, spread - drop)
    local left = piece()
    left:SetTexCoord(0, 0.5, 0.49, 0.51)
    left:SetPoint("TOPLEFT", -spread, -spread - drop)
    left:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", spread, spread - drop)
    local right = piece()
    right:SetTexCoord(0.5, 1, 0.49, 0.51)
    right:SetPoint("TOPRIGHT", spread, -spread - drop)
    right:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT", -spread, spread - drop)
end

-- Rounded-square mask for icons (menu tiles, picker cells).
function W.MaskIcon(icon, owner)
    if not owner.CreateMaskTexture then return end
    local mask = owner:CreateMaskTexture()
    mask:SetTexture(M .. "roundsquare", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(icon)
    icon:AddMaskTexture(mask)
end

-- Panels --------------------------------------------------------------------------
function W.Panel(name, parent, width, height, title, template)
    local f = CreateFrame("Frame", name, parent or UIParent, template)
    f:SetSize(width, height)
    f:SetFrameStrata("DIALOG")
    f:EnableMouse(true)
    f:SetClampedToScreen(true)

    W.Shadow(f, 26, 0.6, 6)
    f.edge = W.RoundRect(f, "BACKGROUND", 18, 1, 1, 1, 0.10, -6)
    f.bg = W.RoundRect(f, "BACKGROUND", 17, C.panel[1], C.panel[2], C.panel[3], 0.97, -5, 1)

    if title then
        -- small accent pill above the title
        local host = CreateFrame("Frame", nil, f)
        host:SetSize(30, 4)
        host:SetPoint("TOPLEFT", 24, -16)
        W.RoundRect(host, "ARTWORK", 2, C.accent[1], C.accent[2], C.accent[3], 1)
        f.title = W.Font(f, 21)
        f.title:SetPoint("TOPLEFT", 24, -28)
        f.title:SetText(title)
    end
    f:HookScript("OnShow", function(self) W.FadeIn(self, 0.16) end)
    return f
end

-- Fits a panel on screen: never larger than 94% x 92% of the UI.
function W.FitToScreen(f, maxScale)
    local W_, H = UIParent:GetWidth(), UIParent:GetHeight()
    local s = math.min(maxScale or 1.15, (W_ * 0.94) / f:GetWidth(), (H * 0.92) / f:GetHeight())
    f:SetScale(s)
end

-- Cards group related settings inside a panel.
function W.Card(parent, width, height, title)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(width, height)
    W.RoundRect(f, "BACKGROUND", 14, 1, 1, 1, 0.045, 1)
    if title then
        f.heading = W.SectionTitle(f, title)
        f.heading:SetPoint("TOPLEFT", 16, -14)
    end
    return f
end

function W.SectionTitle(parent, text)
    local fs = W.Font(parent, 12, C.accentSoft[1], C.accentSoft[2], C.accentSoft[3])
    fs:SetText(string.upper(text))
    return fs
end

function W.Divider(parent, anchor, y)
    local line = W.Color(parent, "ARTWORK", 1, 1, 1, 0.06)
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, y or 0)
    line:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
    return line
end

-- Buttons ----------------------------------------------------------------------------
-- style: nil/"secondary" (dark), "primary" (accent), "ghost" (no fill).
-- No hover highlight: on a touch screen the cursor stays where you tapped, so a
-- hover state would stick. Feedback is a press tint instead.
local STYLES = {
    primary = { fill = { C.accent[1], C.accent[2], C.accent[3], 1 }, edge = { 1, 1, 1, 0.14 } },
    secondary = { fill = { C.panelLight[1], C.panelLight[2], C.panelLight[3], 1 }, edge = { 1, 1, 1, 0.08 } },
    ghost = { fill = { 0, 0, 0, 0 }, edge = { 1, 1, 1, 0.10 } },
    selected = { fill = { C.accent[1], C.accent[2], C.accent[3], 1 }, edge = { 1, 1, 1, 0.16 } },
}

function W.Button(parent, width, height, text, onClick, style)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width, height)
    local radius = math.min(11, math.floor(height / 2))
    b.style = style or "secondary"
    b.edgeRR = W.RoundRect(b, "BACKGROUND", radius, 1, 1, 1, 0.08, 0)
    b.fillRR = W.RoundRect(b, "BACKGROUND", radius, 0, 0, 0, 1, 1, 1)
    b.pressRR = W.RoundRect(b, "ARTWORK", radius, 1, 1, 1, 0, 2)
    b.text = W.Font(b, 15)
    b.text:SetPoint("LEFT", 8, 0)
    b.text:SetPoint("RIGHT", -8, 0)
    b.text:SetJustifyH("CENTER")
    b.text:SetText(text or "")

    local function paint(self, key)
        local st = STYLES[key] or STYLES.secondary
        self.fillRR:SetColor(st.fill[1], st.fill[2], st.fill[3], st.fill[4])
        self.edgeRR:SetColor(st.edge[1], st.edge[2], st.edge[3], st.edge[4])
    end
    b.Paint = paint
    paint(b, b.style)

    b:SetScript("OnMouseDown", function(self)
        if self.disabled then return end
        self.pressRR:SetColor(1, 1, 1, 0.14)
    end)
    b:SetScript("OnMouseUp", function(self) self.pressRR:SetColor(1, 1, 1, 0) end)
    b:SetScript("OnClick", function(self, ...)
        if self.disabled then return end
        if onClick then onClick(self, ...) end
    end)
    function b:SetLabel(t) self.text:SetText(t) end
    function b:SetSelected(on)
        self:Paint(on and "selected" or self.style)
        self.text:SetTextColor(1, 1, 1)
    end
    function b:SetDisabledLook(off)
        self.disabled = off and true or nil
        self:SetAlpha(off and 0.4 or 1)
    end
    return b
end

-- Pill-shaped segmented control: options = { {value=, label=}, ... }
function W.Segmented(parent, width, height, options, getter, setter)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(width, height)
    W.RoundRect(f, "BACKGROUND", math.min(12, height / 2), C.panelLight[1], C.panelLight[2], C.panelLight[3], 1)
    f.buttons = {}
    local pad = 3
    local bw = (width - pad * 2) / #options
    local function refresh()
        local current = getter()
        for _, b in ipairs(f.buttons) do
            local on = (b.value == current)
            b.chip:SetShown(on)
            if on then b.text:SetTextColor(1, 1, 1) else b.text:SetTextColor(C.muted[1], C.muted[2], C.muted[3]) end
        end
    end
    for i, opt in ipairs(options) do
        local b = CreateFrame("Button", nil, f)
        b:SetSize(bw, height - pad * 2)
        b:SetPoint("LEFT", pad + (i - 1) * bw, 0)
        b.chip = W.RoundRect(b, "BACKGROUND", math.min(10, (height - pad * 2) / 2), C.accent[1], C.accent[2], C.accent[3], 1, 1)
        b.press = W.RoundRect(b, "ARTWORK", math.min(10, (height - pad * 2) / 2), 1, 1, 1, 0, 1)
        b.text = W.Font(b, 14)
        b.text:SetPoint("LEFT", 4, 0)
        b.text:SetPoint("RIGHT", -4, 0)
        b.text:SetJustifyH("CENTER")
        b.text:SetText(opt.label)
        b.value = opt.value
        b:SetScript("OnMouseDown", function(self) self.press:SetColor(1, 1, 1, 0.08) end)
        b:SetScript("OnMouseUp", function(self) self.press:SetColor(1, 1, 1, 0) end)
        b:SetScript("OnClick", function(self)
            setter(self.value)
            refresh()
        end)
        function b:SetSelected(on) self.chip:SetShown(on) end
        f.buttons[i] = b
    end
    f.Refresh = refresh
    f:SetScript("OnShow", refresh)
    refresh()
    return f
end

-- A settings row: label (and optional explanation) on the left, a pill switch on the right.
function W.Toggle(parent, width, label, sublabel, getter, setter)
    local f = CreateFrame("Button", nil, parent)
    f:SetSize(width, sublabel and 56 or 44)
    f.label = W.Font(f, 15)
    f.label:SetPoint("TOPLEFT", 0, sublabel and -9 or -14)
    f.label:SetPoint("RIGHT", -76, 0)
    f.label:SetJustifyH("LEFT")
    f.label:SetText(label)
    if sublabel then
        f.sub = W.Font(f, 12, C.muted[1], C.muted[2], C.muted[3])
        f.sub:SetPoint("TOPLEFT", f.label, "BOTTOMLEFT", 0, -4)
        f.sub:SetPoint("RIGHT", -76, 0)
        f.sub:SetJustifyH("LEFT")
        f.sub:SetText(sublabel)
    end
    local track = CreateFrame("Frame", nil, f)
    track:SetSize(56, 32)
    track:SetPoint("RIGHT")
    local trackRR = W.RoundRect(track, "BACKGROUND", 16, 0.25, 0.26, 0.32, 1)
    local knobShadow = W.Tex(track, "ARTWORK", M .. "soft", 0, 0, 0, 0.5)
    knobShadow:SetSize(38, 38)
    local knob = W.Tex(track, "ARTWORK", M .. "circle", 1, 1, 1, 1, 1)
    knob:SetSize(26, 26)
    local function paint(on)
        if on then trackRR:SetColor(C.accent[1], C.accent[2], C.accent[3], 1)
        else trackRR:SetColor(0.25, 0.26, 0.32, 1) end
        knob:ClearAllPoints()
        knobShadow:ClearAllPoints()
        if on then knob:SetPoint("RIGHT", -3, 0) else knob:SetPoint("LEFT", 3, 0) end
        knobShadow:SetPoint("CENTER", knob, "CENTER", 0, -1)
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

-- Label on the left, a [-  value  +] pill on the right.
function W.Stepper(parent, width, label, getter, setter, minV, maxV, step, format)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(width, 44)
    f.label = W.Font(f, 15)
    f.label:SetPoint("LEFT")
    f.label:SetText(label)

    local pill = CreateFrame("Frame", nil, f)
    pill:SetSize(156, 40)
    pill:SetPoint("RIGHT")
    W.RoundRect(pill, "BACKGROUND", 20, C.panelLight[1], C.panelLight[2], C.panelLight[3], 1)
    local value = W.Font(pill, 15, C.gold[1], C.gold[2], C.gold[3])
    value:SetPoint("CENTER")

    local function show() value:SetText(format and format(getter()) or tostring(getter())) end
    local function change(delta)
        local v = getter() + delta
        v = math.max(minV, math.min(maxV, math.floor(v / step + 0.5) * step))
        setter(v)
        show()
    end
    local function roundBtn(glyph, point, delta)
        local b = CreateFrame("Button", nil, f)
        b:SetSize(36, 36)
        b:SetPoint(point, pill, point, point == "LEFT" and 2 or -2, 0)
        b:SetFrameLevel(pill:GetFrameLevel() + 2)
        local bg = W.Tex(b, "BACKGROUND", M .. "circle", 1, 1, 1, 0.08)
        bg:SetAllPoints()
        b.text = W.Font(b, 20)
        b.text:SetPoint("CENTER", 0, 1)
        b.text:SetText(glyph)
        b:SetScript("OnMouseDown", function() bg:SetVertexColor(1, 1, 1, 0.2) end)
        b:SetScript("OnMouseUp", function() bg:SetVertexColor(1, 1, 1, 0.08) end)
        b:SetScript("OnClick", function() change(delta) end)
        return b
    end
    f.minus = roundBtn("-", "LEFT", -step)
    f.plus = roundBtn("+", "RIGHT", step)
    f.Refresh = show
    f:SetScript("OnShow", show)
    show()
    return f
end

-- Round close button for panels.
function W.CloseButton(parent, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(40, 40)
    b:SetPoint("TOPRIGHT", -14, -14)
    local bg = W.Tex(b, "BACKGROUND", M .. "circle", C.panelLight[1], C.panelLight[2], C.panelLight[3], 1)
    bg:SetAllPoints()
    b.text = W.Font(b, 16, C.muted[1], C.muted[2], C.muted[3])
    b.text:SetPoint("CENTER", 0, 1)
    b.text:SetText("X")
    b:SetScript("OnMouseDown", function() bg:SetVertexColor(0.3, 0.32, 0.4, 1) end)
    b:SetScript("OnMouseUp", function() bg:SetVertexColor(C.panelLight[1], C.panelLight[2], C.panelLight[3], 1) end)
    b:SetScript("OnClick", onClick or function() parent:Hide() end)
    return b
end

-- Toasts: short messages at the top of the screen (also echoed to chat).
local toast
function W.Toast(text, duration)
    if not toast then
        toast = CreateFrame("Frame", "ForeverTouchToast", UIParent)
        toast:SetFrameStrata("TOOLTIP")
        toast:SetSize(300, 46)
        toast:SetPoint("TOP", 0, -84)
        W.Shadow(toast, 16, 0.5, 3)
        W.RoundRect(toast, "BACKGROUND", 23, 0.08, 0.09, 0.13, 0.96)
        local dot = W.Tex(toast, "ARTWORK", M .. "circle", C.accent[1], C.accent[2], C.accent[3], 1)
        dot:SetSize(10, 10)
        dot:SetPoint("LEFT", 20, 0)
        toast.text = W.Font(toast, 15)
        toast.text:SetPoint("LEFT", 40, 0)
        toast:EnableMouse(false)
        toast:Hide()
        toast:SetScript("OnUpdate", function(self, elapsed)
            self.t = self.t + elapsed
            local fadeIn, hold = 0.18, self.hold
            if self.t < fadeIn then
                self:SetAlpha(self.t / fadeIn)
            elseif self.t < fadeIn + hold then
                self:SetAlpha(1)
            elseif self.t < fadeIn + hold + 0.45 then
                self:SetAlpha(1 - (self.t - fadeIn - hold) / 0.45)
            else
                self:Hide()
            end
        end)
    end
    toast.text:SetText(text)
    local w = (toast.text.GetStringWidth and toast.text:GetStringWidth() or 300)
    toast:SetWidth(math.max(220, w + 64))
    toast.t, toast.hold = 0, duration or 2.6
    toast:SetAlpha(0)
    toast:Show()
end
