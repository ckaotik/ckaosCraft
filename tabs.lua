-- adds useful professions as tabs on the recipe book
local addonName, addon, _ = ...
local search = addon:NewModule('ProfessionTabs')

-- GLOBALS: _G, LibStub


--[[
local function SetTradeSkillTab(index, spellID, isSecondary)
	local frame = TradeSkillFrame
	local button = frame[index]
	if not button then
		button = CreateFrame('CheckButton', nil, frame, 'SpellBookSkillLineTabTemplate SecureActionButtonTemplate')
		button:SetScript('OnEnter', addon.ShowTooltip)
		button:SetScript('OnLeave', addon.HideTooltip)
		button:SetAttribute('type', 'spell')
		frame[index] = button
	end

	button:ClearAllPoints()
	button:Show()
	local previous = frame[index - 1]
	if isSecondary then
		if previous and previous:GetID() < 0 then
			button:SetPoint('BOTTOMLEFT', previous, 'TOPLEFT', 0, 12)
			button:SetID(previous:GetID() - 1)
		else
			-- first bottom tab
			button:SetPoint('BOTTOMLEFT', '$parent', 'BOTTOMRIGHT', 0, 30)
			button:SetID(-1)
		end
	else
		if previous and index > 1 then
			button:SetPoint('TOPLEFT', previous, 'BOTTOMLEFT', 0, -12)
			button:SetID(previous:GetID() + 1)
		else
			-- first top tab
			button:SetPoint('TOPLEFT', '$parent', 'TOPRIGHT', 0, -30)
			button:SetID(1)
		end
	end

	local spellName, rank, icon = GetSpellInfo(spellID)
	button:SetNormalTexture(icon)
	button.link = GetSpellLink(spellID)
	-- button.tiptext = spellName
	-- button.tiptext2 = rank
	button:SetAttribute('spell', spellName)
end

local function UpdateTradeSkillTabs()
	local tradeSkillSpells = {}
	local secondarySpells = {}

	for index, profession in ipairs({ GetProfessions() }) do
		local name, texture, rank, maxRank, numSpells, spellOffset, skillLine, rankModifier, specializationIndex, specializationOffset = GetProfessionInfo(profession)

		local hasMainSpell
		for offset = 1, numSpells or 0 do
			local link, tradeLink = GetSpellLink(spellOffset + offset, _G.BOOKTYPE_SPELL)
			if not IsPassiveSpell(spellOffset + offset, _G.BOOKTYPE_SPELL) then
				local _, spellID = addon.GetLinkData(link)
				if tradeLink or spellID == 2656 then
					if not hasMainSpell then
						table.insert(tradeSkillSpells, spellID)
					end
					hasMainSpell = true
				else
					table.insert(secondarySpells, spellID)
				end
			end
		end
	end

	for index, spellID in ipairs(tradeSkillSpells) do
		SetTradeSkillTab(index, spellID)
	end
	for index, spellID in ipairs(secondarySpells) do
		SetTradeSkillTab(index + #tradeSkillSpells, spellID, true)
	end
end --]]
