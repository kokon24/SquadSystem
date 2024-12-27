//===========================================================================
//
//  Squad System v0.9.8
//  by loktar and kokon
//
//    -------
//    * API *
//    -------
//    * Variables *
//    -------------
//  *   integer array squadUnits
//          - Unit types that generate a squad when trained or hired
//
//  *   integer array squadSize
//          - Squad size for squads generated with squadUnits
//
//  *   integer SQUAD_MAX_UNIT_COUNT
//          - Maximum index of squadUnits and squadSize
//
//  *   string SQUAD_SFX_PATH
//          - Default path for special effect to attach to squad units
//          - Set to null to disable special effects
//          - Default: null
//
//  *   string SQUAD_SFX_ATTACH
//          - Default attachment point for special effect to attach to squad units
//          - Default: "overhead"
//
//  *   string SQUAD_LEADER_SFX_PATH
//          - Default path for special effect to attach to squad leader
//          - Set to null to use same effect as regular squad members
//          - Default: null
//
//  *   string SQUAD_LEADER_SFX_ATTACH
//          - Default attachment point for special effect to attach to squad leader
//          - Default: "overhead"
//
//  *   integer SQUAD_DISBAND_MULTIPLIER
//          - Multiplier that determines the chance of a squad disbanding when one of its units dies
//          - Formula: squad_disband_multiplier/squad_size
//          - E.g. 100: 50 percent chance when 2 units left, 33 percent chance when 3 units left
//          - Set to 0 to disable disbanding
//          - Default: 0
//
//  *   integer MIN_DISBANDABLE_SQUAD_SIZE
//         - Default: 3
//
//  *   real SQUAD_FLEE_DISTANCE
//          - Distance units of a disbanded squad will flee in a random direction
//          - set to 0 to disable fleeing
//          - Default: 0
//
//  *   real SQUAD_COMBAT_OVEREXTENSION_DISTANCE
//          - Squad members will try to come closer to each other if they are too far away during comabat
//          - Default: 300
//            (+ 25 per unit. 4 units = 400)
//
//  *   boolean LEADER_DEATH_DISBAND
//          - If true, squads will disband if their leader dies
//          - Default: false
//
//  *   real SQUAD_SHARED_DAMAGE_ACTIVATION_CHANCE
//          - Chance that part of the incoming attack damage is distributed between other squad members
//          - Default: 0.50 (50%)
//
//  *   real SQUAD_MAX_PERCENT_OF_SHARED_DAMAGE
//          - Direct defender damage is reduced up to SQUAD_MAX_PERCENT_OF_SHARED_DAMAGE
//          - Shared damage does not cause death. Only DAMAGE_TYPE_NORMAL is split
//          - Default: 0.60 (60%)
//
//  *   real SQUAD_MIN_PERCENT_OF_SHARED_DAMAGE
//          - Default: 0.3 (30%)
//
//  *   real SQUAD_MIN_AMOUNT_OF_SHARED_DAMAGE
//          - If shared damage is less than SQUAD_MIN_AMOUNT_OF_SHARED_DAMAGE it will not be deducted from the original defender
//          - Default: 3
//
//    * Functions *
//    -------------
//  *   SquadAddUnit(group squad, unit whichUnit)
//          - Adds a unit to a squad
//          - Will remove the unit from any squad it is already in
//
//  *   SquadRemoveUnit(group squad, unit whichUnit)
//          - Removes a unit from a squad
//          - Destroys squad if only 1 or 0 members remain
//
//  *   SquadSetLeader(group squad, unit whichUnit)
//          - Sets the squad's leader
//          - Adds the unit to squad if not already a member
//
//  *   unit SquadGetLeader(group squad)
//          - Returns the leader of a squad
//
//  *   SquadSetSfx(group squad, string path, string attach)
//          - Sets the special effect to be attached to units of the squad
//          - Set to null to disable special effects for the squad
//
//  *   SquadSetLeaderSfx(group squad, string path, string attach)
//          - Sets the special effect to be attached to the leader of the squad
//          - Set to null to use same special effect as regular units
//
//  *   UnitCreateSquad(unit whichUnit)
//          - If the unit is one of the squadUnits types, creates a squad
//
//  *   group UnitTypeCreateSquad(player whichPlayer, integer unitid, integer size, real x, real y, real facing)
//          - Create a squad of unit type
//          - Returns the squad
//
//  *   DisbandSquad(group squad)
//          - Removes all units from the squad and destroys it
//          - Does not cause fleeing
//
//  *   group UnitGetSquad(unit whichUnit)
//          - Returns the unit's squad
//          - Returns null if unit doesn't have a squad
//
//  *   IndividualOrderTarget(unit whichUnit, string order, widget target)
//          - Issues target order to unit without ordering the squad
//
//  *   IndividualOrderImmediate(unit whichUnit, string order)
//          - Issues immediate order to unit without ordering the squad
//
//  *   IndividualOrderPoint(unit whichUnit, string order, real x, real y)
//          - Issues point order to unit without ordering the squad
//
//===========================================================================
library SquadSystem initializer InitSquadSystem requires SquadUtils
    globals
        // Config
        integer array squadUnits
        integer array squadSize
        integer SQUAD_MAX_UNIT_COUNT = -1
        string SQUAD_SFX_PATH = null
        string SQUAD_SFX_ATTACH = "overhead"
        string SQUAD_LEADER_SFX_PATH = null
        string SQUAD_LEADER_SFX_ATTACH = "overhead"
        integer SQUAD_DISBAND_MULTIPLIER = 0
        integer SQUAD_MIN_DISBANDABLE_SIZE = 3
        real SQUAD_FLEE_DISTANCE = 0
        real SQUAD_COMBAT_OVEREXTENSION_DISTANCE = 300
        boolean LEADER_DEATH_DISBAND = false
        boolean SQUAD_SHARED_DAMAGE_ENABLED = true
        real SQUAD_SHARED_DAMAGE_ACTIVATION_CHANCE = 0.5
        real SQUAD_MAX_PERCENT_OF_SHARED_DAMAGE = 0.6
        real SQUAD_MIN_PERCENT_OF_SHARED_DAMAGE = 0.3
        real SQUAD_MIN_AMOUNT_OF_SHARED_DAMAGE = 3.0
        
        // Misc
        private group pauseSelection = CreateGroup()
        private group pauseGroupOrder = CreateGroup()
        
        // Unit hashtable
        private hashtable htbUnit = InitHashtable()
        private constant integer SQUAD = 0
        private constant integer SFX = 1
        
        // Squad hashtable
        private hashtable htbSquad = InitHashtable()
        private constant integer SFX_PATH = 0
        private constant integer SFX_ATTACH = 1
        private constant integer LEADER = 2
        private constant integer LEADER_SFX_PATH = 3
        private constant integer LEADER_SFX_ATTACH = 4
    endglobals
    
    //=========================================================
    // Squad functions
    //=========================================================
    // Get a unit's squad
    function UnitGetSquad takes unit whichUnit returns group
        local integer handleId = GetHandleId(whichUnit)
        
        if HaveSavedHandle(htbUnit, handleId, SQUAD) then
            return LoadGroupHandle(htbUnit, handleId, SQUAD)
        endif
        
        return null
    endfunction
    
    // Get a squad's leader
    function SquadGetLeader takes group squad returns unit
        local integer handleId = GetHandleId(squad)
        if HaveSavedHandle(htbSquad, handleId, LEADER) then
            return LoadUnitHandle(htbSquad, handleId, LEADER)
        endif
        return null
    endfunction
    
    // Remove unit from squad
    function SquadRemoveUnit takes group squad, unit whichUnit returns nothing
        local integer unitHandleId = GetHandleId(whichUnit)
        local integer squad_size
        
        call GroupRemoveUnit(squad, whichUnit)
        set squad_size = BlzGroupGetSize(squad)
        
        if squad_size == 1 then // Remove last member if only 1 is left
            call SquadRemoveUnit(squad, FirstOfGroup(squad))
        elseif squad_size == 0 then // Destroy squad if empty
            call FlushChildHashtable(htbSquad, GetHandleId(squad))
            call DestroyGroup(squad)
        elseif whichUnit == SquadGetLeader(squad) then
            call RemoveSavedHandle(htbSquad, GetHandleId(squad), LEADER)
        endif
        
        if HaveSavedHandle(htbUnit, unitHandleId, SFX) then
            call DestroyEffect(LoadEffectHandle(htbUnit, unitHandleId, SFX))
        endif
        
        call FlushChildHashtable(htbUnit, unitHandleId)
    endfunction
    
    // Add a unit to a squad
    function SquadAddUnit takes group squad, unit whichUnit returns nothing
        local trigger trg
        local group oldSquad
        local integer unitHandleId = GetHandleId(whichUnit)
        local integer squadHandleId = GetHandleId(squad)
        local string sfx_path = null
        local string sfx_attach
        
        set oldSquad = UnitGetSquad(whichUnit)
        if oldSquad != null then
            call SquadRemoveUnit(oldSquad, whichUnit)
        endif
        
        call GroupAddUnit(squad, whichUnit)
        call SaveGroupHandle(htbUnit, unitHandleId, SQUAD, squad)
        
        // Get SFX path
        if HaveSavedString(htbSquad, squadHandleId, SFX_PATH) then
            set sfx_path = LoadStr(htbSquad, squadHandleId, SFX_PATH)
        else
            set sfx_path = SQUAD_SFX_PATH
        endif
        // Get SFX attachment point
        if HaveSavedString(htbSquad, squadHandleId, SFX_ATTACH) then
            set sfx_attach = LoadStr(htbSquad, squadHandleId, SFX_ATTACH)
        else
            set sfx_attach = SQUAD_SFX_ATTACH
        endif
        
        // Add effect
        if sfx_path != null then
            call SaveEffectHandle(htbUnit, unitHandleId, SFX, AddSpecialEffectTarget(sfx_path, whichUnit, sfx_attach))
        endif
        
        set trg = null
        set oldSquad = null
    endfunction
    
    // Add leader to squad
    function SquadSetLeader takes group squad, unit whichUnit returns nothing
        local string sfx_path
        local string sfx_attach
        local integer squadHandleId = GetHandleId(squad)
        local integer unitHandleId = GetHandleId(whichUnit)
        
        call SaveUnitHandle(htbSquad, squadHandleId, LEADER, whichUnit)
        
        if not IsUnitInGroup(whichUnit, squad) then
            call SquadAddUnit(squad, whichUnit)
        endif
        
        // Get SFX path
        if HaveSavedString(htbSquad, squadHandleId, LEADER_SFX_PATH) then
            set sfx_path = LoadStr(htbSquad, squadHandleId, LEADER_SFX_PATH)
        else
            set sfx_path = SQUAD_LEADER_SFX_PATH
        endif
        // Get SFX attachment point
        if HaveSavedString(htbSquad, squadHandleId, LEADER_SFX_ATTACH) then
            set sfx_attach = LoadStr(htbSquad, squadHandleId, LEADER_SFX_ATTACH)
        else
            set sfx_attach = SQUAD_LEADER_SFX_ATTACH
        endif
        
        // Add/replace effect
        if sfx_path != null then
            if HaveSavedHandle(htbUnit, unitHandleId, SFX) then
                call DestroyEffect(LoadEffectHandle(htbUnit, unitHandleId, SFX))
                call RemoveSavedHandle(htbUnit, unitHandleId, SFX)
            endif
            call SaveEffectHandle(htbUnit, unitHandleId, SFX, AddSpecialEffectTarget(sfx_path, whichUnit, sfx_attach))
        endif
    endfunction
    
    // Create squad from unit
    function UnitCreateSquad takes unit whichUnit returns group
        local group squad = null
        local player owningPlayer
        local integer typeId
        local real x
        local real y
        local real facing
        local boolean isSquadUnit = false
        local integer index = 0
        local integer size_index = 0
        
        if SQUAD_MAX_UNIT_COUNT >= 0 then
            set typeId = GetUnitTypeId(whichUnit)
            
            loop
                set isSquadUnit = squadUnits[index] == typeId
                set index = index + 1
                exitwhen index > SQUAD_MAX_UNIT_COUNT or isSquadUnit
            endloop
            
            if isSquadUnit then
                set squad = CreateGroup()
                set owningPlayer = GetOwningPlayer(whichUnit)
                set x = GetUnitX(whichUnit)
                set y = GetUnitY(whichUnit)
                set facing = GetUnitFacing(whichUnit)
                set size_index = index-1
                set index = 0
                
                call SquadAddUnit(squad, whichUnit)
                loop
                    call SquadAddUnit(squad, CreateUnit(owningPlayer, typeId, x, y, facing))
                    set index = index + 1
                    exitwhen index == squadSize[size_index]-1
                endloop
            endif
        endif
        
        set owningPlayer = null
        return squad
    endfunction
    
    // Create a squad with units of type for player
    function UnitTypeCreateSquad takes player whichPlayer, integer unitid, integer size, real x, real y, real facing returns group
        local group squad = CreateGroup()
        local integer index = 0
        
        loop
            call SquadAddUnit(squad, CreateUnit(whichPlayer, unitid, x, y, facing))
            set index = index + 1
            exitwhen index == size
        endloop
        
        return squad
    endfunction
    
    // Remove all units from squad
    function DisbandSquad takes group squad returns nothing
        local unit pickedUnit
        
        loop
            set pickedUnit = FirstOfGroup(squad)
            exitwhen pickedUnit == null
            call SquadRemoveUnit(squad, pickedUnit)
        endloop
        
        set pickedUnit = null
    endfunction
    
    // Destroy existing effect and create/save new one
    private function SetSfxEnum takes nothing returns nothing
        local unit enumUnit = GetEnumUnit()
        local integer unitHandleId = GetHandleId(enumUnit)
        local integer squadHandleId = GetHandleId(UnitGetSquad(enumUnit))
        local string path = LoadStr(htbSquad, squadHandleId, SFX_PATH)
        
        if HaveSavedHandle(htbUnit, unitHandleId, SFX) then
            call DestroyEffect(LoadEffectHandle(htbUnit, unitHandleId, SFX))
            call RemoveSavedHandle(htbUnit, unitHandleId, SFX)
        endif
        
        if path != null then
            call SaveEffectHandle(htbUnit, unitHandleId, SFX, AddSpecialEffectTarget(path, enumUnit, LoadStr(htbSquad, squadHandleId, SFX_ATTACH)))
        endif
        
        set enumUnit = null
    endfunction
    
    // Set the special effect for a squad
    function SquadSetSfx takes group squad, string path, string attach returns nothing
        local integer handleId = GetHandleId(squad)
        
        call SaveStr(htbSquad, handleId, SFX_PATH, path)
        call SaveStr(htbSquad, handleId, SFX_ATTACH, attach)
        
        call ForGroup(squad, function SetSfxEnum)
    endfunction
    
    // Set the special effect for the leader of a squad
    function SquadSetLeaderSfx takes group squad, string path, string attach returns nothing
        local unit leader = SquadGetLeader(squad)
        local integer squadHandleId = GetHandleId(squad)
        local integer unitHandleId
        
        call SaveStr(htbSquad, squadHandleId, LEADER_SFX_PATH, path)
        call SaveStr(htbSquad, squadHandleId, LEADER_SFX_ATTACH, attach)
        
        if leader != null then
            if path == null then
                if HaveSavedString(htbSquad, squadHandleId, SFX_PATH) then
                    set path = LoadStr(htbSquad, squadHandleId, SFX_PATH)
                else
                    set path = SQUAD_SFX_PATH
                endif
                if HaveSavedString(htbSquad, squadHandleId, SFX_ATTACH) then
                    set attach = LoadStr(htbSquad, squadHandleId, SFX_ATTACH)
                else
                    set attach = SQUAD_SFX_ATTACH
                endif
            endif
            
            if path != null then
                set unitHandleId = GetHandleId(leader)
                if HaveSavedHandle(htbUnit, unitHandleId, SFX) then
                    call DestroyEffect(LoadEffectHandle(htbUnit, unitHandleId, SFX))
                    call RemoveSavedHandle(htbUnit, unitHandleId, SFX)
                endif
                call SaveEffectHandle(htbUnit, unitHandleId, SFX, AddSpecialEffectTarget(path, leader, attach))
            endif
        endif
        
        set leader = null
    endfunction
    
    // Issue target order to unit without ordering the squad
    function IndividualOrderTarget takes unit whichUnit, string order, widget target returns nothing
        call GroupAddUnit(pauseGroupOrder, whichUnit)
        call IssueTargetOrder(whichUnit, order, target)
        call GroupRemoveUnit(pauseGroupOrder, whichUnit)
    endfunction
    
    // Issue immediate order to unit without ordering the squad
    function IndividualOrderImmediate takes unit whichUnit, string order returns nothing
        call GroupAddUnit(pauseGroupOrder, whichUnit)
        call IssueImmediateOrder(whichUnit, order)
        call GroupRemoveUnit(pauseGroupOrder, whichUnit)
    endfunction
    
    // Issue point order to unit without ordering the squad
    function IndividualOrderPoint takes unit whichUnit, string order, real x, real y returns nothing
        call GroupAddUnit(pauseGroupOrder, whichUnit)
        call IssuePointOrder(whichUnit, order, x, y)
        call GroupRemoveUnit(pauseGroupOrder, whichUnit)
    endfunction
    
    //=========================================================
    // Triggers
    //=========================================================
    // Unit sold: create squad
    private function UnitSold takes nothing returns boolean
        call UnitCreateSquad(GetSoldUnit())
        return false
    endfunction
    
    // Unit sold: create squad
    private function UnitTrained takes nothing returns boolean
        call UnitCreateSquad(GetTrainedUnit())
        return false
    endfunction
    
    // Unit selected: modify selection
    private function UnitSelected takes nothing returns nothing
        local unit triggerUnit = GetTriggerUnit()
        local player triggerPlayer = GetTriggerPlayer()
        local group squad = UnitGetSquad(triggerUnit)
        local unit pickedUnit
        local unit leader
        local integer squad_size
        local integer index = 0
        
        // Only proceed if unit has squad and player has control over unit
        if squad != null and not IsUnitInGroup(triggerUnit, pauseSelection) and SquadUtils.PlayerHasControl(triggerUnit, triggerPlayer) then
            call TriggerSleepAction(0.01) // this is necessary to update selection in case leader was previously selected
            call GroupAddGroup(squad, pauseSelection)
            
            // If leader is selected, set triggerUnit to leader
            set leader = SquadGetLeader(squad)
            if leader != null and IsUnitSelected(leader, triggerPlayer) then
                set triggerUnit = leader
            endif
            
            set squad_size = BlzGroupGetSize(squad)
            loop
                exitwhen index >= squad_size
                
                set pickedUnit = BlzGroupUnitAt(squad, index)
                if pickedUnit != triggerUnit then
                    call SelectUnitRemoveForPlayer(pickedUnit, triggerPlayer)
                endif
                
                set index = index + 1
            endloop
            
            call TriggerSleepAction(0.01) // this is necessary to prevent all selected squad units from firing the event
            call GroupRemoveGroup(squad, pauseSelection)
        endif
        
        set triggerUnit = null
        set triggerPlayer = null
        set squad = null
        set pickedUnit = null
        set leader = null
    endfunction
    
    // Unit target order: order squad
    private function SquadTargetOrder takes nothing returns boolean
        local trigger trg
        local string order
        local unit orderedUnit = GetOrderedUnit()
        local unit targetUnit
        local group squad = UnitGetSquad(orderedUnit)
        
        if squad != null and not IsUnitInGroup(orderedUnit, pauseGroupOrder) then
            set trg = GetTriggeringTrigger()
            set order = OrderId2String(GetIssuedOrderId())
            set targetUnit = GetOrderTargetUnit()
            
            call DisableTrigger(trg) // Prevent infinite loop
            // smart order on friendly unit doesn't work
            if order == "smart" and targetUnit != null and IsPlayerAlly(GetOwningPlayer(orderedUnit), GetOwningPlayer(targetUnit)) then
                call GroupPointOrder(squad, order, GetUnitX(targetUnit), GetUnitY(targetUnit))
            else
                call GroupTargetOrder(squad, order, GetOrderTarget())
            endif
            call EnableTrigger(trg)
        endif
        
        set trg = null
        set orderedUnit = null
        set targetUnit = null
        set squad = null
        return false
    endfunction
    
    // Unit immediate order: order squad
    private function SquadImmediateOrder takes nothing returns boolean
        local trigger trg
        local unit orderedUnit = GetOrderedUnit()
        local group squad = UnitGetSquad(orderedUnit)
        
        if squad != null and not IsUnitInGroup(orderedUnit, pauseGroupOrder) then
            set trg = GetTriggeringTrigger()
            call DisableTrigger(trg) // Prevent infinite loop
            call GroupImmediateOrder(squad, OrderId2String(GetIssuedOrderId()))
            call EnableTrigger(trg)
        endif
        
        set trg = null
        set orderedUnit = null
        set squad = null
        return false
    endfunction
    
    // Unit point order: order squad
    private function SquadPointOrder takes nothing returns boolean
        local trigger trg
        local unit orderedUnit = GetOrderedUnit()
        local group squad = UnitGetSquad(orderedUnit)
        
        if squad != null and not IsUnitInGroup(orderedUnit, pauseGroupOrder) then
            set trg = GetTriggeringTrigger()
            call DisableTrigger(trg) // Prevent infinite loop
            call GroupPointOrder(squad, OrderId2String(GetIssuedOrderId()), GetOrderPointX(), GetOrderPointY())
            call EnableTrigger(trg)
        endif
        
        set trg = null
        set orderedUnit = null
        set squad = null
        return false
    endfunction
    
    // Make enumerated units flee to random point
    private function FleeEnum takes nothing returns nothing
        local unit enumUnit = GetEnumUnit()
        local real x = GetRandomReal(-SQUAD_FLEE_DISTANCE, SQUAD_FLEE_DISTANCE)
        local real y = SquareRoot(Pow(SQUAD_FLEE_DISTANCE, 2) - Pow(x, 2))
        
        // y is always positive, allow for negative value
        if GetRandomInt(0, 1) == 0 then
            set y = -y
        endif
        
        call IssuePointOrder(enumUnit, "move", GetUnitX(enumUnit)+x, GetUnitY(enumUnit)+y)
    endfunction
    
    // Unit dies: remove unit from squad and adjust selection
    private function UnitDies takes nothing returns boolean
        local unit dyingUnit = GetDyingUnit()
        local group squad = UnitGetSquad(dyingUnit)
        local group squad_copy
        local player indexPlayer
        local boolean isLeader
        local integer squad_size
        local integer index = 0
        
        if squad != null then
            set squad_size = BlzGroupGetSize(squad)-1
            
            if squad_size > 0 then
                // Get a copy of the squad in case only 1 unit is left and it is disbanded
                set squad_copy = CreateGroup()
                call GroupAddGroup(squad, squad_copy)
                call GroupRemoveUnit(squad_copy, dyingUnit)
                set isLeader = dyingUnit == SquadGetLeader(squad)
                
                // Remove the unit from squad
                call SquadRemoveUnit(squad, dyingUnit)
                
                // Chance the squad disbands
                if squad_size <= SQUAD_MIN_DISBANDABLE_SIZE and (SQUAD_DISBAND_MULTIPLIER/squad_size >= GetRandomInt(1, 100) or (LEADER_DEATH_DISBAND and isLeader)) then
                    if SQUAD_FLEE_DISTANCE > 0 then
                        call GroupAddGroup(squad_copy, pauseGroupOrder)
                        call ForGroup(squad_copy, function FleeEnum)
                        call GroupRemoveGroup(squad_copy, pauseGroupOrder)
                    endif
                    
                    call DisbandSquad(squad_copy)
                    
                // Adjust selection
                else
                    loop
                        set indexPlayer = Player(index)
                        
                        if IsUnitSelected(dyingUnit, indexPlayer) and SquadUtils.PlayerHasControl(dyingUnit, indexPlayer) then
                            call SelectUnitAddForPlayer(FirstOfGroup(squad_copy), indexPlayer)
                        endif
                        
                        set index = index + 1
                        exitwhen index == bj_MAX_PLAYER_SLOTS
                    endloop
                endif
            endif
        endif
        
        set dyingUnit = null
        set squad = null
        set squad_copy = null
        set indexPlayer = null
        return false
    endfunction
    
    

    // Unit is attacked: make sure attacking unit's squad follows through
    private function UnitAttacked takes nothing returns boolean
        local unit squadMember = GetAttacker()
        local group squad = UnitGetSquad(squadMember)
        local integer i = 0
        local integer squadSize = BlzGroupGetSize(squad)
        local real maxRange
        local group distantMeleeMembers
        local group distantRangedMembers
        local string order

        if squadSize <= 1 then
            return false
        endif

        if SquadUtils.IsRangedUnit(squadMember) then
            return false
        endif

        set maxRange = SQUAD_COMBAT_OVEREXTENSION_DISTANCE + 30 * squadSize
        set distantMeleeMembers = SquadUtils.GetDistantGroupMembers(squadMember, squad, maxRange, false)
            
        set distantRangedMembers = SquadUtils.GetDistantGroupMembers(squadMember, squad, maxRange, true)

        loop
            exitwhen i > BlzGroupGetSize(distantMeleeMembers)
            set order = OrderId2String(GetUnitCurrentOrder(BlzGroupUnitAt(distantMeleeMembers, i)))

            if order != "smart" and order != "attack" then
                call IndividualOrderTarget(BlzGroupUnitAt(distantMeleeMembers, i), "smart", squadMember)
            endif

            set i = i + 1
        endloop
        set i = 0
        loop
            exitwhen i > BlzGroupGetSize(distantRangedMembers)

            set order = OrderId2String(GetUnitCurrentOrder(BlzGroupUnitAt(distantRangedMembers, i)))
            if order != "smart" and order != "attack" then
                call IndividualOrderTarget(BlzGroupUnitAt(distantRangedMembers, i), "smart", squadMember)
            endif

            set i = i + 1
        endloop

        set distantMeleeMembers =  null
        set distantRangedMembers =  null
        set squad = null
        
        return false
        
    endfunction


    // Unit damaged: share damage
    // by kokon
    private function UnitDamaging takes nothing returns boolean
        local unit defender = GetTriggerUnit()
        local group squad = UnitGetSquad(defender)
        local real sharedDamage
        if (squad != null) then
          set sharedDamage = SquadUtils.ShareGroupDamage(defender, squad, GetEventDamage(), BlzGetEventAttackType(), BlzGetEventDamageType(), BlzGetEventWeaponType())
          call BlzSetEventDamage(GetEventDamage() - sharedDamage)
        endif


        return false
    endfunction
    //=========================================================
    // Initializer
    //=========================================================
    private function InitSquadSystem takes nothing returns nothing
        local trigger trgUnitSold = CreateTrigger()
        local trigger trgUnitTrained = CreateTrigger()
        local trigger trgUnitSelected = CreateTrigger()
        local trigger trgSquadTargetOrder = CreateTrigger()
        local trigger trgSquadImmediateOrder = CreateTrigger()
        local trigger trgSquadPointOrder = CreateTrigger()
        local trigger trgUnitDies = CreateTrigger()
        local trigger trgUnitAttacked = CreateTrigger()
        local trigger trgUnitDamaging = CreateTrigger()
        local player indexPlayer
        local integer index = 0
        
        // EVENT_PLAYER_UNIT_DAMAGING init should come after other occurances in the map
        call TriggerSleepAction(0.1)
        loop
            set indexPlayer = Player(index)
            call TriggerRegisterPlayerUnitEvent(trgUnitSold, indexPlayer, EVENT_PLAYER_UNIT_SELL, null)
            call TriggerRegisterPlayerUnitEvent(trgUnitTrained, indexPlayer, EVENT_PLAYER_UNIT_TRAIN_FINISH, null)
            call TriggerRegisterPlayerUnitEvent(trgUnitSelected, indexPlayer, EVENT_PLAYER_UNIT_SELECTED, null)
            call TriggerRegisterPlayerUnitEvent(trgSquadTargetOrder, indexPlayer, EVENT_PLAYER_UNIT_ISSUED_TARGET_ORDER, null)
            call TriggerRegisterPlayerUnitEvent(trgSquadImmediateOrder, indexPlayer, EVENT_PLAYER_UNIT_ISSUED_ORDER, null)
            call TriggerRegisterPlayerUnitEvent(trgSquadPointOrder, indexPlayer, EVENT_PLAYER_UNIT_ISSUED_POINT_ORDER, null)
            call TriggerRegisterPlayerUnitEvent(trgUnitDies, indexPlayer, EVENT_PLAYER_UNIT_DEATH, null)
            call TriggerRegisterPlayerUnitEvent(trgUnitAttacked, indexPlayer, EVENT_PLAYER_UNIT_ATTACKED, null)
            if SQUAD_SHARED_DAMAGE_ENABLED == true then
              call TriggerRegisterPlayerUnitEvent(trgUnitDamaging, indexPlayer, EVENT_PLAYER_UNIT_DAMAGING, null)
            endif

            set index = index + 1
            exitwhen index == bj_MAX_PLAYER_SLOTS
        endloop
        
        call TriggerAddCondition(trgUnitSold, function UnitSold)
        call TriggerAddCondition(trgUnitTrained, function UnitTrained)
        call TriggerAddAction(trgUnitSelected, function UnitSelected)
        call TriggerAddCondition(trgSquadTargetOrder, function SquadTargetOrder)
        call TriggerAddCondition(trgSquadImmediateOrder, function SquadImmediateOrder)
        call TriggerAddCondition(trgSquadPointOrder, function SquadPointOrder)
        call TriggerAddCondition(trgUnitDies, function UnitDies)
        call TriggerAddCondition(trgUnitAttacked, function UnitAttacked)
        if SQUAD_SHARED_DAMAGE_ENABLED == true then
          call TriggerAddCondition(trgUnitDamaging, function UnitDamaging)
        endif
        
        set trgUnitSold = null
        set trgUnitTrained = null
        set trgUnitSelected = null
        set trgSquadTargetOrder = null
        set trgSquadImmediateOrder = null
        set trgSquadPointOrder = null
        set trgUnitDies = null
        set trgUnitAttacked = null
        set trgUnitDamaging = null
        set indexPlayer = null
    endfunction
endlibrary