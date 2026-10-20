-- ModernUI: built into the client (not in the original 3.3.5a).
-- Selectable buttons, button groups and minimal tabs, taken from Blizzard's shared UI code (SelectableButton,
-- ButtonGroup, MinimalTab) so AddOns get the real behaviour. The templates are in 90_Templates.xml.

if _G.SelectableButtonMixin then
	return
end

_G.TextureKitConstants = _G.TextureKitConstants or { SetVisibility = true, DoNotSetVisibility = false, UseAtlasSize = true, IgnoreAtlasSize = false }

SelectableButtonMixin = {};

function SelectableButtonMixin:OnLoad()
	self.selected = false;
end

function SelectableButtonMixin:Reset()
	self.CanChangeSelectionOverride = nil;
	self.selected = false;
end

function SelectableButtonMixin:OnClick()
	return self:SetSelected(not self:IsSelected());
end

function SelectableButtonMixin:CanChangeSelection(newSelected)
	if self:IsSelected() == newSelected then
		return false;
	end

	if self.SelectionChangeInterrupt then
		return self.SelectionChangeInterrupt(self, newSelected);
	end

	return true;
end

function SelectableButtonMixin:SetSelectionChangeInterrupt(callback)
	self.SelectionChangeInterrupt = callback;
end

function SelectableButtonMixin:IsSelected()
	return not not self.selected;
end

function SelectableButtonMixin:SetSelected(newSelected)
	if self:CanChangeSelection(newSelected) then
		self:SetSelectedState(newSelected);
		self:OnSelected(newSelected);
	end
end

function SelectableButtonMixin:OnSelected(newSelected)
-- Derive
end

function SelectableButtonMixin:SetSelectedState(newSelected)
	-- Derive
	self.selected = newSelected;
end
--[[
	Required Elements - all buttons in the group need to inherit from SelectableButtonMixin
	and have the OnClick handler defined in XML
]]

ButtonGroupBaseMixin = CreateFromMixins(CallbackRegistryMixin);

ButtonGroupBaseMixin:GenerateCallbackEvents(
	{
		"Selected",
		"Unselected",
	}
);

function ButtonGroupBaseMixin:Init()
	CallbackRegistryMixin.OnLoad(self);
	self.buttons = {};
end

function ButtonGroupBaseMixin:SetShown(shown)
	for index, button in ipairs(self.buttons) do
		button:SetShown(shown);
	end
end

function ButtonGroupBaseMixin:AddButton(button)
	self:AddInternal(button);
end

function ButtonGroupBaseMixin:AddButtons(buttons)
	for buttonIndex, button in ipairs(buttons) do
		self:AddInternal(button);
	end
end

function ButtonGroupBaseMixin:AddInternal(button, func, group)
	table.insert(self.buttons, button);

	-- NOTE: The SelectableButton that this is intended to be used with doesn't actually care about the mouseButton argument.
	local previousOnClickScript = button:GetScript("OnClick");
	assert(not button.previousOnClickScript);
	button.previousOnClickScript = previousOnClickScript;

	button:SetScript("OnClick", function(o, mouseButton)
		-- Only run our group's selection changed callback if the button object didn't have a mixin-OnClick method,
		-- or if the OnClick method indicated that selection state actually changed.
		local wasSelected = button:IsSelected();

		if previousOnClickScript then
			previousOnClickScript(button, mouseButton);
		end

		local isSelected = button:IsSelected();
		local selectionChanged = wasSelected ~= isSelected;

		if not previousOnClickScript or selectionChanged then
			func(group, button, button:IsSelected());
		end
	end);
end

function ButtonGroupBaseMixin:RemoveButton(button)
	self:RemoveInternal(button);
end

function ButtonGroupBaseMixin:RemoveButtons(buttons)
	if buttons == self.buttons then
		self:RemoveAllButtons();
	else
		for buttonIndex, button in ipairs(buttons) do
			self:RemoveInternal(button);
		end
	end
end

function ButtonGroupBaseMixin:RemoveInternal(button)
	tDeleteItem(self.buttons, button);

	-- Restore the button's OnClick to whatever it used to be.
	button:SetScript("OnClick", button.previousOnClickScript);
	button.previousOnClickScript = nil;
end

function ButtonGroupBaseMixin:SetButtons(buttons)
	self:RemoveAllButtons();
	self:AddButtons(buttons);
end

function ButtonGroupBaseMixin:RemoveAllButtons()
	for index, button in ipairs_reverse(self.buttons) do
		self:RemoveInternal(button);
	end
end

function ButtonGroupBaseMixin:GetButtons()
	return self.buttons;
end

function ButtonGroupBaseMixin:Reset()
	self:RemoveAllButtons();
	self:UnregisterEvents();
	self.callbacks = {};
end

function ButtonGroupBaseMixin:FindButtonByPredicate(pred)
	for buttonIndex, button in ipairs(self.buttons) do
		if pred(button) then
			return button;
		end
	end
	return nil;
end

function ButtonGroupBaseMixin:GetButtonsByPredicate(pred)
	local buttons = {};
	for buttonIndex, button in ipairs(self.buttons) do
		if pred(button) then
			table.insert(buttons, button);
		end
	end
	return buttons;
end

function ButtonGroupBaseMixin:Unselect(button)
	self:UnselectAtIndex(self:GetButtonIndex(button));
end

function ButtonGroupBaseMixin:Select(button)
	self:SelectAtIndex(self:GetButtonIndex(button));
end

function ButtonGroupBaseMixin:SelectAtIndex(index)
	self:SetSelectedAtIndex(index, true);
