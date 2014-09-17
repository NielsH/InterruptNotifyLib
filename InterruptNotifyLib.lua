-----------------------------------------------------------------------------------------------
--[[
	Client Lua Script for InterruptNotifyLib
	
	This file is part of InterruptNotifyLib.

    InterruptNotifyLib is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    InterruptNotifyLib is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with InterruptNotifyLib.  If not, see <http://www.gnu.org/licenses/>.
--]]
-----------------------------------------------------------------------------------------------
require "ActionSetLib"
require "AbilityBook"
require "Apollo"
require "ApolloTimer"
require "GameLib"
require "ICCommLib"

-----------------------------------------------------------------------------------------------
-- InterruptNotifyLib Module Definition
-----------------------------------------------------------------------------------------------
local InterruptNotifyLib = {}

-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function InterruptNotifyLib:new(o)
	o = o or {}
    setmetatable(o, self)
    self.__index = self 
	return o
end

function InterruptNotifyLib:Init()
	local bHasConfigureFunction = false
	local strConfigureButtonText = ""
	local tDependencies = {}

    Apollo.RegisterAddon(self, bHasConfigureButton, strConfigureButtonText, tDependencies)
end
-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------
-- DEBUG
--local Rover = Apollo.GetAddon("Rover")
-- DEBUG

-- Timers
local NotifyTimer
local PlayerInfoTimer
local nNotifyInterval = 1.0

-- Player information
local tPlayerInfo = {
	strCharacterName	= nil,
	nClassId			= nil,
	tAbilities			= nil,
	bCharacterReady		= false,
}

-- Holds all the channels we are subscribed to
local tChannels = {}

-- Addon that holds our handler function, assigned in OnLoad
local tHandler = nil

