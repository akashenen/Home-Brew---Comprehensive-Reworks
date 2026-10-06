local PR = {}

local POPUP_VM_TYPE = "PR_RespecChoiceVM"
local TOAST_VM_TYPE = "PR_NotificationToastVM"
local CHOICE_WIDGET_NAMES = { "PR_RespecChoice", "PR_RespecChoice_c" }
local TOAST_WIDGET_NAME = "PR_NotificationToast"

local VANILLA_RESPEC_WIDGET_NAMES = { "CharacterRespec", "CharacterRespec_c" }
local IMPROVED_UI_UUID = "26922ba9-6018-5252-075d-7ff2ba6ed879"
local MAX_TOAST_BIND_ATTEMPTS = 20
local POPUP_BIND_RETRY_TICKS = 20
local MAX_AUTO_CONFIRM_ATTEMPTS = 20
local TOAST_BASE_DURATION_MS = 6000
local TOAST_EXTRA_LEVEL_DURATION_MS = 500
local MAX_PASSIVE_SLOTS = 12

local registered = false
local toastGeneration = 0
local toastTimerId = nil
local autoConfirmInProgress = false
local popupShowGeneration = 0
local popupRetryEventId = nil
local loadOrderWarned = false

local LOCA_HANDLES = {
    ClassLevel = "hf39c9f10gb179g4084g8ff6gc74285976171",
    SummaryHeader = "h2559478fg7db0g4c65gb791gbb5b2f8cce16",
    Classes = "h5e37a2dfg4880g424bga1e6ge5cb67ad838b",
    NoClasses = "h4c0fbf6egc03cg4114g9db7g5a83d073ccf7",
    Subclasses = "h294a397ag4d41g4d36g903eg6902f6f3441c",
    Feats = "h5f0a79b9g4348g4049g9b77g0ff34a14484a",
    ClassPassives = "h6f3bc421g66a2g43a8gb450g95cd5c862ffb",
    ListSeparator = "h9e2ea072gc77dg475dgb36eg2d90b35ef740",
    ToastLevels = "h424602aag4ac8g437bgba0bg09b557a3a31e",
    ToastClasses = "ha2a60b34gfd95g4cd6gafa6g934565f64fa5",
    ToastReady = "hd2c871c3g413fg44b9gb1b1g17f37946342a",
    UnknownClass = "hca715032g6928g42e4g91ebg062f59702816",
    UnknownSubclass = "h5ea6b060g79d4g4542ga9beg674b004d3428",
    UnknownFeat = "h1fa2342eg6b09g4874gbd98g2d575b62a78a",
    UnknownPassive = "h17481e45gd9d8g48e7ga58ag752a8cf65a78",
}

local function InterpolateFallback(template, ...)
    local result = template
    for index, value in ipairs({ ... }) do
        result = result:gsub("%[" .. index .. "%]", function()
            return tostring(value or "")
        end)
    end
    return result
end

--- Localizes the handle and substitutes [n] placeholders, falling back to the template on failure.
local function Interpolate(handle, fallback, ...)
    local args = { ... }
    local message = Ext.Loca.GetTranslatedString(handle)
    if message and message ~= "" and message ~= handle then
        for index, value in ipairs(args) do
            message = message:gsub("%[" .. index .. "%]", function()
                return tostring(value or "")
            end)
        end
        local text = message:gsub("<br>", "\n")
        return text
    end
    return InterpolateFallback(fallback, table.unpack(args))
end

--- Resolves an entry to display text: localized handle first, fallback name, then "?".
---@param entry table|string|nil
---@param kind "Class"|"Subclass"|"Feat"|"Passive"
---@return string
local function DisplayName(entry, kind)
    if type(entry) == "string" then return entry end

    local genericFallback = "Unknown " .. kind:lower()
    local fallback = entry and entry.DisplayNameFallback
    if not fallback or fallback == "" or fallback == genericFallback then
        fallback = "?"
    end
    local handle = entry and entry.DisplayNameHandle
    if handle then
        local translated = Ext.Loca.GetTranslatedString(handle)
        if translated then return translated end
    end

    local unknownHandle = LOCA_HANDLES["Unknown" .. kind]
    return Interpolate(unknownHandle, fallback, fallback)
end

local function Join(values)
    return table.concat(values, Ext.Loca.GetTranslatedString(LOCA_HANDLES.ListSeparator, ", "))
end

