---This class is responsible for displaying an indicator for the desired cut position
---Most of this code was created by taking a look at the LUADOC for the chainsaw class and see where it uses the ringSelector
---@class CutPositionIndicator
---@field ring number @The ID of our own 3d ring used to indicate the target cut position
---@field loadRequestId number @The ID of the request to load our own 3d ring
---@field chainsawIsDeleted boolean @True if the chainsaw was deleted
---@field lengthActionEventId number @The event ID for the "change cut length" action
---@field weightActionEventId number @The event ID for the "change cut weight" action
---@field modeActionEventId number @The event ID for the "change cut mode" action
---@field indicationLength number @The desired cut length in meters
---@field weightLimit number @The desired weight in kg
---@field indicatorMode number @The currently selected indicator mode (length or weight)
---@field chainsawIsSnapped boolean @True if the chainsaw is currently snapped
---@field debugPositionDetection boolean @True if position detection shall be debugged
---@field debugIndicator boolean @True if the cut indicator shall be debugged
---@field traceHooks boolean @True if method injection shall be traced
CutPositionIndicator = {
    -- Constants for translations
    I18N_IDS = {
        DESIRED_LENGTH = 'fh_desired_length',
        WEIGHT_LIMIT = 'fh_weight_limit',
        INDICATOR_MODE = 'fh_indicator_mode',
        MODE_OFF = 'fh_mode_off',
        MODE_LENGTH = 'fh_mode_length',
        MODE_WEIGHT = 'fh_mode_weight'
    },
    INDICATOR_MODE = {
        OFF = 0,
        LENGTH = 1,
        WEIGHT = 2
    },
    ACTION_NAMES = {
        SWITCH_INDICATOR_MODE = "SWITCH_INDICATOR_MODE",
        CYCLE_LENGTH_INDICATOR = "CYCLE_LENGTH_INDICATOR",
        CYCLE_WEIGHT_INDICATOR = "CYCLE_WEIGHT_INDICATOR"
    }
}

local CutPositionIndicator_mt = Class(CutPositionIndicator)

---Creates a new cut position indicator (handler)
---@return CutPositionIndicator @The new object
function CutPositionIndicator.new()
    local self = setmetatable({}, CutPositionIndicator_mt)

    self.ring = nil
    self.loadRequestId = nil
    self.chainsawIsDeleted = false
    self.lengthActionEventId = nil
    self.weightActionEventId = nil
    self.modeActionEventId = nil
    self.indicationLength = 1
    self.weightLimit = 200
    self.indicatorMode = CutPositionIndicator.INDICATOR_MODE.LENGTH
    self.chainsawIsSnapped = false

    self.debugPositionDetection = false
    self.debugIndicator = false
    self.traceHooks = false
    return self
end

---Deletes our own ring before the chainsaw gets deleted
---@param chainsaw table @The chainsaw which will be deleted afterwards
function CutPositionIndicator:before_chainsawDelete(chainsaw)
    if self.traceHooks then
        print(MOD_NAME .. "before_chainsawDelete")
    end
    if chainsaw.carryingPlayer and chainsaw.carryingPlayer == g_localPlayer then
        if self.ring ~= nil then
            delete(self.ring)
            self.ring = nil
        end
        if self.loadRequestId ~= nil then
            g_i3DManager:releaseSharedI3DFile(self.loadRequestId)
            self.loadRequestId = nil
        end
        -- Our object doesn't get deleted, just the chainsaw
        self.chainsawIsDeleted = true
    end
end

---Enables context menu actions when the chainsaw gets activated
---@param chainsaw table @The chainsaw
function CutPositionIndicator:after_chainsawOnHeldStart(chainsaw)
    if self.traceHooks then
        print(MOD_NAME .. ": after_chainsawOnHeldStart")
    end
    if chainsaw.carryingPlayer and chainsaw.carryingPlayer == g_localPlayer then
        --- Register menu actions if necessary (doing that in InputComponent.onRegisterActionEvents seemed to be too early)
        local nameAction = g_inputBinding.nameActions[CutPositionIndicator.ACTION_NAMES.SWITCH_INDICATOR_MODE]
        if nameAction and not g_inputBinding.actionEvents[nameAction] then

            self:registerActionEvents()
        end

        --- Enable menu actions
        g_inputBinding:setActionEventActive(self.modeActionEventId, true)
        if self.indicatorMode == CutPositionIndicator.INDICATOR_MODE.LENGTH then
            g_inputBinding:setActionEventActive(self.lengthActionEventId, true)
        elseif self.indicatorMode == CutPositionIndicator.INDICATOR_MODE.WEIGHT then
            g_inputBinding:setActionEventActive(self.weightActionEventId, true)
        end
    else
        if self.traceHooks then
            print(MOD_NAME .. ": Ignoring event since this is not the correct player")
            DebugUtil.printTableRecursively(chainsaw, "chainsaw ", 0, 2)
        end
    end