-- Abilities we should monitor
-- When adding/changing locales,
-- make sure to update GetLocale() as well
local tLocaleToAbilityNames = {
	[GameLib.CodeEnumClass.Esper] = {
		["enUS"] = {"Crush", "Incapacitate", "Shockwave",},
		["frFR"] = {"Écrasement", "Soumission", "Onde de choc",},
		["deDE"] = {"Zermalmen", "Lahmlegen", "Schockwelle",},
	},
	[GameLib.CodeEnumClass.Medic] = {
		["enUS"] = {"Paralytic Surge",},
		["frFR"] = {"Décharge paralysante",},
		["deDE"] = {"Hochspannungslähmung",},
	},
	[GameLib.CodeEnumClass.Stalker] = {
		["enUS"] = {"Collapse", "False Retreat", "Stagger",},
		["frFR"] = {"Effondrement", "Repli feint", "Défaillance",},
		["deDE"] = {"Kleinkriegen", "Rückzugsfinte", "Links-Rechts-Kombination",},
	},
	[GameLib.CodeEnumClass.Warrior] = {
		["enUS"] = {"Flash Bang", "Grapple", "Kick", "Tremor",},
		["frFR"] = {"Choc fulgurant", "Lutte au corps-à-corps", "Coup de pied", "Tremblement",},
		["deDE"] = {"Blendgranate", "Einhaken", "Tritt", "Beben",},
	},
	[GameLib.CodeEnumClass.Engineer] = {
		["enUS"] = {"Obstruct Vision", "Zap",},
		["frFR"] = {"Vue obstruée", "Elimination"},
		["deDE"] = {"Sicht behindern", "Schocken",},
	},
	[GameLib.CodeEnumClass.Spellslinger] = {
		["enUS"] = {"Arcane Shock", "Gate", "Spatial Shift",},
		["frFR"] = {"Choc arcanique", "Portail", "Glissement spatial",},
		["deDE"] = {"Arkanstoß", "Pforte", "Raumverschiebung",},
	},
}
-- There are 9 tiers, Base + 8
-- Make sure the ability order aligns with tLocaleToAbilityNames
local tClassIdToAbilities =
{
	[GameLib.CodeEnumClass.Esper] = {
		[1] = { -- Crush
			{bInterrupt = true, nIARemove = 1,},
			{bInterrupt = true, nIARemove = 1,},
			{bInterrupt = true, nIARemove = 1,},
			{bInterrupt = true, nIARemove = 1,},
			{bInterrupt = true, nIARemove = 2,},
			{bInterrupt = true, nIARemove = 2,},
			{bInterrupt = true, nIARemove = 2,},
			{bInterrupt = true, nIARemove = 2,},
			{bInterrupt = true, nIARemove = 2,},
		},
		[2] = { -- Incapacitate
			{bInterrupt = false, nIARemove = 1,},
			{bInterrupt = false, nIARemove = 1,},
			{bInterrupt = false, nIARemove = 1,},
			{bInterrupt = false, nIARemove = 1,},
			{bInterrupt = false, nIARemove = 1,},
			{bInterrupt = false, nIARemove = 1,},
			{bInterrupt = false, nIARemove = 1,},
			{bInterrupt = false, nIARemove = 1,},
			{bInterrupt = false, nIARemove = 1,},
		},
		[3] = { -- Shockwave
			{bInterrupt = true, nIARemove = 1,},
			{bInterrupt = true, nIARemove = 1,},
			{bInterrupt = true, nIARemove = 1,},
			{bInterrupt = true, nIARemove = 1,},
			{bInterrupt = true, nIARemove = 1,},
			{bInterrupt = true, nIARemove = 1,},
			{bInterrupt = true, nIARemove = 1,},
			{bInterrupt = true, nIARemove = 1,},
			{bInterrupt = true, nIARemove = 1,},
		},
	},
	[GameLib.CodeEnumClass.Medic] = {
		[1] = { -- Paralytic Surge
			{bInterrupt = true, nIARemove = 1,},
			{bInterrupt = true, nIARemove = 1,},
			{bInterrupt = true, nIARemove = 1,},
			{bInterrupt = true, nIARemove = 1,},
			{bInterrupt = true, nIARemove = 2,},
			{bInterrupt = true, nIARemove = 2,},
			{bInterrupt = true, nIARemove = 2,},
			{bInterrupt = true, nIARemove = 2,},
			{bInterrupt = true, nIARemove = 2,},
		},
	},
	[GameLib.CodeEnumClass.Stalker] = {	
		[1] = { -- Collapse
			{bInterrupt = true, nIARemove = 1,},
			{bInterrupt = true, nIARemove = 1,},
			{bInterrupt = true, nIARemove = 1,},
			{bInterrupt = true, nIARemove = 1,},
			{bInterrupt = true, nIARemove = 1,},
			{bInterrupt = true, nIARemove = 1,},
			{bInterrupt = true, nIARemove = 1,},
			{bInterrupt = true, nIARemove = 1,},
			{bInterrupt = true, nIARemove = 1,},
		},
		[2] = { --False Retreat
			{bInterrupt = true, nIARemove = 1,},
			{bInterrupt = true, nIARemove = 1,},
			{bInterrupt = true, nIARemove = 1,},
			{bInterrupt = true, nIARemove = 1,},
			{bInterrupt = true, nIARemove = 1,},
			{bInterrupt = true, nIARemove = 1,},
			{bInterrupt = true, nIARemove = 1,},
			{bInterrupt = true, nIARemove = 1,},
			{bInterrupt = true, nIARemove = 1,},
		},
		[3] = { -- Stagger
			{bInterrupt = true, nIARemove = 1,},
			{bInterrupt = true, nIARemove = 1,},
			{bInterrupt = true, nIARemove = 1,},
			{bInterrupt = true, nIARemove = 1,},
			{bInterrupt = true, nIARemove = 1,},
			{bInterrupt = true, nIARemove = 1,},
			{bInterrupt = true, nIARemove = 1,},
			{bInterrupt = true, nIARemove = 1,},
			{bInterrupt = true, nIARemove = 1,},
		},
	},
	[GameLib.CodeEnumClass.Warrior] = {
		[1] = { -- Flash Bang
			{bInterrupt = false, nIARemove = 1,},
			{bInterrupt = false, nIARemove = 1,},
			{bInterrupt = false, nIARemove = 1,},
			{bInterrupt = false, nIARemove = 1,},
			{bInterrupt = false, nIARemove = 1,},
			{bInterrupt = false, nIARemove = 1,},
			{bInterrupt = false, nIARemove = 1,},
			{bInterrupt = false, nIARemove = 1,},
			{bInterrupt = false, nIARemove = 1,},
		},
		[2] = { -- Grapple
			-- Has 2 charges at T4, so actually nIARemove = 2
			-- But charges have to follow GCD, so treating as 1
			-- as 2 Interrupts cannot be done at the same time
			{bInterrupt = true, nIARemove = 1,},
			{bInterrupt = true, nIARemove = 1,},
			{bInterrupt = true, nIARemove = 1,},
			{bInterrupt = true, nIARemove = 1,},
			{bInterrupt = true, nIARemove = 1,},
			{bInterrupt = true, nIARemove = 1,},
			{bInterrupt = true, nIARemove = 1,},
			{bInterrupt = true, nIARemove = 1,},
			{bInterrupt = true, nIARemove = 1,},
		},
		[3] = { -- Kick
			{bInterrupt = true, nIARemove = 1,},
			{bInterrupt = true, nIARemove = 1,},
			{bInterrupt = true, nIARemove = 1,},
			{bInterrupt = true, nIARemove = 1,},
			{bInterrupt = true, nIARemove = 1,},
			{bInterrupt = true, nIARemove = 1,},
			{bInterrupt = true, nIARemove = 1,},
			{bInterrupt = true, nIARemove = 1,},
			{bInterrupt = true, nIARemove = 2,},
		},
		[4] = { -- Tremor
			{bInterrupt = true, nIARemove = 0,},
			{bInterrupt = true, nIARemove = 0,},
			{bInterrupt = true, nIARemove = 0,},
			{bInterrupt = true, nIARemove = 0,},
			{bInterrupt = true, nIARemove = 0,},
			{bInterrupt = true, nIARemove = 0,},
			{bInterrupt = true, nIARemove = 0,},
			{bInterrupt = true, nIARemove = 0,},
			{bInterrupt = true, nIARemove = 0,},
		},
	},
	[GameLib.CodeEnumClass.Engineer] = {
		[1] = { -- Obstruct Vision
			{bInterrupt = false, nIARemove = 1,},
			{bInterrupt = false, nIARemove = 1,},
			{bInterrupt = false, nIARemove = 1,},
			{bInterrupt = false, nIARemove = 1,},
			{bInterrupt = false, nIARemove = 1,},
			{bInterrupt = false, nIARemove = 1,},
			{bInterrupt = false, nIARemove = 1,},
			{bInterrupt = false, nIARemove = 1,},
			{bInterrupt = false, nIARemove = 1,},
		},
		[2] = { -- Zap
			{bInterrupt = true, nIARemove = 1,},
			{bInterrupt = true, nIARemove = 1,},
			{bInterrupt = true, nIARemove = 1,},
			{bInterrupt = true, nIARemove = 1,},
			{bInterrupt = true, nIARemove = 2,},
			{bInterrupt = true, nIARemove = 2,},
			{bInterrupt = true, nIARemove = 2,},
			{bInterrupt = true, nIARemove = 2,},
			{bInterrupt = true, nIARemove = 2,},
		},
	},
	[GameLib.CodeEnumClass.Spellslinger] = {
		[1] = { -- Arcane Shock
			{bInterrupt = false, nIARemove = 1,},
			{bInterrupt = false, nIARemove = 1,},
			{bInterrupt = false, nIARemove = 1,},
			{bInterrupt = false, nIARemove = 1,},
			{bInterrupt = false, nIARemove = 1,},
			{bInterrupt = false, nIARemove = 1,},
			{bInterrupt = false, nIARemove = 1,},
			{bInterrupt = false, nIARemove = 1,},
			{bInterrupt = false, nIARemove = 1,},
		},
		[2] = { -- Gate
			{bInterrupt = true, nIARemove = 1,},
			{bInterrupt = true, nIARemove = 1,},
			{bInterrupt = true, nIARemove = 1,},
			{bInterrupt = true, nIARemove = 1,},
			{bInterrupt = true, nIARemove = 2,},
			{bInterrupt = true, nIARemove = 2,},
			{bInterrupt = true, nIARemove = 2,},
			{bInterrupt = true, nIARemove = 2,},
			{bInterrupt = true, nIARemove = 2,},
		},
		[3] = { -- Spatial Shift
			{bInterrupt = true, nIARemove = 1,},
			{bInterrupt = true, nIARemove = 1,},
			{bInterrupt = true, nIARemove = 1,},
			{bInterrupt = true, nIARemove = 1,},
			{bInterrupt = true, nIARemove = 1,},
			{bInterrupt = true, nIARemove = 1,},
			{bInterrupt = true, nIARemove = 1,},
			{bInterrupt = true, nIARemove = 1,},
			{bInterrupt = true, nIARemove = 1,},
		},
	},
}

