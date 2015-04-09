local addonName, addon, _ = ...

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

	-- variant A: load configuration addon
	--[[ local success, reason = LoadAddOn(addonName..'_Config')
	if success then
		-- CloseAllWindows()
		InterfaceOptionsFrame_OpenToCategory(addonName)
	end --]]

	-- variant B: directly initialize panel
	-- LibStub('LibDualSpec-1.0'):EnhanceDatabase(addon.db, addonName)
	LibStub('AceConfig-3.0'):RegisterOptionsTable(addonName, {
		type = 'group',
		args = {
			general  = LibStub('LibOptionsGenerate-1.0'):GetOptionsTable(addon.db, nil, nil, true),
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