end

---Hides our own ring before the chainsaw gets deactivated
---@param chainsaw table @The chainsaw
function CutPositionIndicator:before_chainsawOnHeldEnd(chainsaw)
    if self.traceHooks then
        print(MOD_NAME .. ": before_chainsawOnHeldEnd")
    end
    if chainsaw.carryingPlayer and chainsaw.carryingPlayer == g_localPlayer then
        if self.ring ~= nil then
            setVisibility(self.ring, false)
        end

        -- Disable menu actions
        g_inputBinding:setActionEventActive(self.modeActionEventId, false)
        g_inputBinding:setActionEventActive(self.lengthActionEventId, false)
        g_inputBinding:setActionEventActive(self.weightActionEventId, false)
    else
        if self.traceHooks then
            print(MOD_NAME .. ": Ignoring event since this is not the correct player")
            DebugUtil.printTableRecursively(chainsaw, "chainsaw ", 0, 2)
        end
    end
end

---This gets called by the game engine once the I3D for the ring selector has finished loading. Note that this is not an override of a chainsaw function
---but a new one instead.
---@param node number @The ID of the 3D node which was created.
---@param failedReason table @A potential failure reason if the node couldn't be created.
---@param args table @The arguments which were supplied to loadSharedI3DFileAsync (6th argument and beyond)
function CutPositionIndicator:onOwnRingLoaded(node, failedReason, args)
    if self.traceHooks then
        print(MOD_NAME .. "onOwnRingLoaded")
    end
    if node ~= 0 then
        if not self.chainsawIsDeleted then
            self.ring = getChildAt(node, 0)
            setVisibility(self.ring, false)
            -- Note: The position of our ring is based on the log, so we don't link it to the player's point of view.
            link(getRootNode(), self.ring)

            -- We use a fixed color for the ring so we can apply it as soon as it's loaded
            setShaderParameter(self.ring, "colorScale", 0.7, .0, 0.7, 1, false)
        end
        delete(node)
    end
end

---Trigger loading of a second ring after the chainsaw loaded its own ring selector
---@param chainsaw table @The chainsaw
---@param xmlFile table @Unused
function CutPositionIndicator:after_chainsawPostLoad(chainsaw, xmlFile)
    if self.traceHooks then
        print(MOD_NAME .. "after_chainsawPostLoad")
    end

    self.chainsawIsDeleted = false
    self.chainsawIsSnapped = false

    -- Load another ring selector in addition to the one used by the base game chainsaw:
    -- 1: Get the name of the chainsaw XML file from the hand tool XML file
    local chainsawXmlFileName = chainsaw.configFileName
    if chainsawXmlFileName == nil then
        Logging.warning("%s: Failed retrieving the chainsaw XML file name. Cut Position Indicator will not work.", MOD_NAME)
        return
    end
    -- 2: Load the chainsaw XML file and get the path to the i3d of the ring selector
    local chainsawXmlId = loadXMLFile("FH_ChainsawXml", chainsawXmlFileName, FHSettingsRepository.FH_KEY)
    if chainsawXmlId == nil or chainsawXmlId == 0 then
        Logging.warning("%s: Failed loading the chainsaw XML file from '%s'. Cut Position Indicator will not work.", MOD_NAME, chainsawXmlId)
        return
    end
    local ringSelectorI3DFileName = getXMLString(chainsawXmlId, "handtool.chainsaw.ringSelector#filename")
    if ringSelectorI3DFileName == nil then
        Logging.warning("%s: Failed reading the ring selector filename from '%s'. Cut Position Indicator will not work.", MOD_NAME, chainsawXmlId)
        return
    end
    ringSelectorI3DFileName = Utils.getFilename(ringSelectorI3DFileName, chainsaw.baseDirectory)
    -- Load the file again
    self.loadRequestId = g_i3DManager:loadSharedI3DFileAsync(ringSelectorI3DFileName, false, false, self.onOwnRingLoaded, self)
    if self.traceHooks then
        print(("%s: Triggered loading of ring selector I3D from %s with request ID %s"):format(MOD_NAME, ringSelectorI3DFileName, self.loadRequestId))
    end

end

---Rotates an object so its own X axis points along the given unit vector
---@param object number @The ID of the object to rotate
---@param xx number @The X dimension of the new direction vector. The vector must have a length of 1
---@param xy number @The y dimension of the new direction vector.
---@param xz number @The z dimension of the new direction vector.
function CutPositionIndicator.rotateObjectAroundYAxis(object, xx,xy,xz)
    -- Rotate the ring around its own Y axis to match the tree direction
    setRotation(object, 0,0,0)
    local xxInd,xyInd,xzInd = localDirectionToWorld(object, 1,0,0)
    local yRotation = MathUtil.getVectorAngleDifference(xxInd,xyInd,xzInd, xx,xy,xz)
    -- The rotation seems to be an absolute value, so we need to invert it in some cases
    if xz > 0 then
        yRotation = yRotation * -1
    end
    setRotation(object, 0, yRotation, 0)