-----------------------------------------------------------------------------------------------
-- InterruptNotifyLib OnLoad
-----------------------------------------------------------------------------------------------
function InterruptNotifyLib:OnLoad()
	Apollo.RegisterEventHandler("AbilityBookChange", "UpdatePlayerInfoTimer", self)
end

-----------------------------------------------------------------------------------------------
-- InterruptNotifyLib Helper Functions
-----------------------------------------------------------------------------------------------
local function in_table(needle, haystack)
	for _, value in pairs(haystack) do
		if needle == value then
			return true
		end
	end
	return false
end

local function GetLocale()
	-- We cannot get this directly so need to do a comparision
	local strCancel = Apollo.GetString(1)

	-- German
	if strCancel == "Abbrechen" then
		return "deDE"
	end

	-- French
	if strCancel == "Annuler" then
		return "frFR"
	end

	-- Other
	return "enUS"
end

-----------------------------------------------------------------------------------------------
-- InterruptNotifyLib Functions
-----------------------------------------------------------------------------------------------
function InterruptNotifyLib:UpdatePlayerInfoTimer()
	-- Fired as event handler for AbilityBookChange.
	-- Due to the API being stupid, after AbilityBookChange is fired
	-- the API doesn't give us the new data immediately, so we need to add a delay.
	PlayerInfoTimer = ApolloTimer.Create(1, false, "SetPlayerInfo", self)
