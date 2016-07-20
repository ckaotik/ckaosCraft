-- adds useful professions as tabs on the recipe book
local addonName, addon, _ = ...
local plugin = addon:NewModule('Tabs', 'AceEvent-3.0')

-- GLOBALS: _G, LibStub
-- interesting globals: PROFESSION_RANKS, CURRENT_TRADESKILL, GetSpellTabInfo(profIndex)

local function TabPreClick(self, btn)
	if IsModifiedClick('CHATLINK') then
		-- print chat link, don't trigger spell
		self:SetAttribute('type', nil)
		local spellLink, tradeSkillLink = GetSpellLink(self.spellID)
		ChatEdit_InsertLink(tradeSkillLink or spellLink)
	elseif not self:GetChecked() then
		-- don't close profession when clicking active tab
		self:SetAttribute('type', nil)
	end
end

local function TabPostClick(self, btn)
	-- reactivate button
	self:SetAttribute('type', 'spell')
	plugin:UpdateTabs()
end

local tabs = {}
local function GetTab(index)
	if not tabs[index] then
		local tab = CreateFrame('CheckButton', addonName..'ProfessionTab'..index, TradeSkillFrame, 'SpellBookSkillLineTabTemplate SecureActionButtonTemplate', index)
		tab:SetScript('OnEnter', addon.ShowTooltip)
		tab:SetScript('OnLeave', addon.HideTooltip)
		tab:SetScript('PreClick', TabPreClick)
		tab:SetScript('PostClick', TabPostClick)
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
	local currentSkill, rank, maxRank, skillLineModifier = C_TradeSkillUI.GetTradeSkillLine()
	for index, tab in pairs(tabs) do
		local isShown = tab.name == currentSkill and tab:GetID() > 0
		tab:SetChecked(isShown)
	end
end

local ARCHAEOLOGY = 794
local SURVEY, SMELTING, LOCKPICKING, RUNEFORGING = 80451, 2656, 1804, 53428
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

			local displaySkill = not IsPassiveSpell(spellIndex, _G.BOOKTYPE_PROFESSION)
			-- display specialization or base skill, as configured
			displaySkill = displaySkill and (specializationOffset == 0
				or (self.db.profile.showSpecialization == (specializationOffset == offset)))
			-- display archaeology frame toggle, as configured
			displaySkill = displaySkill and (self.db.profile.showArchaeology or skillLine ~= ARCHAEOLOGY or spellID == SURVEY)
			if displaySkill then
				local spellLink, tradeLink = GetSpellLink(spellIndex, BOOKTYPE_SPELL)
				local hasRecipes = tradeLink ~= nil or spellID == SMELTING
				local isPrimary  = index <= 2

				if not isPrimary or hasRecipes then
					local tab = UpdateTab(hasRecipes and tabIndex or secTabIndex, spellID)
					if hasRecipes then
						tabIndex = tabIndex + 1
					else
						secTabIndex = secTabIndex - 1
					end
					tab.name = name
				end
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
