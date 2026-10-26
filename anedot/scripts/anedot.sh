#!/usr/bin/env bash
# Anedot v3 API helper. Needs bash, curl, jq.
#
#   anedot.sh CREATE_PAGE --account SLUG|ID --title TEXT [options]   build + activate + verify; prints URL and id
#   anedot.sh PAUSE|ACTIVATE --account A --page PAGE_ID   pause or reopen a page (ACTIVATE re-verifies the form)
#   anedot.sh ACCOUNTS [--json]          accounts: slug, displayName, id, status, org type, time zone
#   anedot.sh STATS --account A --from YYYY-MM-DD --to YYYY-MM-DD    one-line totals in dollars
#   anedot.sh RECENT --account A [N]     last N donations (default 5), one line each
#   anedot.sh ALL PATH                   every page of a list endpoint as one JSON array
#   anedot.sh METHOD PATH [json-file]    one raw request; "HTTP <code>" on stderr, body on stdout
#
# CREATE_PAGE options: --slug S, --body HTML, --amounts 25,50,100,250,500,1000 (dollars),
#   --once-only, --federal (employer+occupation required; auto-on for federal accounts),
#   --header-image-id ID / --logo-image-id ID (ids from GET /org/v3/account_images),
#   --primary HEX --button-text HEX --bg HEX (colors), --draft (paused, no link).
#
# Token: ANEDOT_TOKEN, or ANEDOT_TOKEN_CMD (a command that prints it). Never echoed.
# Exits non-zero on any non-2xx status, printing the status and error body to stderr.
set -euo pipefail

BASE="${ANEDOT_BASE:-https://anedot.com}"
PUBLIC="${ANEDOT_PUBLIC:-https://secure.anedot.com}"
UA="${ANEDOT_UA:-Mozilla/5.0 (anedot-bot-skills)}"
RETRIES_401="${ANEDOT_401_RETRIES:-2}"   # a valid token can briefly 401; a bad one fails in ~3s
RETRIES_BUSY="${ANEDOT_BUSY_RETRIES:-3}" # 429, 5xx, and network errors (code 000)
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/anedot-skill/accounts.json"

command -v jq >/dev/null || { echo "anedot.sh: jq is required" >&2; exit 2; }
die() { echo "anedot.sh: $*" >&2; exit 1; }

token() {
  if [ -n "${ANEDOT_TOKEN:-}" ]; then printf '%s' "$ANEDOT_TOKEN"
  elif [ -n "${ANEDOT_TOKEN_CMD:-}" ]; then bash -c "$ANEDOT_TOKEN_CMD"
  else echo "anedot.sh: set ANEDOT_TOKEN or ANEDOT_TOKEN_CMD" >&2; exit 2
  fi
}

request() { # METHOD PATH [datafile] -> body on stdout, "HTTP <code>" on stderr
  local m="$1" p="$2" d="${3:-}" tok out code n401=0 nbusy=0
  tok="${TOK:-$(token)}"; [ -n "$tok" ] || { echo "anedot.sh: token is empty" >&2; exit 2; }
  out="$(mktemp)"
  local args=(-s -o "$out" -w '%{http_code}' -X "$m" "$BASE$p"
    -H "Authorization: Bearer $tok" -H "User-Agent: $UA" -H "Accept: application/json")
  if [ -n "$d" ]; then args+=(-H "Content-Type: application/json" --data @"$d"); fi
  while :; do
    code="$(curl "${args[@]}" || true)"; code="${code:-000}"
    case "$code" in
      401) [ "$n401" -lt "$RETRIES_401" ] || break; n401=$((n401+1)); sleep 1 ;;
      429|5??|000) [ "$nbusy" -lt "$RETRIES_BUSY" ] || break; nbusy=$((nbusy+1)); sleep $((nbusy*2)) ;;
      *) break ;;
    esac
  done
  echo "HTTP $code" >&2
  cat "$out"; rm -f "$out"
  [ "${code:0:1}" = "2" ]
}

