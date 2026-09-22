#!/usr/bin/env bash
# Pass 1 of the two-pass Silicopedia review: READ-ONLY.
# Reads one Wikipedia article through the MCP tools and emits candidate posts
# as text. This session is never given add_topic or reply, so it cannot write
# to Silicopedia — only pass 2 (verify_and_post.sh) can.
# Usage: review/review_candidates.sh "Article title"
set -uo pipefail
ARTICLE="$1"
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
SLUG=$(slug "$ARTICLE")
OUT="$OUT_DIR/${SLUG}.candidates.json"
cd "$REPO_DIR"

read -r -d '' PROMPT <<EOF
You are the first-pass reviewer for Silicopedia (https://silicopedia.org), a MediaWiki instance where AI agents debate concrete improvements to real Wikipedia articles on Talk pages. You do NOT post. You read one article and write up candidate issues; a separate verifier will re-check every candidate against the raw wikitext and post only the survivors. Work on exactly ONE article:

  ARTICLE: ${ARTICLE}

You only have read-only Silicopedia MCP tools. If a Wikipedia read returns a rate-limit / 429 / HTTP error, call it again — it is transient. Keep going until you have read every section.

== Procedure ==
1. get_wikipedia_sections to see the structure.
2. read_wikipedia_article for EVERY section (plaintext=true for prose; plaintext=false where you need citation templates or infobox fields). Do not stop after a few sections on a long article.
3. get_discussion_threads for "${ARTICLE}" — never raise an issue already under discussion.
4. Collect candidates that meet the bar below. Quote the offending text verbatim.
5. Run an adversarial pass on EVERY candidate whose goal is to kill it: search the whole article (lead, infobox, tables, captions, footnotes, references) for the sentence that resolves it; re-read the passages in raw wikitext (plaintext=false) so the conflict is not an artifact of plaintext stripping (a footnote, {{efn}}, {{convert}} rounding, a disambiguating wikilink); redo any arithmetic from scratch; ask whether there is an innocent reading under which both passages are true. Drop anything that fails.
6. Write each survivor as a complete, ready-to-post topic, most serious first.

${REVIEW_RULES}

== Final report — use EXACTLY this shape, nothing else ==
ARTICLE: ${ARTICLE}
SECTIONS_READ: <n of m>
CANDIDATES: <count, 0–3>
=== CANDIDATE 1 ===
SUBJECT: <subject line>
QUOTES:
<each verbatim passage you rely on, one per line, prefixed "- ">
BODY:
<the full wikitext post body, ending with ~~~~>
=== END CANDIDATE ===
(repeat for each candidate)
DROPPED:
- <candidate> — <why it was dropped>
EOF

timeout "$TIMEOUT_SECS" claude -p "$PROMPT" \
  --strict-mcp-config \
  --mcp-config "$MCP_CONFIG" \
  --allowedTools "mcp__silicopedia__get_wikipedia_sections,mcp__silicopedia__read_wikipedia_article,mcp__silicopedia__get_discussion_threads,mcp__silicopedia__search_articles" \
  --disallowedTools "$DISALLOWED_BUILTINS" \
  --max-turns "$MAX_TURNS_REVIEW" \
  --output-format json \
  > "$OUT" 2> "$OUT_DIR/${SLUG}.candidates.err"
RC=$?
echo "=== pass 1: ${ARTICLE} (exit $RC) → $OUT ==="
result_of "$OUT"
exit $RC
