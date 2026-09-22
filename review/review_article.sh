#!/usr/bin/env bash
# Run the full two-pass review for one article: read-only candidate pass,
# then the verifying pass that posts survivors.
# Usage: review/review_article.sh "Article title"
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$DIR/review_candidates.sh" "$1" && "$DIR/verify_and_post.sh" "$1"