call() { # METHOD PATH [datafile] -> body on stdout; on failure, status and body go to stderr
  local body cf; cf="$(mktemp)"
  if ! body="$(request "$@" 2>"$cf")"; then
    echo "anedot.sh: $1 $2 failed: $(cat "$cf")" >&2
    printf '%s\n' "$body" | head -c 500 >&2; echo >&2; rm -f "$cf"; exit 1
  fi
  rm -f "$cf"; printf '%s' "$body"
}

all() { # PATH -> one JSON array on stdout
  local path="$1" sep='?' page=1 body next total n
  [[ "$path" == *\?* ]] && sep='&'
  while :; do
    body="$(call GET "${path}${sep}page=${page}")"
    # Pages go to files, not argv, so large result sets do not hit "Argument list too long".
    jq -c '.data // []' <<<"$body" > "$tmp/page-$(printf '%06d' "$page").json"
    next="$(jq -r '.meta.nextPage // empty' <<<"$body")"
    total="$(jq -r '.meta.totalPages // empty' <<<"$body")"
    n="$(jq '(.data // []) | length' <<<"$body")"
    if [ -n "$next" ] && [ "$n" -gt 0 ]; then page="$next"
    elif [ -n "$total" ] && [ "$page" -lt "$total" ]; then page=$((page+1))
    else break; fi
  done
  jq -s 'add // []' "$tmp"/page-*.json
  rm -f "$tmp"/page-*.json
}

# Accounts are shown and matched by displayName and slug only; the legal name (`name`) is left out on purpose.
ACCT_KEYS='{id, displayName, slug, status, category, subCategory, timeZone}'
accounts_json() { # fetches every account in parallel, refreshes the cache
  local id pids=()
  all "/user/v3/accounts?per_page=100" > "$tmp/accounts-list.json"
  for id in $(jq -r '.[].id' "$tmp/accounts-list.json"); do
    ( call GET "/org/v3/accounts/$id" | jq -c "$ACCT_KEYS" > "$tmp/acc-$id.json" ) & pids+=("$!")
  done
  for id in "${pids[@]}"; do wait "$id"; done
  jq -s '.' "$tmp"/acc-*.json 2>/dev/null | jq '. // []' > "$tmp/accounts.json"
  mkdir -p "$(dirname "$CACHE")" && cp "$tmp/accounts.json" "$CACHE"
  cat "$tmp/accounts.json"
}

account() { # SLUG|ID -> one account JSON (cache first; an id costs one GET)
  local a="$1" hit=""
  if [[ "$a" =~ ^a[0-9a-f]{10}$ ]]; then call GET "/org/v3/accounts/$a" | jq -c "$ACCT_KEYS"; return; fi
  a="${a#/}"; a="${a%/}"
  [ -f "$CACHE" ] && hit="$(jq -c --arg s "$a" '[.[]|select(.slug==$s)][0] // empty' "$CACHE")"
  [ -n "$hit" ] || hit="$(accounts_json | jq -c --arg s "$a" '[.[]|select(.slug==$s)][0] // empty')"
  [ -n "$hit" ] || die "no account with slug '$a' (run ACCOUNTS to list them)"
  printf '%s\n' "$hit"
}

