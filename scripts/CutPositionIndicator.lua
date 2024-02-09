---@class CutPositionIndicator
---This class is responsible for displaying an indicator for the desired cut position
---Most of this code was created by taking a look at the LUADOC for the chainsaw class and see where it uses the ringSelector
CutPositionIndicator = {}

local CutPositionIndicator_mt = Class(CutPositionIndicator)

---Creates a new cut position indicator (handler)
---@return table @The new object
function CutPositionIndicator.new()
    local self = setmetatable({}, CutPositionIndicator_mt)

    self.ring = nil
    self.loadRequestId = nil
    self.chainsawIsDeleted = false
    self.debugPositionDetection = false
    self.debugIndicator = false
    return self
end

-- Create an object now so it can be referenced by method overrides
local cutPositionIndicator = CutPositionIndicator.new()

---Deletes our own ring before the chainsaw gets deleted
---@param chainsaw table @The chainsaw which will be deleted afterwards
function CutPositionIndicator:before_chainsawDelete(chainsaw)
    if chainsaw.isClient then
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

---Hides our own ring before the chainsaw gets deactivated
---@param chainsaw table @The chainsaw
function CutPositionIndicator:before_chainsawDeactivate(chainsaw)
    if chainsaw.isClient then
        if self.ring ~= nil then
            setVisibility(self.ring, false)
        end
    end
end

---This gets called by the game engine once the I3D for the ring selector has finished loading. Note that this is not an override of a chainsaw function
---but a new one instead.
---@param node number @The ID of the 3D node which was created.
---@param failedReason table @A potential failure reason if the node couldn't be created.
---@param args table @Arguments (unknown)
function CutPositionIndicator:onOwnRingLoaded(node, failedReason, args)
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
---@param xmlFile table @The object which contains the chainsaw XML file's contents
function CutPositionIndicator:after_chainsawPostLoad(chainsaw, xmlFile)
    -- Load another ring selector in addition to the one used by the base game chainsaw
    local filename = xmlFile:getValue("handTool.chainsaw.ringSelector#file")
    if filename ~= nil then
        filename = Utils.getFilename(filename, chainsaw.baseDirectory)
        -- Base game "pins" the shared I3D in cache, but there's no point in doing that twice (it's a shared cache, after all), so we skip that step

        -- Load the file again
        self.loadRequestId = g_i3DManager:loadSharedI3DFileAsync(filename, false, false, self.onOwnRingLoaded, self, chainsaw.player)
    end
    self.chainsawIsDeleted = false
end

