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
    self:RegisterChatCommand("arenadodge", "ShowFrame")
    self:RegisterEvent("WHO_LIST_UPDATE", "OnWhoListUpdate")
end

function ArenaDodger:ShowFrame()
    if not self.frame then
        self:CreateFrame()
    end
    self.frame:Show()
    self:UpdatePlayerList()
end

function ArenaDodger:CreateFrame()
    local frame = AceGUI:Create("Frame")
    frame:SetTitle(L["ArenaDodger"])
    frame:SetWidth(350)
    frame:SetHeight(400)
    frame:SetLayout("Flow")
    frame:SetCallback("OnClose", function(widget) 
        AceGUI:Release(widget)
        self.frame = nil
    end)
    self.frame = frame

    -- Input for adding players
    local editbox = AceGUI:Create("EditBox")
    editbox:SetLabel(L["Enter a player name:"])
    editbox:SetWidth(200)
    editbox:SetCallback("OnEnterPressed", function(widget, event, text)
        self:AddPlayer(text)
        widget:SetText("")
    end)
    frame:AddChild(editbox)

    -- Refresh button
    local refreshButton = AceGUI:Create("Button")
    refreshButton:SetText(L["Refresh"])
    refreshButton:SetWidth(100)
    refreshButton:SetCallback("OnClick", function() 
        self:Print("Refresh button clicked")
        self:RefreshLocations() 
    end)
    frame:AddChild(refreshButton)

    -- Add some spacing to avoid layout issues
    local spacer = AceGUI:Create("Label")
    spacer:SetText("")
    spacer:SetWidth(10)
    frame:AddChild(spacer)

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
        playerGroup:SetLayout("Flow")

        local label = AceGUI:Create("Label")
        local location = self.db.global.playerLocations[name] or L["Unknown"]
        label:SetText(name .. " - " .. location)
        label:SetWidth(200) -- Reduced to make space for "Remove"
        playerGroup:AddChild(label)

        local removeButton = AceGUI:Create("Button")
        removeButton:SetText("Remove") -- Changed from "X" to "Remove"
        removeButton:SetWidth(80) -- Increased width to fit "Remove"
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
    if #players > 0 then
        self:Print("Refreshing locations for: " .. table.concat(players, ", "))
    else
        self:Print("No players to refresh")
    end

    for name, _ in pairs(self.db.global.dodgeList) do
        self:CheckPlayerLocation(name)
    end
end

function ArenaDodger:CheckPlayerLocation(name)
    self:Print("Attempting to check location for: " .. name)
    SetWhoToUI(1) -- Enable UI response to ensure WHO_LIST_UPDATE fires
    SendWho('n-"' .. name .. '"') -- Query by exact name
    self:Print("Sent /who request for: " .. name)
    -- Hide the Who window after a short delay
    self:ScheduleTimer(function()
        if WhoFrame:IsShown() then
            HideUIPanel(WhoFrame)
        end
    end, 0.1) -- 0.1-second delay to ensure the frame is shown
end

function ArenaDodger:OnWhoListUpdate()
    local numWhos = GetNumWhoResults()
    self:Print("WHO_LIST_UPDATE triggered, results: " .. numWhos)

    -- Track if we found each player in the dodgeList
    local foundPlayers = {}
    for name, _ in pairs(self.db.global.dodgeList) do
        foundPlayers[name] = false
    end

    -- Process the results
    for i = 1, numWhos do
        local name, _, _, _, _, zone = GetWhoInfo(i)
        self:Print("Who result: " .. name .. " in " .. (zone or "nil"))
        if self.db.global.dodgeList[name] then
            foundPlayers[name] = true
            if ARENA_MAPS[zone] then
                self.db.global.playerLocations[name] = zone
                self:Print(name .. " confirmed in arena: " .. zone)
            else
                self.db.global.playerLocations[name] = zone or "Unknown"
                self:Print(name .. " not in arena, zone: " .. (zone or "nil"))
            end
        end
    end

    -- Set "Offline" for players not found in the results
    for name, found in pairs(foundPlayers) do
        if not found then
            self.db.global.playerLocations[name] = "Offline"
            self:Print(name .. " is offline")
        end
    end

    self:UpdatePlayerList()
end