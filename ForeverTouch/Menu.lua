-- Menu: one round button that opens a big grid of tiles for every game window.
-- Opening, closing and the window toggles all run through secure code, so the
-- menu also works in combat.

local _, ns = ...
local W = ns.W
local C = ns.color

local TILE, GAP, COLS = 104, 12, 4

-- Game menu: ToggleGameMenu closes other windows first (Escape semantics), so
-- fall back to showing the frame directly, and say so if nothing worked.
local function toggleGameMenu()
    local f = GameMenuFrame
    if f and f:IsShown() then
        if HideUIPanel then HideUIPanel(f) else f:Hide() end
        return
    end
    if ToggleGameMenu then pcall(ToggleGameMenu) end
    if f and not f:IsShown() and ShowUIPanel then pcall(ShowUIPanel, f) end
    if not f or not f:IsShown() then
        ns.Print("Couldn't open the game menu - press Escape on DroidDeck's keyboard.")
    end
end

-- { label, icon, micro buttons to click (first that exists), Lua fallback,
--   windows the tile should toggle (used to detect a micro click that did nothing) }
local TILES = {
    { "Character", "Interface\\Icons\\INV_Chest_Cloth_17", { "CharacterMicroButton" },
        function() ToggleCharacter("PaperDollFrame") end, { "CharacterFrame" } },
    { "Bags", "Interface\\Icons\\INV_Misc_Bag_08", nil,
        function() ToggleAllBags() end },
    { "Spellbook", "Interface\\Icons\\INV_Misc_Book_09", { "SpellbookMicroButton", "PlayerSpellsMicroButton" },
        function() if ToggleSpellBook then ToggleSpellBook(BOOKTYPE_SPELL or "spell") end end,
        { "SpellBookFrame", "PlayerSpellsFrame" } },
    { "Talents", "Interface\\Icons\\Ability_Marksmanship", { "TalentMicroButton", "PlayerSpellsMicroButton" },
        function() if ToggleTalentFrame then ToggleTalentFrame() end end,
        { "TalentFrame", "PlayerTalentFrame", "PlayerSpellsFrame" } },
    { "Quests", "Interface\\Icons\\INV_Misc_Note_01", { "QuestLogMicroButton" },
        function() if ToggleQuestLog then ToggleQuestLog() end end, { "QuestLogFrame", "QuestMapFrame" } },
    { "Map", "Interface\\Icons\\INV_Misc_Map_01", { "WorldMapMicroButton" },
        function() if ToggleWorldMap then ToggleWorldMap() end end, { "WorldMapFrame" } },
    { "Social", "Interface\\Icons\\INV_Letter_02", { "SocialsMicroButton" },
        function() if ToggleFriendsFrame then ToggleFriendsFrame() end end, { "FriendsFrame" } },
    { "Chat", "Interface\\Icons\\INV_Scroll_03", nil,
        function()
            if ChatFrame_OpenChat then ChatFrame_OpenChat("") end
            ns.Print("Chat open - bring up DroidDeck's keyboard to type.")
        end },
    { "Close windows", "Interface\\Icons\\Spell_Shadow_SacrificialShield", nil,
        function() if CloseAllWindows then CloseAllWindows() end end },
    { "Edit layout", "Interface\\Icons\\INV_Misc_Wrench_01", nil,
        function() ns.EnterEditMode() end },
    { "Touch settings", "Interface\\Icons\\INV_Misc_Gear_01", nil,
        function() ns.ShowSettings() end },
    { "Game menu", "Interface\\Icons\\INV_Misc_QuestionMark", { "MainMenuMicroButton" },
        toggleGameMenu, { "GameMenuFrame" } },
}

local TOGGLE_ONCLICK = [[
    local panel = self:GetFrameRef("panel")
    if panel:IsShown() then panel:Hide() else panel:Show() end
]]
local CLOSE_ONCLICK = [[ self:GetParent():Hide() ]]
-- Close on release only: with dual click registration the press may be the
-- click that acts, and the menu must still be open for it.
local TILE_PRE = [[ if not down then return button, true end ]]
local TILE_POST = [[ self:GetParent():Hide() ]]
ns.snippets.MENU_TOGGLE = TOGGLE_ONCLICK
ns.snippets.MENU_CLOSE = CLOSE_ONCLICK
ns.snippets.MENU_TILE_PRE = TILE_PRE
ns.snippets.MENU_TILE_POST = TILE_POST

-- Only micro buttons that act in OnClick can be clicked from code; some (the
-- Game menu one in Classic-style UIs) act in OnMouseUp, so a secure click
-- would do nothing.
local function findMicro(names)
    if not names then return nil end
    for _, n in ipairs(names) do
        local b = _G[n]
        if b and b.GetScript and b:GetScript("OnClick") then return b end
    end
end

local function windowsShown(names)
    local state = {}
    for i, n in ipairs(names or {}) do
        local f = _G[n]
        state[i] = (f and f.IsShown and f:IsShown()) and true or false
    end
    return state
end

local function runTile(def)
    local ok, err = pcall(def[4])
    if not ok then
        ns.Print("%s didn't open: %s", def[1], tostring(err))
    end
end

