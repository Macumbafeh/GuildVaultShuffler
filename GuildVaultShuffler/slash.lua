--------------------------------------------------------------------------------
--  Guild Vault Shuffler (c) 2012-2013 by Siarkowy (aka Acesulfam)
--  Released under the terms of GNU GPL v3 license.
--------------------------------------------------------------------------------

local Shuffler  = GuildVaultShuffler
local pair2id   = Shuffler.pair2id

local NUM_TABROWS = 7
local temp = {}
local function wipe(t) for k in pairs(t) do t[k] = nil end end

function Shuffler:OnSlash(msg)
    -- change item links to item IDs
    msg = msg:gsub("%s*|c%x+|Hitem:(%d+).-|h|r", "%1")

    msg = msg:gsub("col(%d+)%-(%d+):(%d+)", function(a, b, id)
        wipe(temp)
        for i = a, b do tinsert(temp, format("col%d:%d", i, id)) end
        return table.concat(temp, " ")
    end)

    -- expand column ranges
    msg = msg:gsub("col(%d+)", function(id) return format("%d-%d", (id - 1) * NUM_TABROWS + 1, id * NUM_TABROWS) end)

    -- expand item ranges: set 7-12:item
    msg = msg:gsub("(%d+)%-(%d+):(%d+)", function(a, b, id)
        wipe(temp)
        for i = a, b do tinsert(temp, format("%d:%d", i, id)) end
        return table.concat(temp, " ")
    end)

    -- expand remaining ranges: clear 1-8
    msg = msg:gsub("(%d+)%-(%d+)", function(a, b)
        wipe(temp)
        for i = a, b do tinsert(temp, i) end
        return table.concat(temp, " ")
    end)

    local command, param = msg:match("(%S*)%s*(.*)%s*")

    if command == "shuffle" then
        self:Shuffle()

    elseif command == "set" then
        for slot, item, count in param:gmatch("(%d+):(%d+)") do
            self:SetItemForSlot(pair2id(GetCurrentGuildBankTab(), slot), tonumber(item))
        end

        self:Print("Slot data changed.")

    elseif command == "clear" then
        for slot in param:gmatch("%d+") do
            self:SetItemForSlot(pair2id(GetCurrentGuildBankTab(), slot), nil)
        end

        self:Print("Slot data cleared.")

    else -- usage
        self:Print("Version %s usage: |cffffff7f/gvs [ set || unset ]|r", GetAddOnMetadata("GuildVaultShuffler", "Version"))
        self:Echo("   |cffffff7fset <slot>:<item> [ ... <slotN>:<itemN> ]|r - Sets current tab's specified slots to given item where <slot> can be a decimal (3) or range (2-8) and <item> can be a link or ID.")
        self:Echo("   |cffffff7funset <slot> [ ... <slotN> ]|r - Unsets current tab's specified slot data.")
        self:Echo("Substitute |cffffff7f<slot>|r with a single decimal (|cffffff7f5|r) or a range (|cffffff7f7-13|r).")
    end
end

function SlashCmdList.GUILDVAULTSHUFFLER(msg) Shuffler:OnSlash(msg) end
SLASH_GUILDVAULTSHUFFLER1 = "/gvshuffler"
SLASH_GUILDVAULTSHUFFLER2 = "/gvs"
