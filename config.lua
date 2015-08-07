local addonName, addon, _ = ...

local function GetProfessionLabel(key, value)
	local profession = select(key, GetProfessions())
	local name, icon, rank, maxRank, numSpells, spelloffset, skillLine, rankModifier, specializationIndex, specializationOffset = GetProfessionInfo(profession)
	local label = '|T' .. icon .. ':0|t ' .. name
	return key, label
end

local function OpenConfiguration(self, args)
	-- remove placeholder configuration panel
	for i, panel in ipairs(_G.INTERFACEOPTIONS_ADDONCATEGORIES) do
		if panel == self then
			tremove(INTERFACEOPTIONS_ADDONCATEGORIES, i)
			break
		end
	end
	self:SetScript('OnShow', nil)
	self:Hide()

	local types = {
		Recipes = {
			craftables = '*none*'
		},
	}

	local L = {
		listTooltipsName = 'Show recipe result tooltip',
		listTooltipsDesc = 'Display crafted item in tooltip when hovering recipe lines.',

		Tabs = {
			showArchaeologyName = 'Show archaeology',
			showArchaeologyDesc = 'Show archaeology as secondary tab.',
			showSpecializationName = 'Show specialization',
			showSpecializationDesc = 'Use specialization icon and tooltip instead of base profession, when available.',
		},
		Tracker = {
			hideMaxedName = 'Hide maxed',
			hideMaxedDesc = 'Hide professions that are already maxed.',
			trackProfessionName = 'Track professions',
			trackProfessionDesc = GetProfessionTooltip,
			trackProfessionDesc = 'Check to add to the objective tracker.',
		},
	}

	-- LibStub('LibDualSpec-1.0'):EnhanceDatabase(addon.db, addonName)
	LibStub('AceConfig-3.0'):RegisterOptionsTable(addonName, {
		type = 'group',
		args = {
			general  = LibStub('LibOptionsGenerate-1.0'):GetOptionsTable(addon.db, types, L, true),
			profiles = LibStub('AceDBOptions-3.0'):GetOptionsTable(addon.db)
		},
	})
	local AceConfigDialog = LibStub('AceConfigDialog-3.0')
	AceConfigDialog:AddToBlizOptions(addonName, nil, nil, 'general')
	AceConfigDialog:AddToBlizOptions(addonName, 'Profiles', addonName, 'profiles')

	OpenConfiguration = function(panel, args)
		InterfaceOptionsFrame_OpenToCategory(addonName)
	end
	OpenConfiguration(self, args)
end

-- create a fake configuration panel
local panel = CreateFrame('Frame')
      panel.name = addonName
      panel:Hide()
      panel:SetScript('OnShow', OpenConfiguration)
InterfaceOptions_AddCategory(panel)

-- use slash command to toggle config
local slashName = addonName:upper()
_G['SLASH_'..slashName..'1'] = '/'..addonName
_G.SlashCmdList[slashName] = function(args) OpenConfiguration(panel, args) end
