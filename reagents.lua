-- easily craft reagents right from the tradeskill
local addonName, addon, _ = ...
local reagents = addon:NewModule('Reagents')

-- GLOBALS: _G, LibStub
function reagents:OnEnable()
	--[[ self.db = addon.db:RegisterNamespace('Recipes', {
		char = {
			craftables = {},
		},
	}) --]]
end
