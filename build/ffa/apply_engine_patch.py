#!/usr/bin/env python3
from pathlib import Path

CHAR = Path('src/char.go')
text = CHAR.read_text(encoding='utf-8')

old_enemy = '''\t// Neutral players or partners\n\tif e.teamside < 0 || e.teamside == c.teamside {\n\t\treturn false\n\t}\n'''
new_enemy = '''\t// Neutral players or partners. In FFA every other root player is an enemy,\n\t// even when the engine internally stores both fighters on the same side.\n\tif e.teamside < 0 {\n\t\treturn false\n\t}\n\tif sys.gameMode == "freeforall" {\n\t\t// Helpers and the owning root share playerNo. Keep them friendly to one another.\n\t\tif e.playerNo == c.playerNo {\n\t\t\treturn false\n\t\t}\n\t} else if e.teamside == c.teamside {\n\t\treturn false\n\t}\n'''

if old_enemy not in text:
    raise SystemExit('FFA patch failed: isEnemyOf partner block was not found')
text = text.replace(old_enemy, new_enemy, 1)
CHAR.write_text(text, encoding='utf-8')
print('Applied FFA enemy-classification patch to src/char.go')
