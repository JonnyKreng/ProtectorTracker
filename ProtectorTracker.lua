local WM = GetWindowManager()

ProtectorTracker = {}
ProtectorTracker.name = "ProtectorTracker"
ProtectorTracker.inZone = false
ProtectorTracker.default = {
    offsetX = 500,
    offsetY = 500
}
ProtectorTracker.savedVariables = ProtectorTracker.default
ProtectorTracker.magic = {
    AS_ZONE = 1000,
    PROTECTOR = 64508
}
ProtectorTracker.Frame = {}
ProtectorTracker.ProtectorId = 0

function ProtectorTracker.onCombatEvent(eventCode, result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId) 
    if (result == ACTION_RESULT_EFFECT_GAINED and abilityId == ProtectorTracker.magic.PROTECTOR) then
        ProtectorTracker.ProtectorId = targetUnitId
    elseif (result == ACTION_RESULT_DIED and targetUnitId == ProtectorTracker.ProtectorId) then
        d("Protector Death ID:" .. targetUnitId)
        ProtectorTracker.ProtectorId = 0
    end
end


function ProtectorTracker.targetChange(event, unitTag)
    name = GetUnitName('reticleover')
    d(name)
    ProtectorTracker.update()
end

function ProtectorTracker.Start()
    d("register combat")
    ProtectorTracker.Frame:SetHidden(false)
    EVENT_MANAGER:RegisterForEvent(ProtectorTracker.name .. "COMBAT_EVENT", EVENT_COMBAT_EVENT, ProtectorTracker.onCombatEvent);
    --EVENT_MANAGER:RegisterForEvent(ProtectorTracker.name .. "TARGET_SWAP", EVENT_TARGET_CHANGED, ProtectorTracker.targetChange);
end

function ProtectorTracker.Stop()
    ProtectorTracker.Frame:SetHidden(true)
    EVENT_MANAGER:UnregisterForUpdate(ProtectorTracker.name .. "COMBAT_EVENT")
    --EVENT_MANAGER:UnregisterForUpdate(ProtectorTracker.name .. "TARGET_SWAP")
end

function ProtectorTracker.Initialize()
    d("On Load")
    ProtectorTracker.savedVariables = ZO_SavedVars:NewCharacterIdSettings("ProtectorTrackerVars", 1, "ProtectorTracker", ProtectorTracker.default, GetWorldName())
    ProtectorTracker.Frame = WM:CreateTopLevelWindow(ProtectorTracker.name .. "frame")
	ProtectorTracker.Frame:SetClampedToScreen(true)
	ProtectorTracker.Frame:SetDimensions(34, 34)
	ProtectorTracker.Frame:ClearAnchors()
	ProtectorTracker.Frame:SetMouseEnabled(false)
	ProtectorTracker.Frame:SetMovable(false)
    ProtectorTracker.Frame:SetHidden(true)
    ProtectorTracker.Frame:SetHandler("OnMoveStop", ProtectorTracker.savePos)
    ProtectorTracker.setPos()

    local t = WM:CreateControl(ProtectorTracker.name .. "texture", ProtectorTracker.Frame, CT_TEXTURE)
    t:SetTexture("esoui/art/lfg/gamepad/lfg_menuicon_normaldungeon.dds")
    t:SetAnchorFill()

    EVENT_MANAGER:RegisterForEvent(ProtectorTracker.name .. "ZONE_CHANGE", EVENT_PLAYER_ACTIVATED, ProtectorTracker.zoneCheck);
end

