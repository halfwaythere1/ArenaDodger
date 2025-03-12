local ADDON_NAME = "ArenaDodger"
local ArenaDodger = LibStub("AceAddon-3.0"):NewAddon(ADDON_NAME, "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME)
local AceGUI = LibStub("AceGUI-3.0")


-- Arena maps for WoW 3.3.5a
local ARENA_MAPS = {
    [L["Nagrand Arena"]] = true,
    [L["Ruins of Lordaeron"]] = true,
    [L["Blade's Edge Arena"]] = true,
    [L["Dalaran Arena"]] = true,
    [L["Ring of Valor"]] = true,
}

-- Default DB
local defaults = {
    global = {
        dodgeList = {},
        playerLocations = {},
    },
}

function ArenaDodger:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("ArenaDodgerDB", defaults)
    self:RegisterChatCommand("adodger", "ShowFrame")
    self:RegisterEvent("WHO_LIST_UPDATE", "OnWhoListUpdate")
end

function ArenaDodger:ShowFrame()
    if not self.frame then
        self:CreateFrame()
    end
    self.frame:Show()
    self:UpdatePlayerList() -- Ensure the list is populated when the frame is shown
end

function ArenaDodger:CreateFrame()
    local frame = AceGUI:Create("Frame")
    frame:SetTitle(L["ArenaDodger"])
    frame:SetWidth(350)
    frame:SetHeight(400)
    frame:SetLayout("Flow")
    frame:SetCallback("OnClose", function(widget) 
        AceGUI:Release(widget)
        self.frame = nil -- Clear the frame reference when closed
    end)
    self.frame = frame

    -- Input for adding players
    local editbox = AceGUI:Create("EditBox")
    editbox:SetLabel(L["Enter a player name:"])
    editbox:SetWidth(200)
    frame:AddChild(editbox)
    editbox:SetCallback("OnEnterPressed", function(widget, event, text)
        self:AddPlayer(text)
        widget:SetText("")
        widget.editbox:ClearFocus() -- Use the underlying Blizzard EditBox's ClearFocus
    end)

    -- Refresh button
    local refreshButton = AceGUI:Create("Button")
    refreshButton:SetText(L["Refresh"])
    refreshButton:SetWidth(100)
    refreshButton:SetCallback("OnClick", function() 
        self:RefreshLocations() 
    end)
    frame:AddChild(refreshButton)

    -- Player list
    self.playerList = AceGUI:Create("SimpleGroup")
    self.playerList:SetFullWidth(true)
    self.playerList:SetLayout("List")
    frame:AddChild(self.playerList)

    self:UpdatePlayerList()
end

function ArenaDodger:AddPlayer(name)
    if name and name ~= "" then
        name = strtrim(name)
        -- Capitalize the name (first letter uppercase, rest lowercase)
        name = name:sub(1, 1):upper() .. name:sub(2):lower()
        if not self.db.global.dodgeList[name] then
            self.db.global.dodgeList[name] = true
            self.db.global.playerLocations[name] = L["Unknown"]
            self:UpdatePlayerList()
            self:RefreshLocations()
        end
    end
end

function ArenaDodger:RemovePlayer(name)
    if self.db.global.dodgeList[name] then
        self.db.global.dodgeList[name] = nil
        self.db.global.playerLocations[name] = nil
        self:UpdatePlayerList()
    end
end

function ArenaDodger:UpdatePlayerList()
    if not self.playerList then return end
    self.playerList:ReleaseChildren()

    for name, _ in pairs(self.db.global.dodgeList) do
        local playerGroup = AceGUI:Create("SimpleGroup")
        playerGroup:SetFullWidth(true)
        playerGroup:SetLayout("Flow") -- Flow layout will stack widgets horizontally, we'll adjust below

        -- Label for the name
        local nameLabel = AceGUI:Create("Label")
        nameLabel:SetText(name)
        nameLabel:SetWidth(220)
        nameLabel:SetFontObject(GameFontNormalLarge) -- Larger font
        playerGroup:AddChild(nameLabel)

        -- Label for the location
        local locationLabel = AceGUI:Create("Label")
        local location = self.db.global.playerLocations[name] or L["Unknown"]
        locationLabel:SetText(location)
        locationLabel:SetWidth(220)
        locationLabel:SetFontObject(GameFontNormalLarge) -- Larger font
        playerGroup:AddChild(locationLabel)

        local separatorLabel = AceGUI:Create("Label")
        separatorLabel:SetText("----------------------------------------------------")
        separatorLabel:SetWidth(220)
        separatorLabel:SetFontObject(GameFontNormalSmall)
        playerGroup:AddChild(separatorLabel)

        -- Add remove button
        local removeButton = AceGUI:Create("Button")
        removeButton:SetText(L["Remove"])
        removeButton:SetWidth(85)
        removeButton:SetCallback("OnClick", function() self:RemovePlayer(name) end)
        playerGroup:AddChild(removeButton)

        self.playerList:AddChild(playerGroup)
    end
end

function ArenaDodger:RefreshLocations()
    local players = {}
    for name, _ in pairs(self.db.global.dodgeList) do
        table.insert(players, name)
    end

    -- Track which players we're querying
    self.pendingQueries = {}
    for name, _ in pairs(self.db.global.dodgeList) do
        self.pendingQueries[name] = true
        self:CheckPlayerLocation(name)
    end
end

function ArenaDodger:CheckPlayerLocation(name)
    SetWhoToUI(1) -- Enable UI response to ensure WHO_LIST_UPDATE fires
    SendWho('n-"' .. name .. '"') -- Query by exact name
    self:ScheduleTimer(function()
        if FriendsFrame:IsShown() then
            HideUIPanel(FriendsFrame)
        end
    end, 0.3) -- 0.1 second delay
end

function ArenaDodger:OnWhoListUpdate()
    local numWhos = GetNumWhoResults()

    -- Process results for each queried player
    for i = 1, numWhos do
        local name, _, _, _, _, zone = GetWhoInfo(i)
        if self.db.global.dodgeList[name] then
            if ARENA_MAPS[zone] then
                self.db.global.playerLocations[name] = zone
            else
                self.db.global.playerLocations[name] = L["Not In Arena"] or L["Unknown"]
            end
            -- Mark this player as processed
            if self.pendingQueries then
                self.pendingQueries[name] = nil
            end
            self:UpdatePlayerList()
        end
    end

    -- Check for players with no results (e.g., offline)
    if self.pendingQueries then
        for name, _ in pairs(self.pendingQueries) do
            self.db.global.playerLocations[name] = L["Offline"]
        end
        self.pendingQueries = nil -- Clear the queries
        self:UpdatePlayerList()
    end
end