end

---Calculates a corner of a search square at a fixed width from the start of the log
---@param chainsawX number @The X part of the chainsaw's ring selector
---@param chainsawY number @The Y part of the chainsaw's ring selector
---@param chainsawZ number @The Z part of the chainsaw's ring selector
---@param xx number @The X part of the unit vector along the log's X axis
---@param xy number @The Y part of the unit vector along the log's X axis
---@param xz number @The Z part of the unit vector along the log's X axis
---@param yx number @The X part of the unit vector along the log's Y axis
---@param yy number @The Y part of the unit vector along the log's Y axis
---@param yz number @The Z part of the unit vector along the log's Y axis
---@param zx number @The X part of the unit vector along the log's Z axis
---@param zy number @The Y part of the unit vector along the log's Z axis
---@param zz number @The Z part of the unit vector along the log's Z axis
---@param lenBelow number @The amount of meters between the start of the log and the chainsaw's ring selector
---@param searchSquareSize number @The size of one side of the search square
---@return table @The X/Y/Z coordinates of the search square corner
function CutPositionIndicator:getIndicatorSearchLocationForFixedWidth(chainsawX, chainsawY, chainsawZ, xx,xy,xz, yx,yy,yz, zx,zy,zz, lenBelow, searchSquareSize)
    -- Determine how far the projected cut location must be from the chainsaw focus location
    local xDiff = g_currentMission.forestryHelperSettings:getAdjustedLength(self.indicationLength) - lenBelow

    -- Shift the chainsaw location by the required X distance, along the local X axis of the tree
    local desiredLocation = {}
    desiredLocation.x, desiredLocation.y, desiredLocation.z = chainsawX + xDiff * xx, chainsawY + xDiff * xy, chainsawZ + xDiff * xz

    -- Find the tree at this location
    local searchSquareHalfSize = searchSquareSize / 2
    local searchSquareCorner = {
        x = desiredLocation.x - yx * searchSquareHalfSize - zx * searchSquareHalfSize,
        y = desiredLocation.y - yy * searchSquareHalfSize - zy * searchSquareHalfSize,
        z = desiredLocation.z - yz * searchSquareHalfSize - zz * searchSquareHalfSize
    }
    return searchSquareCorner
end

