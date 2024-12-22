//=========================================================================== 
library SquadUtils 
    //========================================================= 
    // Util 
    //========================================================= 
    struct SquadUtils 

        static method PlayerHasControl takes unit whichUnit, player whichPlayer returns boolean 
            local player owningPlayer = GetOwningPlayer(whichUnit) 
            local boolean result = owningPlayer == whichPlayer or GetPlayerAlliance(owningPlayer, whichPlayer, ALLIANCE_SHARED_CONTROL) 
            set owningPlayer = null 
            return result 
        endmethod
    
        // By kokon 
        static method GetMaxDistanceBetweenUnits takes group g returns real 
            local unit u1 
            local unit u2 
            local real maxDistance = 0.0 
            local real dx 
            local real dy 
            local real distance 
            local integer i 
            local integer j 
            local integer groupSize = BlzGroupGetSize(g) 
    
            if groupSize < 2 then 
                return 0.0 
            endif 
    
            set i = 0 
            loop 
                exitwhen i >= groupSize 
            
                set u1 = BlzGroupUnitAt(g, i) 
                set j = i + 1 
                loop 
                    exitwhen j >= groupSize 
                
                    set u2 = BlzGroupUnitAt(g, j) 
                
                    set dx = GetUnitX(u2) - GetUnitX(u1) 
                    set dy = GetUnitY(u2) - GetUnitY(u1) 
                    set distance = dx * dx + dy * dy
                
                    if distance > maxDistance then
                        set maxDistance = distance
                    endif
                    
                    set j = j + 1
                endloop
                
                set i = i + 1
            endloop
            
            set u1 = null
            set u2 = null
        
            return SquareRoot(maxDistance)
        endmethod 
 
        // By kokon 
        static method GetIndexOfLowestHPUnit takes group g returns integer 
            local integer lowestIndex = - 1 
            local real lowestHP = 99999999.0 
            local integer i = 0 
            local integer groupSize = BlzGroupGetSize(g) 
            local unit u 
            local real hp 
 
            loop 
                exitwhen i >= groupSize
                set u = BlzGroupUnitAt(g, i) 
                set hp = GetUnitState(u, UNIT_STATE_LIFE) 
      
                if hp < lowestHP then 
                    set lowestHP = hp 
                    set lowestIndex = i 
                endif 
      
                set i = i + 1 
            endloop 
 
            set u = null 
            return lowestIndex 
        endmethod 
    
        // By kokon 
        static method IsRangedUnit takes unit u returns boolean 
            if BlzGetUnitWeaponRealField(u, UNIT_WEAPON_RF_ATTACK_RANGE, 0) > 200 or BlzGetUnitWeaponRealField(u, UNIT_WEAPON_RF_ATTACK_RANGE, 1) > 200 then 
                return true 
            endif 
            return false 
        endmethod 
    
        // By kokon 
        static method GetAverageHPInGroup takes group g returns real 
            local integer groupSize = BlzGroupGetSize(g) 
            local integer i = 0 
            local real totalHP = 0.0 
            local unit u 
 
            if groupSize == 0 then 
                return 0.0 
            endif 
 
            loop 
                exitwhen i >= groupSize
                set u = BlzGroupUnitAt(g, i) 
                set totalHP = totalHP + GetUnitState(u, UNIT_STATE_LIFE) 
                set i = i + 1 
            endloop 
 
            set u = null 
            return totalHP / groupSize 
        endmethod 

        // By kokon 
        static method GetDistantGroupMembers takes unit primaryUnit, group sourceGroup, real distance, boolean isRanged returns group
            local group resultGroup = CreateGroup()
            local real primaryUnitX = GetUnitX(primaryUnit)
            local real primaryUnitY = GetUnitY(primaryUnit)
            local unit u
            local real dx
            local real dy
            local real currentDistance
            local integer i = 0
            local integer groupSize = BlzGroupGetSize(sourceGroup)
        
            loop
                exitwhen i >= groupSize
                set u = BlzGroupUnitAt(sourceGroup, i)
                if u != primaryUnit then 
                    set dx = GetUnitX(u) - primaryUnitX
                    set dy = GetUnitY(u) - primaryUnitY
                    set currentDistance = SquareRoot(dx * dx + dy * dy)
        
                    if currentDistance > distance and IsRangedUnit(u) == isRanged then
                        call GroupAddUnit(resultGroup, u)
                    endif
                endif
        
                set i = i + 1
            endloop
        
            set u = null
            return resultGroup
        endmethod
    
        // by kokon 
        // returns amount of damage that was distributed to other squad members
        static method ShareGroupDamage takes unit defender, group squad, real incomingDamage, attacktype attackType, damagetype damageType, weapontype weaponType returns real 
            local integer groupSize = BlzGroupGetSize(squad) 
            local real ratio 
            local integer currentIndex 
            local integer safetyIndex = 0 
            local real sharedDamage 
            local real skipChance = 0.0 
            local unit currentUnit 
            local integer splitCount 
            local real averageHpInSquad 
            local real defenderLife 
            local integer appliedDamageSplitCount = 0 
            local real appliedDamageCurrent = 0
            local real appliedDamageTotal = 0
            local real defenderLifeRatio
            local real this_squad_shared_damage_activation_chance
        
            if groupSize < 2 then 
                return 0.0
            endif 

            if damageType != DAMAGE_TYPE_NORMAL then 
                return 0.0
            endif 
            if weaponType == WEAPON_TYPE_WHOKNOWS then 
                return 0.0
            endif 

            set defenderLife = GetUnitState(defender, UNIT_STATE_LIFE)
            set defenderLifeRatio = defenderLife / GetUnitState(defender, UNIT_STATE_MAX_LIFE)

            if groupSize > 2 then
                set this_squad_shared_damage_activation_chance = SQUAD_SHARED_DAMAGE_ACTIVATION_CHANCE * 1.1
            endif
            if(defenderLifeRatio < 0.5) then
                set this_squad_shared_damage_activation_chance =(SQUAD_SHARED_DAMAGE_ACTIVATION_CHANCE + 1.0) / 2
            endif
            if GetRandomReal(0, 1) < this_squad_shared_damage_activation_chance then 
                return 0.0
            endif 
            
            set averageHpInSquad = GetAverageHPInGroup(squad) 
            if defenderLife >= averageHpInSquad * 1.35 then 
                return 0.0
            elseif defenderLife >= averageHpInSquad * 1.1 and GetRandomInt(0, 2) == 2 then 
                return 0.0
            endif 
            set ratio = GetRandomReal(SQUAD_MIN_PERCENT_OF_SHARED_DAMAGE, SQUAD_MAX_PERCENT_OF_SHARED_DAMAGE) 
            set sharedDamage = incomingDamage * ratio 
            if sharedDamage < SQUAD_MIN_AMOUNT_OF_SHARED_DAMAGE then 
                return 0.0
            endif 

            if defenderLife > 0 then 
                set splitCount = groupSize - 1 
                if(splitCount >= 2) then 
                    set splitCount = 2 - GetRandomInt(0, 1) 
                endif 
                loop 
                    exitwhen appliedDamageSplitCount >= splitCount 
                    set currentIndex = GetRandomInt(0, groupSize - 1) 
                    set currentUnit = BlzGroupUnitAt(squad, currentIndex) 
                    if currentUnit != defender and GetUnitState(currentUnit, UNIT_STATE_LIFE) > sharedDamage then 
                        set skipChance =(1 - GetUnitState(currentUnit, UNIT_STATE_LIFE) / GetUnitState(currentUnit, UNIT_STATE_MAX_LIFE)) 
                        if GetIndexOfLowestHPUnit(squad) == currentIndex then 
                            set skipChance = skipChance + 0.20 
                        endif 
                        if averageHpInSquad > GetUnitState(currentUnit, UNIT_STATE_LIFE) * 0.9 then 
                            set skipChance = skipChance + 0.20 
                        endif 
                        if defenderLife > GetUnitState(currentUnit, UNIT_STATE_LIFE) then 
                            set skipChance = skipChance + 0.20 
                        endif 
                        if IsRangedUnit(currentUnit) == true then 
                            set skipChance = skipChance + 0.20 
                        endif 
                        if GetRandomReal(0, 1.0) > skipChance then 
                            set appliedDamageCurrent = sharedDamage / splitCount
                            set appliedDamageTotal = appliedDamageTotal + appliedDamageCurrent
                            call UnitDamageTarget(GetEventDamageSource(), currentUnit, appliedDamageCurrent, true, false, attackType, damageType, WEAPON_TYPE_WHOKNOWS) 
                            set appliedDamageSplitCount = appliedDamageSplitCount + 1 
                        endif 
                    endif 
                    set safetyIndex = safetyIndex + 1 
                    exitwhen safetyIndex >= 12 
                endloop 
            endif 
  
            set defender = null 
            set squad = null 
            set currentUnit = null 


            return appliedDamageTotal
        endmethod 
    endstruct 

endlibrary