end

function InterruptNotifyLib:SetPlayerInfo()
	local unitPlayer				= GameLib.GetPlayerUnit()
	if not unitPlayer then
		-- Try it again after a second, this should only happen if the character is not loaded yet.
		PlayerInfoTimer = ApolloTimer.Create(1, false, "SetPlayerInfo", self)
		return false
	end

	tPlayerInfo["strCharacterName"] = unitPlayer:GetName()
	tPlayerInfo["nClassId"]			= unitPlayer:GetClassId()
	tPlayerInfo["tAbilities"]		= self:GetActiveInterrupts(tPlayerInfo["nClassId"])

	-- Validate return data
	if tPlayerInfo and tPlayerInfo["strCharacterName"] and tPlayerInfo["nClassId"] and tPlayerInfo["tAbilities"] then
		if type(tPlayerInfo["strCharacterName"]) == "string" and type(tPlayerInfo["nClassId"]) == "number" and type(tPlayerInfo["tAbilities"]) == "table" then
			tPlayerInfo["bCharacterReady"] = true
			return true
		end
	end

	-- If for some reason we got unexpected data in tPlayerInfo
	error("Something went wrong while attempting to initialize tPlayerInfo via SetPlayerInfo().")
	return false
end

function InterruptNotifyLib:AddChannel(strChannel, tOwner, strCallback)
	if not strChannel or not tOwner or not strCallback then
		return false
	end

	if not tPlayerInfo or not tPlayerInfo["bCharacterReady"] then
		local bIsPlayerInfoSet = self:SetPlayerInfo()
		if not bIsPlayerInfoSet then
			return false
		end
	end

	tChannels[strChannel] = {
		ChannelName		= strChannel,
		CallbackOwner	= tOwner,
		CallbackFunc	= strCallback,
		CommChannel		= ICCommLib.JoinChannel(strChannel, "OnChannelMsg", self)
	}

	-- Make sure nothing went wrong with creating the channel, otherwise reset the table key
	if not tChannels[strChannel].CommChannel then
		tChannels[strChannel] = nil
		return false
	end

	-- Announce interrupts every 1 second, can be changed via SetUpdateTimer()
	NotifyTimer = ApolloTimer.Create(nNotifyInterval, true, "OnNotifyTimer", self)
	return true