---Calculates a search corner to find the indicator position for the weight limit mode
---@param shapeId number @The ID of the log shape
---@param chainsawX number @The X part of the chainsaw's ring selector
---@param chainsawY number @The Y part of the chainsaw's ring selector
---@param chainsawZ number @The Z part of the chainsaw's ring selector
---@param xx number @The X part of the unit vector along the log's X axis
---@param xy number @The Y part of the unit vector along the log's X axis
---@param xz number @The Z part of the unit vector along the log's X axis
---@param yx number @The X part of the unit vector along the log's Y axis
---@param yy number @The Y part of the unit vector along the log's Y axis
---@param yz number @The Z part of the unit vector along the log's Y axis
---@param zx number @The X part of the unit vector along the log's Z axis
---@param zy number @The Y part of the unit vector along the log's Z axis
---@param zz number @The Z part of the unit vector along the log's Z axis
---@param lenBelow number @The amount of meters between the start of the log and the chainsaw's ring selector
---@param searchSquareSize number @The size of one side of the search square
---@return table @The X/Y/Z coordinates of the search square corner
function CutPositionIndicator:getIndicatorSearchLocationForWeightLimit(shapeId, chainsawX, chainsawY, chainsawZ, xx,xy,xz, yx,yy,yz, zx,zy,zz, lenBelow, searchSquareSize)

    -- Find the radius at the tree's start
    local adjustedLenBelow = lenBelow - .1
    local treeStartLocation = {
        x = chainsawX - adjustedLenBelow * xx,
        y = chainsawY - adjustedLenBelow * xy,
        z = chainsawZ - adjustedLenBelow * xz
    }
    local searchSquareHalfSize = searchSquareSize / 2
    local searchSquareCorner = {
        x = treeStartLocation.x - yx * searchSquareHalfSize - zx * searchSquareHalfSize,
        y = treeStartLocation.y - yy * searchSquareHalfSize - zy * searchSquareHalfSize,
        z = treeStartLocation.z - yz * searchSquareHalfSize - zz * searchSquareHalfSize
    }
    if self.debugPositionDetection then
        DebugUtil.drawDebugGizmoAtWorldPos(searchSquareCorner.x, searchSquareCorner.y, searchSquareCorner.z, yx,yy,yz, zx,zy,zz, "startSearch", false)
        DebugUtil.drawDebugAreaRectangle(
            searchSquareCorner.x, searchSquareCorner.y, searchSquareCorner.z,
            searchSquareCorner.x + yx * searchSquareSize,
            searchSquareCorner.y + yy * searchSquareSize,
            searchSquareCorner.z + yz * searchSquareSize,
            searchSquareCorner.x + zx * searchSquareSize,
            searchSquareCorner.y + zy * searchSquareSize,
            searchSquareCorner.z + zz * searchSquareSize,
            false, .7,0,.7
        )
    end
    local minY, maxY, minZ, maxZ = testSplitShape(shapeId, searchSquareCorner.x, searchSquareCorner.y, searchSquareCorner.z, xx,xy,xz, yx,yy,yz, searchSquareSize, searchSquareSize)
    if minY == nil then
        return nil
    end
    -- else: Tree was found, calculate the radius
    local radius = math.max((maxY - minY), (maxZ - minZ)) / 2.0

    -- Get the density of the tree
    local density = getMass(shapeId) / getVolume(shapeId)

    -- Calculate the volume we'd need for 200kg
    local targetVolume = self.weightLimit / density / 1000 -- density is tons / liter so we divide by 1000 to get kg / liter

    -- Calculate the length a perfect cylinder would have to have that volume (since the log is not a perfect cylinder, it will have less than 200kg)
    local area = math.pi * radius * radius
    -- Increase the length by a factor to cope for the fact that the log is more like the frustom of a cone
    local targetLength = targetVolume / area

    -- Get the radius at the target length
    searchSquareCorner.x = searchSquareCorner.x + xx * targetLength
    searchSquareCorner.y = searchSquareCorner.y + xy * targetLength
    searchSquareCorner.z = searchSquareCorner.z + xz * targetLength
    if self.debugPositionDetection then
        DebugUtil.drawDebugGizmoAtWorldPos(searchSquareCorner.x, searchSquareCorner.y, searchSquareCorner.z, yx,yy,yz, zx,zy,zz, "secondSearch", false)
        DebugUtil.drawDebugAreaRectangle(
            searchSquareCorner.x, searchSquareCorner.y, searchSquareCorner.z,
            searchSquareCorner.x + yx * searchSquareSize,
            searchSquareCorner.y + yy * searchSquareSize,
            searchSquareCorner.z + yz * searchSquareSize,
            searchSquareCorner.x + zx * searchSquareSize,
            searchSquareCorner.y + zy * searchSquareSize,
            searchSquareCorner.z + zz * searchSquareSize,
            false, .7,0,.7
        )
    end
    minY, maxY, minZ, maxZ = testSplitShape(shapeId, searchSquareCorner.x, searchSquareCorner.y, searchSquareCorner.z,  xx,xy,xz, yx,yy,yz, searchSquareSize, searchSquareSize)
    if minY == nil then
        return nil
    end
    -- else: Tree was still found, get the new radius
    local radius2 = math.max((maxY - minY), (maxZ - minZ)) / 2.0

    -- Calculate the volume again
    local averageRadius = (radius + radius2) / 2
    local estimatedLength = targetLength
    local estimatedVolume = math.pi * averageRadius * averageRadius * estimatedLength
    local estimatedMass = estimatedVolume * density * 1000

    -- Adjust the target length accordingly
    targetLength = targetLength * self.weightLimit / estimatedMass

    if self.debugPositionDetection then
        local textSize = getCorrectTextSize(0.015)
        local color = {1,1,1}
        Utils.renderTextAtWorldPosition(searchSquareCorner.x, searchSquareCorner.y + .7, searchSquareCorner.z, ('mass: %.3f'):format(getMass(shapeId)), textSize, 0, color)
        Utils.renderTextAtWorldPosition(searchSquareCorner.x, searchSquareCorner.y + .65, searchSquareCorner.z, ('volume: %.3f'):format(getVolume(shapeId)), textSize, 0, color)
        Utils.renderTextAtWorldPosition(searchSquareCorner.x, searchSquareCorner.y + .6, searchSquareCorner.z, ('density: %.3f'):format(density), textSize, 0, color)
        Utils.renderTextAtWorldPosition(searchSquareCorner.x, searchSquareCorner.y + .55, searchSquareCorner.z, ('targetVolume: %.3f'):format(targetVolume), textSize, 0, color)
        Utils.renderTextAtWorldPosition(searchSquareCorner.x, searchSquareCorner.y + .5, searchSquareCorner.z, ('area: %.3f'):format(area), textSize, 0, color)
        Utils.renderTextAtWorldPosition(searchSquareCorner.x, searchSquareCorner.y + .45, searchSquareCorner.z, ('targetLength: %.3f'):format(targetLength), textSize, 0, color)
        Utils.renderTextAtWorldPosition(searchSquareCorner.x, searchSquareCorner.y + .4, searchSquareCorner.z, ('radius: %.3f'):format(radius), textSize, 0, color)
        Utils.renderTextAtWorldPosition(searchSquareCorner.x, searchSquareCorner.y + .35, searchSquareCorner.z, ('estimatedLength: %.3f'):format(estimatedLength), textSize, 0, color)
        Utils.renderTextAtWorldPosition(searchSquareCorner.x, searchSquareCorner.y + .3, searchSquareCorner.z, ('estimatedVolume: %.3f'):format(estimatedVolume), textSize, 0, color)
        Utils.renderTextAtWorldPosition(searchSquareCorner.x, searchSquareCorner.y + .25, searchSquareCorner.z, ('estimatedMass: %.3f'):format(estimatedMass), textSize, 0, color)
    end

    -- Determine how far the projected cut location must be from the chainsaw focus location
    local xDiff = targetLength - lenBelow

    -- Shift the chainsaw location by the required X distance, along the local X axis of the tree
    local desiredLocation = {}
    desiredLocation.x, desiredLocation.y, desiredLocation.z = chainsawX + xDiff * xx, chainsawY + xDiff * xy, chainsawZ + xDiff * xz

    -- Find the tree at this location
    searchSquareCorner = {
        x = desiredLocation.x - yx * searchSquareHalfSize - zx * searchSquareHalfSize,
        y = desiredLocation.y - yy * searchSquareHalfSize - zy * searchSquareHalfSize,
        z = desiredLocation.z - yz * searchSquareHalfSize - zz * searchSquareHalfSize
    }
    return searchSquareCorner
