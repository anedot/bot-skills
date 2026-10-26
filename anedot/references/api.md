# Anedot v3 API reference

Facts here were verified against production with a PAT unless marked **Unverified**.

## Auth and transport

- Base host: `https://anedot.com`. Not `api.anedot.com`.
- Headers on every call:
  - `Authorization: Bearer <PAT>`
  - `Accept: application/json`
  - A browser-like `User-Agent`, for example `Mozilla/5.0 (anedot-bot-skills)`
  - `Content-Type: application/json` on POST and PATCH
- The API can briefly answer `401` to a valid PAT, for example during a deploy. Retry up to 12 times with a 1 second sleep before treating a 401 as real.
- `account_id` is the account `id` from `/user/v3/accounts` (an 11-character hex string such as `a1b2c3d4e5f`). Passing the account slug returns `404`.
- JSON keys are camelCase in requests and responses.

## Helper

`scripts/anedot.sh` wraps the rules above.

```bash
export ANEDOT_TOKEN_CMD='<command that prints your PAT>'   # or export ANEDOT_TOKEN=...
scripts/anedot.sh GET  "/user/v3/accounts"
scripts/anedot.sh POST "/org/v3/action_pages?account_id=$ACCT" page.json
scripts/anedot.sh ALL  "/org/v3/donations?account_id=$ACCT&per_page=500&start_date=2026-01-01"
```

`METHOD PATH [json-file]` prints the body to stdout and `HTTP <code>` to stderr. It exits non-zero on a non-2xx status. `ALL PATH` walks every page and prints one JSON array of records.

The core of it, if you need to inline the call:

```bash
# METHOD, API_PATH, and optional DATA (a JSON file) are set by the caller.
args=(-s -o out.json -w '%{http_code}' -X "$METHOD" "https://anedot.com$API_PATH"
  -H "Authorization: Bearer $ANEDOT_TOKEN" -H "User-Agent: Mozilla/5.0 (anedot-bot-skills)"
  -H "Accept: application/json")
[ -n "${DATA:-}" ] && args+=(-H "Content-Type: application/json" --data @"$DATA")
for i in $(seq 1 12); do
  code=$(curl "${args[@]}")
  [ "$code" != "401" ] && break; sleep 1
done
```

## Pagination

- Lists take `page` and `per_page`. Donations accepted `per_page=500` in testing.
- Donations `meta` is `{previousPage, currentPage, nextPage}` with no total. Page until `nextPage` is null or `data` is empty.
- Most other lists return `meta: {currentPage, totalPages, totalCount}`.

## Endpoints

### Identity and accounts

| Call | Notes |
|---|---|
| `GET /user/v3/me` | The token's user: `id`, `firstName`, `lastName`, `email`, ... |
| `GET /user/v3/accounts` | Accounts the token can reach: `id`, `name`, `displayName`, `status`, `image`. No slug. |
| `GET /org/v3/accounts/{id}` | One account. Has `slug`, `name`, `timeZone`, `url`, `balance`, and more. |

### Donations (read only for a PAT)

`GET /org/v3/donations?account_id={id}`

Verified query params:

- `sort`: `-created_at` (newest first). Default order is by donation date, newest first. Other sortable fields per the API implementation: `amount`, `date`, `created_at`, `updated_at`, `first_name`, `last_name`, `status`, `frequency`, `origin`, `source`, `donor_type`.
- `start_date`, `end_date`: `YYYY-MM-DD`. **Unverified:** whether `end_date` is inclusive and which time zone the day boundary uses. Check edge records against `createdAt`.
- `amount_gteq` in cents. The API implementation also lists `amount_gt`, `amount_lt`, `amount_eq`, `amount_lteq`.
- `email`: partial, case-insensitive match.

Accepted per the API implementation, not yet exercised: `first_name`, `last_name`, `phone` (partial match), `status` (comma list), `action_page_ids` (comma list), `fund_ids`, `recurring` (accepted without error; effect not confirmed), `source_code`, `origin`, `city`, `region`, `postal_code`, `card_last_four`.

Record fields seen: `id`, `amount` and `netAmount` and `originalAmount` and `refundedAmount` (cents), `anedotFeeAmount`, `vendorFeeAmount`, `feesPaidByDonor`, `status` (seen: `completed`, `voided`), `createdAt` (UTC `Z`), `donationDate` (account-local offset), `firstName`, `lastName`, `email`, `phone`, `donorType`, `fund` (`{name, identifier}`), `actionPageId`, `actionPageName`, `actionPageSlug`, `actionPageAccountSlug`, `source` (for example `credit_card`), `origin`, `sourceCode`, `utmCodes`, `items`, `submissionId`.

There is no `fees` field. Fees are `anedotFeeAmount` plus `vendorFeeAmount`. The donation record carries no frequency field. **Unverified:** how to tell a recurring gift from a one-time gift on the record.

### Other reads

| Call | Notes |
|---|---|
| `GET /org/v3/account_donors?account_id={id}` | Donor profiles: `id`, names, `email`, address, employer. `meta.totalCount` gives the donor count. |
| `GET /org/v3/action_pages?account_id={id}` | Pages, with `meta.totalCount`. |
| `GET /org/v3/action_pages_funds?account_id={id}` | Funds: `id`, `name`, `identifier`, `active`. |
| `GET /org/v3/action_pages_commitments?account_id={id}` | Recurring commitments. Returned 200 with an empty list in testing. **Unverified:** record shape. |
| `GET /org/v3/charge_summaries?account_id={id}` | Returned 200 with an empty list in testing. |
| `GET /org/v3/account_summaries/{id}` | Returned 404. Do not use. |

### Action pages

| Call | Notes |
|---|---|
| `POST /org/v3/action_page_{type}_configurations?account_id={id}` | Create a config. `{type}` is `amount`, `confirmation`, `design`, `field`, `fund`, `general`, `payment`. Returns 201 and an `id`. |
| `GET/PATCH /org/v3/action_page_design_configurations/{id}?account_id={id}` | Design config. `/org/v3/design_configurations/{id}` and paths nested under the page both 404. |
| `POST /org/v3/action_pages?account_id={id}` | Create the page with the seven config ids. Returns 201. |
| `GET/PATCH /org/v3/action_pages/{id}?account_id={id}` | Read or edit a page. |
| `PATCH /org/v3/action_pages/{id}/activate?account_id={id}` | Make it live. Returns 204 with no body. |

The API implementation also routes `deactivate`, `pause`, and `archive` on the same member path. **Unverified** with a PAT.

Page facts:

- There is no draft status. A draft is a page created with a pause window (`pauseStartAt` now, `pauseEndAt` far in the future, plus `pausedMessage`). It reads back as `status: "paused"`. After `activate` it read back as `status: "active"` with both pause fields null. Persisted statuses per the API implementation are `active`, `archived`, and `deleted`; `paused` is derived from the window.
- Public URL: `https://secure.anedot.com/{account slug}/{page slug}`.
- `headerImageUrl` takes any public image URL and wins over `headerImageId`.

### Images: the PAT limit

- The image upload endpoint answers `403 {"error":"Personal access tokens cannot call this endpoint"}`.
- So `headerImageId`, `logoImageId`, and `backgroundImageId` cannot be set from a PAT.
- Header: use `headerImageUrl`.
- Logo: no URL field exists. `logoImageUrl` is the logo's click-through link, not its source. The installer uploads a logo once in the dashboard, then reuses that design config.
