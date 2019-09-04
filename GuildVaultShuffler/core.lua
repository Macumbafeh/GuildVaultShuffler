--------------------------------------------------------------------------------
--  Guild Vault Shuffler (c) 2012-2013 by Siarkowy (aka Acesulfam)
--  Released under the terms of GNU GPL v3 license.
--------------------------------------------------------------------------------

local Shuffler = CreateFrame("Frame", "GuildVaultShuffler")

-- Config

local DB_VERSION = 20130110

-- Upvalues

local NUM_SLOTSPERTAB   = 98
local NUM_TABCOLUMNS    = 14
local NUM_TABROWS       = 7

-- local guild
local ignore = 0
local shuffling
local vault

local GetCurrentGuildBankTab = GetCurrentGuildBankTab
local GetGuildBankItemLink = GetGuildBankItemLink

-- Utils

function Shuffler:Print(...) DEFAULT_CHAT_FRAME:AddMessage("|cFFFFA500Guild Vault Shuffler:|r " .. format(...)) end
function Shuffler:Echo(...) DEFAULT_CHAT_FRAME:AddMessage(format(...)) end

local function pair2id(tab, slot)
    return (tab - 1) * NUM_SLOTSPERTAB + slot
end

local function id2pair(id)
    local mod = id % NUM_SLOTSPERTAB
    return ceil(id / NUM_SLOTSPERTAB), mod ~= 0 and mod or NUM_SLOTSPERTAB
end

Shuffler.pair2id = pair2id
Shuffler.id2pair = id2pair

local function GetItemStackSize(item)
    return ( select(8, GetItemInfo(item)) )
end

-- Events

function Shuffler:ADDON_LOADED(name)
    if name == "Blizzard_GuildBankUI" then
        self:EnhanceVaultUI()

        self:UnregisterEvent("ADDON_LOADED")
        self.ADDON_LOADED = nil

    elseif name == "GuildVaultShuffler" then
        -- initialise database
        GVSDB = GVSDB and GVSDB.version == DB_VERSION and GVSDB or {
            vaults  = { },
            taint   = true,

            version = DB_VERSION
        }

        self.db = GVSDB
    end
end

function Shuffler:GUILDBANKBAGSLOTS_CHANGED()
    if ignore > 0 then
        ignore = ignore - 1
        return
    end

    if shuffling then self:Shuffle() end
end

function Shuffler:GUILDBANKFRAME_OPENED()
    vault = self:GetGuildVault()
end

-- Core

function Shuffler:GetGuildVault(guild)
    guild = guild or GetGuildInfo("player")
    if not guild then return false end
    self.db.vaults[guild] = self.db.vaults[guild] or { }
    return self.db.vaults[guild]
end

function Shuffler:SetItemForSlot(slot, item, guild)
    local vault = self:GetGuildVault(guild)
    if not vault then return false end
    vault[slot] = item
    return true
end

function Shuffler:SetItemForSlots(...)
    for i = 1, select("#", ...), 2 do
        local slot, id = select(i, ...)
        if not self:SetItemForSlot(slot, id) then
            return false
        end
    end

    return true
end

function Shuffler:CheckItemSlots()
    local tab = GetCurrentGuildBankTab()
    local slot = 0

    for column = 1, 7 do
        for offset = 1, 14 do
            slot = slot + 1

            if not self:IsItemInCorrectSlot(GetGuildBankItemLink(tab, slot), pair2id(tab, slot)) then
                self:Taint(column, offset, 1, .3, .3)
            end
        end
    end
end