end

---Show or hide our own ring whenever the visibliity of the chainsaw's ring selector changes
---@param chainsaw table @The chain saw
---@param shape RingSelectorInfo @Contains information about the split shape the chainsaw is pointing at
function CutPositionIndicator:after_updateRingSelector(chainsaw, shape, ...)
    if self.traceHooks then
        print(MOD_NAME .. ": after_updateRingSelector")
    end
    if chainsaw.carryingPlayer and chainsaw.carryingPlayer == g_localPlayer and self.ring ~= nil then
        -- Just tie the visibility of our ring to the one of the chainsaw's ring selector, but don't show it if the tree hasn't been cut already
        local cutIndicatorShallBeVisible = false
        if chainsaw.spec_chainsaw.ringNode ~= nil and getVisibility(chainsaw.spec_chainsaw.ringNode) and shape.node ~= nil and shape.node ~= 0 and entityExists(shape.node) and getRigidBodyType(shape.node) ~= RigidBodyType.STATIC then
            cutIndicatorShallBeVisible = (self.indicatorMode ~= CutPositionIndicator.INDICATOR_MODE.OFF)
        end
        setVisibility(self.ring, cutIndicatorShallBeVisible)

        if cutIndicatorShallBeVisible then
            -- FS25: The center of the ring selector is now supplied as an argument
            local chainsawX, chainsawY, chainsawZ = shape.x, shape.y, shape.z

            -- Unit vectors along the local X axis of the log, same for Y and Z below
            -- There is a special case for trees, however, since they grow in world Y direction, so the X axis is not their main axis
            -- In order to make the following code less confusing, we rotate the tree's axis system so it grows along its X axis
            local xx,xy,xz = localDirectionToWorld(shape.node, 0,1,0)
            local yx,yy,yz = localDirectionToWorld(shape.node, 1,0,0)
            local zx,zy,zz = localDirectionToWorld(shape.node, 0,0,-1)

            -- Detect how far the beginning of the tree is away
            local lenBelow = getSplitShapePlaneExtents(shape.node, chainsawX, chainsawY, chainsawZ, xx,xy,xz)

            -- Make a large enough search square to find the tree again
            local searchSquareSize = 2
            local searchSquareCorner = {}
            if self.indicatorMode == CutPositionIndicator.INDICATOR_MODE.LENGTH then
                searchSquareCorner = self:getIndicatorSearchLocationForFixedWidth(chainsawX, chainsawY, chainsawZ, xx,xy,xz, yx,yy,yz, zx,zy,zz, lenBelow, searchSquareSize)
            elseif self.indicatorMode == CutPositionIndicator.INDICATOR_MODE.WEIGHT then
                searchSquareCorner = self:getIndicatorSearchLocationForWeightLimit(shape.node, chainsawX, chainsawY, chainsawZ, xx,xy,xz, yx,yy,yz, zx,zy,zz, lenBelow, searchSquareSize)
            end

            if searchSquareCorner ~= nil and self.debugPositionDetection then
                DebugUtil.drawDebugGizmoAtWorldPos(chainsawX,chainsawY,chainsawZ, yx,yy,yz, zx,zy,zz, "Cut", false)
                DebugUtil.drawDebugGizmoAtWorldPos(searchSquareCorner.x, searchSquareCorner.y, searchSquareCorner.z, yx,yy,yz, zx,zy,zz, "search", false)
                DebugUtil.drawDebugAreaRectangle(
                    searchSquareCorner.x, searchSquareCorner.y, searchSquareCorner.z,
                    searchSquareCorner.x + yx * searchSquareSize,
                    searchSquareCorner.y + yy * searchSquareSize,
                    searchSquareCorner.z + yz * searchSquareSize,
                    searchSquareCorner.x + zx * searchSquareSize,
                    searchSquareCorner.y + zy * searchSquareSize,
                    searchSquareCorner.z + zz * searchSquareSize,
                    false, .7,0,.7
                )
            end

            -- Search in a square starting in the search square corner. We supply X and Y unit vectors, but the function will actually search in the Y/Z plane
            local minY, maxY, minZ, maxZ = nil, nil, nil, nil
            if searchSquareCorner ~= nil then
                minY, maxY, minZ, maxZ = testSplitShape(shape.node, searchSquareCorner.x, searchSquareCorner.y, searchSquareCorner.z, xx,xy,xz, yx,yy,yz, searchSquareSize, searchSquareSize)
            end
            if minY ~= nil then
                -- Move the corner of the search square used above to the center of the found location. min/max Y/Z are relative to the search square corner
                local yCenter = (minY + maxY) / 2.0
                local zCenter = (minZ + maxZ) / 2.0
                local indicatorX = searchSquareCorner.x + yCenter * yx + zCenter * zx
                local indicatorY = searchSquareCorner.y + yCenter * yy + zCenter * zy
                local indicatorZ = searchSquareCorner.z + yCenter * yz + zCenter * zz
                setTranslation(self.ring, indicatorX, indicatorY, indicatorZ)

                -- Adjust the radius
                local diameter = math.max((maxY - minY), (maxZ - minZ)) * 1.4
                setScale(self.ring, 1, diameter, diameter)

                CutPositionIndicator.rotateObjectAroundYAxis(self.ring, xx,xy,xz)

                if self.debugIndicator then
                    local yx1,yy1,yz1 = localDirectionToWorld(self.ring, 0,1,0)
                    local zx1,zy1,zz1 = localDirectionToWorld(self.ring, 0,0,1)
                    DebugUtil.drawDebugGizmoAtWorldPos(indicatorX, indicatorY, indicatorZ, yx1,yy1,yz1, zx1,zy1,zz1, ('%.3f'):format(diameter), false)
                    DebugUtil.drawDebugGizmoAtWorldPos(indicatorX, indicatorY, indicatorZ, yx,yy,yz, zx,zy,zz, "", false)
                end
            else
                -- Failed finding the shape at that location. It is probably too short
                setVisibility(self.ring, false)
                setRotation(self.ring, 0,0,0)
            end
        end

        -- Snap the base game ring selector to our indicator if the player is close
        if getVisibility(self.ring) then
            -- Calculate the distance between the centers of the two rings
            local xInd,yInd,zInd = localToWorld(self.ring, 0,0,0)
            local xCut,yCut,zCut = localToWorld(chainsaw.spec_chainsaw.ringNode, 0,0,0)
            local xDiff,yDiff,zDiff = xInd-xCut, yInd-yCut, zInd-zCut
            local distance = math.sqrt(xDiff * xDiff + yDiff * yDiff + zDiff * zDiff)

            if distance < 0.2 then -- +/- 20cm
                -- Figure out the position of our own ring in the local coordinate system of the chainsaw's ring selector
                -- The chainsaw's ring selector's translation is relative to some other object, so we use the coordinate system of that object instead
                -- Not sure why that's the right thing, but Chainsaw:updateRingSelector does it, too, and it won't work without the getParent call
                local xCutLocal, yCutLocal, zCutLocal = worldToLocal(getParent(chainsaw.spec_chainsaw.ringNode), xInd, yInd, zInd)
                -- Translate the chainsaw's ring selector onto those coordinates
                setTranslation(chainsaw.spec_chainsaw.ringNode, xCutLocal, yCutLocal, zCutLocal)
                self.chainsawIsSnapped = true
            else
                self.chainsawIsSnapped = false
            end
        else
            -- Chainsaw can't be snapped if the ring is not visible
            self.chainsawIsSnapped = false
        end
    else
        -- Chainsaw can't be snapped if the cut indicator shall not be shown
        self.chainsawIsSnapped = false
    end