opt() { # NAME DEFAULT ARGS... -> value of --NAME
  local n="$1" d="$2"; shift 2
  while [ $# -gt 0 ]; do [ "$1" = "--$n" ] && { printf '%s' "${2:-}"; return; }; shift; done
  printf '%s' "$d"
}
elapsed() { awk -v a="$1" -v b="$(date +%s.%N)" 'BEGIN{print b-a}'; }
flag() { local n="$1"; shift; for x in "$@"; do [ "$x" = "--$n" ] && return 0; done; return 1; }

verify_live() { # URL -> 0 when the public page renders the donation form (paused pages have no <form>)
  local _
  for _ in 1 2 3 4 5; do
    curl -s -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130 Safari/537.36" \
      "$1?v=$RANDOM" | grep -q '<form' && return 0
    sleep 1
  done
  return 1
}

create_page() {
  local acc acct slug title pslug body amounts sfx fed=false freq draft=false t0 now
  t0="$(date +%s.%N)"
  acc="$(account "$(opt account "" "$@")")"; acct="$(jq -r .id <<<"$acc")"; slug="$(jq -r .slug <<<"$acc")"
  title="$(opt title "" "$@")"; [ -n "$title" ] || title="Support $(jq -r .displayName <<<"$acc")"
  pslug="$(opt slug "" "$@")"
  [ -n "$pslug" ] || pslug="$(printf '%s' "$title" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g')"
  body="$(opt body "<p>Your gift, one-time or monthly, keeps this work going. Thank you.</p>" "$@")"
  amounts="$(opt amounts "25,50,100,250,500,1000" "$@")"
  freq='["once","monthly"]'; flag once-only "$@" && freq='["once"]'
  if flag federal "$@" || jq -e '.category=="political" and .subCategory=="federal"' <<<"$acc" >/dev/null; then fed=true; fi
  flag draft "$@" && draft=true
  sfx="$(od -An -N2 -tx2 /dev/urandom | tr -d ' ')"   # config names must be unique per account
  TOK="$(token)"; export TOK

  # Phase 1 (parallel): fund lookup plus the six configs that do not need it.
  ( call GET "/org/v3/action_pages_funds?account_id=$acct&per_page=100" > "$tmp/funds.json" ) & local pf=$!
  jq -n --arg n "$title - amounts $sfx" --arg a "$amounts" --argjson f "$freq" '{name:$n,default:false,
    amountPresets:{default:($a|split(",")|map({amount:((tonumber*100)|round),featured:false,description:null}))},
    amountPresetsOther:true,recurringOptions:$f,recurringDefaultFrequency:"once",displayFrequencyAsCheckbox:false,
    transactionMinimum:100,transactionMaximum:2500000}' > "$tmp/amount.json"
  jq -n --arg n "$title - payment $sfx" '{name:$n,default:false,creditCardEnabled:true,applepayEnabled:true,
    googlepayEnabled:true,anedotEnabled:true,personalDirectDebitEnabled:true,businessDirectDebitEnabled:true,
    paypalEnabled:false,bitcoinOpenNodeEnabled:false,feeCoverType:"disabled"}' > "$tmp/payment.json"
  jq -n --arg n "$title - general $sfx" '{name:$n,default:false,acceptsDonationsForAllPurchaseTypes:true,externalRaisedAmount:0}' > "$tmp/general.json"
  jq -n --arg n "$title - receipt $sfx" --arg from "$(jq -r .displayName <<<"$acc")" '{name:$n,default:false,
    emailFromName:$from,subjectLine:"Thank you for your gift",content:[{type:"text",content:{
    text:"<p>Thank you for your gift, {{first_name}}!</p>",hasSecondColumn:null,secondColumnText:null}}]}' > "$tmp/confirmation.json"
  jq -n --arg n "$title - fields $sfx" --argjson fed "$fed" '{name:$n,default:false,type:"ActionPageFieldConfigurations::Donation",
    displayName:true,requireName:true,includeMiddleName:false,includeSuffix:false,includeTitle:false,requireTitle:false,
    includeOrganization:false,displayEmail:true,requireEmail:true,displayAddress:true,requireAddress:true,
    displayPhone:true,requirePhone:false,displayEmployment:$fed,includeEmployerName:$fed,requireEmployerName:$fed,
    includeOccupation:$fed,requireOccupation:$fed}' > "$tmp/field.json"
  jq -n --arg n "$title - design $sfx" --arg p "$(opt primary "#053dad" "$@")" --arg b "$(opt button-text "#ffffff" "$@")" \
    --arg bg "$(opt bg "#f5f7f6" "$@")" --arg logo "$(opt logo-image-id "" "$@")" '{name:$n,default:false,
    backgroundColor:$bg,actionElementColorPrimary:$p,actionElementColorSecondary:$b}
    + (if $logo != "" then {logoImageId:$logo} else {} end)' > "$tmp/design.json"
  local t pids=()
  for t in amount payment general confirmation field design; do
    ( call POST "/org/v3/action_page_${t}_configurations?account_id=$acct" "$tmp/$t.json" | jq -r .id > "$tmp/$t.id" ) & pids+=("$!")
  done
  wait "$pf"
  local fund; fund="$(jq -r '[.data[]|select(.active)] | (map(select(.name|test("general";"i")))[0] // .[0]) | .id // empty' "$tmp/funds.json")"
  [ -n "$fund" ] || die "no active fund on account $slug"
  jq -n --arg n "$title - fund $sfx" --arg f "$fund" '{name:$n,default:false,multiFundExpanded:true,multiFundModifiable:false,
    fundSelectionsAttributes:[{fundId:$f,percentage:100,position:0,shown:true}]}' > "$tmp/fund.json"
  call POST "/org/v3/action_page_fund_configurations?account_id=$acct" "$tmp/fund.json" | jq -r .id > "$tmp/fund.id"
  for t in "${pids[@]}"; do wait "$t" || die "config create failed"; done

  # Phase 2: page. pausedMessage and backgroundImagePosition are required even for a live page.
  now="$(date -u +%FT%TZ)"
  jq -n --arg t "$title" --arg s "$pslug" --arg body "$body" --arg hid "$(opt header-image-id "" "$@")" \
    --argjson draft "$draft" --arg now "$now" \
    --arg a "$(cat "$tmp/amount.id")" --arg c "$(cat "$tmp/confirmation.id")" --arg d "$(cat "$tmp/design.id")" \
    --arg f "$(cat "$tmp/field.id")" --arg fu "$(cat "$tmp/fund.id")" --arg g "$(cat "$tmp/general.id")" --arg p "$(cat "$tmp/payment.id")" \
    '{type:"DonationActionPage",name:$t,slug:$s,headerTitleText:$t,headerTitleAlignment:"center",formAlignment:"center",
    formLayout:"standard",formStyle:"one_column",goal:0,footerShowAccountName:true,showShareButtons:true,recoveryEnabled:true,
    metaPageTitle:$t,metaPageDescription:$t,headerImagePosition:"fill",backgroundImagePosition:"cover",
    pausedMessage:"This page is not open yet. Please check back soon.",
    content:[{type:"text",content:{text:$body,hasSecondColumn:null,secondColumnText:null}}],
    amountConfigurationId:$a,confirmationConfigurationId:$c,designConfigurationId:$d,fieldConfigurationId:$f,
    fundConfigurationId:$fu,generalConfigurationId:$g,paymentConfigurationId:$p}
    + (if $hid != "" then {headerImageId:$hid} else {} end)
    + (if $draft then {pauseStartAt:$now,pauseEndAt:"2099-12-31T00:00:00Z"} else {} end)' > "$tmp/page.json"
  local page id
  if ! page="$(request POST "/org/v3/action_pages?account_id=$acct" "$tmp/page.json" 2>/dev/null)"; then
    jq -e '.errors[]?|select(.attribute=="slug")' <<<"$page" >/dev/null || die "page create failed: $(head -c 300 <<<"$page")"
    pslug="$pslug-$sfx"; jq --arg s "$pslug" '.slug=$s' "$tmp/page.json" > "$tmp/page2.json"
    page="$(call POST "/org/v3/action_pages?account_id=$acct" "$tmp/page2.json")"
  fi
  id="$(jq -r .id <<<"$page")"; pslug="$(jq -r .slug <<<"$page")"
  if $draft; then
    printf 'draft %s (paused, no public link until activated) %.1fs\n' "$id" "$(elapsed "$t0")"; return
  fi

  # Phase 3: activate, then verify the public page shows the form (a paused page has no <form>).
  call PATCH "/org/v3/action_pages/$id/activate?account_id=$acct" >/dev/null
  local url="$PUBLIC/$slug/$pslug"
  verify_live "$url" || die "page $id was activated but $url does not show the form yet"
  printf '%s\nid %s  %.1fs\n' "$url" "$id" "$(elapsed "$t0")"
}

