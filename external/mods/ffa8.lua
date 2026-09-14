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
        -- Keep at least one selectable human control path for menu navigation.
        -- This does not force P1 to be human in the actual fight.
    end
    main.ffa8.human = human
end

local function configure(mode, count)
    count = normalizeCount(count)
    main.ffa8.count = count
    main.ffa8.mode = mode
    setHumanPreset(mode, count)

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

    -- FFA is allocated through the engine's simultaneous root slots internally,
    -- but team selection is bypassed by the FFA start.lua patch.
    for side = 1, 2 do
        main.teamMenu[side].ratio = false
        main.teamMenu[side].single = false
        main.teamMenu[side].simul = true
        main.teamMenu[side].tag = false
        main.teamMenu[side].turns = false
    end

    -- The patched start logic controls each slot independently.
    main.coop = mode == 'allhuman'
    main.cpuSide[1] = mode == 'allai'
    main.cpuSide[2] = mode ~= 'allhuman'

    setHomeTeam(1)
    setGameMode('freeforall')
    modifyGameOption('Options.Team.PowerShare', 0)
    hook.run('main.t_itemname')
    return start.f_selectMode
end

local function addCountHandlers(prefix, mode)
    for n = 2, 8 do
        local key = prefix .. '_' .. tostring(n)
        main.t_itemname[key] = function()
            return configure(mode, n)
        end
    end
end

-- Build a proper FFA submenu without requiring screenpack edits.
main.f_appendItemname(motif.title_info.menu, '', 'ffa', {
    __value = 'FFA',
    __order = {'allhuman', 'vsai', 'allai', 'custom'},
    allhuman = {
        __value = 'All Human FFA',
        __order = {'2','3','4','5','6','7','8'},
        ['2']='2 Players', ['3']='3 Players', ['4']='4 Players', ['5']='5 Players',
        ['6']='6 Players', ['7']='7 Players', ['8']='8 Players',
    },
    vsai = {
        __value = 'VS AI FFA',
        __order = {'2','3','4','5','6','7','8'},
        ['2']='2 Players', ['3']='3 Players', ['4']='4 Players', ['5']='5 Players',
        ['6']='6 Players', ['7']='7 Players', ['8']='8 Players',
    },
    allai = {
        __value = 'All AI FFA',
        __order = {'2','3','4','5','6','7','8'},
        ['2']='2 Players', ['3']='3 Players', ['4']='4 Players', ['5']='5 Players',
        ['6']='6 Players', ['7']='7 Players', ['8']='8 Players',
    },
    custom = {
        __value = 'Custom FFA',
        __order = {'count','p1','p2','p3','p4','p5','p6','p7','p8','start'},
        count = 'Players: 4',
        p1 = 'P1: Human', p2 = 'P2: AI', p3 = 'P3: AI', p4 = 'P4: AI',
        p5 = 'P5: AI', p6 = 'P6: AI', p7 = 'P7: AI', p8 = 'P8: AI',
        start = 'Start Custom FFA',
    },
})

addCountHandlers('ffa_allhuman', 'allhuman')
addCountHandlers('ffa_vsai', 'vsai')
addCountHandlers('ffa_allai', 'allai')

local function updateCustomLabels(t)
    if type(t) ~= 'table' then return end
    for i, item in ipairs(t) do
        if item.itemname == 'ffa_custom_count' then
            item.displayname = 'Players: ' .. tostring(main.ffa8.count)
        else
            for p = 1, 8 do
                if item.itemname == 'ffa_custom_p' .. tostring(p) then
                    local active = p <= main.ffa8.count
                    local role = main.ffa8.human[p] and 'Human' or 'AI'
                    item.displayname = 'P' .. tostring(p) .. ': ' .. role .. (active and '' or ' (inactive)')
                end
            end
        end
    end
end

main.t_itemname['ffa_custom_count'] = function(t)
    main.ffa8.count = main.ffa8.count + 1
    if main.ffa8.count > 8 then main.ffa8.count = 2 end
    updateCustomLabels(t)
    return t
end

for p = 1, 8 do
    local pn = p
    main.t_itemname['ffa_custom_p' .. tostring(p)] = function(t)
        if pn <= main.ffa8.count then
            main.ffa8.human[pn] = not main.ffa8.human[pn]
        end
        updateCustomLabels(t)
        return t
    end
end

main.t_itemname['ffa_custom_start'] = function()
    return configure('custom', main.ffa8.count)
end