end

---Registers an action event which will trigger on key press
---@param eventKey string @The event key from the modDesc.xml
---@param callbackFunction function @The function to be called on press
---@return boolean @True if event registration was succesful, false if events had been registered already
---@return string @The ID of the action event
function CutPositionIndicator:registerOnPressAction(eventKey, callbackFunction)
    if self.traceHooks then
        print(MOD_NAME .. ": registerOnPressAction")
    end
    -- Register the action. Bool variables: Trigger on key release, trigger on key press, trigger always, unknown
    local registrationSuccessful, actionEventId = g_inputBinding:registerActionEvent(eventKey, self, callbackFunction, false, true, false, true)
    if registrationSuccessful then
        g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_LOW)
        g_inputBinding:setActionEventActive(actionEventId, false)
        g_inputBinding:setActionEventText(actionEventId, "")
        g_inputBinding:setActionEventTextVisibility(actionEventId, true)
        if self.traceHooks then
            print(MOD_NAME .. ": Successfully registered " .. eventKey)
        end
    else
        Logging.warning("%s: Failed registering action event for %s", MOD_NAME, eventKey)
    end
    return registrationSuccessful, actionEventId
end

---Registers the "Cycle Cut Indicator" event so it can be displayed in the help menu
function CutPositionIndicator:registerActionEvents()
    if self.traceHooks then
        print(MOD_NAME .. ": registerActionEvents")
    end
    local isValid, actionEventId
    isValid, actionEventId = self:registerOnPressAction('CYCLE_LENGTH_INDICATOR', CutPositionIndicator.cycleLengthIndicator)
    if isValid then self.lengthActionEventId = actionEventId end
    isValid, actionEventId = self:registerOnPressAction('CYCLE_WEIGHT_INDICATOR', CutPositionIndicator.cycleWeightIndicator)
    if isValid then self.weightActionEventId = actionEventId end
    isValid, actionEventId = self:registerOnPressAction('SWITCH_INDICATOR_MODE', CutPositionIndicator.cycleIndicatorMode)
    if isValid then self.modeActionEventId = actionEventId end
    self:updateF1MenuTexts()
