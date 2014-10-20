local addonName, addon, _ = ...
_G[addonName] = LibStub('AceAddon-3.0'):NewAddon(addon, addonName, 'AceEvent-3.0')

-- GLOBALS: _G, LibStub, Auctional, TopFit, GameTooltip, Atr_ShowTipWithPricing, TradeSkillListScrollFrame, TradeSkillSkillName, TradeSkillFilterBar
-- GLOBALS: IsAddOnLoaded, CreateFrame, GetCoinTextureString, GetItemInfo, IsModifiedClick, GetSpellInfo, GetProfessionInfo, GetTradeSkill, GetTradeSkillInfo, GetTradeSkillItemLink, GetAuctionBuyout, GetTradeSkillRecipeLink, GetTradeSkillReagentInfo, GetTradeSkillReagentItemLink, FauxScrollFrame_GetOffset, DressUpItemLink, IsEquippableItem, GameTooltip_ShowCompareItem, GetCVarBool, GetTradeSkillNumReagents
-- GLOBALS: string, pairs, type, select, hooksecurefunc, tonumber, floor, gsub

-- convenient and smart tooltip handling
function addon.ShowTooltip(self, anchor)
	if not self.tiptext and not self.link then return end
	GameTooltip:SetOwner((anchor and type(anchor) == 'table') and anchor or self, 'ANCHOR_RIGHT')
	GameTooltip:ClearLines()

	if self.link then
		GameTooltip:SetHyperlink(self.link)
	elseif type(self.tiptext) == 'string' and self.tiptext ~= "" then
		GameTooltip:SetText(self.tiptext, nil, nil, nil, nil, true)
		local lineIndex = 2
		while self['tiptext'..lineIndex] do
			if self['tiptext'..lineIndex..'Right'] then
				GameTooltip:AddDoubleLine(self['tiptext'..lineIndex], self['tiptext'..lineIndex..'Right'], 1, 1, 1, 1, 1, 1)
			else
				GameTooltip:AddLine(self['tiptext'..lineIndex], 1, 1, 1, nil, true)
			end
			lineIndex = lineIndex + 1
		end
	elseif type(self.tiptext) == 'function' then
		self.tiptext(self, GameTooltip)
	end
	GameTooltip:Show()
end
function addon.HideTooltip() GameTooltip:Hide() end

function addon.GetLinkID(link)
	if not link or type(link) ~= "string" then return end
	local linkType, id = link:match("\124H([^:]+):([^:\124]+)")
	if not linkType then
		linkType, id = link:match("([^:\124]+):([^:\124]+)")
	end
	return tonumber(id), linkType
end

function addon.GlobalStringToPattern(str)
	str = gsub(str, "([%(%)])", "%%%1")
	str = gsub(str, "%%%d?$?c", "(.+)")
	str = gsub(str, "%%%d?$?s", "(.+)")
	str = gsub(str, "%%%d?$?d", "(%%d+)")
	return str
end

function addon:OnInitialize()
	self.db = LibStub('AceDB-3.0'):New(addonName..'DB', {
		profile = {
			skillUpLevels   = true,
			profitIndicator = true,
			listTooltips    = true,
			customSearch    = true,
			scanRecipes     = true,
			autoScanRecipes = false,
		},
	}, true)

	-- setup ldb launcher
	--[[ self.ldb = LibStub:GetLibrary('LibDataBroker-1.1'):NewDataObject(addonName, {
		type  = 'launcher',
		icon  = 'Interface\\Icons\\ACHIEVEMENT_GUILDPERK_MRPOPULARITY_RANK2',
		label = addonName,

		OnClick = function(button, btn, up)
			if btn == 'RightButton' then
				-- open config
				-- InterfaceOptionsFrame_OpenToCategory(self.options)
			else
				ToggleFrame(self.frame)
			end
		end,
	}) --]]
end