end

function InterruptNotifyLib:GetChannels()
	return tChannels
end

function InterruptNotifyLib:OnChannelMsg(channel, tMsg, strSender)
	-- This fires when we receive messages from other players. We will first reconstruct the message
	-- and convert spell ids into localized names before sending it off to the callback handler.
	local tCallbackMsg = {}
	local tAbilities = tMsg["tAbilities"]
	for key, value in pairs(tAbilities) do
		local strName 			= GameLib.GetSpell(value["nSpellId"]):GetName()
		tCallbackMsg[strName]	= value
	end

	local tOwner		= tChannels[tMsg.strChannel]["CallbackOwner"]
	local strCallback	= tChannels[tMsg.strChannel]["CallbackFunc"]

	if type(tOwner) ~= "table" or type("strCallback") ~= "string" or type(tOwner[strCallback]) ~= "function" then
		error("Invalid callback.")
	end

	tOwner[strCallback](tOwner, tCallbackMsg)
end

function InterruptNotifyLib:OnNotifyTimer()
	if not tPlayerInfo or not tPlayerInfo["bCharacterReady"] then
		return false
	end

	local tMsgData = tPlayerInfo
	for key, value in pairs(tMsgData["tAbilities"]) do
		value["nCooldown"] 			= GameLib.GetSpell(value["nSpellId"]):GetCooldownTime()
		value["nCooldownRemaining"]	= GameLib.GetSpell(value["nSpellId"]):GetCooldownRemaining()

		if value["nCooldownRemaining"] == 0 then
			value["bOnCooldown"] = false
		else
			value["bOnCooldown"] = true
		end
	end

	-- Now send it off to our subscribed channels
	for key, value in pairs(tChannels) do
		tMsgData["strChannel"] = key
		value["CommChannel"]:SendMessage(tMsgData)
	end
end

function InterruptNotifyLib:GetActiveInterrupts(nClassId)
	if not nClassId or not tLocaleToAbilityNames[nClassId] then
		return false
	end

	-- Because we don't know the locale of the user we need to re-construct
	-- tClassIdToAbilities where the keys that are now numeric are replaced
	-- with the correct ability name from tLocaleToAbilityNames.
	-- We will filter our return table to only have abilities that are in our current LAS
	local locale 				= GetLocale()
	local tAbilities 			= {}
	local tAbilitiesActiveById 	= ActionSetLib:GetCurrentActionSet()
	local tAbilitiesList 		= AbilityBook.GetAbilitiesList()

	for key, value in pairs(tLocaleToAbilityNames[nClassId][locale]) do
		for k, v in pairs(tAbilitiesList) do
			if v.strName == value then
				if v.nCurrentTier > 0 then
					-- v.nCurrentTier can be 0 if ability is locked, and v.tTiers table does not contain 0
					local tAbility 		= v.tTiers[v.nCurrentTier]
					local nCurrentTier 	= tAbility.nTier
					local nAbilityId	= tAbility.nId
					local nSpellId		= tAbility.splObject:GetId()

					if in_table(nAbilityId, tAbilitiesActiveById) then
						tAbilities[nSpellId] 				= tClassIdToAbilities[nClassId][key][nCurrentTier]
						tAbilities[nSpellId]["nAbilityId"]	= nAbilityId
						tAbilities[nSpellId]["nSpellId"]	= nSpellId
					end
				end
			end
		end
	end
	return tAbilities
end

function InterruptNotifyLib:SetUpdateTimer(nInterval)
	if not nInterval or type(nInterval) ~= "number" or nInterval <= 0 then
		return false
	end
	nNotifyInterval = nInterval
	-- Only re-create the timer if it was already running.
	-- Otherwise it'll start on its own with the new interval during AddChannel()
	if NotifyTimer then
		NotifyTimer = ApolloTimer.Create(nInterval, true, "OnNotifyTimer", self)
	end
	return true
end

-----------------------------------------------------------------------------------------------
-- InterruptNotifyLib Instance
-----------------------------------------------------------------------------------------------
local InterruptNotifyLibInst = InterruptNotifyLib:new()
InterruptNotifyLibInst:Init()
