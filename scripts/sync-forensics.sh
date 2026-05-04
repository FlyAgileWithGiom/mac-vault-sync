#!/bin/bash
# sync-forensics.sh — Read-only diagnostic of FS↔DB divergence
# Output: markdown report grouped by top-level directory
# Usage: ./sync-forensics.sh > /tmp/sync-report.md

set -e

VAULT="/Users/guillaume/ObsidianNotes"
STATE_FILE="$VAULT/.vault-sync-state.json"
DB_URL="https://sync.fly-agile.com/vault-obsidiannotes"
CRED="livesync:EN69sTca81B4rYPBRsREGhjnHkbeSAqF"
CUTOFF="2026-05-03 18:00"   # ICT — local Mac time
DAEMON_LOG="$HOME/.local/log/vault-sync-daemon.log"

echo "# Sync Forensics — $(date '+%Y-%m-%d %H:%M %Z')"
echo
echo "**Cutoff canonique** : \`$CUTOFF\` ICT (heure locale Mac)."
echo "Tout ce qui est postérieur = fantôme (résurrection ou bruit du sync cassé)."
echo

# ============================================================
# Section A — FS files post-cutoff, grouped by top-level dir
# ============================================================
echo "## A — Fichiers FS post-cutoff (mtime OR ctime > $CUTOFF)"
echo

POST_FS=$(mktemp)
{
  find "$VAULT" -newermt "$CUTOFF" -type f \
    -not -path "*/.git/*" -not -path "*/.trash/*" -not -path "*/.obsidian/*" \
    2>/dev/null
  find "$VAULT" -newerBt "$CUTOFF" -type f \
    -not -path "*/.git/*" -not -path "*/.trash/*" -not -path "*/.obsidian/*" \
    2>/dev/null
} | sort -u > "$POST_FS"

TOTAL_POST=$(wc -l < "$POST_FS" | tr -d ' ')
echo "**Total fichiers FS suspects** : $TOTAL_POST"
echo
echo "Groupé par dossier racine (top 25) :"
echo
echo '```'
awk -F/ -v vault="$VAULT/" '{
  s=$0; sub(vault, "", s);
  n=index(s, "/");
  if (n>0) print substr(s, 1, n-1);
  else print "(root)";
}' "$POST_FS" | sort | uniq -c | sort -rn | head -25
echo '```'
echo

echo "Sample paths (top 20, hors fichiers system) :"
echo
echo '```'
grep -v 'DS_Store\|vault-sync' "$POST_FS" | head -20 | sed "s|$VAULT/||"
echo '```'
echo

# ============================================================
# Section B — DB-only docs, grouped by top-level dir
# ============================================================
echo "## B — Docs en DB sans contrepartie FS"
echo
echo "(Calcul: ID en DB qui n'a pas de fichier équivalent sur le FS)"
echo

DB_IDS=$(mktemp)
FS_IDS=$(mktemp)
DB_ONLY=$(mktemp)

curl -s -u "$CRED" "$DB_URL/_all_docs?limit=999999" \
  | python3 -c "
import json, sys
d = json.load(sys.stdin)
for r in d.get('rows', []):
    if r['id'].startswith('file/'):
        print(r['id'])
" | sort > "$DB_IDS"

find "$VAULT" -type f \
  -not -path "*/.git/*" -not -path "*/.trash/*" -not -path "*/.obsidian/*" \
  -not -name ".DS_Store" \
  2>/dev/null | sed "s|$VAULT/|file/|" | sort > "$FS_IDS"

comm -23 "$DB_IDS" "$FS_IDS" > "$DB_ONLY"
TOTAL_DBONLY=$(wc -l < "$DB_ONLY" | tr -d ' ')

echo "**Total docs DB-only** : $TOTAL_DBONLY"
echo
echo "Groupé par dossier racine (top 25) :"
echo
echo '```'
awk -F/ '{
  if (NF >= 3) print $2;
  else print "(top-level)";
}' "$DB_ONLY" | sort | uniq -c | sort -rn | head -25
echo '```'
echo

echo "Sample paths (top 30) :"
echo
echo '```'
head -30 "$DB_ONLY" | sed 's|^file/||'
echo '```'
echo

# ============================================================
# Section C — Doublons NFD/NFC
# ============================================================
echo "## C — Doublons NFD/NFC"
echo

python3 -c "
import unicodedata, json
raw = json.load(open('$STATE_FILE'))
revmap_str = raw.get('vault-sync-revmap', '{}')
revmap = json.loads(revmap_str) if isinstance(revmap_str, str) else revmap_str
counts = {}
samples = {}
for k in revmap:
    nfc = unicodedata.normalize('NFC', k)
    counts[nfc] = counts.get(nfc, 0) + 1
    samples.setdefault(nfc, []).append(k)
dups = [(k, v) for k, v in counts.items() if v > 1]
print(f'**Doublons détectés** : {len(dups)} chemins ont plusieurs représentations Unicode')
print()
print('Top 20 doublons:')
print()
print('\`\`\`')
for nfc, n in sorted(dups, key=lambda x: -x[1])[:20]:
    print(f'  ({n}x) {nfc}')
    for s in samples[nfc][:3]:
        marker = '*' if s != nfc else ' '
        print(f'    {marker} {s!r}')
print('\`\`\`')
"
echo

# ============================================================
# Section D — Daemon log timeline
# ============================================================
echo "## D — Daemon log (derniers events)"
echo
echo '```'
tail -60 "$DAEMON_LOG" 2>/dev/null | grep -E "Starting headless|EMFILE|reconcile|Pull:|State:|Error" | head -40
echo '```'
echo

# ============================================================
# Section E — revMap quick stats
# ============================================================
echo "## E — revMap state"
echo

python3 -c "
import json
raw = json.load(open('$STATE_FILE'))
revmap_str = raw.get('vault-sync-revmap', '{}')
revmap = json.loads(revmap_str) if isinstance(revmap_str, str) else revmap_str
print(f'**Total revMap entries** : {len(revmap)}')
print()
print('Sample top-level prefixes (count d entries par dossier racine) :')
print()
print('\`\`\`')
from collections import Counter
prefixes = Counter()
for k in revmap:
    parts = k.split('/', 2)
    if len(parts) >= 2:
        prefixes[parts[1]] += 1
    else:
        prefixes['(root)'] += 1
for p, n in prefixes.most_common(20):
    print(f'  {n:6d}  {p}')
print('\`\`\`')
"
echo

# Cleanup
rm -f "$POST_FS" "$DB_IDS" "$FS_IDS" "$DB_ONLY"

echo "---"
echo
echo "**Légende décision dossier-par-dossier** : pour chaque dossier listé en sections A et B,"
echo "marquer dans le rapport final \`planning/sync-state-2026-05-04.md\` une de ces décisions :"
echo "- \`SUPPRIMER\` : tous les fichiers de ce dossier sont des fantômes, à éliminer FS+DB"
echo "- \`GARDER\` : ce dossier est du contenu légitime à conserver"
echo "- \`EXAMINER\` : cas par cas, lister les fichiers à supprimer"
