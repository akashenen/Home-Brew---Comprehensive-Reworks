---@class PendingPartialRespec
---@field level integer|nil
---@field charLevel integer
---@field snapshot table|nil

---@type table<string, PendingPartialRespec>
local pendingRespec = {}

---@param character string
---@return string
local function Guid(character)
    return string.sub(tostring(character), -36)
end

---@param peerId integer
---@return integer
local function PeerToReservedUserID(peerId)
    return peerId - (peerId % 0x10000) + 1
end

-- Only during dialog? Not sure, haven't tested
local RESPEC_START_FLAG = "6d4979bc-8e95-46be-9c27-96c6e22b0152"
local TOAST_DELAY_MS = 1000
local classDisplayNames = {}
local featDisplayNames = {}
local featDescriptionGuids = {}
local featDescriptionsLoaded = false
local passiveDisplayNames = {}
local hbClassPassives = nil

-- Exact union of the thirteen HB class-choice PassiveLists. Embedding the IDs
-- avoids relying on PassiveList static-data exposure, which varies by SE build.
local HB_CLASS_PASSIVE_IDS = [[AdaptivePlating;ArcaneCalibrationMatrix;AutomatedArcaneSuppression;CastleDefense;DeadZoneCalibration;ElementalPayload;EmergencyPowerCell;FailsafeInjection;IncendiaryRounds;KineticFeedbackLoop;LikeClockwork;ModularAugmentation;NaniteDispersionField;Overclocked;PrecisionRifling;RecoilCompensation;Safeguard;SpeedLoader;SyntheticActionEconomy;VitalAim;BarbarousAssault;BrutalCritical;DangerSense;DeathGlare;Faceoff;FuriousCriticals;LandsStride;OverwhelmingPower;PeakPhysicality;RageoftheMountain;RageoftheUndefeated;RagingVitality;RelentlessRage;RipandTear;RootedinAnger;TemperedRetaliation;TerrifyingBellow;UnrelentingRampage;UnarmouredBeast;UnstoppableForce;Aggressive_Rhythm;Discerning_Insult;Distracting_Dissonance;Dueling_Ditties;Echoes_of_Fortitude;Encouraging_Momentum;Engaging_Composition;Guiding_Performance;Harmonious_Aura;Infuriating_Amplification;Inspirational_Resonance;Inspiring_Crescendo;Insufferable_Discord;Melodic_Precision;Mobile_Maestro;Mocksmith;Silver_Tongued_Savant;Soothing_Words;Unprecedented_Encore;Vigorously_Tuned;Aegis;Blessed_Resolve;BloodforBlood;Consecrative_Sacrifice;Divine_Resiliance;Divine_Restoration;Ethereal_Intuition;Flames_of_Repentance;Holy_Fortitude;Guided_Strikes;Holy_Retribution;Immaculate_Ward;Martyrdom;Paradisiacal_Gift;Sacral_Bulwark;Sanctified_Presence;Sanctifying_Aura;Stalwart;Stout_Believer;Venerational_Strikes;Armour_of_Thorns;Combats_Harvest;Earthern_Sentinel;Feral_Precision;Feral_Resiliance;Ferocious_Stand;Instinctive_Transformation;Kindred_Instinct;WildShape_Combat;Natural_Bounty;Natural_Resurgence;Natures_Mercy;Natures_Wrath;Pack_Leader;Primal_Bloodletter;Primal_Surge;Primal_Takedown;Shapechangers_Versatility;Territorial_Dominance;Wild_Stride;Aspect_of_Defiance;Challengers_Call;Charge_of_the_Collective;Duellist;Full_Arsenal;Heavy_Assault;Intuitive_Warning;Ironclad;Iron_Will;Leaders_Momentum;Martial_Fortress;Martial_Reclaim;Merciless;Natural_Born_Leader;Opportunist;Proper_Form;Reckless_Abandon;Sentinels_Protection;Tactical_Retreat;Tunnel_Fighter;Counterflow;Critical_Flow;Dance_of_Flowing_Water;Deflective_Reflex;Dexterous_Ward;Fist_of_Crushing_Rock;Focused_Stream;Fortified_Psyche;Harmonious_Barrage;Harmonious_Defense;Martial_Empowerment;Mystic_Strikes;Opportune_Reversal;Resonance_of_Body;Sagacious_Resilience;Soused_Rampart;Tempestuous_Reprise;Tranquil_Fortitude;Windwaker;Zen_Accuracy;Attonement;Critical_Oath;Death_Sentence;Divine_Health;Divine_Resurgence;Divine_Sense;Divine_Shielding;Holy_Bulwark;Holy_Wrath;Infallible_Beacon;Lay_On_Hands;Oathbound_Renewal;Oath_Channeling;Principle_of_Belief;Repel_the_Damned;Resplendent_Reverb;Smite_Makes_Right;Stalwart_Eruption;Stalwart_Resolve;Visage_of_Sanctity;Ambush_Breaker;Ballistic_Infusion;Beastbonds_Precision;Beastial_Recovery;Blood_Bond;Bounty_Hunter;Close_Quarters_Shooter;Escapist;Explosive_Arrowheads;Hidden_Inventory;Marksmans_Edge;Multiattack_Defense;Natural_Huntsman;Natural_Opportunity;Protective_Bond;Sniper;Superior_Technique;Sure_Shot;Two_Weapon_Fighting;Wanton_Synergy;Cunning_Strikes;Cutthroat;Elusive_Retreat;Elusive_Shadow;Fast_Hands;Fatal_Manoeuvre;Grievous_Wounds;Illusory_Advantage;Light_Footwork;Low_Visibility;Manipulator;Now_You_See_Me;Quick_Reflexes;Reactive_Movement;Sharp_Eyes;CSpectre;Spectral_Hunter;Umbral_Sight;Vanishing_Act;Venomous;ArcaneOverflow;ArcaneOppression;ArcaneReservoir;CharismaticInfusion;CharismaticShield;DormantCharge;ElementalAfterglow;EnchantingInfluence;EphemeralBarrier;EssentialEpiphany;EvasiveWarp;LatentAcuity;MistyEscape;MysticEmpowerment;NaturalVortex;ReactiveReprise;SharedCreation;SorcerousAcumen;SorcerousFocus;VeiledSynergy;BaneofthePact;BindingTransposition;BoundElements;BoundCompulsion;CurseofHellfire;DarkRetaliation;CDevilsSight;EldritchEnervation;EldritchLethargy;EldritchPull;HellishRebuttal;HellboundVision;LuckoftheDevil;MasterofChaos;OneWithShadows;PactProtection;PactStricken;RepellingBlast;ResiliantServitude;ShadeWalker;Arcane_Interruption;Arcane_Reverb;Arcane_Shield;Boon_of_Plumes;Edict_of_Divinity;Elemental_Countercharge;Enchanted_Safeguard;Flames_Riposte;Illusory_Phantasm;Magical_Insight;Mystic_Override;Potent_Cantrips;Potent_Spells;Spellblade;Spellbound_Rebirth;Spell_Surge;Telekinetic_Command;CWarMagic;Wizards_Clarity;Woven_Precision]]