local tradeSkills = {
	[2259] 	= "Alchemy",
	[2018] 	= "Blacksmithing",
	[7411] 	= "Enchanting",
	[4036] 	= "Engineering",
	[13614] = "Herbalism",		-- actually 2366 but this has the correct skill name
	[45357] = "Inscription",
	[25229] = "Jewelcrafting",
	[2108] 	= "Leatherworking",
	[2575] 	= "Mining",
	[8613] 	= "Skinning",
	[3908] 	= "Tailoring",

	[78670]	= "Archaeology",
	[2550] 	= "Cooking",
	[3273] 	= "First Aid",
	[7620] 	= "Fishing",
}
local skillColors = {
	[1] = "|cffFF8040",		-- orange
	[2] = "|cffFFFF00",		-- yellow
	[3] = "|cff40BF40",		-- green
	[4] = "|cff808080", 	-- gray
}
local function GetTradeSkill(skill)
	if not skill then return end
	if type(skill) == "number" then
		skill = GetProfessionInfo(skill)
	end
	for spellID, skillName in pairs(tradeSkills) do
		if ( GetSpellInfo(spellID) ) == skill then
			return skillName
		end
	end
	return nil
end
local function GetTradeSkillColoredString(orange, yellow, green, gray)
	return string.format("|cffFF8040%s|r/|cffFFFF00%s|r/|cff40BF40%s|r/|cff808080%s|r",
		orange or "", yellow or "", green or "", gray or "")
end

local LPT = LibStub('LibPeriodicTable-3.1', true)
local function AddTradeSkillLevels(id)
	if not addon.db.profile.skillUpLevels then return end

	local tradeskill = _G.CURRENT_TRADESKILL
		  tradeskill = GetTradeSkill(tradeskill)
	local recipe = GetTradeSkillItemLink(id)
		  recipe = tonumber(select(3, string.find(recipe or "", "-*:(%d+)[:|].*")) or "")
	if not recipe then return end

	local setName = "TradeskillLevels"..(tradeskill and "."..tradeskill or "")
	if LPT and LPT.sets[setName] then
		for item, value, set in LPT:IterateSet(setName) do
			if item == recipe or item == -1 * recipe then
				local newText = ( GetTradeSkillInfo(id) ) .. "\n" .. GetTradeSkillColoredString(string.split("/", value))
				TradeSkillSkillName:SetText(newText)
				break
			end
		end
	end
end

local function AddTradeSkillInfoIcon(line)
	local button = CreateFrame("Button", "$parentInfoIcon", line)
	button:SetSize(12, 12)
	button:SetNormalTexture("Interface\\COMMON\\Indicator-Gray")
	button:SetPoint("TOPLEFT", 0, -2)
	button:Hide()

	button:SetScript("OnEnter", addon.ShowTooltip)
	button:SetScript("OnLeave", addon.HideTooltip)

	line.infoIcon = button
	return button
end

local function AddTradeSkillLineReagentCost(message, button, skillIndex, selected, isGuild)
	if not addon.db.profile.profitIndicator then return end

	local _, skillType = GetTradeSkillInfo(skillIndex)
	if not skillType or (skillType ~= "optimal" and skillType ~= "medium" and skillType ~= "easy") then
		if button.infoIcon then button.infoIcon:Hide() end
	else
		local craftPrice = 0
		for reagentIndex = 1, GetTradeSkillNumReagents(skillIndex) do
			local _, _, amount = GetTradeSkillReagentInfo(skillIndex, reagentIndex)
			local reagent = GetTradeSkillReagentItemLink(skillIndex, reagentIndex)
			      reagent = addon.GetLinkID(reagent)

			if reagent then
				local reagentPrice = 0
				if LPT and LPT:ItemInSet(reagent, "Tradeskill.Mat.BySource.Vendor") then
					reagentPrice = 4 * (select(11, GetItemInfo(reagent)) or 0)
				else
					-- TODO: what about BoP things?
					reagentPrice = GetAuctionBuyout and GetAuctionBuyout(reagent) or 0
				end
				reagentPrice = reagentPrice * amount
				craftPrice   = craftPrice + reagentPrice
			end
		end

		local craftedItem  = GetTradeSkillItemLink(skillIndex)
		local craftedValue = craftedItem and GetAuctionBuyout and GetAuctionBuyout(craftedItem) or 0

		if craftPrice > 0 and craftedValue > 0 then
			local infoIcon = button.infoIcon or AddTradeSkillInfoIcon(button)
			      infoIcon.tiptext = string.format('%s %s\n%s: %s', _G.COSTS_LABEL, GetCoinTextureString(craftPrice), _G.SELL_PRICE, GetCoinTextureString(craftedValue))

			local difference = craftedValue - craftPrice
			if difference > 0 then
				infoIcon.tiptext = infoIcon.tiptext .. "\n"..string.format(_G.LOOT_ROLL_YOU_WON, GetCoinTextureString(difference))
				if craftPrice > 0 and difference / craftPrice > 0.2 and difference > 500000 then
					infoIcon:SetNormalTexture('Interface\\COMMON\\Indicator-Green')
				else
					infoIcon:SetNormalTexture('Interface\\COMMON\\Indicator-Yellow')
				end
			else
				infoIcon:SetNormalTexture('Interface\\COMMON\\Indicator-Red')
			end
			infoIcon:Show()
		elseif button.infoIcon then
			button.infoIcon:Hide()
		end

		--[[ if craftPrice > 0 then
			name = _G["TradeSkillSkill"..lineIndex]:GetText()
			if name then
				_G["TradeSkillSkill"..lineIndex]:SetText(name .. " "..GetCoinTextureString(floor(craftPrice/1000)*1000))
			end
		end --]]
	end
