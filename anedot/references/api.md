# Anedot v3 API reference

Facts here were verified against production with a PAT unless marked **Unverified**.

## Auth and transport

- Base host: `https://anedot.com`. Not `api.anedot.com`.
- Headers on every call:
  - `Authorization: Bearer <PAT>`
  - `Accept: application/json`
  - A browser-like `User-Agent`, for example `Mozilla/5.0 (anedot-bot-skills)`
  - `Content-Type: application/json` on POST and PATCH
- The API can briefly answer `401` to a valid PAT, for example during a deploy. Retry a 401 at most 2 times with a 1 second sleep, then treat it as a bad token. A bad token should fail in a few seconds, not a minute.
- Retry `429`, `5xx`, and network errors a few times with a growing sleep.
- `account_id` is the account `id` from `/user/v3/accounts` (an 11-character hex string such as `a1b2c3d4e5f`). Passing the account slug returns `404`.
- JSON keys are camelCase in requests and responses.
- List endpoints wrap records as `{data: [...], meta: {...}}`. Single-record `GET`s and create responses return the record itself, with no `data` wrapper.
- Error bodies look like `{"errors":[{"attribute":"...","details":["..."]}]}` on `422`. `401` and `404` can come back with an empty body.

## Helper

`scripts/anedot.sh` wraps the rules above.

```bash
export ANEDOT_TOKEN_CMD='<command that prints your PAT>'   # or export ANEDOT_TOKEN=...
scripts/anedot.sh GET  "/user/v3/me"                 # token check
scripts/anedot.sh ACCOUNTS                         # one line per account: slug, displayName, id, status, type, zone
scripts/anedot.sh CREATE_PAGE --account my-org      # live page in ~3s; prints URL and id
scripts/anedot.sh POST "/org/v3/action_pages?account_id=$ACCT" page.json
scripts/anedot.sh ALL  "/org/v3/donations?account_id=$ACCT&per_page=500&start_date=2026-01-01"
```

`METHOD PATH [json-file]` prints the body to stdout and `HTTP <code>` to stderr. It exits non-zero on a non-2xx status. `ALL PATH` walks every page and prints one JSON array of records. If any page fails, `ALL` prints the failing path, status, and body to stderr and exits non-zero; it never returns a partial list. `ACCOUNTS` prints tab-separated lines (`--json` for `[{id, displayName, slug, status, category, subCategory, timeZone}]`) and caches them in `~/.cache/anedot-skill/accounts.json` for slug lookups. It leaves out the legal name (`name`) on purpose: identify, show, and match accounts by `displayName` and `slug` only.

When you capture the body of a single call, keep stderr out of it (`2>/dev/null` or `2>code.txt`) so the `HTTP <code>` line does not break JSON parsing.

The core of it, if you need to inline the call:

```bash
# METHOD, API_PATH, and optional DATA (a JSON file) are set by the caller.
args=(-s -o out.json -w '%{http_code}' -X "$METHOD" "https://anedot.com$API_PATH"
  -H "Authorization: Bearer $ANEDOT_TOKEN" -H "User-Agent: Mozilla/5.0 (anedot-bot-skills)"
  -H "Accept: application/json")
[ -n "${DATA:-}" ] && args+=(-H "Content-Type: application/json" --data @"$DATA")
for i in 1 2 3; do   # first try plus at most 2 retries on 401
  code=$(curl "${args[@]}")
  [ "$code" != "401" ] && break; sleep 1
done
```

## Pagination

- Lists take `page` and `per_page`. Donations accepted `per_page=500` in testing; `per_page` is honored on other lists too.
- Donations `meta` is `{previousPage, currentPage, nextPage}` with no total. Page until `nextPage` is null or `data` is empty.
- Most other lists return `meta: {currentPage, totalPages, totalCount}`.

## Endpoints

### Identity and accounts

| Call | Notes |
|---|---|
| `GET /user/v3/me` | The token's user: `id`, `firstName`, `lastName`, `email`, ... |
| `GET /user/v3/accounts` | Accounts the token can reach: `id`, `name` (legal name), `displayName`, `status`, `image`. No slug. Paginated (`meta.totalPages`). Show and match by `displayName` and slug, never `name`. |
| `GET /org/v3/accounts/{id}` | One account. Has `slug`, `displayName`, `name` (legal name; do not display or match on it), `timeZone`, `url`, `status`, and org type: `category` (seen `nonprofit`, `political`), `subCategory` (seen `501c3`, `federal`), `entityType`, `politicalParty`, `fecCommitteeId`. Also holds tax ids and balance; do not show those unless asked. |

### Donations (read only for a PAT)

`GET /org/v3/donations?account_id={id}`

Verified query params:

- `sort`: `-created_at` (newest first). Default order is by donation date, newest first. Other sortable fields per the API implementation: `amount`, `date`, `created_at`, `updated_at`, `first_name`, `last_name`, `status`, `frequency`, `origin`, `source`, `donor_type`.
- `start_date`, `end_date`: `YYYY-MM-DD`, both inclusive, on the account's local day (its `timeZone`), matching `donationDate`. Verified: a gift at 23:43 local on the 31st (03:43Z on the 1st) is excluded by `start_date` of the 1st, and `start_date=end_date=D` returns that whole local day.
- `amount_gteq` in cents. The API implementation also lists `amount_gt`, `amount_lt`, `amount_eq`, `amount_lteq`.
- `email`: partial, case-insensitive match.

