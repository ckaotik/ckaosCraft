-- enlarges and enhances the recipe book so you can see what you do
local addonName, addon, _ = ...
local recipebook = addon:NewModule('RecipeBook', 'AceEvent-3.0')

-- GLOBALS: _G, LibStub, TRADE_SKILLS_DISPLAYED
-- GLOBALS: CreateFrame, PlaySound, TradeSkillOnlyShowMakeable, TradeSkillOnlyShowSkillUps, TradeSkillUpdateFilterBar
-- GLOBALS: hooksecurefunc, pairs, select
local floor = math.floor

local function UpdateScrollFrameWidth(self)
	local scrollFrame = self:GetParent()
	local skillName, _, reqText, _, headerLeft, _, description, _ = scrollFrame:GetScrollChild():GetRegions()
	if self:IsShown() then
		scrollFrame:SetPoint('BOTTOMRIGHT', -32, 28)
		headerLeft:SetTexCoord(0, 0.5, 0, 1)
	else
		scrollFrame:SetPoint('BOTTOMRIGHT', -5, 28)
		headerLeft:SetTexCoord(0, 0.6, 0, 1)
	end
	local newWidth = scrollFrame:GetWidth()
	scrollFrame:GetScrollChild():SetWidth(newWidth)
	scrollFrame:UpdateScrollChildRect()

	-- text don't stretch properly without fixed width
	description:SetWidth(newWidth - 5)
	  skillName:SetWidth(newWidth - 50)
	    reqText:SetWidth(newWidth - 5)
end

local function OnTradeSkillFrame_SetSelection(index)
	local scrollFrame = _G.TradeSkillDetailScrollFrame
	      scrollFrame:SetVerticalScroll(0)
	local skillName, reqLabel, reqText, cooldown, headerLeft, headerRight, description, reagentLabel = scrollFrame:GetScrollChild():GetRegions()

	if description:GetText() == ' ' then description:SetText(nil) end
	if not cooldown:GetText() then cooldown:SetHeight(-10) end

	-- add a section for required items
	reqLabel:SetTextColor(reagentLabel:GetTextColor())
	reqLabel:SetShadowColor(reagentLabel:GetShadowColor())
	cooldown:ClearAllPoints()
	cooldown:SetPoint('TOPLEFT', description, 'BOTTOMLEFT', 0, -10)
	reqLabel:SetPoint('TOPLEFT', cooldown, 'BOTTOMLEFT', 0, -10)
	reqText:SetPoint('TOPLEFT', reqLabel, 'BOTTOMLEFT', 0, 0)
	reagentLabel:SetPoint('TOPLEFT', reqText, 'BOTTOMLEFT', 0, -10)

	-- TODO: display reagent tooltip only when hovering item (via :SetHitRectInsets(left, right, top, bottom))
end