set_state() { # PAUSE|ACTIVATE
  local acc acct page st url
  acc="$(account "$(opt account "" "$@")")"; acct="$(jq -r .id <<<"$acc")"; page="$(opt page "" "$@")"
  [ -n "$page" ] || die "$CMD needs --page PAGE_ID"
  call PATCH "/org/v3/action_pages/$page/$(tr '[:upper:]' '[:lower:]' <<<"$CMD")?account_id=$acct" >/dev/null
  st="$(call GET "/org/v3/action_pages/$page?account_id=$acct" | jq -r '"\(.status) \(.slug)"')"
  url="$PUBLIC/$(jq -r .slug <<<"$acc")/${st#* }"
  if [ "$CMD" = ACTIVATE ]; then verify_live "$url" || die "activated but $url does not show the form yet"; echo "$url"; fi
  echo "$page ${st% *}"
}

donations() { # ACCT QUERY -> JSON array
  all "/org/v3/donations?account_id=$1&per_page=500&$2"
}

stats() {
  local acct from to
  acct="$(account "$(opt account "" "$@")" | jq -r .id)"; from="$(opt from "" "$@")"; to="$(opt to "" "$@")"
  { [ -n "$from" ] && [ -n "$to" ]; } || die "STATS needs --from and --to (YYYY-MM-DD, inclusive, account-local days)"
  donations "$acct" "start_date=$from&end_date=$to" | jq -r --arg w "$from..$to" '
    (map(select(.status=="completed"))) as $c |
    "\($w): \($c|length) completed, gross $\(($c|map(.amount)|add // 0)/100), fees $\(($c|map((.anedotFeeAmount//0)+(.vendorFeeAmount//0))|add // 0)/100), net $\(($c|map(.netAmount)|add // 0)/100), recurring \($c|map(select(.actionPagesCommitmentId!=null))|length), donors \($c|map(.email|ascii_downcase? // "")|unique|length)" ,
    "other: \(map(select(.status!="completed"))|group_by(.status)|map("\(.[0].status) \(length)")|join(", ") | if .=="" then "none" else . end)"'
}