---@param classes table|nil
---@return string
local function BuildClassText(classes)
    local values = {}
    for _, entry in ipairs(classes or {}) do
        local name = DisplayName(entry.Name, "Class")
        values[#values + 1] = Interpolate(
            LOCA_HANDLES.ClassLevel,
            "[1] [2]",
            name,
            entry.Level or 0
        )
    end
    return #values > 0 and Join(values) or Ext.Loca.GetTranslatedString(LOCA_HANDLES.NoClasses, "None")
end

---@param entries table|nil
---@param kind "Subclass"|"Feat"|"Passive"
---@return string
local function BuildNameText(entries, kind)
    local values = {}
    for _, entry in ipairs(entries or {}) do
        values[#values + 1] = DisplayName(entry, kind)
    end
    return Join(values)
end

--- Renders the popup summary text (kept levels, classes, subclasses, feats).
---@param summary table|nil
---@return string
local function BuildSummary(summary)
    summary = summary or {}
    local level = tonumber(summary.Level) or 1
    local lines = {
        Interpolate(
            LOCA_HANDLES.SummaryHeader,
            "<i>Kept through level [1]</i>:",
            level
        ),
        Interpolate(
            LOCA_HANDLES.Classes,
            "Classes: [1]",
            BuildClassText(summary.Classes)
        ),
    }

    if #(summary.Subclasses or {}) > 0 then
        lines[#lines + 1] = Interpolate(
            LOCA_HANDLES.Subclasses,
            "Subclasses: [1]",
            BuildNameText(summary.Subclasses, "Subclass")
        )
    end

    if #(summary.Feats or {}) > 0 then
        local heading = Interpolate(LOCA_HANDLES.Feats, "Feats: [1]", ""):gsub("[:%s]+$", "")
        lines[#lines + 1] = heading .. "\n" .. BuildNameText(summary.Feats, "Feat")
    end

    return table.concat(lines, "\n")
end

---@param vm ViewModel
---@param passives table|nil
local function SetPassiveSlots(vm, passives)
    passives = passives or {}
    vm.PR_HasClassPassives = #passives > 0

    for index = 1, MAX_PASSIVE_SLOTS do
        local entry = passives[index]
        vm["PR_Passive" .. index .. "Visible"] = entry ~= nil
        local name = entry and DisplayName(entry, "Passive") or ""
        vm["PR_Passive" .. index .. "Name"] = entry and (name .. (index < math.min(#passives, MAX_PASSIVE_SLOTS) and "," or "")) or ""
    end
end

--- Renders the completion toast text (restored levels + classes kept).
---@param classes table|nil
---@param levelCount integer|nil
---@return string
local function BuildToastMarkup(classes, levelCount)
    local level = math.max(1, tonumber(levelCount) or 1)
    return table.concat({
        Interpolate(
            LOCA_HANDLES.ToastLevels,
            "<i>Levels 1-[1] restored</i>",
            level
        ),
        Interpolate(
            LOCA_HANDLES.ToastClasses,
            "Classes kept: [1]",
            BuildClassText(classes)
        ),
        Interpolate(
            LOCA_HANDLES.ToastReady,
            "Ready to rebuild from level [1]",
            level + 1
        ),
    }, "\n")
end

local function RegisterVM()
    if registered then return end

    local popupProperties = {
        PR_PopupVisible = { Type = "Bool", Notify = true },
        PR_SelectedLevel = { Type = "Double", Notify = true },
        PR_MaxLevel = { Type = "Double" },
        PR_Summary = { Type = "String", Notify = true },
        PR_HasClassPassives = { Type = "Bool", Notify = true },
        PR_CurrentPlayer = { Type = "Object" },
        PR_ConfirmCommand = { Type = "Command" },
        PR_FullRespecCommand = { Type = "Command" },
        PR_LevelChangedCommand = { Type = "Command" },
    }
    for index = 1, MAX_PASSIVE_SLOTS do
        popupProperties["PR_Passive" .. index .. "Visible"] = { Type = "Bool", Notify = true }
        popupProperties["PR_Passive" .. index .. "Name"] = { Type = "String", Notify = true }
    end

    -- The popup (single-slider level picker: value N keeps levels 1-N)
    Ext.UI.RegisterType(POPUP_VM_TYPE, popupProperties)

    -- The toast
    Ext.UI.RegisterType(TOAST_VM_TYPE, {
        PR_ToastMarkup = { Type = "String", Notify = true },
        PR_ToastVisible = { Type = "Bool", Notify = true },
    })

    registered = true
    PRPrint(1, "Partial respec ViewModel types registered")
end

local function CancelToastTimer()
    toastGeneration = toastGeneration + 1
    if toastTimerId then
        Ext.Timer.Cancel(toastTimerId)
        toastTimerId = nil
    end
end

local function CancelPopupRetry()
    if popupRetryEventId then
        Ext.Events.Tick:Unsubscribe(popupRetryEventId)
        popupRetryEventId = nil
    end
end

--- Recursive search for a named Noesis visual child, used by FindWidget.
---@param widget NoesisObject
---@param name string
---@param depth integer
---@return NoesisObject|nil
local function FindVisualChild(widget, name, depth)
    if not widget or depth > 12 then return nil end

    local childCount = widget.VisualChildrenCount
    if type(childCount) ~= "number" then return nil end

    for index = childCount, 1, -1 do
        local child = widget:VisualChild(index)
        if child then
            local childName = child.Name
            if childName == name then return child end

            local nested = FindVisualChild(child, name, depth + 1)
            if nested then return nested end
        end
    end

    return nil
end

---@param name string
---@return NoesisObject|nil
local function FindWidget(name)
    local root = Ext.UI.GetRoot()
    if not root then return nil end
    local contentRoot = root:Find("ContentRoot")
    if not contentRoot then return nil end
    return FindVisualChild(contentRoot, name, 0)
end

---@return ViewModel|nil
local function CurrentVM()
    for _, name in ipairs(CHOICE_WIDGET_NAMES) do
        local widget = FindWidget(name)
        if widget then return widget.DataContext end
    end
    return nil
end

--- Returns the toast widget's ViewModel, creating and binding it if the widget has none.
---@return ViewModel|nil
local function CurrentToastVM()
    RegisterVM()
    local widget = FindWidget(TOAST_WIDGET_NAME)
    if not widget then return nil end

    local vm = widget.DataContext
    local ok, visible = pcall(function()
        return vm and vm.PR_ToastVisible
    end)
    if ok and visible ~= nil then return vm end

    local newVM = Ext.UI.Instantiate("se::" .. TOAST_VM_TYPE)
    newVM.PR_ToastMarkup = ""
    newVM.PR_ToastVisible = false
    widget.DataContext = newVM
    return newVM
end

local function HideToast()
    CancelToastTimer()
    local vm = CurrentToastVM()
    if vm then
        vm.PR_ToastVisible = false
    end
end

---@param vm ViewModel|nil
---@param maxLevel integer
---@return integer
local function SelectedLevel(vm, maxLevel)
    local value = tonumber(vm and vm.PR_SelectedLevel) or maxLevel
    local level = math.floor(value + 0.5)
    if level < 1 then level = 1 end
    if level > maxLevel then level = maxLevel end
    return level
end

---@param vm ViewModel
---@param levelSummaries table<integer, table>
---@param level integer
local function RefreshLevelText(vm, levelSummaries, level)
    local summary = levelSummaries[level] or { Level = level }
    vm.PR_Summary = BuildSummary(summary)
    SetPassiveSlots(vm, summary.ClassPassives)
end

--- Builds the popup ViewModel: slider value, summary text, and command handlers.
---@param character string
---@param maxLevel integer
---@param levelSummaries table<integer, table>
---@return ViewModel
local function BuildVM(character, maxLevel, levelSummaries)
    RegisterVM()
    HideToast()

    maxLevel = math.max(1, maxLevel)
    local vm = Ext.UI.Instantiate("se::" .. POPUP_VM_TYPE)
    vm.PR_PopupVisible = true
    vm.PR_MaxLevel = maxLevel
    vm.PR_SelectedLevel = maxLevel
    RefreshLevelText(vm, levelSummaries, maxLevel)

    vm.PR_LevelChangedCommand:SetHandler(function()
        local current = CurrentVM()
        if not current then return end

        local level = SelectedLevel(current, maxLevel)
        current.PR_SelectedLevel = level
        RefreshLevelText(current, levelSummaries, level)
    end)

    vm.PR_ConfirmCommand:SetHandler(function()
        local current = CurrentVM()
        if not current then return end

        local level = SelectedLevel(current, maxLevel)
        current.PR_PopupVisible = false
        PRPrint(0, "Partial respec confirmed through level %d", level)
        PartialRespecChannel:SendToServer({
            Character = character,
            Level = level,
        })
    end)

    vm.PR_FullRespecCommand:SetHandler(function()
        local current = CurrentVM()
        if current then current.PR_PopupVisible = false end
        PRPrint(1, "Partial respec selected full respec")
        PartialRespecChannel:SendToServer({
            Character = character,
            Cancelled = true,
        })
    end)

    return vm
end

--- Exposes the vanilla CurrentPlayer on the popup VM so XAML can reach the
--- face button input events. The popup uses a custom DataContext, so
--- CurrentPlayer is unreachable from XAML otherwise.
---@param vm ViewModel
local function BindCurrentPlayer(vm)
    for _, name in ipairs(VANILLA_RESPEC_WIDGET_NAMES) do
        local widget = FindWidget(name)
        if widget then
            local ok, player = pcall(function()
                local dc = widget.DataContext
                return dc and dc.CurrentPlayer
            end)
            if ok and player then
                vm.PR_CurrentPlayer = player
                return
            end
        end
    end
end

---@param character string
---@param characterLevel integer
---@param levelSummaries table<integer, table>
---@return boolean
function PR.Show(character, characterLevel, levelSummaries)
    local widget
    for _, name in ipairs(CHOICE_WIDGET_NAMES) do
        widget = FindWidget(name)
        if widget then break end
    end
    if not widget then return false end

    widget.DataContext = BuildVM(
        character,
        math.max(1, characterLevel),
        levelSummaries
    )

    if widget.Name == "PR_RespecChoice_c" then
        BindCurrentPlayer(widget.DataContext)
    end

    PRPrint(1, "Partial respec popup shown for %s (level %d)", character, characterLevel)
    return true
end

function PR.Hide()
    CancelPopupRetry()
    local vm = CurrentVM()
    HideToast()
    if vm then
        vm.PR_PopupVisible = false
    end
end

---@param classes table|nil
---@param levelCount integer|nil
---@return boolean
function PR.ShowToast(classes, levelCount)
    local vm = CurrentToastVM()
    if not vm then return false end

    CancelToastTimer()
    vm.PR_ToastMarkup = BuildToastMarkup(classes, levelCount)
    vm.PR_ToastVisible = true

    local levels = math.max(1, tonumber(levelCount) or 1)
    local duration = TOAST_BASE_DURATION_MS + (levels - 1) * TOAST_EXTRA_LEVEL_DURATION_MS
    local generation = toastGeneration
    toastTimerId = Ext.Timer.WaitFor(duration, function()
        if generation ~= toastGeneration then return end

        local current = CurrentToastVM()
        if current then current.PR_ToastVisible = false end
        toastTimerId = nil
    end)

    PRPrint(0, "Partial respec completion toast shown")
    return true
end

--- Retries executing the vanilla FinishCreating command until the respec screen mounts.
---@param attemptsLeft integer
local function AutoConfirmVanillaRespec(attemptsLeft)
    local widget
    for _, name in ipairs(VANILLA_RESPEC_WIDGET_NAMES) do
        widget = FindWidget(name)
        if widget then break end
    end

    if not widget then
        if attemptsLeft <= 0 then
            autoConfirmInProgress = false
            PRWarn(0, "Automatic respec confirmation failed: vanilla widget did not mount")
            return
        end
        Ext.OnNextTick(function()
            AutoConfirmVanillaRespec(attemptsLeft - 1)
        end)
        return
    end

    local vmOk, vm = pcall(function() return widget.DataContext end)
    local commandOk, finishRespecCommand = pcall(function()
        return vmOk and vm and vm.FinishCreating
    end)
    if not vmOk or not commandOk or not finishRespecCommand then
        if attemptsLeft <= 0 then
            autoConfirmInProgress = false
            PRWarn(0, "Automatic respec confirmation failed: FinishCreating is unavailable")
            return
        end
        Ext.OnNextTick(function()
            AutoConfirmVanillaRespec(attemptsLeft - 1)
        end)
        return
    end

    local canExecuteOk, canExecuteRespecConfirm = pcall(function()
        return finishRespecCommand:CanExecute(nil)
    end)
    if not canExecuteOk or canExecuteRespecConfirm ~= true then
        if attemptsLeft <= 0 then
            autoConfirmInProgress = false
            PRWarn(0, "Automatic respec confirmation failed: FinishCreating is not executable")
            return
        end
        Ext.OnNextTick(function()
            AutoConfirmVanillaRespec(attemptsLeft - 1)
        end)
        return
    end

    local executeOk, executeError = pcall(function()
        finishRespecCommand:Execute(nil)
    end)
    if not executeOk then
        if attemptsLeft <= 0 then
            autoConfirmInProgress = false
            PRWarn(0, "Automatic respec confirmation failed: %s", tostring(executeError))
            return
        end
        Ext.OnNextTick(function()
            AutoConfirmVanillaRespec(attemptsLeft - 1)
        end)
        return
    end

    PRPrint(0, "Automatic vanilla respec confirmation requested")
    autoConfirmInProgress = false
end

local function StartAutoConfirm()
    if autoConfirmInProgress then return end
    autoConfirmInProgress = true
    AutoConfirmVanillaRespec(MAX_AUTO_CONFIRM_ATTEMPTS)
end

---@param classes table|nil
---@param levelCount integer|nil
---@param attemptsLeft integer
local function ShowToastWhenMounted(classes, levelCount, attemptsLeft)
    if PR.ShowToast(classes, levelCount) then return end
    if attemptsLeft <= 0 then
        PRWarn(0, "Partial respec toast widget did not mount")
        return
    end

    Ext.OnNextTick(function()
        ShowToastWhenMounted(classes, levelCount, attemptsLeft - 1)
    end)
end

--- ImpUI declares CharacterRespec with Override, wiping our Extend widget when it loads after us.
local function WarnOnceOnBadLoadOrder()
    if loadOrderWarned then return end
    local partialIndex, impUIIndex
    for index, uuid in ipairs(Ext.Mod.GetLoadOrder()) do
        if tostring(uuid) == ModuleUUID then partialIndex = index end
        if tostring(uuid) == IMPROVED_UI_UUID then impUIIndex = index end
        if partialIndex and impUIIndex then break end
    end
    if impUIIndex and partialIndex and impUIIndex > partialIndex then
        loadOrderWarned = true
        PRWarn(0, "ImprovedUI (ImpUI) loads before Partial Respec and overrides the respec screen; place Partial Respec below ImpUI in the load order")
    end
end

---@param character string
---@param characterLevel integer
---@param levelSummaries table<integer, table>
---@param generation integer
local function ShowWhenMounted(character, characterLevel, levelSummaries, generation)
    CancelPopupRetry()
    if generation ~= popupShowGeneration then return end
    if PR.Show(character, characterLevel, levelSummaries) then return end

    WarnOnceOnBadLoadOrder()
    local ticksPassed = 0
    popupRetryEventId = Ext.Events.Tick:Subscribe(function()
        if generation ~= popupShowGeneration then
            CancelPopupRetry()
            return
        end

        ticksPassed = ticksPassed + 1
        if ticksPassed < POPUP_BIND_RETRY_TICKS then return end

        ticksPassed = 0
        if PR.Show(character, characterLevel, levelSummaries) then
            CancelPopupRetry()
        end
    end)
end

PartialRespecChannel:SetHandler(function(message)
    if type(message) ~= "table" then
        PRWarn(0, "Partial respec UI rejected an invalid message")
        return
    end

    if message.Visible == false then
        popupShowGeneration = popupShowGeneration + 1
        PR.Hide()
        return
    end

    if not PartialRespecEnabled then return end

    if message.Toast == true then
        ShowToastWhenMounted(
            message.ToastClasses or {},
            message.ToastLevelCount,
            MAX_TOAST_BIND_ATTEMPTS
        )
        return
    end

    if message.Confirmed == true then
        popupShowGeneration = popupShowGeneration + 1
        PR.Hide()
        StartAutoConfirm()
        return
    end

    popupShowGeneration = popupShowGeneration + 1
    ShowWhenMounted(
        message.Character,
        message.MaxLevel or 1,
        message.LevelSummaries or {},
        popupShowGeneration
    )
end)

if MCMLoaded then
    Ext.ModEvents.BG3MCM.MCM_Setting_Saved:Subscribe(function(payload)
        if payload
            and payload.modUUID == ModuleUUID
            and payload.settingId == "enabled"
            and payload.value == false then
            autoConfirmInProgress = false
            popupShowGeneration = popupShowGeneration + 1
            PR.Hide()
        end
    end)
end
