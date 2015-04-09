-- adds useful professions as tabs on the recipe book
local addonName, addon, _ = ...
local plugin = addon:NewModule('Tabs', 'AceEvent-3.0')

-- GLOBALS: _G, LibStub
-- interesting globals: BOOKTYPE_PROFESSION, PROFESSION_RANKS, CURRENT_TRADESKILL, GetSpellTabInfo(profIndex)
-- TODO: Don't close when clicking already displayed tradeskill: IsCurrentSpell("Schmiedekunst")
-- TODO: allow shift-linking

local tabs = {}
local function TabOnClick(self, btn, up)
	-- do not highlight camp fire etc.
	if self:GetID() < 0 then
		plugin:UpdateTabs()
	end
end

local function GetTab(index)
	if not tabs[index] then
		local tab = CreateFrame('CheckButton', nil, TradeSkillFrame, 'SpellBookSkillLineTabTemplate SecureActionButtonTemplate', index)
		tab:SetScript('OnEnter', addon.ShowTooltip)
		tab:SetScript('OnLeave', addon.HideTooltip)
		tab:SetScript('PostClick', TabOnClick)
		tab:SetAttribute('type', 'spell')
		tabs[index] = tab

		if index == 1 then
			-- first top tab
			tab:SetPoint('TOPLEFT', '$parent', 'TOPRIGHT', 0, -30)
		elseif index == -1 then
			-- first bottom tab
			tab:SetPoint('BOTTOMLEFT', '$parent', 'BOTTOMRIGHT', 0, 30)
		elseif index > 1 then
			tab:SetPoint('TOPLEFT', tabs[index - 1], 'BOTTOMLEFT', 0, -12)
		else
			tab:SetPoint('BOTTOMLEFT', tabs[index + 1], 'TOPLEFT', 0, 12)
		end
	end
	return tabs[index]
end

local function UpdateTab(index, spellID)
	local spellName, rank, icon = GetSpellInfo(spellID)
	if spellName then
		local tab = GetTab(index)
		tab.spellID = spellID
		tab.link = GetSpellLink(spellID)
		tab:SetNormalTexture(icon)
		tab:SetAttribute('spell', spellName)
		tab:Show()
		return tab
	else
		local tab = GetTab(index, true)
		if tab then tab:Hide() end
	end
end

local defaults = {
	profile = {
		showSpecialization = true,
		showArchaeology = true,
	},
}
function plugin:OnEnable()
	self.db = addon.db:RegisterNamespace('Tabs', defaults)
	self:RegisterEvent('TRADE_SKILL_SHOW', 'UpdateTabs')
	self:RegisterEvent('SKILL_LINES_CHANGED', 'Update')

	-- tabs need some space
	UIPanelWindows['TradeSkillFrame'].extraWidth = 32
	self:Update()
end

function plugin:OnDisable()
	self:UnregisterEvent('TRADE_SKILL_SHOW')
	self:UnregisterEvent('SKILL_LINES_CHANGED')
end

function plugin:UpdateTabs()
	local currentSkill, rank, maxRank, skillLineModifier = GetTradeSkillLine()
	for index, tab in pairs(tabs) do
		local isShown = tab.name == currentSkill and tab:GetID() > 0
		tab:SetChecked(isShown)
	end
end

-- arch is the skill line, the rest are spell ids
local ARCHAEOLOGY, SURVEY, SMELTING, LOCKPICKING, RUNEFORGING = 794, 80451, 2656, 1804, 53428
function plugin:Update()
	for index, tab in pairs(tabs) do
		UpdateTab(index, nil)
	end

	local tabIndex, secTabIndex = 1, -1
	for index, profession in pairs({ GetProfessions() }) do
		local name, texture, rank, maxRank, numSpells, spellOffset, skillLine, rankModifier, specializationIndex, specializationOffset = GetProfessionInfo(profession)

		for offset = 1, numSpells or 0 do
			local spellIndex = spellOffset + offset
			local spellName, _, spellIcon, _, _, _, spellID = GetSpellInfo(spellIndex, BOOKTYPE_SPELL)

			-- handle specializations if available
			local displaySkill = specializationOffset == 0
				or (self.db.profile.showSpecialization == (specializationOffset == offset))
			if displaySkill and (self.db.profile.showArchaeology or skillLine ~= ARCHAEOLOGY or spellID == SURVEY)
				and not IsPassiveSpell(spellIndex, _G.BOOKTYPE_PROFESSION) then
				local spellLink, tradeLink = GetSpellLink(spellIndex, BOOKTYPE_SPELL)
				local isPrimary = tradeLink ~= nil or spellID == SMELTING

				local tab = UpdateTab(isPrimary and tabIndex or secTabIndex, spellID)
				if isPrimary then
					tabIndex = tabIndex + 1
				else
					secTabIndex = secTabIndex - 1
				end
				tab.name = name
			end
		end
	end

	-- class specific professions
	if IsSpellKnown(RUNEFORGING) then
		UpdateTab(tabIndex, RUNEFORGING)
		tabIndex = tabIndex + 1
	end
	if IsSpellKnown(LOCKPICKING) then
		UpdateTab(secTabIndex, LOCKPICKING)
		secTabIndex = secTabIndex + 1
	end
end