local PROGRESSION_SELECTION_COMPONENTS = {
    "ProgressionPassives",
    "ProgressionMeta",
    "ProgressionFeat",
    "ProgressionReplicatedFeat",
    "LevelUp",
}

---@class PartialRespecDisplayName
---@field DisplayNameHandle string|nil
---@field DisplayNameFallback string
---@field PassiveId string|nil

---@param value string
---@return string|nil
local function HumanizeResourceName(value)
    local name = tostring(value)
    if name:match("^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$") then
        return nil
    end
    name = name:gsub("^ProgressionSubClass_", "")
    name = name:gsub("^ProgressionClass_", "")
    name = name:gsub("^Progression_", "")
    name = name:gsub("^Class_", "")
    name = name:gsub("^SubClass_", "")
    name = name:gsub("^Feat_", "")
    name = name:gsub("([a-z])([A-Z])", "%1 %2")
    name = name:gsub("_", " ")
    return name
end

--- Extracts a localization handle from a TranslatedString.
---@param value TranslatedString
---@return string|nil
local function TranslatedDisplayNameHandle(value)
    if not value or not value.Handle then return nil end

    local valueHandle = value.Handle
    local handle = valueHandle.Handle or valueHandle
    if handle then
        local result = tostring(handle)
        if result ~= "" and not result:find("^ResStr_") then
            return result
        end
    end
    return nil