local function createTile(panel, i, def)
    local tile = CreateFrame("Button", "ForeverTouchMenuTile" .. i, panel, "SecureActionButtonTemplate")
    tile:SetSize(TILE, TILE)
    if ns.dualClick then tile:RegisterForClicks("AnyUp", "AnyDown") else tile:RegisterForClicks("AnyUp") end
    local micro = findMicro(def[3])
    if micro then
        tile:SetAttribute("type", "click")
        tile:SetAttribute("clickbutton", micro)
    end

    W.RoundRect(tile, "BACKGROUND", 16, 1, 1, 1, 0.07, 0)
    W.RoundRect(tile, "BACKGROUND", 15, C.panelLight[1], C.panelLight[2], C.panelLight[3], 1, 1, 1)
    local press = W.RoundRect(tile, "ARTWORK", 16, 1, 1, 1, 0, 2)

    local iconShadow = W.Tex(tile, "BORDER", ns.media .. "soft", 0, 0, 0, 0.55)
    iconShadow:SetSize(74, 74)
    iconShadow:SetPoint("TOP", 0, -6)
    local icon = tile:CreateTexture(nil, "ARTWORK")
    icon:SetSize(52, 52)
    icon:SetPoint("TOP", 0, -14)
    icon:SetTexture(def[2])
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    W.MaskIcon(icon, tile)

    local label = W.Font(tile, 13)
    label:SetPoint("BOTTOM", 0, 11)
    label:SetPoint("LEFT", 4, 0)
    label:SetPoint("RIGHT", -4, 0)
    label:SetJustifyH("CENTER")
    label:SetText(def[1])

    tile:HookScript("OnMouseDown", function() press:SetColor(1, 1, 1, 0.12) end)
    tile:HookScript("OnMouseUp", function() press:SetColor(1, 1, 1, 0) end)

    if not micro then
        tile:HookScript("PostClick", function(_, _, down)
            if down then return end
            -- Next frame, after the secure wrapper has closed the menu.
            C_Timer.After(0, function() runTile(def) end)
        end)
    elseif def[5] then
        -- Self-check: if Blizzard's button didn't toggle its window, do it ourselves.
        local before
        tile:HookScript("PreClick", function(_, _, down)
            if (down and true or false) == ns.useKeyDownNow() then before = windowsShown(def[5]) end
        end)
        tile:HookScript("PostClick", function(_, _, down)
            if not before then return end
            local snapshot = before
            before = nil
            C_Timer.After(0, function()
                local after = windowsShown(def[5])
                for i = 1, #after do
                    if after[i] ~= snapshot[i] then return end
                end
                runTile(def)
            end)
        end)
    end

    -- Close the menu after any tile. Secure wrapper so it also works in combat;
    -- fall back to an out-of-combat close if the wrapper is unavailable.
    local wrapped = SecureHandlerWrapScript and pcall(SecureHandlerWrapScript, tile, "OnClick", panel, TILE_PRE, TILE_POST)
    if not wrapped then
        tile:HookScript("PostClick", function(_, _, down)
            if not down and not InCombatLockdown() then panel:Hide() end
        end)
    end
    return tile
end

local function createMenu()
    local rows = math.ceil(#TILES / COLS)
    local width = COLS * TILE + (COLS - 1) * GAP + 48
    local height = rows * TILE + (rows - 1) * GAP + 100

    local panel = W.Panel("ForeverTouchMenu", UIParent, width, height, "Menu", "SecureHandlerBaseTemplate")
    panel:SetPoint("CENTER")
    panel:SetFrameStrata("DIALOG")
    panel:SetFrameLevel(20)
    panel:Hide()

    -- Dimmed backdrop; tapping anywhere outside the grid closes the menu.
    local catcher = CreateFrame("Button", "ForeverTouchMenuCatcher", panel, "SecureHandlerClickTemplate")
    catcher:SetAllPoints(UIParent)
    catcher:SetFrameLevel(5)
    catcher:RegisterForClicks("AnyUp")
    catcher:SetAttribute("_onclick", CLOSE_ONCLICK)
    local dim = W.Color(catcher, "BACKGROUND", 0, 0, 0, 0.5)
    dim:SetAllPoints()

    local close = CreateFrame("Button", "ForeverTouchMenuClose", panel, "SecureHandlerClickTemplate")
    close:SetSize(40, 40)
    close:SetPoint("TOPRIGHT", -14, -14)
    close:RegisterForClicks("AnyUp")
    close:SetAttribute("_onclick", CLOSE_ONCLICK)
    local cbg = W.Tex(close, "BACKGROUND", ns.media .. "circle", C.panelLight[1], C.panelLight[2], C.panelLight[3], 1)
    cbg:SetAllPoints()
    local cx = W.Font(close, 16, C.muted[1], C.muted[2], C.muted[3])
    cx:SetPoint("CENTER", 0, 1)
    cx:SetText("X")

    for i, def in ipairs(TILES) do
        local tile = createTile(panel, i, def)
        local col = (i - 1) % COLS
        local row = math.floor((i - 1) / COLS)
        tile:SetPoint("TOPLEFT", 24 + col * (TILE + GAP), -76 - row * (TILE + GAP))
    end

    panel:HookScript("OnShow", function(self)
        if not InCombatLockdown() then W.FitToScreen(self, 1.2) end
    end)

    -- The always-visible round menu button.
    local toggle = CreateFrame("Button", "ForeverTouchMenuButton", UIParent, "SecureHandlerClickTemplate")
    W.DecorateRound(toggle, 58)
    toggle.icon:Hide()
    toggle.plate:SetVertexColor(C.accent[1] * 0.6, C.accent[2] * 0.6, C.accent[3] * 0.6, 0.95)
    for k = -1, 1 do
        local bar = W.Color(toggle, "ARTWORK", 1, 1, 1, 0.95, 1)
        bar:SetSize(24, 3)
        bar:SetPoint("CENTER", 0, k * 8)
    end
    toggle:SetFrameStrata("MEDIUM")
    toggle:RegisterForClicks("AnyUp")
    toggle:SetFrameRef("panel", panel)
    toggle:SetAttribute("_onclick", TOGGLE_ONCLICK)

    ns.menuPanel = panel
    ns.RegisterGroup("menu", toggle, "Menu button")
end

ns.OnInit(createMenu)