end

---Updates the texts of all F1 menu entries (no matter if visible or not)
function CutPositionIndicator:updateF1MenuTexts()
    self:updateIndicatorModeText()
    self:updateLengthIndicatorText()
    self:updateWeightIndicatorText()
end

---Cycles the desired cut length
function CutPositionIndicator:cycleLengthIndicator()
    if self.traceHooks then
        print(MOD_NAME .. "cycleLengthIndicator")
    end
    self.indicationLength = 1 + self.indicationLength % 12 -- from 1 to 12
    self:updateLengthIndicatorText()
end

---Cycles the weight limit
function CutPositionIndicator:cycleWeightIndicator()
    if self.traceHooks then
        print(MOD_NAME .. "cycleWeightIndicator")
    end
     -- 200 (base game) to 1000 (max lumberjack strength setting)
    self.weightLimit = (self.weightLimit - 100) % 900 + 200
    self:updateWeightIndicatorText()
end

-- Cycles the indication mode
function CutPositionIndicator:cycleIndicatorMode()
    if self.traceHooks then
        print(MOD_NAME .. "cycleIndicatorMode")
    end

    if self.indicatorMode == CutPositionIndicator.INDICATOR_MODE.OFF then

        -- Next mode: Length
        g_inputBinding:setActionEventActive(self.lengthActionEventId, true)
        self.indicatorMode = CutPositionIndicator.INDICATOR_MODE.LENGTH

    elseif self.indicatorMode == CutPositionIndicator.INDICATOR_MODE.LENGTH then

        if not g_currentMission.missionDynamicInfo.isMultiplayer then
            -- Next mode: Weight
            g_inputBinding:setActionEventActive(self.lengthActionEventId, false)
            g_inputBinding:setActionEventActive(self.weightActionEventId, true)
            self.indicatorMode = CutPositionIndicator.INDICATOR_MODE.WEIGHT
        else
            -- multiplayer: We currently can't get the mass or density of split shapes -> weight mode is not possible
            g_inputBinding:setActionEventActive(self.lengthActionEventId, false)
            self.indicatorMode = CutPositionIndicator.INDICATOR_MODE.OFF
        end

    elseif self.indicatorMode == CutPositionIndicator.INDICATOR_MODE.WEIGHT then

        -- Next mode: off
        g_inputBinding:setActionEventActive(self.weightActionEventId, false)
        self.indicatorMode = CutPositionIndicator.INDICATOR_MODE.OFF

    end
    self:updateIndicatorModeText()
end