function Shuffler:EnhanceVaultUI()
    local b = CreateFrame("Button", "GVSShuffleButton", GuildBankFrame, "UIPanelButtonTemplate")
    b:ClearAllPoints()
    b:SetText("Shuffle")
    b:SetWidth(100)
    b:SetHeight(21)
    b:SetPoint("BOTTOMLEFT", GuildBankFrame, "BOTTOMLEFT", 25, 37)

    b:SetScript("OnClick", function()
        self:Shuffle()
    end)

    hooksecurefunc("GuildBankFrameTab_OnClick", function(id)
        if id == 1 then b:Show() else b:Hide() end
    end)

    local function GuildBankButtonOnClick(frame, btn, isDown)
        local tab = GetCurrentGuildBankTab()
        local slot = frame:GetParent():GetID() + frame:GetID()
        local item = tonumber((GetGuildBankItemLink(tab, slot) or ""):match("item:(%d+)"))

        if btn == "MiddleButton" then
            self:SetItemForSlot(pair2id(tab, slot), not IsControlKeyDown() and item or nil)
            ClearCursor()
        end
    end

    for col = 1, 7 do
        for btn = 1, 14 do
            local f = getglobal(format("GuildBankColumn%dButton%d", col, btn))
            f:RegisterForClicks("AnyUp")
            f:HookScript("OnClick", GuildBankButtonOnClick)
        end
    end

    local menu = {
        {
            text = "Taint wrong items",
            func = function()
                self.db.taint = not self.db.taint
                GuildBankFrame_Update()
            end,
            checked = function() return self.db.taint end,
            keepShownOnClick = true
        }
    }

    local b = CreateFrame("Button", "GVSDropdownButton", GVSShuffleButton)
    local m = CreateFrame("Frame", "GVSMenuFrame", b, "UIDropDownMenuTemplate")
    b:SetWidth(27)
    b:SetHeight(27)
    b:SetPoint("TOPLEFT", GVSShuffleButton, "TOPRIGHT", -3, 3)
    b:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Round")
    b:SetDisabledTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Disabled")
    b:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Down")

    b:SetScript("OnClick", function(frame, btn)
        EasyMenu(menu, m, frame, 0 , 0, "MENU")
    end)

    hooksecurefunc("GuildBankFrame_Update", function()
        if self.db.taint then self:CheckItemSlots() end
    end)
end

function Shuffler:IsItemInCorrectSlot(link, vaultidx)
    if not link then return true end -- mark empty slots as correct
    local itemid = tonumber(link:match("item:(%d+)"))
    local slotid = self:GetGuildVault()[vaultidx]
    return not slotid or slotid == itemid
end

function Shuffler:SlotInfo(tab, slot)
    return GetGuildBankItemLink(tab, slot), GetGuildBankItemInfo(tab, slot)
end

function Shuffler:Shuffle()
    shuffling = true

    local tab = GetCurrentGuildBankTab()

    for slot = 1, NUM_SLOTSPERTAB do
        local correct = vault[pair2id(tab, slot)]
        local link, _, count = self:SlotInfo(tab, slot)
        local item = link and tonumber(link:match("item:(%d+)"))

        if not link and correct then -- empty slot with template data
            for slot2 = NUM_SLOTSPERTAB, 1, -1 do
                local link2 = GetGuildBankItemLink(tab, slot2)

                if slot ~= slot2 and link2 and tonumber(link2:match("item:(%d+)")) == correct and (slot2 > slot or vault[pair2id(tab, slot2)] and vault[pair2id(tab, slot2)] ~= correct) then
                    ignore = 1
                    PickupGuildBankItem(tab, slot2)
                    PickupGuildBankItem(tab, slot)
                    return
                end
            end

        elseif link then
            if correct and item ~= correct then -- wrong item in slot

                for slot2 = 1, NUM_SLOTSPERTAB do -- lookup another item
                    local link2, _, count2 = self:SlotInfo(tab, slot2)

                    if slot ~= slot2 and link2 and tonumber(link2:match("item:(%d+)")) == correct and vault[pair2id(tab, slot2)] ~= correct then
                        ignore = 1
                        PickupGuildBankItem(tab, slot2)
                        PickupGuildBankItem(tab, slot)
                        return
                    end
                end
            elseif count < GetItemStackSize(link) then -- non full stack
                for slot2 = NUM_SLOTSPERTAB, slot + 1, -1 do
                    if slot2 ~= slot and GetGuildBankItemLink(tab, slot2) == link then
                        ignore = 1
                        PickupGuildBankItem(tab, slot2)
                        PickupGuildBankItem(tab, slot)
                        return
                    end
                end
            end
        end
    end

    shuffling = false
    self:Print("Guild tab shuffle completed.")
end

function Shuffler:Taint(column, offset, r, g, b, a)
    getglobal(format("GuildBankColumn%dButton%dIconTexture", column, offset)):SetVertexColor(r or 0, g or 0, b or 0, a or 1)
end

-- Init

function Shuffler:Init()
    self:SetScript("OnEvent", function(self, event, ...) self[event](self, ...) end)

    self:RegisterEvent("ADDON_LOADED")
    self:RegisterEvent("GUILDBANKBAGSLOTS_CHANGED")
    self:RegisterEvent("GUILDBANKFRAME_OPENED")

    self.Init = nil
end

Shuffler:Init()
