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

function targetChange(event, unitTag)

end

function ProtectorTracker.Start()
    d("register combat")
    ProtectorTracker.Frame:SetHidden(false)
    EVENT_MANAGER:RegisterForEvent(ProtectorTracker.name .. "COMBAT_EVENT", EVENT_COMBAT_EVENT, ProtectorTracker.onCombatEvent);
    EVENT_MANAGER:RegisterForEvent(ProtectorTracker.name .. "TARGET_SWAP", EVENT_TARGET_CHANGED, ProtectorTracker.targetChange);
end

function ProtectorTracker.Stop()
    ProtectorTracker.Frame:SetHidden(true)
    EVENT_MANAGER:UnregisterForUpdate(ProtectorTracker.name .. "COMBAT_EVENT")
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

function ProtectorTracker.targetChange(event, unitTag)
    if unitTag == 'reticleover' then
        local x,y,z = GetMapPlayerPosition('player')
        d("x:"..x .." y:" ..y .. " h:".. z)
        local x,y,z = GetMapPlayerPosition('reticleover')
        d("x:"..x .." y:" ..y .. " h:".. z)
        local x,y,z = GetMapPlayerPosition('reticleovertarget')
        d("x:"..x .." y:" ..y .. " h:".. z)
    end
end

function ProtectorTracker.zoneCheck()
    EVENT_MANAGER:RegisterForEvent(ProtectorTracker.name .. "TARGET_CHANGE", EVENT_TARGET_CHANGED, ProtectorTracker.targetChange);

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