Accepted per the API implementation, not yet exercised: `first_name`, `last_name`, `phone` (partial match), `status` (comma list), `action_page_ids` (comma list), `fund_ids`, `recurring` (accepted without error; effect not confirmed), `source_code`, `origin`, `city`, `region`, `postal_code`, `card_last_four`.

Record fields seen: `id`, `amount` and `netAmount` and `originalAmount` and `refundedAmount` (cents), `anedotFeeAmount`, `vendorFeeAmount`, `feesPaidByDonor`, `status` (seen: `completed`, `voided`, `refunded`, `declined`), `createdAt` (UTC `Z`), `donationDate` (account-local offset), `firstName`, `lastName`, `email`, `phone`, `donorType`, `fund` (`{name, identifier}`), `actionPageId`, `actionPageName`, `actionPageSlug`, `actionPageAccountSlug`, `actionPagesCommitmentId` (set when the gift belongs to a recurring commitment, else null), `source` (for example `credit_card`, `bank_account`), `origin`, `sourceCode`, `utmCodes`, `items`, `submissionId`.

There is no `fees` field. Fees are `anedotFeeAmount` plus `vendorFeeAmount`; on completed gifts `amount - netAmount` equals that sum. The donation record carries no frequency field. A gift with a non-null `actionPagesCommitmentId` is part of a recurring commitment; look up the commitment for its schedule.

### Other reads

| Call | Notes |
|---|---|
| `GET /org/v3/account_donors?account_id={id}` | Donor profiles: `id`, names, `email`, address, employer. `meta.totalCount` gives the donor count. |
| `GET /org/v3/action_pages?account_id={id}` | Pages, with `meta.totalCount`. |
| `GET /org/v3/action_pages_funds?account_id={id}` | Funds: `id`, `name`, `identifier`, `active`. |
| `GET /org/v3/action_pages_commitments?account_id={id}` | Recurring commitments. Records: `id`, `active`, `scheduleAttributes` (`every`, for example `month`, and `interval`), `nextCaptureOn`, `occurrences`, `totalAmount`, `totalRaised`, `actionPage`, `donorProfileId`. `GET .../action_pages_commitments/{id}` reads one. **Unverified:** units of `totalAmount` and `totalRaised`. An account with no recurring gifts returns an empty list. |
| `GET /org/v3/charge_summaries?account_id={id}` | Returned 200 with an empty list in testing. |
| `GET /org/v3/account_summaries/{id}` | Returned 404. Do not use. |

### Action pages

| Call | Notes |
|---|---|
| `POST /org/v3/action_page_{type}_configurations?account_id={id}` | Create a config. `{type}` is `amount`, `confirmation`, `design`, `field`, `fund`, `general`, `payment`. Returns 201 and an `id`. |
| `GET/PATCH /org/v3/action_page_design_configurations/{id}?account_id={id}` | Design config. `/org/v3/design_configurations/{id}` and paths nested under the page both 404. |
| `GET /org/v3/action_page_field_configurations/{id}?account_id={id}` | Field config (name, email, phone, address, employer, occupation). Keys are listed in `create-donation-page.md`. |
| `POST /org/v3/action_pages?account_id={id}` | Create the page with the seven config ids. Returns 201. |
| `GET /org/v3/action_pages?account_id={id}` | Page list. Each item has `id`, `name`, `slug`, `status`, `pageType` (`donation`, `lead`, `event`), and the seven `*ConfigurationId` fields. The list item has no `type` key; the full page `GET` has more fields. |
| `GET/PATCH /org/v3/action_pages/{id}?account_id={id}` | Read or edit a page. |
| `PATCH /org/v3/action_pages/{id}/activate?account_id={id}` | Make it live. Returns 204 with no body. |

`PATCH .../pause` is verified: 204, then `status: "paused"` with a 100-year pause window (`anedot.sh PAUSE`). The API implementation also routes `deactivate` and `archive`; **unverified** with a PAT.

Page facts:

- There is no draft status. A draft is a page created with a pause window (`pauseStartAt` now, `pauseEndAt` far in the future, plus `pausedMessage`). It reads back as `status: "paused"`. After `activate` it read back as `status: "active"` with both pause fields null. Persisted statuses per the API implementation are `active`, `archived`, and `deleted`; `paused` is derived from the window.
- Public URL: `https://secure.anedot.com/{account slug}/{page slug}`. Fetch it with a browser-like `User-Agent`; curl's default agent gets `403`. A paused page still returns 200, so check the HTML for `<form`, not only the status. Only share a link once the page is active and the form shows.
- A page created with a pause window reads back with `pauseStartAt` and `pauseEndAt` in the account's time zone.
- Live check: the HTML of a live page contains `<form`; a paused page has none. The `pausedMessage` text is embedded in both, so do not test for it. `pausedMessage` and `backgroundImagePosition` are required on create.

### Images

- `POST /org/v3/account_images` answers `403 {"error":"Personal access tokens cannot call this endpoint"}`. `GET /org/v3/account_images` works and lists uploaded images (`id`, `file.url`).
- The checkout renders `headerImageId` (page) and `logoImageId` (design config) from uploaded images. Setting `headerImageId` by page PATCH is verified; `logoImageId` uses the same design-config PATCH (not yet verified). `headerImageUrl` is accepted but not rendered.
- A new image needs a one-time dashboard upload; then set its id.