---Updates the text of the length indicator help menu entry
function CutPositionIndicator:updateLengthIndicatorText()
    local length = g_currentMission.forestryHelperSettings:getAdjustedLength(self.indicationLength)
    g_inputBinding:setActionEventText(
        self.lengthActionEventId,
        ('%s: %.2f %s'):format(g_i18n:getText(CutPositionIndicator.I18N_IDS.DESIRED_LENGTH), length, g_i18n:getText("unit_mShort")))
end

---Updates the text of the weight indicator help menu entry
function CutPositionIndicator:updateWeightIndicatorText()
    g_inputBinding:setActionEventText(
        self.weightActionEventId,
        ('%s: %d %s'):format(g_i18n:getText(CutPositionIndicator.I18N_IDS.WEIGHT_LIMIT), self.weightLimit, g_i18n:getText("unit_kg")))
end

---Updates the text of the indicator mode entry
function CutPositionIndicator:updateIndicatorModeText()
    local indicatorModeText = ""
    if self.indicatorMode == CutPositionIndicator.INDICATOR_MODE.OFF then
        indicatorModeText = g_i18n:getText(CutPositionIndicator.I18N_IDS.MODE_OFF)
    elseif self.indicatorMode == CutPositionIndicator.INDICATOR_MODE.LENGTH then
        indicatorModeText = g_i18n:getText(CutPositionIndicator.I18N_IDS.MODE_LENGTH)
    elseif self.indicatorMode == CutPositionIndicator.INDICATOR_MODE.WEIGHT then
        indicatorModeText = g_i18n:getText(CutPositionIndicator.I18N_IDS.MODE_WEIGHT)
    end
    g_inputBinding:setActionEventText(
        self.modeActionEventId,
        ('%s: %s'):format(g_i18n:getText(CutPositionIndicator.I18N_IDS.INDICATOR_MODE), indicatorModeText))
end

---Overrides the cut location in case the chainsaw is currently snapped to the cut indicator. Without this, the cut would be in the wrong location
---@param superFunc function @The base game function which splits the log in two.
---@param shapeId number @The ID of the tree shape to be split
---@param x number @The X coordinate.
---@param y number @The Y coordinate.
---@param z number @The Z coordinate.
---@param xx number @The X part of the unit vector in X direction.
---@param xy number @The Y part of the unit vector in X direction.
---@param xz number @The Y part of the unit vector in X direction.
---@param yx number @The X part of the unit vector in Y direction.
---@param yy number @The Y part of the unit vector in Y direction.
---@param yz number @The Y part of the unit vector in Y direction.
---@param cutSizeY number @The size of the search rectangle in Y dimension
---@param cutSizeZ number @The size of the search rectangle in Z dimension
---@param farmId number @The ID of the farm (not sure why this is needed, maybe for statistics)
function CutPositionIndicator:adaptCutIfNecessary(superFunc, shapeId, x,y,z, xx,xy,xz, yx,yy,yz, cutSizeY, cutSizeZ, farmId)
    if self.traceHooks then
        print(MOD_NAME .. "adaptCutIfNecessary")
    end
    x, y, z = self:getAdjustedCutPosition(x,y,z, xx,xy,xz, yx,yy,yz, cutSizeY, cutSizeZ)
    superFunc(shapeId, x,y,z, xx,xy,xz, yx,yy,yz, cutSizeY, cutSizeZ, farmId)
    if #ChainsawUtil.curSplitShapes == 0 then
        g_currentMission:showBlinkingWarning(g_i18n:getText("fh_cut_not_possible", 2000))
    else
        print(("%s: Shape %d was split into %d parts"):format(MOD_NAME, shapeId, #ChainsawUtil.curSplitShapes))
        self.chainsawIsSnapped = false
    end
end

function CutPositionIndicator:getAdjustedCutPosition(x,y,z, xx,xy,xz, yx,yy,yz, cutSizeY, cutSizeZ)
    print(("%s: Checking if chainsaw snapping needs to be adjusted at (%.3f|%.3f|%.3f)"):format(MOD_NAME, x, y, z))
    if self.chainsawIsSnapped then
        x,y,z = getWorldTranslation(self.ring)
        local halfCutSizeY = cutSizeY / 2.0
        local halfCutSizeZ = cutSizeZ / 2.0
        local zx,zy,zz = MathUtil.crossProduct(xx,xy,xz, yx,yy,yz)
        x = x - yx * halfCutSizeY - zx * halfCutSizeZ
        y = y - yy * halfCutSizeY - zy * halfCutSizeZ
        z = z - yz * halfCutSizeY - zz * halfCutSizeZ
        print(("%s: Cut was adjusted to (%.3f|%.3f|%.3f)"):format(MOD_NAME, x, y, z))
    else
        print(MOD_NAME .. ": No adaptation required since chainsaw is not snapped")
    end
    return x, y, z
end
