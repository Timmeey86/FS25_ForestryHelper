---This class allows easier creation of configuration options in the general settings page
---@class UIHelper
UIHelper = {}

---Creates a new section with the given title
---@param generalSettingsPage table @The general settings page of the base game
---@param i18nTitleId string @The I18N ID of the title to be displayed
---@return table|nil @The created section element
function UIHelper.createSection(generalSettingsPage, i18nTitleId)
	local sectionTitle = nil
	for _, elem in ipairs(generalSettingsPage.generalSettingsLayout.elements) do
		if elem.name == "sectionHeader" then
			sectionTitle = elem:clone(generalSettingsPage.generalSettingsLayout)
			sectionTitle:setText(g_i18n:getText(i18nTitleId))
			break
		end
	end
	if sectionTitle then
		sectionTitle.focusId = FocusManager:serveAutoFocusId()
		table.insert(generalSettingsPage.controlsList, sectionTitle)
	end
	return sectionTitle
end

---Sets the focusId properties of the element and any children to a new unique ID each
---@param element table the element
function UIHelper.updateFocusIds(element)
	if not element then
		return
	end
	element.focusId = FocusManager:serveAutoFocusId()
	for _, child in pairs(element.elements) do
		UIHelper.updateFocusIds(child)
	end
end

local function createElement(generalSettingsPage, template, id, i18nTextId, target, callbackFunc)
	local elementBox = template:clone(generalSettingsPage.generalSettingsLayout)
	-- Remove any existing focus IDs as they would not be unique and cause trouble later on
	UIHelper.updateFocusIds(elementBox)

	elementBox.id = id .. "Box"
	-- Assign the object which shall receive change events
	local elementOption = elementBox.elements[1]
	elementOption.target = target
	elementOption:setCallback("onClickCallback", callbackFunc)
	-- WORKAROUND: The target serves two purposes:
	-- 1.) Any callback will be executed on the target object
	-- 2.) The focus manager will ignore anything which has a different target _name_ than the current UI
	-- => Since we want to allow any target for callbacks, we just copy the general settings page's name to the target
	target.name = generalSettingsPage.name
	-- Change generic values
	elementOption.id = id
	elementOption:setDisabled(false)
	-- Change the text element
	local textElement = elementBox.elements[2]
	textElement:setText(g_i18n:getText(i18nTextId .. "_short"))
	-- Change the tooltip
	local toolTip = elementOption.elements[1]
	toolTip:setText(g_i18n:getText(i18nTextId .. "_long"))

	table.insert(generalSettingsPage.controlsList, elementBox)
	return elementBox
end


---Adds a simple yes/no switch to the UI
---@param generalSettingsPage   table       @The base game object for the settings page
---@param id                    string      @The unique ID of the new element
---@param i18nTextId            string      @The key in the internationalization XML (must be two keys with a _short and _long suffix)
---@param target                table       @The object which contains the callback func
---@param callbackFunc          string      @The name of the function to call when the value changes
---@return                      table       @The created object
function UIHelper.createBoolElement(generalSettingsPage, id, i18nTextId, target, callbackFunc)
	return createElement(generalSettingsPage, generalSettingsPage.checkWoodHarvesterAutoCutBox, id, i18nTextId, target, callbackFunc)
end

---Creates an element which allows choosing one out of several text values
---@param generalSettingsPage   table       @The base game object for the settings page
---@param id                    string      @The unique ID of the new element
---@param i18nTextId            string      @The key in the internationalization XML (must be two keys with a _short and _long suffix)
---@param i18nValueMap          table       @An map of values containing translation IDs for the possible values
---@param target                table       @The object which contains the callback func
---@param callbackFunc          string      @The name of the function to call when the value changes
---@return                      table       @The created object
function UIHelper.createChoiceElement(generalSettingsPage, id, i18nTextId, i18nValueMap, target, callbackFunc)
	local choiceElementBox = createElement(generalSettingsPage, generalSettingsPage.multiVolumeVoiceBox, id, i18nTextId, target, callbackFunc)

	local choiceElement = choiceElementBox.elements[1]
	local texts = {}
	for _, valueEntry in pairs(i18nValueMap) do
		table.insert(texts, g_i18n:getText(valueEntry.i18nTextId))
	end
	choiceElement:setTexts(texts)

	return choiceElementBox
end

---Creates an element which allows choosing one out of several integer values
---@param generalSettingsPage   table       @The base game object for the settings page
---@param id                    string      @The unique ID of the new element
---@param i18nTextId            string      @The key in the internationalization XML (must be two keys with a _short and _long suffix)
---@param minValue              integer     @The first value which can be selected
---@param maxValue              integer     @The last value which can be selected
---@param step                  integer     @The difference between any two values. Make sure this matches max value
---@param unit                  string      @The unit to be displayed (may be empty)
---@param target                table       @The object which contains the callback func
---@param callbackFunc          string      @The name of the function to call when the value changes
---@return                      table       @The created object
function UIHelper.createRangeElement(generalSettingsPage, id, i18nTextId, minValue, maxValue, step, unit, target, callbackFunc)
	local rangeElementBox = createElement(generalSettingsPage, generalSettingsPage.multiVolumeVoiceBox, id, i18nTextId, target, callbackFunc)

	local rangeElement = rangeElementBox.elements[1]
	local texts = {}
	local digits = 0
	local tmpStep = step
	while tmpStep < 1 do
		digits = digits + 1
		tmpStep = tmpStep * 10
	end
	local formatTemplate = (".%df"):format(digits)
	for i = minValue, maxValue, step do
		local text = ("%" .. formatTemplate):format(i)
		if unit then
			text = ("%s %s"):format(text, unit)
		end
		table.insert(texts, text)
	end
	rangeElement:setTexts(texts)

	return rangeElementBox
end

---Hooks into the focus manager at just the right point in time to register any relevant controls.
---Make sure you also supply your section headers here!
---@param controls table @A list of controls
function UIHelper.registerFocusControls(controls)
	FocusManager.setGui = Utils.appendedFunction(FocusManager.setGui, function(_, gui)
		for _, control in ipairs(controls) do
			if not control.focusId or not FocusManager.currentFocusData.idToElementMapping[control.focusId] then
				if not FocusManager:loadElementFromCustomValues(control, nil, nil, false, false) then
					Logging.warning("Failed loading focus element for %s. Keyboard/controller menu navigation might be bugged.", control.id or control.name)
				end
			end
		end
		local settingsPage = g_gui.screenControllers[InGameMenu].pageSettings
		-- Invalidate the layout in order to relink items properly
		settingsPage.generalSettingsLayout:invalidateLayout()
	end)
end