end

function ButtonGroupBaseMixin:UnselectAtIndex(index)
	self:SetSelectedAtIndex(index, false);
end

local function SetButtonSelectedAndGetWasChanged(button, selected)
	local wasSelected = button:IsSelected();
	button:SetSelected(selected);
	return wasSelected ~= button:IsSelected();
end

function ButtonGroupBaseMixin:SetSelectedAtIndex(index, selected)
	local button = self:GetAtIndex(index);
	if button then

		if SetButtonSelectedAndGetWasChanged(button, selected) then
			self:OnSelectionChange(button, selected);
		end
	end
end

function ButtonGroupBaseMixin:GetSelectedButtons()
	return self:GetButtonsByPredicate(
		function(button)
			return button:IsSelected();
		end
	);
end

function ButtonGroupBaseMixin:GetButtonIndex(button)
	return tIndexOf(self.buttons, button);
end

function ButtonGroupBaseMixin:GetAtIndex(index)
	return self.buttons[index];
end

ButtonGroupMixin = CreateFromMixins(ButtonGroupBaseMixin);

function ButtonGroupMixin:OnSelectionChange(button, newSelected)
	local event = newSelected and ButtonGroupBaseMixin.Event.Selected or ButtonGroupBaseMixin.Event.Unselected;
	self:TriggerEvent(event, button, self:GetButtonIndex(button));
end

function ButtonGroupMixin:AddInternal(button)
	ButtonGroupBaseMixin.AddInternal(self, button, self.OnSelectionChange, self);
end

function CreateButtonGroup()
	return CreateAndInitFromMixin(ButtonGroupMixin);
end

RadioButtonGroupMixin = CreateFromMixins(ButtonGroupBaseMixin);

function RadioButtonGroupMixin:CanChangeSelection(button, newSelected)
	return not (not newSelected and #self:GetSelectedButtons() == 1);
end

function RadioButtonGroupMixin:OnSelectionChange(button, newSelected)
	-- Deselect everything that was selected
	for selectedButtonIndex, selectedButton in ipairs(self:GetSelectedButtons()) do
		if selectedButton ~= button then
			selectedButton:SetSelected(false);
			self:TriggerEvent(ButtonGroupBaseMixin.Event.Unselected, selectedButton, self:GetButtonIndex(selectedButton));
		end
	end

	-- Select the new thing if appropriate
	if newSelected then
		self:TriggerEvent(ButtonGroupBaseMixin.Event.Selected, button, self:GetButtonIndex(button));
	else
		self:TriggerEvent(ButtonGroupBaseMixin.Event.Unselected, button, self:GetButtonIndex(button));
	end
end

function RadioButtonGroupMixin:AddInternal(button)
	button:SetSelectionChangeInterrupt(GenerateClosure(self.CanChangeSelection, self));
	ButtonGroupBaseMixin.AddInternal(self, button, self.OnSelectionChange, self);
end

function RadioButtonGroupMixin:RemoveInternal(button)
	button:SetSelectionChangeInterrupt(nil);
	ButtonGroupBaseMixin.RemoveInternal(self, button);
end

DeselectableRadioButtonGroupMixin = CreateFromMixins(RadioButtonGroupMixin);

function DeselectableRadioButtonGroupMixin:CanChangeSelection(button, newSelected)
	return true;
end

--[[
	Required Elements - all buttons in the group need to inherit from SelectableButtonTemplate
	and you CAN override the OnLoad, and OnClick handler if needed
]]--
function CreateRadioButtonGroup()
	return CreateAndInitFromMixin(RadioButtonGroupMixin);
end

function CreateDeselectableRadioButtonGroup()
	return CreateAndInitFromMixin(DeselectableRadioButtonGroupMixin);
end


MinimalTabMixin = {};

function MinimalTabMixin:OnLoad()
	SelectableButtonMixin.OnLoad(self);

	self.Text:SetText(self.tabText);
	self:SetWidth(self.Text:GetStringWidth() + 40);

	self:OnSelected(false);
end

function MinimalTabMixin:GetAtlas()
	if self:IsSelected() then
		return self.selectedLeftTexture, self.selectedRightTexture, self.selectedMiddleTexture;
	end

	if self.over then
		return self.overLeftTexture, self.overRightTexture, self.overMiddleTexture;
	end
	return self.upLeftTexture, self.upRightTexture, self.upMiddleTexture;
end

function MinimalTabMixin:UpdateAtlas()
	local leftAtlas, rightAtlas, middleAtlas = self:GetAtlas();
	self.Left:SetAtlas(leftAtlas, TextureKitConstants.UseAtlasSize);
	self.Right:SetAtlas(rightAtlas, TextureKitConstants.UseAtlasSize);
	self.Middle:SetAtlas(middleAtlas, TextureKitConstants.UseAtlasSize);
end

function MinimalTabMixin:OnSelected(newSelected)
	self:UpdateAtlas();

	if newSelected then
		self.Text:SetPoint("BOTTOM", 0, 6);
		self.Text:SetFontObject("GameFontHighlightSmall");
	else
		self.Text:SetPoint("BOTTOM", 0, 4);
		self.Text:SetFontObject("GameFontNormalSmall");
	end
end

function MinimalTabMixin:OnEnter()
	self:UpdateAtlas();
end

function MinimalTabMixin:OnLeave()
	self:UpdateAtlas();
end

function MinimalTabMixin:OnEnable()
	self:UpdateAtlas();
end

function MinimalTabMixin:OnDisable()
	self:UpdateAtlas();
end
