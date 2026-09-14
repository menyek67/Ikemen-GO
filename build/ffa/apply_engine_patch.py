#!/usr/bin/env python3
from pathlib import Path

CHAR = Path('src/char.go')
text = CHAR.read_text(encoding='utf-8')

replacements = []

old_enemy = '''\t// Neutral players or partners\n\tif e.teamside < 0 || e.teamside == c.teamside {\n\t\treturn false\n\t}\n'''
new_enemy = '''\t// Neutral players or partners. In FFA every other root player is an enemy,\n\t// even when the engine internally stores both fighters on the same side.\n\tif e.teamside < 0 {\n\t\treturn false\n\t}\n\tif sys.gameMode == "freeforall" {\n\t\t// Helpers and the owning root share playerNo. Keep them friendly to one another.\n\t\tif e.playerNo == c.playerNo {\n\t\t\treturn false\n\t\t}\n\t} else if e.teamside == c.teamside {\n\t\treturn false\n\t}\n'''
replacements.append((old_enemy, new_enemy, 'isEnemyOf partner block'))

old_player_hit = '''\t\tif c.atktmp != 0 && c.id != getter.id &&\n\t\t\t(c.hitdef.affectteam == 0 || (getter.teamside != c.hitdef.teamside) == (c.hitdef.affectteam > 0)) {\n'''
new_player_hit = '''\t\tisEnemyTarget := getter.teamside != c.hitdef.teamside\n\t\tif sys.gameMode == "freeforall" {\n\t\t\tisEnemyTarget = getter.playerNo != c.playerNo\n\t\t}\n\n\t\tif c.atktmp != 0 && c.id != getter.id &&\n\t\t\t(c.hitdef.affectteam == 0 || isEnemyTarget == (c.hitdef.affectteam > 0)) {\n'''
replacements.append((old_player_hit, new_player_hit, 'player HitDef team relation'))

old_proj_hit = '''\t\t\t// Teamside check\n\t\t\t// Since the teamside parameter is new to Ikemen, we can make that one allow the projectile to hit the root\n\t\t\tif p.hitdef.affectteam != 0 &&\n\t\t\t\t((getter.teamside != p.hitdef.teamside) != (p.hitdef.affectteam > 0) ||\n\t\t\t\t\t(getter.teamside == p.hitdef.teamside) != (p.hitdef.affectteam < 0)) {\n\t\t\t\tcontinue\n\t\t\t}\n'''
new_proj_hit = '''\t\t\t// Teamside check. FFA treats every different root slot as hostile even when\n\t\t\t// both roots are stored on the same internal Simul side.\n\t\t\tprojEnemyTarget := getter.teamside != p.hitdef.teamside\n\t\t\tprojFriendlyTarget := getter.teamside == p.hitdef.teamside\n\t\t\tif sys.gameMode == "freeforall" {\n\t\t\t\tprojEnemyTarget = getter.playerNo != i\n\t\t\t\tprojFriendlyTarget = getter.playerNo == i\n\t\t\t}\n\t\t\tif p.hitdef.affectteam != 0 &&\n\t\t\t\t(projEnemyTarget != (p.hitdef.affectteam > 0) ||\n\t\t\t\t\tprojFriendlyTarget != (p.hitdef.affectteam < 0)) {\n\t\t\t\tcontinue\n\t\t\t}\n'''
replacements.append((old_proj_hit, new_proj_hit, 'projectile-to-player team relation'))

old_proj_cancel = '''\t\t\tif getter.atktmp != 0 && (getter.hitdef.affectteam == 0 ||\n\t\t\t\t(p.hitdef.teamside != getter.teamside) == (getter.hitdef.affectteam > 0)) &&\n'''
new_proj_cancel = '''\t\t\tif getter.atktmp != 0 && (getter.hitdef.affectteam == 0 ||\n\t\t\t\tprojEnemyTarget == (getter.hitdef.affectteam > 0)) &&\n'''
replacements.append((old_proj_cancel, new_proj_cancel, 'player-to-projectile team relation'))

for old, new, label in replacements:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'FFA patch failed: expected exactly one {label}, found {count}')
    text = text.replace(old, new, 1)
    print(f'Applied: {label}')

CHAR.write_text(text, encoding='utf-8')
print('FFA engine patch complete: src/char.go')
