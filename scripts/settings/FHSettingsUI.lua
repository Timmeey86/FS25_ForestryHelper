---This file allows configuring the Forestry Helper settings within the ingame settings menu
---@class FHSettingsUI
---@field private settings FHSettings @The settings object
---@field groupTitle table @The group title in the settings UI
---@field lengthFactorMode table @The UI control for the length factor mode
---@field lengthFactorAbs table @The UI control for the absolute length factor value
---@field lengthFactorRel table @The UI control for the relative length factor value
FHSettingsUI = {
	I18N_IDS = {
		GROUP_TITLE = "fh_group_title",
		LENGTH_FACTOR_MODE = "fh_length_factor_mode",
		LENGTH_FACTOR_ABS = "fh_length_factor_abs",
		LENGTH_FACTOR_REL = "fh_length_factor_rel"
	},
	LENGTH_FACTOR_MODE_I18N_IDS = {
		{ index = 1, i18nTextId = "fh_length_factor_mode_abs" },
		{ index = 2, i18nTextId = "fh_length_factor_mode_rel" }
	}
}

local FHSettingsUI_mt = Class(FHSettingsUI)
---Creates the UI part of the Forestry Helper settings
---@return FHSettingsUI @The new instance
function FHSettingsUI.new()
	local self = setmetatable({}, FHSettingsUI_mt)
	return self
end

---Extends the settings page with our own controls
---@param settings FHSettings @The settings
function FHSettingsUI.injectUiSettings(settings)

	local inGameMenu = g_gui.screenControllers[InGameMenu]
	local settingsPage = inGameMenu.pageSettings

	if settingsPage.forestryHelperSettings ~= nil then
		return
	end

	local fhSettingsUI = FHSettingsUI.new()

	-- Create a text for the title
	fhSettingsUI.groupTitle = UIHelper.createSection(settingsPage, FHSettingsUI.I18N_IDS.GROUP_TITLE)

	-- Create a UI element for chosing the length factor mode
	fhSettingsUI.lengthFactorMode = UIHelper.createChoiceElement(
		settingsPage,
		"fh_lengthFactorMode",
		FHSettingsUI.I18N_IDS.LENGTH_FACTOR_MODE,
		FHSettingsUI.LENGTH_FACTOR_MODE_I18N_IDS,
		fhSettingsUI,
		"onLengthFactorModeChanged")

	-- Create two UI elements for the length factor, those will be switched out later in accordance with the selected mode
	fhSettingsUI.lengthFactorAbs = UIHelper.createRangeElement(
		settingsPage,
		"fh_lengthFactorAbs",
		FHSettingsUI.I18N_IDS.LENGTH_FACTOR_ABS,
		FHSettings.LENGTH_FACTOR_ABS_MIN, FHSettings.LENGTH_FACTOR_ABS_MAX, FHSettings.LENGTH_FACTOR_ABS_STEP,
		g_i18n:getText("unit_mShort"),
		fhSettingsUI,
		"onAbsFactorChanged")
	fhSettingsUI.lengthFactorRel = UIHelper.createRangeElement(
		settingsPage,
		"fh_lengthFactorRel",
		FHSettingsUI.I18N_IDS.LENGTH_FACTOR_REL,
		FHSettings.LENGTH_FACTOR_REL_MIN, FHSettings.LENGTH_FACTOR_REL_MAX, FHSettings.LENGTH_FACTOR_REL_STEP,
		"%",
		fhSettingsUI,
		"onRelFactorChanged")

	-- Apply the initial values
	fhSettingsUI.settings = settings
	fhSettingsUI:updateUiElements()

	UIHelper.registerFocusControls({fhSettingsUI.groupTitle, fhSettingsUI.lengthFactorMode, fhSettingsUI.lengthFactorAbs, fhSettingsUI.lengthFactorRel})
	settingsPage.generalSettingsLayout:invalidateLayout()

	-- Remember values for future calls
	settingsPage.forestryHelperSettings = fhSettingsUI
end

InGameMenuSettingsFrame.onFrameOpen = Utils.appendedFunction(InGameMenuSettingsFrame.onFrameOpen, function()
	local settingsPage = g_gui.screenControllers[InGameMenu].pageSettings
	if settingsPage.forestryHelperSettings then
		local fhSettingsUI = settingsPage.forestryHelperSettings
		fhSettingsUI:updateUiElements()
	end
end)

---Updates the UI elements to the reflect the current settings
function FHSettingsUI:updateUiElements()
	print(MOD_NAME .. ": Updating UI elements")
		-- Reflect the current settings state in the UI
	self.lengthFactorMode.elements[1]:setState(self.settings.lengthFactorMode)
	local isAbsMode = self.settings.lengthFactorMode == FHSettings.LENGTH_FACTOR_TYPE_ABS

	-- TODO: Disabling messes with the focus manager too much
	--self.lengthFactorAbs:setDisabled(not isAbsMode)
	self.lengthFactorAbs.elements[1]:setState(self.settings.lengthFactorAbsIndex)

	--self.lengthFactorRel:setDisabled(isAbsMode)
	self.lengthFactorRel.elements[1]:setState(self.settings.lengthFactorRelIndex)
end

---Reacts to changes of the length factor mode
---@param newState number @The new state
function FHSettingsUI:onLengthFactorModeChanged(newState)
	self.settings.lengthFactorMode = newState
	-- Update dependent fields
	self:updateUiElements()
	self.settings.cutPositionIndicator:updateF1MenuTexts()
end
---Reacts to changes of the absolute length factor
---@param newState number @The new state
function FHSettingsUI:onAbsFactorChanged(newState)
	self.settings.lengthFactorAbsIndex = newState
	self.settings.cutPositionIndicator:updateF1MenuTexts()
end
---Reacts to changes of the relative length factor
---@param newState number @The new state
function FHSettingsUI:onRelFactorChanged(newState)
	self.settings.lengthFactorRelIndex = newState
	self.settings.cutPositionIndicator:updateF1MenuTexts()
end
