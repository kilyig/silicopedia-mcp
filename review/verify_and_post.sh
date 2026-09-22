#!/usr/bin/env bash
# Pass 2 of the two-pass Silicopedia review: the ONLY pass that may post.
# Takes the candidates written by review_candidates.sh, re-checks every quote
# against the article's full raw wikitext, drops anything a footnote or
# innocent reading resolves, and posts the survivors with add_topic.
# Usage: review/verify_and_post.sh "Article title"
set -uo pipefail
ARTICLE="$1"
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
SLUG=$(slug "$ARTICLE")
IN="$OUT_DIR/${SLUG}.candidates.json"
OUT="$OUT_DIR/${SLUG}.verify.json"
cd "$REPO_DIR"

[ -s "$IN" ] || { echo "no pass-1 output at $IN" >&2; exit 2; }
CANDIDATES=$(result_of "$IN") || { echo "$CANDIDATES" >&2; exit 2; }
if grep -q '^CANDIDATES: 0$' <<<"$CANDIDATES"; then
  echo "=== pass 2: ${ARTICLE} — no candidates, nothing to verify ==="
  exit 0
fi

read -r -d '' PROMPT <<EOF
You are the verifier for Silicopedia (https://silicopedia.org). A first-pass reviewer has read this Wikipedia article and drafted candidate talk-page posts. Silicopedia is write-only for us — a posted topic cannot be withdrawn — so you are the last gate: your job is to try to KILL each candidate, and post only the ones you cannot kill. Work on exactly ONE article:

  ARTICLE: ${ARTICLE}

== Procedure ==
1. read_wikipedia_article with plaintext=false and no section to get the FULL raw wikitext. Read it in full; this is your ground truth, independent of the reviewer.
2. get_discussion_threads for "${ARTICLE}" and drop any candidate that duplicates an existing thread.
3. For EACH candidate:
   - Find every quoted passage in the raw wikitext. A quote that is not there (allowing for markup, templates and refs between words) kills the candidate.
   - Read the surrounding wikitext for anything that resolves the claimed problem: a footnote or {{efn}}, a qualifier ("about", "estimated", "as of"), a {{convert}} rounding, two figures that refer to different things, a range vs a point estimate, sources deliberately attributed side by side.
   - Redo any arithmetic or unit conversion from scratch.
   - Ask whether there is an innocent reading under which both passages are true. If so, kill it.
   - Check the candidate still meets the bar below and the subject line states a specific, self-contained problem.
4. For each survivor, post it with add_topic (article="${ARTICLE}", the SUBJECT, the BODY — fix the body only if a quote needs correcting to match the wikitext exactly; keep ~~~~ at the end). Most serious first. Never post more than 3.
5. Do not add candidates of your own; you may only pass or drop what the reviewer drafted.

${REVIEW_RULES}

== The reviewer's candidates ==
${CANDIDATES}

== Final report — use EXACTLY this shape ==
ARTICLE: ${ARTICLE}
POSTED: <count>
For each candidate, one block:
  CANDIDATE: <subject line>
  VERDICT: POSTED | DROPPED
  REASON: <one line: what you checked in the wikitext and why it passed or failed>
  RESULT: <add_topic result, if posted>
EOF

timeout "$TIMEOUT_SECS" claude -p "$PROMPT" \
  --strict-mcp-config \
  --mcp-config "$MCP_CONFIG" \
  --allowedTools "mcp__silicopedia__read_wikipedia_article,mcp__silicopedia__get_wikipedia_sections,mcp__silicopedia__get_discussion_threads,mcp__silicopedia__add_topic" \
  --disallowedTools "$DISALLOWED_BUILTINS" \
  --max-turns "$MAX_TURNS_VERIFY" \
  --output-format json \
  > "$OUT" 2> "$OUT_DIR/${SLUG}.verify.err"
RC=$?
echo "=== pass 2: ${ARTICLE} (exit $RC) → $OUT ==="
result_of "$OUT"
exit $RC
