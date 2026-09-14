#!/usr/bin/env python3
from pathlib import Path


def replace_once(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'FFA patch failed: expected exactly one {label}, found {count}')
    print(f'Applied: {label}')
    return text.replace(old, new, 1)

# -----------------------------------------------------------------------------
# Engine opponent and hit relation patch
# -----------------------------------------------------------------------------
char_path = Path('src/char.go')
text = char_path.read_text(encoding='utf-8')

text = replace_once(text,
'''\t// Neutral players or partners\n\tif e.teamside < 0 || e.teamside == c.teamside {\n\t\treturn false\n\t}\n''',
'''\t// Neutral players or partners. In FFA every other root player is an enemy,\n\t// even when the engine internally stores both fighters on the same side.\n\tif e.teamside < 0 {\n\t\treturn false\n\t}\n\tif sys.gameMode == "freeforall" {\n\t\t// Helpers and the owning root share playerNo. Keep them friendly to one another.\n\t\tif e.playerNo == c.playerNo {\n\t\t\treturn false\n\t\t}\n\t} else if e.teamside == c.teamside {\n\t\treturn false\n\t}\n''', 'isEnemyOf partner block')

text = replace_once(text,
'''\t\tif c.atktmp != 0 && c.id != getter.id &&\n\t\t\t(c.hitdef.affectteam == 0 || (getter.teamside != c.hitdef.teamside) == (c.hitdef.affectteam > 0)) {\n''',
'''\t\tisEnemyTarget := getter.teamside != c.hitdef.teamside\n\t\tif sys.gameMode == "freeforall" {\n\t\t\tisEnemyTarget = getter.playerNo != c.playerNo\n\t\t}\n\n\t\tif c.atktmp != 0 && c.id != getter.id &&\n\t\t\t(c.hitdef.affectteam == 0 || isEnemyTarget == (c.hitdef.affectteam > 0)) {\n''', 'player HitDef team relation')

text = replace_once(text,
'''\t\t\t// Teamside check\n\t\t\t// Since the teamside parameter is new to Ikemen, we can make that one allow the projectile to hit the root\n\t\t\tif p.hitdef.affectteam != 0 &&\n\t\t\t\t((getter.teamside != p.hitdef.teamside) != (p.hitdef.affectteam > 0) ||\n\t\t\t\t\t(getter.teamside == p.hitdef.teamside) != (p.hitdef.affectteam < 0)) {\n\t\t\t\tcontinue\n\t\t\t}\n''',
'''\t\t\t// Teamside check. FFA treats every different root slot as hostile even when\n\t\t\t// both roots are stored on the same internal Simul side.\n\t\t\tprojEnemyTarget := getter.teamside != p.hitdef.teamside\n\t\t\tprojFriendlyTarget := getter.teamside == p.hitdef.teamside\n\t\t\tif sys.gameMode == "freeforall" {\n\t\t\t\tprojEnemyTarget = getter.playerNo != i\n\t\t\t\tprojFriendlyTarget = getter.playerNo == i\n\t\t\t}\n\t\t\tif p.hitdef.affectteam != 0 &&\n\t\t\t\t(projEnemyTarget != (p.hitdef.affectteam > 0) ||\n\t\t\t\t\tprojFriendlyTarget != (p.hitdef.affectteam < 0)) {\n\t\t\t\tcontinue\n\t\t\t}\n''', 'projectile-to-player team relation')

text = replace_once(text,
'''\t\t\tif getter.atktmp != 0 && (getter.hitdef.affectteam == 0 ||\n\t\t\t\t(p.hitdef.teamside != getter.teamside) == (getter.hitdef.affectteam > 0)) &&\n''',
'''\t\t\tif getter.atktmp != 0 && (getter.hitdef.affectteam == 0 ||\n\t\t\t\tprojEnemyTarget == (getter.hitdef.affectteam > 0)) &&\n''', 'player-to-projectile team relation')

char_path.write_text(text, encoding='utf-8')
print('FFA engine patch complete: src/char.go')

# -----------------------------------------------------------------------------
# Select-screen allocation and independent Human/AI slot control
# -----------------------------------------------------------------------------
start_path = Path('external/script/start.lua')
start = start_path.read_text(encoding='utf-8')

start = replace_once(start,
'''function start.f_remapAI(ai)\n\t--Offset\n''',
'''function start.f_remapAI(ai)\n\t-- FFA slots are independent players even though they are internally allocated\n\t-- through the engine's two Simul sides. Human/AI ownership is per player slot.\n\tif gameMode('freeforall') and type(main.ffa8) == 'table' then\n\t\tlocal count = math.max(2, math.min(8, tonumber(main.ffa8.count) or 4))\n\t\tfor pn = 1, count do\n\t\t\tremapInput(pn, pn)\n\t\t\tif type(main.ffa8.human) == 'table' and main.ffa8.human[pn] then\n\t\t\t\tsetCom(pn, 0)\n\t\t\telse\n\t\t\t\tsetCom(pn, ai or start.f_difficulty(pn, 0))\n\t\t\tend\n\t\tend\n\t\treturn\n\tend\n\n\t--Offset\n''', 'FFA per-slot Human/AI remap')

start = replace_once(start,
'''function start.f_teamMenu(side, t)\n\tif #t == 0 then\n''',
'''function start.f_teamMenu(side, t)\n\t-- FFA bypasses the visible Team/Simul menu. The engine still uses Simul root\n\t-- slots internally, but the player only sees FFA and a total player count.\n\tif gameMode('freeforall') and type(main.ffa8) == 'table' then\n\t\tlocal count = math.max(2, math.min(8, tonumber(main.ffa8.count) or 4))\n\t\tlocal sideCount\n\t\tif side == 1 then\n\t\t\tsideCount = math.floor((count + 1) / 2)\n\t\telse\n\t\t\tsideCount = math.floor(count / 2)\n\t\tend\n\t\tstart.p[side].numSimul = sideCount\n\t\tstart.p[side].numChars = sideCount\n\t\tstart.p[side].teamMode = 1 -- internal Simul allocator only\n\t\tstart.p[side].teamEnd = true\n\n\t\tif #start.p[side].t_selCmd == 0 then\n\t\t\tif main.ffa8.mode == 'allhuman' then\n\t\t\t\tfor member = 1, sideCount do\n\t\t\t\t\tlocal pn = start.f_getPlayerNo(side, member)\n\t\t\t\t\ttable.insert(start.p[side].t_selCmd, {cmd = getRemapInput(pn), player = pn, selectState = 0})\n\t\t\t\tend\n\t\t\telse\n\t\t\t\t-- One menu cursor per internal side selects that side's fighters sequentially.\n\t\t\t\t-- Match control itself is reassigned per slot by start.f_remapAI above.\n\t\t\t\tlocal pn = start.f_getPlayerNo(side, 1)\n\t\t\t\ttable.insert(start.p[side].t_selCmd, {cmd = start.f_menuCmd(side), player = pn, selectState = 0})\n\t\t\tend\n\t\tend\n\t\treturn\n\tend\n\n\tif #t == 0 then\n''', 'FFA team-menu bypass and 2-8 allocation')

start_path.write_text(start, encoding='utf-8')
print('FFA menu allocation patch complete: external/script/start.lua')
