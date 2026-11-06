-- SpellPicker: tap a touch button, then tap a spell, macro or item to put on it.
-- No dragging required (dragging from the spellbook still works too).

local _, ns = ...
local W = ns.W
local C = ns.color

local COLS, ROWS = 6, 3
local CELL_W, CELL_H, ICON = 96, 98, 50
local PER_PAGE = COLS * ROWS

local BOOK = BOOKTYPE_SPELL or "spell"

-- Spellbook access across client generations -----------------------------------
local function spellTabs()
    local tabs = {}
    if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines then
        for i = 1, C_SpellBook.GetNumSpellBookSkillLines() do
            local info = C_SpellBook.GetSpellBookSkillLineInfo(i)
            if info and not info.shouldHide then
                tabs[#tabs + 1] = { name = info.name, offset = info.itemIndexOffset, count = info.numSpellBookItems }
            end
        end
    elseif GetNumSpellTabs then
        for i = 1, GetNumSpellTabs() do
            local name, _, offset, count = GetSpellTabInfo(i)
            if name then tabs[#tabs + 1] = { name = name, offset = offset, count = count } end
        end
    end
    return tabs
end

local function bookEntry(index)
    if C_SpellBook and C_SpellBook.GetSpellBookItemInfo then
        local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
        local info = C_SpellBook.GetSpellBookItemInfo(index, bank)
        if not info or info.isPassive then return end
        local future = Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.FutureSpell
        if future and info.itemType == future then return end
        return info.name, info.iconID, info.subName
    end
    local kind = GetSpellBookItemInfo(index, BOOK)
    if kind == "FUTURESPELL" or kind == nil then return end
    if IsPassiveSpell and IsPassiveSpell(index, BOOK) then return end
    local name, sub = GetSpellBookItemName(index, BOOK)
    return name, GetSpellBookItemTexture(index, BOOK), sub
end

local function pickupBook(index)
    if C_SpellBook and C_SpellBook.PickupSpellBookItem then
        local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
        C_SpellBook.PickupSpellBookItem(index, bank)
    else
        PickupSpellBookItem(index, BOOK)
    end
end

local function collectSpells(tab)
    local list, byName = {}, {}
    for index = tab.offset + 1, tab.offset + tab.count do
        local name, icon, sub = bookEntry(index)
        if name then
            local entry = { name = name, sub = sub, icon = icon, pickup = function() pickupBook(index) end }
            -- Classic books list every rank; by default only keep the highest.
            if not ns.db.pickerAllRanks and byName[name] then
                list[byName[name]] = entry
            else
                list[#list + 1] = entry
                byName[name] = #list
            end
        end
    end
    return list
end

local function collectMacros()
    local list = {}
    local numGlobal, numChar = GetNumMacros()
    local perAccount = MAX_ACCOUNT_MACROS or 36
    local function add(i)
        local name, icon = GetMacroInfo(i)
        if name then list[#list + 1] = { name = name, icon = icon, pickup = function() PickupMacro(i) end } end
    end
    for i = 1, numGlobal or 0 do add(i) end
    for i = perAccount + 1, perAccount + (numChar or 0) do add(i) end
    return list
end

local function containerSlots(bag)
    if C_Container and C_Container.GetContainerNumSlots then return C_Container.GetContainerNumSlots(bag) end
    return GetContainerNumSlots(bag)
end

local function containerItem(bag, slot)
    if C_Container and C_Container.GetContainerItemInfo then
        local info = C_Container.GetContainerItemInfo(bag, slot)
        if info then return info.itemID, info.iconFileID end
        return
    end
    local icon, _, _, _, _, _, _, _, _, itemID = GetContainerItemInfo(bag, slot)
    return itemID, icon
end

local function pickupContainer(bag, slot)
    if C_Container and C_Container.PickupContainerItem then
        C_Container.PickupContainerItem(bag, slot)
    else
        PickupContainerItem(bag, slot)
    end
end

local function collectItems()
    local list, seen = {}, {}
    local getSpell = (C_Item and C_Item.GetItemSpell) or GetItemSpell
    local getName = (C_Item and C_Item.GetItemNameByID) or GetItemInfo
    for bag = 0, NUM_BAG_SLOTS or 4 do
        for slot = 1, containerSlots(bag) or 0 do
            local itemID, icon = containerItem(bag, slot)
            if itemID and not seen[itemID] and getSpell(itemID) then
                seen[itemID] = true
                list[#list + 1] = {
                    name = getName(itemID) or "Item",
                    icon = icon,
                    pickup = function() pickupContainer(bag, slot) end,
                }
            end
        end
    end
    return list
end

-- Assignment ----------------------------------------------------------------------
function ns.AssignToSlot(slot, pickup)
    if InCombatLockdown() then
        ns.Print("Buttons can't be changed during combat.")
        return false
    end
    ClearCursor()
    pickup()
    PlaceAction(slot)
    ClearCursor() -- drops whatever used to be on the slot
    return true
end

function ns.ClearSlot(slot)
    if InCombatLockdown() then return false end
    ClearCursor()
    PickupAction(slot)
    ClearCursor()
    return true
end

-- UI ------------------------------------------------------------------------------
local picker

local function buildPicker()
    local width = COLS * CELL_W + 48
    local height = ROWS * CELL_H + 236
    local f = W.Panel("ForeverTouchPicker", UIParent, width, height, "Choose an action")
    f:SetPoint("CENTER")
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:Hide()
    W.CloseButton(f)
    table.insert(UISpecialFrames, "ForeverTouchPicker")

    f.subtitle = W.Font(f, 13, C.muted[1], C.muted[2], C.muted[3])
    f.subtitle:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -4)

    -- Tabs row (rebuilt each time it opens, spellbook tabs vary by class)
    f.tabBar = CreateFrame("Frame", nil, f)
    f.tabBar:SetPoint("TOPLEFT", 20, -86)
    f.tabBar:SetPoint("TOPRIGHT", -20, -86)
    f.tabBar:SetHeight(40)
    f.tabButtons = {}

    f.cells = {}
    for i = 1, PER_PAGE do
        local cell = CreateFrame("Button", nil, f)
        cell:SetSize(CELL_W - 8, CELL_H - 8)
        local col = (i - 1) % COLS
        local row = math.floor((i - 1) / COLS)
        cell:SetPoint("TOPLEFT", 24 + col * CELL_W, -140 - row * CELL_H)
        W.RoundRect(cell, "BACKGROUND", 12, 1, 1, 1, 0.04, 0)
        local press = W.RoundRect(cell, "BACKGROUND", 12, C.accent[1], C.accent[2], C.accent[3], 0, 1)
        local shadow = W.Tex(cell, "BORDER", ns.media .. "soft", 0, 0, 0, 0.5)
        shadow:SetSize(ICON + 22, ICON + 22)
        shadow:SetPoint("TOP", 0, 2)
        cell.icon = cell:CreateTexture(nil, "ARTWORK")
        cell.icon:SetSize(ICON, ICON)
        cell.icon:SetPoint("TOP", 0, -8)
        cell.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        W.MaskIcon(cell.icon, cell)
        cell.name = W.Font(cell, 11)
        cell.name:SetPoint("TOP", cell.icon, "BOTTOM", 0, -4)
        cell.name:SetWidth(CELL_W - 10)
        cell.name:SetHeight(28)
        cell.name:SetJustifyV("TOP")
        cell.name:SetJustifyH("CENTER")
        cell:SetScript("OnMouseDown", function() press:SetColor(C.accent[1], C.accent[2], C.accent[3], 0.45) end)
        cell:SetScript("OnMouseUp", function() press:SetColor(C.accent[1], C.accent[2], C.accent[3], 0) end)
        cell:SetScript("OnClick", function(self)
            if not self.entry or not f.slot then return end
            if ns.AssignToSlot(f.slot, self.entry.pickup) then
                f:Hide()
            end
        end)
        f.cells[i] = cell
    end

    f.empty = W.Font(f, 14, C.muted[1], C.muted[2], C.muted[3])
    f.empty:SetPoint("CENTER", 0, 10)

    -- Footer
    f.prev = W.Button(f, 60, 44, "<", function() f:SetPage(f.page - 1) end)
    f.prev:SetPoint("BOTTOMLEFT", 22, 22)
    f.next = W.Button(f, 60, 44, ">", function() f:SetPage(f.page + 1) end)
    f.next:SetPoint("LEFT", f.prev, "RIGHT", 8, 0)
    f.pageText = W.Font(f, 13, C.muted[1], C.muted[2], C.muted[3])
    f.pageText:SetPoint("LEFT", f.next, "RIGHT", 12, 0)

    f.clear = W.Button(f, 150, 44, "Empty this button", function()
        if f.slot and ns.ClearSlot(f.slot) then f:Hide() end
    end)
    f.clear:SetPoint("BOTTOMRIGHT", -22, 22)
    f.ranks = W.Button(f, 120, 44, "", function()
        ns.db.pickerAllRanks = not ns.db.pickerAllRanks
        f:SelectTab(f.tab)
    end)
    f.ranks:SetPoint("RIGHT", f.clear, "LEFT", -8, 0)

    function f:SetPage(p)
        local maxPage = math.max(1, math.ceil(#self.list / PER_PAGE))
        self.page = math.max(1, math.min(maxPage, p))
        for i, cell in ipairs(self.cells) do
            local entry = self.list[(self.page - 1) * PER_PAGE + i]
            cell.entry = entry
            if entry then
                cell.icon:SetTexture(entry.icon)
                local label = entry.name
                if entry.sub and entry.sub ~= "" and ns.db.pickerAllRanks then label = label .. "\n" .. entry.sub end
                cell.name:SetText(label)
                cell:Show()
            else
                cell:Hide()
            end
        end
        self.pageText:SetText(maxPage > 1 and ("Page " .. self.page .. " / " .. maxPage) or "")
        self.prev:SetShown(maxPage > 1)
        self.next:SetShown(maxPage > 1)
        self.empty:SetText(#self.list == 0 and "Nothing here yet." or "")
    end

    function f:SelectTab(key)
        self.tab = key
        local def = self.tabDefs[key]
        self.list = def and def.collect() or {}
        for _, b in ipairs(self.tabButtons) do b:SetSelected(b.key == key) end
        self.ranks:SetShown(def and def.isSpells or false)
        self.ranks:SetLabel(ns.db.pickerAllRanks and "All ranks" or "Best rank")
        self:SetPage(1)
    end

    function f:BuildTabs()
        local defs = {}
        for _, tab in ipairs(spellTabs()) do
            defs[#defs + 1] = { label = tab.name, isSpells = true, collect = function() return collectSpells(tab) end }
        end
        defs[#defs + 1] = { label = "Items", collect = collectItems }
        defs[#defs + 1] = { label = "Macros", collect = collectMacros }
        self.tabDefs = defs
        for _, b in ipairs(self.tabButtons) do b:Hide() end
        local gap = 6
        local barWidth = self:GetWidth() - 40
        local bw = math.min(150, (barWidth - gap * (#defs - 1)) / #defs)
        for i, def in ipairs(defs) do
            local b = self.tabButtons[i]
            if not b then
                b = W.Button(self.tabBar, bw, 40, "", function(btn) f:SelectTab(btn.key) end)
                self.tabButtons[i] = b
            end
            b:SetSize(bw, 40)
            b:ClearAllPoints()
            b:SetPoint("LEFT", (i - 1) * (bw + gap), 0)
            b.key = i
            b:SetLabel(def.label)
            b:Show()
        end
    end
    return f
end

function ns.OpenPicker(slot, button)
    if not slot then return end
    if InCombatLockdown() then
        ns.Print("Buttons can't be changed during combat.")
        return
    end
    picker = picker or buildPicker()
    picker.slot = slot
    local index = button and button.index
    picker.title:SetText(index and ("Choose an action for button " .. index) or "Choose an action")
    picker.subtitle:SetText("Tap a spell, item or macro. It goes on action slot " .. slot .. ".")
    picker:BuildTabs()
    -- Start on the class tab (tab 2) when there is one; tab 1 is General.
    picker:SelectTab(#picker.tabDefs > 3 and 2 or 1)
    W.FitToScreen(picker, 1.2)
    picker:Show()
end