end

local function AddTradeSkillReagentCosts()
	if not addon.db.profile.profitIndicator then return end

	local skillIndex, reagentIndex, reagent, amount, name, lineIndex, skillType
	local craftedItem, craftedValue, infoIcon, difference
	local reagentPrice, craftPrice

	local hasFilterBar = TradeSkillFilterBar:IsShown()
	local displayedSkills = hasFilterBar and (_G.TRADE_SKILLS_DISPLAYED - 1) or _G.TRADE_SKILLS_DISPLAYED
	local offset = FauxScrollFrame_GetOffset(TradeSkillListScrollFrame)
	for line = 1, displayedSkills do
		skillIndex = line + offset
		lineIndex = line + (hasFilterBar and 1 or 0)

		local button = _G['TradeSkillSkill'..lineIndex]
		AddTradeSkillLineReagentCost('TRADE_SKILL_ROW_UPDATE', button, skillIndex)
		-- addon:SendMessage('TRADE_SKILL_ROW_UPDATE', button, skillIndex)
	end
end

local function AddTradeSkillHoverLink(self)
	if not addon.db.profile.listTooltips then return end

	local ID = self:GetID()
	local recipeLink = ID and GetTradeSkillRecipeLink(ID)
	local result = GetTradeSkillItemLink(ID)

	if result and recipeLink then
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")

		if IsEquippableItem(result) then
			GameTooltip:SetHyperlink(result)
			if IsModifiedClick("COMPAREITEMS") or (GetCVarBool("alwaysCompareItems") and not GameTooltip:IsEquippedItem()) then
				GameTooltip_ShowCompareItem(GameTooltip, true)
			end
		end
		GameTooltip:SetHyperlink(recipeLink)

		if Atr_ShowTipWithPricing then
			GameTooltip:AddLine(" ")
			Atr_ShowTipWithPricing(GameTooltip, result, 1)
		elseif IsAddOnLoaded("Auctional") then
			Auctional.ShowSimpleTooltipData(GameTooltip, result)
		end
		if IsAddOnLoaded("TopFit") and TopFit.TooltipAddCompareLines then
			TopFit.TooltipAddCompareLines(GameTooltip, result)
		end
		GameTooltip:Show()

		if not self.touched then
			self:HookScript("OnClick", function(self)
				if IsModifiedClick("DRESSUP") then
					DressUpItemLink(result)
				end
			end)
			self.touched = true
		end
	end
end

function addon:OnEnable()
	hooksecurefunc("TradeSkillFrame_Update", AddTradeSkillReagentCosts)
	self:RegisterMessage('TRADE_SKILL_ROW_UPDATE', AddTradeSkillLineReagentCost)
	hooksecurefunc("TradeSkillFrame_SetSelection", AddTradeSkillLevels)
	hooksecurefunc("TradeSkillFrameButton_OnEnter", AddTradeSkillHoverLink)
	hooksecurefunc("TradeSkillFrameButton_OnLeave", addon.HideTooltip)
end