recent() {
  local acct n
  acct="$(account "$(opt account "" "$@")" | jq -r .id)"
  n="$(printf '%s\n' "$@" | grep -E '^[0-9]+$' | head -1)"; n="${n:-5}"
  call GET "/org/v3/donations?account_id=$acct&sort=-created_at&per_page=$n" | jq -r '.data[] |
    "\(.donationDate[0:16]|sub("T";" "))  $\(.amount/100)  \(.status)  \(.firstName) \(.lastName)  \(.actionPageName)\(if .actionPagesCommitmentId then "  recurring" else "" end)"'
}

case "${1:-}" in
  ALL|ACCOUNTS|CREATE_PAGE|STATS|RECENT|PAUSE|ACTIVATE)
    tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
    CMD="$1"; shift
    case "$CMD" in
      ALL) all "${1:?usage: anedot.sh ALL PATH}" ;;
      ACCOUNTS) if flag json "$@"; then accounts_json; else
        accounts_json | jq -r '.[] | [.slug, .displayName, .id, .status, "\(.category)/\(.subCategory)", .timeZone] | @tsv'; fi ;;
      CREATE_PAGE) create_page "$@" ;;
      STATS) stats "$@" ;;
      RECENT) recent "$@" ;;
      PAUSE|ACTIVATE) set_state "$@" ;;
    esac ;;
  ""|-h|--help) sed -n '2,20p' "$0" >&2; exit 2 ;;
  *) request "$@" ;;
esac
