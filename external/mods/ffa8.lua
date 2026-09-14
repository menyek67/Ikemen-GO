-- IKEMEN GO FFA 2-8
-- User-facing FFA menu. The engine build patch makes standard P2/Enemy logic
-- see every other active root as hostile only while gameMode == freeforall.

local function contains(t, v)
    for _, x in ipairs(t or {}) do
        if x == v then return true end
    end
    return false
end

local states = gameOption('Common.States')
if not contains(states, 'external/mods/ffa8.zss') then
    table.insert(states, 'external/mods/ffa8.zss')
    modifyGameOption('Common.States', states)
end

main.ffa8 = main.ffa8 or {
    count = 4,
    mode = 'vsai',
    human = {true, false, false, false, false, false, false, false},
}

local function normalizeCount(n)
    n = math.floor(tonumber(n) or 4)
    return math.max(2, math.min(8, n))
end

local function setHumanPreset(mode, count)
    local human = {}
    for i = 1, 8 do human[i] = false end
    if mode == 'allhuman' then
        for i = 1, count do human[i] = true end
    elseif mode == 'vsai' then
        human[1] = true
    elseif mode == 'allai' then
        -- none
    elseif mode == 'custom' then
        for i = 1, 8 do human[i] = main.ffa8.human[i] == true end
    end
    main.ffa8.human = human
end

local function configure(mode, count)
    count = normalizeCount(count)
    main.ffa8.count = count
    main.ffa8.mode = mode
    setHumanPreset(mode, count)

    print(string.format('[FFA8] start mode=%s players=%d', tostring(mode), count))

    main.aiRamp = false
    main.charparam.ai = true
    main.charparam.arcadepath = false
    main.charparam.music = true
    main.charparam.stage = true
    main.charparam.single = false

    main.motif.vsscreen = true
    main.motif.victoryscreen = true
    main.orderSelect[1] = false
    main.orderSelect[2] = false
    main.selectMenu[1] = true
    main.selectMenu[2] = true
    main.stageMenu = true

    -- FFA is allocated through simultaneous root slots internally. The patched
    -- start.lua bypasses the visible Team/Simul menu and allocates the requested
    -- total number of independent root fighters across both internal sides.
    for side = 1, 2 do
        main.teamMenu[side].ratio = false
        main.teamMenu[side].single = false
        main.teamMenu[side].simul = true
        main.teamMenu[side].tag = false
        main.teamMenu[side].turns = false
    end

    -- IMPORTANT: keep the legacy side-level CPU flags disabled. If they are set,
    -- start.f_selectReset marks that side's team menu as already completed before
    -- the FFA allocator can assign its requested root slots. Match Human/AI control
    -- is instead assigned independently per root in the patched start.f_remapAI.
    main.coop = false
    main.cpuSide[1] = false
    main.cpuSide[2] = false

    setHomeTeam(1)
    setGameMode('freeforall')
    modifyGameOption('Options.Team.PowerShare', 0)
    hook.run('main.t_itemname')
    return start.f_selectMode
end

-- IKEMEN's generated nested menu dispatches only the final segment to
-- main.t_itemname. Each actionable leaf therefore needs a globally unique name.
local function addCountHandlers(prefix, mode)
    for n = 2, 8 do
        local leaf = prefix .. tostring(n)
        local players = n
        main.t_itemname[leaf] = function()
            return configure(mode, players)
        end
    end
end

-- Build the FFA submenu without requiring screenpack edits. The final argument
-- inserts the top-level FFA entry immediately before EXIT.
main.f_appendItemname(motif.title_info.menu, '', 'ffa', {
    __value = 'FFA',
    __order = {'allhuman', 'vsai', 'allai', 'custom'},
    allhuman = {
        __value = 'All Human FFA',
        __order = {'ffah2','ffah3','ffah4','ffah5','ffah6','ffah7','ffah8'},
        ffah2='2 Players', ffah3='3 Players', ffah4='4 Players', ffah5='5 Players',
        ffah6='6 Players', ffah7='7 Players', ffah8='8 Players',
    },
    vsai = {
        __value = 'VS AI FFA',
        __order = {'ffav2','ffav3','ffav4','ffav5','ffav6','ffav7','ffav8'},
        ffav2='2 Players', ffav3='3 Players', ffav4='4 Players', ffav5='5 Players',
        ffav6='6 Players', ffav7='7 Players', ffav8='8 Players',
    },
    allai = {
        __value = 'All AI FFA',
        __order = {'ffaa2','ffaa3','ffaa4','ffaa5','ffaa6','ffaa7','ffaa8'},
        ffaa2='2 Players', ffaa3='3 Players', ffaa4='4 Players', ffaa5='5 Players',
        ffaa6='6 Players', ffaa7='7 Players', ffaa8='8 Players',
    },
    custom = {
        __value = 'Custom FFA',
        __order = {'ffacount','ffacp1','ffacp2','ffacp3','ffacp4','ffacp5','ffacp6','ffacp7','ffacp8','ffacstart'},
        ffacount = 'Players: 4',
        ffacp1 = 'P1: Human', ffacp2 = 'P2: AI', ffacp3 = 'P3: AI', ffacp4 = 'P4: AI',
        ffacp5 = 'P5: AI', ffacp6 = 'P6: AI', ffacp7 = 'P7: AI', ffacp8 = 'P8: AI',
        ffacstart = 'Start Custom FFA',
    },
}, 'exit')

addCountHandlers('ffah', 'allhuman')
addCountHandlers('ffav', 'vsai')
addCountHandlers('ffaa', 'allai')

local function updateCustomLabels(t)
    if type(t) ~= 'table' then return end
    for _, item in ipairs(t) do
        if item.itemname == 'ffacount' then
            item.displayname = 'Players: ' .. tostring(main.ffa8.count)
        else
            for p = 1, 8 do
                if item.itemname == 'ffacp' .. tostring(p) then
                    local active = p <= main.ffa8.count
                    local role = main.ffa8.human[p] and 'Human' or 'AI'
                    item.displayname = 'P' .. tostring(p) .. ': ' .. role .. (active and '' or ' (inactive)')
                end
            end
        end
    end
end

-- Custom-setting handlers intentionally return nil so the user remains inside
-- the Custom FFA submenu instead of fading out to character select immediately.
main.t_itemname['ffacount'] = function(t)
    main.ffa8.count = main.ffa8.count + 1
    if main.ffa8.count > 8 then main.ffa8.count = 2 end
    updateCustomLabels(t)
    return nil
end

for p = 1, 8 do
    local pn = p
    main.t_itemname['ffacp' .. tostring(p)] = function(t)
        if pn <= main.ffa8.count then
            main.ffa8.human[pn] = not main.ffa8.human[pn]
        end
        updateCustomLabels(t)
        return nil
    end
end

main.t_itemname['ffacstart'] = function()
    return configure('custom', main.ffa8.count)
end
