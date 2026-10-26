#!/usr/bin/env bash
# Anedot v3 API helper.
#
#   anedot.sh METHOD PATH [json-file]   one request; prints "HTTP <code>" to stderr, body to stdout
#   anedot.sh ALL PATH                  GET every page of a list endpoint; prints one JSON array of records
#
# Token: set ANEDOT_TOKEN, or set ANEDOT_TOKEN_CMD to a command that prints it
# (for example a vault CLI read). The token is never echoed.
set -euo pipefail

BASE="${ANEDOT_BASE:-https://anedot.com}"
UA="${ANEDOT_UA:-Mozilla/5.0 (anedot-bot-skills)}"

token() {
  if [ -n "${ANEDOT_TOKEN:-}" ]; then printf '%s' "$ANEDOT_TOKEN"
  elif [ -n "${ANEDOT_TOKEN_CMD:-}" ]; then bash -c "$ANEDOT_TOKEN_CMD"
  else echo "anedot.sh: set ANEDOT_TOKEN or ANEDOT_TOKEN_CMD" >&2; exit 2
  fi
}

request() { # METHOD PATH [datafile] -> body on stdout, code on stderr
  local m="$1" p="$2" d="${3:-}" tok out code
  tok="$(token)"; out="$(mktemp)"
  local args=(-s -o "$out" -w '%{http_code}' -X "$m" "$BASE$p"
    -H "Authorization: Bearer $tok" -H "User-Agent: $UA" -H "Accept: application/json")
  [ -n "$d" ] && args+=(-H "Content-Type: application/json" --data @"$d")
  # The API can briefly 401 a valid token (for example during a deploy). Retry up to 12 times.
  for _ in $(seq 1 12); do
    code="$(curl "${args[@]}")"
    [ "$code" != "401" ] && break
    sleep 1
  done
  echo "HTTP $code" >&2
  cat "$out"; rm -f "$out"
  [ "${code:0:1}" = "2" ]
}

if [ "${1:-}" = "ALL" ]; then
  path="$2"; sep='?'; [[ "$path" == *\?* ]] && sep='&'
  page=1; acc='[]'
  while :; do
    body="$(request GET "${path}${sep}page=${page}" 2>/dev/null)"
    acc="$(jq -c --argjson a "$acc" '$a + (.data // [])' <<<"$body")"
    next="$(jq -r '.meta.nextPage // empty' <<<"$body")"
    total="$(jq -r '.meta.totalPages // empty' <<<"$body")"
    n="$(jq '(.data // []) | length' <<<"$body")"
    if [ -n "$next" ] && [ "$n" -gt 0 ]; then page="$next"
    elif [ -n "$total" ] && [ "$page" -lt "$total" ]; then page=$((page+1))
    else break; fi
  done
  echo "$acc"
else
  request "$@"
fi
