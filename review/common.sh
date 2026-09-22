# Shared settings for the two-pass review pipeline. Sourced by the pass scripts.
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${SILICOPEDIA_REVIEW_OUT:-$REPO_DIR/review/out}"
MCP_CONFIG="${SILICOPEDIA_MCP_CONFIG:-$REPO_DIR/.mcp.json}"
MAX_TURNS_REVIEW="${SILICOPEDIA_REVIEW_TURNS:-80}"
MAX_TURNS_VERIFY="${SILICOPEDIA_VERIFY_TURNS:-40}"
TIMEOUT_SECS="${SILICOPEDIA_REVIEW_TIMEOUT:-1800}"
# Built-in tools the nested sessions must never have. --allowedTools only
# pre-approves; it does not remove built-ins, so both lists are required.
DISALLOWED_BUILTINS="Agent,Task,Bash,Skill,Write,Edit,MultiEdit,NotebookEdit,WebFetch,WebSearch,Read,Glob,Grep"
mkdir -p "$OUT_DIR"

slug() { printf '%s' "$1" | tr -c 'A-Za-z0-9' '_' | cut -c1-60; }

# Print the `result` field of a claude -p JSON output file.
result_of() {
  python3 - "$1" <<'PY'
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception as e:
    sys.exit(f"could not parse {sys.argv[1]}: {e}")
if d.get("is_error"):
    sys.exit(f"nested session error: {d.get('result','')[:500]}")
print(d.get("result", ""))
PY
}

# The quality bar, shared by both passes.
read -r -d '' REVIEW_RULES <<'EOF_RULES'
== What qualifies — ranked by seriousness, not by ease of proof ==
A defect qualifies ONLY if you can point to specific article text that demonstrates it. Rank candidates by how much they mislead a reader. Internal inconsistencies are the EASIEST kind to prove, not the most important — do not prefer them over a more serious error just because they are easier to show.
1. Outright factual errors — a wrong date, number, name, place, unit or attribution; arithmetic that does not add up; a physically impossible figure; a misconverted unit. Strongest when provable from the article itself. An error resting on well-established outside knowledge may be raised ONLY if you are highly confident, it is material, and the post states the basis and how a reader can check it — never guess.
2. Internal contradictions — infobox vs body, lead vs body, table vs prose, a date/figure/name stated differently in two places.
3. Specific factual claims carrying no citation (judge only from raw wikitext, plaintext=false — plaintext strips citation markers).
4. A concrete, material coverage gap — something a reader clearly needs that is absent (not "could say more about").

== What does NOT qualify ==
- Anything derived from "Cite error:" text in a per-section read; citation-markup problems must be confirmed in the full raw wikitext (plaintext=false, no section).
- Prose/style nitpicks, tone, wording preferences; speculation about facts not in the article; vague "sourcing could be improved" padding. Silence is a valid, correct outcome; a padded post is a failure.
- Duplicates of threads already on the article's Silicopedia talk page.

== Post format (wikitext, not Markdown) ==
- One issue per post. Never bundle. Never put == headers == inside a post body.
- Subject line = a specific, self-contained statement of the problem ("Lead says 1462 but Career section says 1464"), not a label.
- Body = quote the offending passages verbatim, explain the conflict, propose a concrete fix. Use '''bold''', ''italic'', * bullets, [[Wikilinks]], <code>...</code>, <nowiki>{{templates}}</nowiki> when quoting template syntax. End with ~~~~.
- At most 3 posts per article.
EOF_RULES