---Show or hide our own ring whenever the visibliity of the chainsaw's ring selector changes
---@param chainsaw table @The chain saw
function CutPositionIndicator:after_chainsawUpdateRingSelector(chainsaw, shape)
    if self.ring ~= nil then
        -- Just tie the visibility of our ring to the one of the chainsaw's ring selector
        setVisibility(self.ring, getVisibility(chainsaw.ringSelector))

        if shape ~= nil and shape ~= 0 and getVisibility(self.ring) then
            -- Find the center of the cut location in world coordinates
            local chainsawX, chainsawY, chainsawZ = localToWorld(chainsaw.ringSelector, 0,0,0)
            -- Unit vectors along the local X axis of the log, same for Y and Z below
            -- There is a special case for trees, however, since they grow in world Y direction, so the X axis is not their main axis
            -- In order to make the following code less confusing, we rotate the tree's axis system so it grows along its X axis
            local xx,xy,xz = localDirectionToWorld(shape, 0,1,0)
            local yx,yy,yz = localDirectionToWorld(shape, 1,0,0)
            local zx,zy,zz = localDirectionToWorld(shape, 0,0,-1)

            -- Detect how far the beginning of the tree is away
            local lenBelow = getSplitShapePlaneExtents(shape, chainsawX, chainsawY, chainsawZ, xx,xy,xz)

            -- Determine how far the projected cut location must be from the chainsaw focus location
            local TEMP_desiredLength = 6
            local xDiff = TEMP_desiredLength - lenBelow

            -- Shift the chainsaw location by the required X distance, along the local X axis of the tree
            local desiredLocation = {}
            desiredLocation.x, desiredLocation.y, desiredLocation.z = chainsawX + xDiff * xx, chainsawY + xDiff * xy, chainsawZ + xDiff * xz

            -- Find the tree at this location
            local searchSquareHalfSize = .6
            local searchSquareSize = searchSquareHalfSize * 2
            local searchSquareCorner = {
                x = desiredLocation.x - yx * searchSquareHalfSize - zx * searchSquareHalfSize,
                y = desiredLocation.y - yy * searchSquareHalfSize - zy * searchSquareHalfSize,
                z = desiredLocation.z - yz * searchSquareHalfSize - zz * searchSquareHalfSize
            }

            if self.debugPositionDetection then
                DebugUtil.drawDebugGizmoAtWorldPos(chainsawX,chainsawY,chainsawZ, yx,yy,yz, zx,zy,zz, "Cut", false)
                DebugUtil.drawDebugGizmoAtWorldPos(desiredLocation.x, desiredLocation.y, desiredLocation.z, yx,yy,yz, zx,zy,zz, "desired", false)
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
            local minY, maxY, minZ, maxZ = testSplitShape(shape, searchSquareCorner.x, searchSquareCorner.y, searchSquareCorner.z, xx,xy,xz, yx,yy,yz, searchSquareSize, searchSquareSize)
            if minY ~= nil then
                -- Move the corner of the search square used above to the center of the found location. min/max Y/Z are relative to that location
                local yCenter = (minY + maxY) / 2.0
                local zCenter = (minZ + maxZ) / 2.0
                local indicatorX = searchSquareCorner.x + yCenter * yx + zCenter * zx
                local indicatorY = searchSquareCorner.y + yCenter * yy + zCenter * zy
                local indicatorZ = searchSquareCorner.z + yCenter * yz + zCenter * zz
                setTranslation(self.ring, indicatorX, indicatorY, indicatorZ)

                -- Rotate the ring around its own Y axis to match the tree direction
                setRotation(self.ring, 0,0,0)
                local xxInd,xyInd,xzInd = localDirectionToWorld(self.ring, 1,0,0)
                local yRotation = MathUtil.getVectorAngleDifference(xxInd,xyInd,xzInd, xx,xy,xz)
                -- The rotation seems to be an absolute value, so we need to invert it in some cases
                if xz > 0 then
                    yRotation = yRotation * -1
                end
                setRotation(self.ring, 0, yRotation, 0)

                if self.debugIndicator then
                    local yx1,yy1,yz1 = localDirectionToWorld(self.ring, 0,1,0)
                    local zx1,zy1,zz1 = localDirectionToWorld(self.ring, 0,0,1)
                    DebugUtil.drawDebugGizmoAtWorldPos(indicatorX, indicatorY, indicatorZ, yx1,yy1,yz1, zx1,zy1,zz1, "Indicator", false)
                    DebugUtil.drawDebugGizmoAtWorldPos(indicatorX, indicatorY, indicatorZ, yx,yy,yz, zx,zy,zz, "", false)
                end
            else
                -- Failed finding the shape at that location. It is probably too short
                setVisibility(self.ring, false)
                setRotation(self.ring, 0,0,0)
            end

            -- temp: use fixed scale
            setScale(self.ring, 1,1,1)
        end
    end
end

-- Register all our functions as late as possible just in case other mods which are further behind in the alphabet replace methods 
-- rather than overriding them properly.
Mission00.loadMission00Finished = Utils.appendedFunction(Mission00.loadMission00Finished, function(mission, node)
    Chainsaw.delete = Utils.prependedFunction(Chainsaw.delete, function(chainsaw) cutPositionIndicator:before_chainsawDelete(chainsaw) end)
    Chainsaw.onDeactivate = Utils.prependedFunction(Chainsaw.onDeactivate, function(chainsaw, allowInput) cutPositionIndicator:before_chainsawDeactivate(chainsaw) end)
    Chainsaw.postLoad = Utils.appendedFunction(Chainsaw.postLoad, function(chainsaw, xmlFile) cutPositionIndicator:after_chainsawPostLoad(chainsaw, xmlFile) end)
    Chainsaw.updateRingSelector = Utils.appendedFunction(Chainsaw.updateRingSelector, function(chainsaw, shape) cutPositionIndicator:after_chainsawUpdateRingSelector(chainsaw, shape) end)
end)