end

local RESOURCE_TYPES_WITH_NAME = { ClassDescription = true, Feat = true }
local RESOURCE_TYPES_WITH_DISPLAY_NAME = { ClassDescription = true, FeatDescription = true }

--- Resolves a static resource's display name (localized handle + humanized fallback).
---@param resourceGuid string
---@param resourceType string
---@param fallback string
---@return PartialRespecDisplayName
local function ResourceDisplayName(resourceGuid, resourceType, fallback)
    local displayName = {
        DisplayNameHandle = nil,
        DisplayNameFallback = fallback,
    }

    local resource = Ext.StaticData.Get(resourceGuid, resourceType)
    if resource then
        -- Feat has only Name, FeatDescription only DisplayName; ClassDescription has both.
        if RESOURCE_TYPES_WITH_DISPLAY_NAME[resourceType] then
            displayName.DisplayNameHandle = TranslatedDisplayNameHandle(resource.DisplayName)
        end

        if RESOURCE_TYPES_WITH_NAME[resourceType] then
            local resourceName = resource.Name
            if resourceName then
                local name = HumanizeResourceName(resourceName)
                if name then displayName.DisplayNameFallback = name end
            end
        end

        if displayName.DisplayNameHandle then return displayName end
    end
    return displayName
end

---@param classGuid string
---@return PartialRespecDisplayName
local function ClassDisplayName(classGuid)
    if classDisplayNames[classGuid] then
        return classDisplayNames[classGuid]
    end

    classDisplayNames[classGuid] = ResourceDisplayName(classGuid, "ClassDescription", "Unknown class?")
    return classDisplayNames[classGuid]
end

---@param subclassGuid string
---@return PartialRespecDisplayName
local function SubClassDisplayName(subclassGuid)
    return ResourceDisplayName(subclassGuid, "ClassDescription", "Unknown subclass?")
end

--- Builds a FeatId -> FeatDescription guid map once to find localized feat display handles.
local function LoadFeatDescriptionGuids()
    if featDescriptionsLoaded then return end

    local descriptionGuids = Ext.StaticData.GetAll("FeatDescription")
    if not descriptionGuids then return end

    for _, descriptionGuid in ipairs(descriptionGuids) do
        local description = Ext.StaticData.Get(descriptionGuid, "FeatDescription")
        if description then
            local featId = description.FeatId
            if featId then
                local key = tostring(featId)
                if not featDescriptionGuids[key] then
                    featDescriptionGuids[key] = tostring(descriptionGuid)
                end
            end
        end
    end

    featDescriptionsLoaded = true
end

--- Feat display name with localized fallback via the linked FeatDescription resource.
---@param featGuid string
---@return PartialRespecDisplayName
local function FeatDisplayName(featGuid)
    if featDisplayNames[featGuid] then
        return featDisplayNames[featGuid]
    end

    local displayName = ResourceDisplayName(featGuid, "Feat", "Unknown feat")
    LoadFeatDescriptionGuids()

    local descriptionGuid = featDescriptionGuids[featGuid]
    if descriptionGuid then
        local descriptionName = ResourceDisplayName(
            descriptionGuid,
            "FeatDescription",
            displayName.DisplayNameFallback
        )
        if descriptionName.DisplayNameHandle then
            displayName.DisplayNameHandle = descriptionName.DisplayNameHandle
        end
    end

    featDisplayNames[featGuid] = displayName
    return displayName