function ProtectorTracker.update()
    --SetMapToMapListIndex(1)

    local sphereList = { -- Vorne = Rechts
        sphere1 = { -- Eingang Vorne
            y = 0.7063,
            x = 0.5344,
            name = "Eingang Vorne"
        },
        sphere2 = { -- Eingang Hinten
            y = 0.7063,
            x = 0.4997,
            name = "Eingang Hinten"
        },
        sphere3 = { -- Mitte Hinten
            y = 0.7444,
            x = 0.4944,
            name = "Mitte Hinten"
        },
        sphere4 = { -- Mitte Vorne
            y = 0.7446,
            x = 0.5377,
            name = "Mitte Vorne"
        },
        sphere5 = { -- Ausgang Vorne 
            y = 0.7857,
            x = 0.5341,
            name = " Ausgang Vorne"
        },
        sphere6 = { -- Ausgang Hinten 
            y = 0.7867,
            x = 0.4963,
            name = "Ausgang Hinten "
        }
    }

    SetMapToPlayerLocation()
    local py,px,ph = GetMapPlayerPosition('player') 
    px = round(px) 
    py = round(py)
    local ch = GetPlayerCameraHeading()
    ch = (ch+math.pi)%(math.pi*2)
    sky = "-"
    if math.pi/4 > ch or ch >= (math.pi*7)/4 then
        sky = "S"
    elseif (math.pi*3)/4 > ch and ch >= math.pi/4 then
        sky = "W"
    elseif (math.pi*5)/4 > ch and ch >= (math.pi*3)/4 then
        sky = "N"
    elseif  (math.pi*7)/4 > ch and ch >= (math.pi*5)/4 then
        sky = "E"
    end

    d("+++++++++++++++++++++++++++++++++++++++++++++++++++++")
    name = GetUnitName('reticleover')
    if name == "Ordinator Protector" then
        d("odi")
    end
    d(name)
    d("x:".. px .." y:" .. py .. " h:".. round(ch) .. "-" .. sky)

    m = math.tan(ch)
    b = py - (px * m)

    for name,sphere in pairs(sphereList) do 
        delta = (sphere.x * m + b) - sphere.y 
        --d(sphere.name .. ": " .. delta)
        
        error = round(math.sqrt(math.pow(sphere.x-px,2) +math.pow(sphere.y-py,2)))*0.1 --Make error bigger with Distance
        error = error*((math.abs(m)+1)/1)   --Mitigate the tan() changes for tan(pi/2) -> inf
        if error < 0.005 then error = 0.005 end
        if  error >= math.abs(delta) then
            if not (
                (sphere.x > px and sky == "N") or 
                (sphere.x < px and sky == "S") or 
                (sphere.y < py and sky == "W") or
                (sphere.y > py and sky == "E")    
                ) then
                d(sphere.name)
            end
        end    
    end

    --d(min.name)
end

function round(num)
    return math.floor(num*10000)/10000
end

function ProtectorTracker.zoneCheck()
    
    EVENT_MANAGER:RegisterForUpdate(ProtectorTracker.name .. "UPDATE", 0, ProtectorTracker.update)

    if (GetZoneId(GetUnitZoneIndex("player")) == ProtectorTracker.magic.AS_ZONE) then
        ProtectorTracker.inZone = true
        ProtectorTracker.Start()
        d("start")
    elseif (ProtectorTracker.inZone) then
        ProtectorTracker.inZone = false
        ProtectorTracker.Stop()
        d("stop")
    end
end

function ProtectorTracker.savePos()
    ProtectorTracker.savedVariables.offsetX = ProtectorTracker.Frame:GetLeft()
    ProtectorTracker.savedVariables.offsetY = ProtectorTracker.Frame:GetTop()
end
    
function ProtectorTracker.setPos()
    ProtectorTracker.Frame:ClearAnchors()
    ProtectorTracker.Frame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, ProtectorTracker.savedVariables.offsetX, ProtectorTracker.savedVariables.offsetY)
end

function ProtectorTracker.OnAddOnLoaded(event, addonName)
    if addonName == ProtectorTracker.name then
        ProtectorTracker:Initialize()
    end
end



EVENT_MANAGER:RegisterForEvent(ProtectorTracker.name, EVENT_ADD_ON_LOADED, ProtectorTracker.OnAddOnLoaded)