--[[ Size references:
	ReforgingFrame  => 428 x 430
	TradeSkillFrame => 540 x 468
	PaperDollFrame  => 540 x 424
--]]
local function InitializeTradeSkillFrame()
	local frame = _G.TradeSkillFrame
	      frame:SetSize(540, 450)

	-- recipe list area
	local list = _G.TradeSkillListScrollFrame
	      list:ClearAllPoints()
	      list:SetPoint('TOPLEFT', 0, -83)
	      list:SetPoint('BOTTOMRIGHT', '$parent', 'BOTTOMLEFT', 300, 28)

	-- create additional rows since scroll frame area grew
	local numRows = floor((frame:GetHeight() - 83 - 28) / _G.TRADE_SKILL_HEIGHT)
	for index = TRADE_SKILLS_DISPLAYED+1, numRows do
		local row = CreateFrame('Button', 'TradeSkillSkill'..index, frame, 'TradeSkillSkillButtonTemplate', index)
		      row:SetPoint('TOPLEFT', _G['TradeSkillSkill'..(index-1)], 'BOTTOMLEFT')
		      row.skillup:Hide()
		      row.SubSkillRankBar:Hide()
		      row:SetNormalTexture('')
		_G['TradeSkillSkill'..index..'Highlight']:SetTexture('')
	end
	_G.TRADE_SKILLS_DISPLAYED = numRows

	-- previewing created items
	for index = 1, TRADE_SKILLS_DISPLAYED do
		_G['TradeSkillSkill'..index]:HookScript('OnClick', function(self)
			local result = GetTradeSkillItemLink(self:GetID())
			if IsEquippableItem(result) and IsModifiedClick('DRESSUP') then
				DressUpItemLink(result)
			end
		end)
	end

	-- detail/reagent panel
	local details = _G.TradeSkillDetailScrollFrame
	      details:ClearAllPoints()
	      details:SetPoint('TOPLEFT', list, 'TOPRIGHT', 28, 0)
	      details:SetPoint('BOTTOMRIGHT', -5, 28)
	details.ScrollBar:HookScript('OnShow', UpdateScrollFrameWidth)
	details.ScrollBar:HookScript('OnHide', UpdateScrollFrameWidth)

	-- hide top-bottom separator
	local sepLeft, sepRight = select(21, frame:GetRegions())
	sepLeft:Hide(); sepRight:Hide()

	-- move bottom action buttons
	_G.TradeSkillCreateAllButton:SetPoint('BOTTOMLEFT', 'TradeSkillCreateButton', 'BOTTOMLEFT', -167, 0)

	-- stretching the scroll bars
	for _, scrollFrame in pairs({list, details}) do
		local topScrollBar, bottomScrollBar = scrollFrame:GetRegions()
		local middleScrollBar = scrollFrame:CreateTexture(scrollFrame:GetName()..'Middle', 'BACKGROUND')
		      middleScrollBar:SetTexture('Interface\\PaperDollInfoFrame\\UI-Character-ScrollBar')
		      middleScrollBar:SetTexCoord(0, 0.46875, 0.03125, 0.9609375)
		      middleScrollBar:SetPoint('TOPLEFT', topScrollBar, 'TOPLEFT', 1, 0)
		      middleScrollBar:SetPoint('BOTTOMRIGHT', bottomScrollBar, 'TOPRIGHT', 0, 0)
	end

	-- sidebar/craft details changes
	local background = details:CreateTexture(nil, 'BACKGROUND')
	      background:SetTexture('Interface\\ACHIEVEMENTFRAME\\UI-ACHIEVEMENT-PARCHMENT')
	      background:SetTexCoord(0.5, 1, 0, 1)
	      background:SetAllPoints()


	local skillName, reqLabel, reqText, cooldown, headerLeft, headerRight, description, reagentLabel = details:GetScrollChild():GetRegions()
	headerRight:ClearAllPoints()
	headerRight:SetPoint('TOPRIGHT', 20-5, 3-5)
	headerLeft:SetPoint('BOTTOMRIGHT', headerRight, 'BOTTOMLEFT')
	headerLeft:SetTexCoord(0, 0.6, 0, 1)
	for _, region in pairs({headerLeft, _G.TradeSkillSkillIcon, skillName}) do
		local point, relativeTo, relativePoint, xOffset, yOffset = region:GetPoint()
		region:SetPoint(point, relativeTo, relativePoint, xOffset + 2, yOffset - 5)
	end

	local sideBarWidth = details:GetWidth()
	skillName:SetNonSpaceWrap(true)
	skillName:SetWidth(sideBarWidth - 50)
	description:SetNonSpaceWrap(true)
	description:SetWidth(sideBarWidth - 5)
	description:SetPoint('TOPLEFT', 5, -55)
	reqText:SetWidth(sideBarWidth - 5)

	-- move reagents below one another and widen buttons
	for index = 1, _G.MAX_TRADE_SKILL_REAGENTS do
		local button = _G['TradeSkillReagent'..index]
		local nameFrame = _G['TradeSkillReagent'..index..'NameFrame']
		      nameFrame:SetPoint('RIGHT', 3, 0)
		local itemName = button.name or button.Name
		      itemName:SetPoint('LEFT', nameFrame, 'LEFT', 20, 0)
		      itemName:SetPoint('RIGHT', nameFrame, 'RIGHT', -5, 0)
		if index ~= 1 then
			button:ClearAllPoints()
			button:SetPoint('TOPLEFT', _G['TradeSkillReagent'..(index-1)], 'BOTTOMLEFT', 0, -2)
		end
		local _, _, _, _, yOffset = button:GetPoint()
		button:SetPoint('TOPRIGHT', 0+5, yOffset)
	end

	-- add search hints and basic improvements
	local searchBox = _G.TradeSkillFrameSearchBox
	      searchBox.tiptext = 'Search in recipe, item or reagent names or in item descriptions.\nitem level ± 2: "~123"\nitem level range: "123 - 456"'
	      searchBox.searchIcon = _G.TradeSkillFrameSearchBoxSearchIcon
	searchBox:SetScript('OnEnter', addon.ShowTooltip)
	searchBox:SetScript('OnLeave', addon.HideTooltip)
	searchBox:SetScript('OnEditFocusLost',   _G.SearchBoxTemplate_OnEditFocusLost)
	searchBox:SetScript('OnEditFocusGained', _G.SerachBoxTemplate_OnEditFocusGained)

	-- add missing clear search button
	local clearButton = CreateFrame('Button', '$parentClearButton', searchBox)
	      clearButton:SetSize(17, 17)
	      clearButton:SetPoint('RIGHT', -3, 0)
	      clearButton:Hide()
	clearButton:SetScript('OnEnter', function(self) self.texture:SetAlpha(1) end)
	clearButton:SetScript('OnLeave', function(self) self.texture:SetAlpha(0.5) end)
	clearButton:SetScript('OnClick', function(self, btn, up)
		PlaySound('igMainMenuOptionCheckBoxOn')
		local editBox = self:GetParent()
		      editBox:SetText('')
		      editBox:ClearFocus()
		if editBox.clearFunc then editBox.clearFunc(editBox) end
		if not editBox:HasFocus() then editBox:GetScript('OnEditFocusLost')(editBox) end
	end)
	local clearIcon = clearButton:CreateTexture(nil, 'OVERLAY')
	      clearIcon:SetTexture('Interface\\FriendsFrame\\ClearBroadcastIcon')
	      clearIcon:SetAllPoints()
	      clearIcon:SetAlpha(0.5)
	clearButton.texture = clearIcon
	searchBox.clearButton = clearButton

	-- add quick filters
	local hasMaterials = CreateFrame('CheckButton', '$parentHasMaterials', frame, 'UICheckButtonTemplate')
	      hasMaterials:SetPoint('LEFT', 'TradeSkillLinkButton', 'RIGHT', 10, 0)
	      hasMaterials:SetSize(24, 24)
	local hasMatLabel = hasMaterials:CreateFontString(nil, nil, 'GameFontNormal')
	      hasMatLabel:SetPoint('LEFT', hasMaterials, 'RIGHT', 2, 0)
	      hasMatLabel:SetText(_G.CRAFT_IS_MAKEABLE)
	      hasMaterials:SetHitRectInsets(-5, -10 - hasMatLabel:GetStringWidth(), -2, -2)
	hooksecurefunc('TradeSkillOnlyShowMakeable', function(enable) hasMaterials:SetChecked(enable) end)
	hasMaterials:SetScript('OnClick', function(self, btn, up)
		local enable = self:GetChecked()
		frame.filterTbl.hasMaterials = enable
		TradeSkillOnlyShowMakeable(enable)
		TradeSkillUpdateFilterBar()
	end)
	local hasSkillUp = CreateFrame('CheckButton', '$parentHasSkillUp', frame, 'UICheckButtonTemplate')
	      hasSkillUp:SetPoint('TOPLEFT', '$parentHasMaterials', 'BOTTOMLEFT', 0, -2)
	      hasSkillUp:SetSize(24, 24)
	local hasSkillLabel = hasSkillUp:CreateFontString(nil, nil, 'GameFontNormal')
	      hasSkillLabel:SetPoint('LEFT', hasSkillUp, 'RIGHT', 2, 0)
	      hasSkillLabel:SetText(_G.TRADESKILL_FILTER_HAS_SKILL_UP)
	      hasSkillUp:SetHitRectInsets(-5, -10 - hasSkillLabel:GetStringWidth(), -2, -2)
	hooksecurefunc('TradeSkillOnlyShowSkillUps', function(enable) hasSkillUp:SetChecked(enable) end)
	hasSkillUp:SetScript('OnClick', function(self, btn, up)
		local enable = self:GetChecked()
		frame.filterTbl.hasSkillUp  = enable
		TradeSkillOnlyShowSkillUps(enable)
		TradeSkillUpdateFilterBar()
	end)
	frame.hasMaterials, frame.hasSkillUp = hasMaterials, hasSkillUp
	hooksecurefunc('TradeSkillUpdateFilterBar', function(subName, slotName, ignore)
		if ignore then return end
		-- don't list "hasMaterials" or "hasSkillUp" in the filter bar
		local hasMaterials, hasSkillUp = frame.filterTbl.hasMaterials, frame.filterTbl.hasSkillUp
		frame.filterTbl.hasMaterials = false
		frame.filterTbl.hasSkillUp   = false
		TradeSkillUpdateFilterBar(subName, slotName, true)
		frame.filterTbl.hasMaterials = hasMaterials
		frame.filterTbl.hasSkillUp   = hasSkillUp
	end)
end

function recipebook:OnEnable()
	self:RegisterEvent('TRADE_SKILL_SHOW')
end

function recipebook:OnDisable()
	self:UnregisterEvent('TRADE_SKILL_SHOW')
end

function recipebook:TRADE_SKILL_SHOW(event, ...)
	InitializeTradeSkillFrame()
	hooksecurefunc('TradeSkillFrame_SetSelection', OnTradeSkillFrame_SetSelection)
	self:UnregisterEvent('TRADE_SKILL_SHOW')
end