end

--- Adds passive IDs from either an array-like value or a delimited string.
---@param destination table<string, boolean>
---@param value any
local function AddPassiveIds(destination, value)
    if type(value) == "string" then
        for passiveId in value:gmatch("[^,;]+") do
            passiveId = passiveId:match("^%s*(.-)%s*$")
            if passiveId ~= "" then destination[passiveId] = true end
        end
    elseif type(value) == "table" then
        for key, entry in pairs(value) do
            if type(key) == "string" and type(entry) == "boolean" and entry then
                destination[key] = true
            end
            AddPassiveIds(destination, entry)
        end
    end
end

--- Loads the union of the HB class-passive lists once.
---@return table<string, boolean>
local function GetHBClassPassives()
    if hbClassPassives then return hbClassPassives end

    hbClassPassives = {}
    AddPassiveIds(hbClassPassives, HB_CLASS_PASSIVE_IDS)
    return hbClassPassives
end

--- Extracts a localization handle from the PassiveData stat format.
---@param value any
---@return string|nil
local function PassiveDisplayNameHandle(value)
    if type(value) == "string" then
        local handle = value:match("^([^;]+)")
        if handle and handle ~= "" and not handle:find("^ResStr_") then
            return handle
        end
    elseif type(value) == "table" then
        return TranslatedDisplayNameHandle(value)
    end
    return nil
end

---@param passiveId string
---@return PartialRespecDisplayName
local function PassiveDisplayName(passiveId)
    if passiveDisplayNames[passiveId] then
        return passiveDisplayNames[passiveId]
    end

    local displayName = {
        DisplayNameHandle = nil,
        DisplayNameFallback = HumanizeResourceName(passiveId) or passiveId,
        PassiveId = passiveId,
    }
    local passive = Ext.Stats.Get(passiveId)
    if passive then
        displayName.DisplayNameHandle = PassiveDisplayNameHandle(passive.DisplayName)
    end

    passiveDisplayNames[passiveId] = displayName
    return displayName
end

--- Recursively finds selected passive IDs in a serialized progression component.
---@param value any
---@param allowed table<string, boolean>
---@param add fun(passiveId: string)
local function FindSelectedPassives(value, allowed, add)
    if type(value) == "string" then
        for passiveId in value:gmatch("[^,;]+") do
            passiveId = passiveId:match("^%s*(.-)%s*$")
            if allowed[passiveId] then add(passiveId) end
        end
    elseif type(value) == "table" then
        for key, entry in pairs(value) do
            if type(key) == "string" and allowed[key] then add(key) end
            FindSelectedPassives(entry, allowed, add)
        end
    end
end

--- Collects only player-selected passives belonging to HB class-choice lists.
---@param character EntityHandle
---@param levelUps table|nil
---@param cutoff integer
---@return table
local function ClassPassivesThroughLevel(character, levelUps, cutoff)
    local results = {}
    local seen = {}
    local allowed = GetHBClassPassives()
    local container = character and character.ProgressionContainer
    local buckets = container and container.Progressions
    if not buckets then return results end

    local function Add(passiveId)
        if seen[passiveId] then return end
        seen[passiveId] = true
        results[#results + 1] = PassiveDisplayName(passiveId)
    end

    for level = 1, cutoff do
        -- CCLevelUp is the most direct record of player selections on builds
        -- that replicate passive choices into the level-up history.
        FindSelectedPassives(levelUps and levelUps[level], allowed, Add)

        for _, progressionEntity in ipairs(buckets[level] or {}) do
            -- SE builds expose the choice in different progression components.
            -- Search every component capable of carrying level-up selections.
            for _, componentName in ipairs(PROGRESSION_SELECTION_COMPONENTS) do
                local component = progressionEntity[componentName]
                if component then
                    local ok, serialized = pcall(Ext.Types.Serialize, component)
                    if ok then
                        FindSelectedPassives(serialized, allowed, Add)
                    end
                end
            end
        end
    end
    return results
end

---@param guid any
---@return boolean
local function IsValidGuid(guid)
    return guid ~= nil and tostring(guid) ~= "00000000-0000-0000-0000-000000000000"
end

--- Summarizes classes/subclasses/feats gained through the cutoff level for the popup and toast.
---@param character EntityHandle
---@param levelUps table|nil
---@param cutoff integer
---@return table
local function BuildLevelSummary(character, levelUps, cutoff)
    local classLevels = {}
    local classOrder = {}
    local feats = {}
    local featKeys = {}

    local function AddFeat(guid, name)
        local key = guid and tostring(guid) or name
        if not key or featKeys[key] then return end
        featKeys[key] = true
        feats[#feats + 1] = name and {
            DisplayNameHandle = nil,
            DisplayNameFallback = name,
        } or FeatDisplayName(key)
    end

    for level = 1, cutoff do
        local levelUp = levelUps and levelUps[level]
        if levelUp then
            if IsValidGuid(levelUp.Class) then
                local classGuid = tostring(levelUp.Class)
                if not classLevels[classGuid] then
                    classLevels[classGuid] = { Level = 0, SubClass = nil }
                    classOrder[#classOrder + 1] = classGuid
                end
                classLevels[classGuid].Level = classLevels[classGuid].Level + 1
                if IsValidGuid(levelUp.SubClass) then
                    classLevels[classGuid].SubClass = tostring(levelUp.SubClass)
                end
            end

            if IsValidGuid(levelUp.Feat) then
                AddFeat(tostring(levelUp.Feat))
            end
        end
    end

    local classes = {}
    local subclasses = {}
    for _, classGuid in ipairs(classOrder) do
        local info = classLevels[classGuid]
        classes[#classes + 1] = {
            Name = ClassDisplayName(classGuid),
            Level = info.Level,
        }
        if info.SubClass then
            subclasses[#subclasses + 1] = SubClassDisplayName(info.SubClass)
        end
    end

    return {
        Level = cutoff,
        Classes = classes,
        Subclasses = subclasses,
        Feats = feats,
        ClassPassives = ClassPassivesThroughLevel(character, levelUps, cutoff),
    }
end

--- Resolves the numeric user id whose viewer sees the respec screen.
--- Uses PartyView ownership: the target character belongs to a view whose UserID identifies the owning player.
--- Scans every PartyView entity (MP may create one per player). Falls back to the host's reserved user.
---@param characterGuid string
---@return integer
local function RespecViewerUser(characterGuid)
    for _, party in pairs(Ext.Entity.GetAllEntitiesWithComponent("PartyView")) do
        for _, view in pairs(party.PartyView.Views) do
            for _, char in pairs(view.Characters) do
                if char.Uuid and char.Uuid.EntityUuid == characterGuid then
                    return view.UserID
                end
            end
        end
    end
    return Osi.GetReservedUserID(Osi.GetHostCharacter())
end

--- Registers the respec as pending and asks the client to show the level-choice popup.
---@param character string
local function BeginPartialRespec(character)
    local characterGuid = Guid(character)
    if pendingRespec[characterGuid] then return end

    local entity = Ext.Entity.Get(characterGuid)
    if not entity then return end

    local level = entity.EocLevel and entity.EocLevel.Level or 12
    local levelSummaries = {}
    local levelUps = entity.CCLevelUp and entity.CCLevelUp.LevelUps
    for cutoff = 1, level do
        levelSummaries[cutoff] = BuildLevelSummary(entity, levelUps, cutoff)
    end
    pendingRespec[characterGuid] = {
        level = nil,
        charLevel = level,
        snapshot = nil,
    }

    Ext.Timer.WaitFor(1500, function()
        PartialRespecChannel:SendToClient({
            Character = characterGuid,
            MaxLevel = level,
            LevelSummaries = levelSummaries,
            Visible = true,
        }, RespecViewerUser(characterGuid))
        PRPrint(0, "Partial respec popup requested for %s (level %d)", characterGuid, level)
    end)
end

Ext.Osiris.RegisterListener("PROC_FlagReactionAfterDialog", 3, "before", function(character, flag)
    if PartialRespecEnabled and Guid(flag) == RESPEC_START_FLAG then
        BeginPartialRespec(character)
    end
end)

Ext.Osiris.RegisterListener("PROC_LaunchRespec", 2, "before", function(character)
    if PartialRespecEnabled then BeginPartialRespec(character) end
end)

Ext.Osiris.RegisterListener("StartRespec", 1, "after", function(character)
    if PartialRespecEnabled then BeginPartialRespec(character) end
end)

---@param entity EntityHandle
local function DestroyExistingProgressions(entity)
    local container = entity.ProgressionContainer
    if not container or not container.Progressions then return 0 end
    local count = 0
    for _, bucket in ipairs(container.Progressions) do
        for _, progressionHandle in ipairs(bucket) do
            if progressionHandle and progressionHandle:IsAlive() then
                Ext.Entity.Destroy(progressionHandle)
                count = count + 1
            end
        end
    end
    return count
end

--- Replay core logic: destroys old progressions, restores snapshot 1..targetLevel, recalculates classes/EocLevel, notifies client.
---@param entity EntityHandle
---@param snapshot table
---@param targetLevel integer
---@param characterGuid string
local function ApplyReplay(entity, snapshot, targetLevel, characterGuid)
    -- Safety net: capture the pre-destruction state before removing progression entities.
    PartialRespecSnapshot.SaveRecoveryDump(entity, characterGuid, targetLevel, snapshot)

    local oldCount = DestroyExistingProgressions(entity)
    PRPrint(1, "Destroyed %d old progression entities", oldCount)

    Ext.OnNextTick(function()
        local plan = PartialRespecSnapshot.ApplySnapshotToCharacter(entity, snapshot, targetLevel)

        PRPrint(0, "Replay applied: buckets=%d entries=%d",
            plan.newBuckets, plan.newEntries)

        -- Delevel character
        local cc = entity.CCLevelUp
        if cc and cc.LevelUps and #cc.LevelUps > targetLevel then
            for i = #cc.LevelUps, targetLevel + 1, -1 do
                cc.LevelUps[i] = nil
            end
            entity:Replicate("CCLevelUp")
            PRPrint(1, "CCLevelUp truncated to %d", targetLevel)
        end

        -- Replay classes/subclasses
        local classLevels = {}
        if cc and cc.LevelUps then
            for i = 1, targetLevel do
                local lvlUp = cc.LevelUps[i]
                if lvlUp and lvlUp.Class and lvlUp.Class ~= "00000000-0000-0000-0000-000000000000" then
                    local guid = tostring(lvlUp.Class)
                    if not classLevels[guid] then
                        classLevels[guid] = { Level = 0, SubClass = "00000000-0000-0000-0000-000000000000" }
                    end
                    classLevels[guid].Level = classLevels[guid].Level + 1
                    if lvlUp.SubClass and lvlUp.SubClass ~= "00000000-0000-0000-0000-000000000000" then
                        classLevels[guid].SubClass = tostring(lvlUp.SubClass)
                    end
                end
            end
        end

        local newClasses = {}
        for guid, info in pairs(classLevels) do
            newClasses[#newClasses + 1] = {
                ClassUUID = guid,
                Level = info.Level,
                SubClassUUID = info.SubClass,
            }
        end
        entity.Classes.Classes = newClasses
        entity:Replicate("Classes")
        PRPrint(1, "Classes recalculated: %d entries summing to %d", #newClasses, targetLevel)

        local toastSummary = BuildLevelSummary(entity, cc and cc.LevelUps, targetLevel)

        entity.EocLevel.Level = targetLevel
        entity:Replicate("EocLevel")
        PRPrint(1, "EocLevel set to %d", targetLevel)

        Ext.Timer.WaitFor(TOAST_DELAY_MS, function()
            PartialRespecChannel:SendToClient({
                Toast = true,
                ToastLevelCount = targetLevel,
                ToastClasses = toastSummary.Classes,
            }, RespecViewerUser(characterGuid))
        end)
    end)
end

Ext.Osiris.RegisterListener("RespecCompleted", 1, "after", function(character)
    local characterGuid = Guid(character)
    if not PartialRespecEnabled then
        pendingRespec[characterGuid] = nil
        return
    end

    local state = pendingRespec[characterGuid]
    if not state then return end

    PartialRespecChannel:SendToClient({ Visible = false }, RespecViewerUser(characterGuid))

    if not state.level or not state.snapshot then
        pendingRespec[characterGuid] = nil
        PRPrint(1, "RespecCompleted: %s (full respec, no replay)", characterGuid)
        return
    end

    local targetLevel = state.level
    local snapshot = state.snapshot
    pendingRespec[characterGuid] = nil

    PRPrint(0, "RespecCompleted: replaying levels 1-%d for %s", targetLevel, characterGuid)

    local entity = Ext.Entity.Get(characterGuid)
    if not entity then
        PRWarn(0, "Replay failed: cannot resolve entity for %s", characterGuid)
        return
    end

    ApplyReplay(entity, snapshot, targetLevel, characterGuid)
end)

Ext.Osiris.RegisterListener("RespecCancelled", 1, "after", function(character)
    local characterGuid = Guid(character)
    local state = pendingRespec[characterGuid]
    if state then
        PartialRespecChannel:SendToClient({ Visible = false }, RespecViewerUser(characterGuid))
    end
    pendingRespec[characterGuid] = nil
end)

PartialRespecChannel:SetHandler(function(message, user)
    if not PartialRespecEnabled then return end

    if type(message) ~= "table" or type(message.Character) ~= "string" then
        PRWarn(0, "PR choice rejected: invalid message")
        return
    end

    local characterGuid = Guid(message.Character)
    local state = pendingRespec[characterGuid]
    if not state then
        PRWarn(1, "PR choice: no pending respec for %s", characterGuid)
        return
    end

    local reservedUser = Osi.GetReservedUserID(characterGuid)
    if type(user) ~= "number"
        or (reservedUser ~= 0 and reservedUser ~= PeerToReservedUserID(user)) then
        PRWarn(0, "PR choice rejected for %s: wrong user?", characterGuid)
        return
    end

    if message.Cancelled == true then
        PRPrint(1, "PR choice: cancel (full respec)")
        state.level = nil
        state.snapshot = nil
        return
    end

    local level = tonumber(message.Level)
    if not level or level < 1 or level > state.charLevel then
        PRWarn(0, "PR choice: invalid level %s", tostring(message.Level))
        return
    end

    local entity = Ext.Entity.Get(characterGuid)
    if not entity then
        PRWarn(0, "PR choice: cannot resolve entity for snapshot")
        return
    end

    local snapshot = PartialRespecSnapshot.SaveCharacter(
        "PartialRespec/replay_" .. characterGuid .. ".json", entity)
    state.level = level
    state.snapshot = snapshot

    PartialRespecChannel:SendToClient({
        Character = characterGuid,
        Confirmed = true,
    }, RespecViewerUser(characterGuid))

    PRPrint(0, "PR choice: keep levels 1-%d for %s", level, characterGuid)
end)
