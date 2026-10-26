---
name: Anedot
description: When the user asks, by voice or text, to create or change an Anedot donation page, look up donations, get account stats, or run donor reports such as lapsed donors.
---
# Anedot

All calls go through `scripts/anedot.sh` (run it with no arguments for usage). Token: `ANEDOT_TOKEN` or `ANEDOT_TOKEN_CMD`, from a secret store. Never print it.

## Common path: one command

| Ask | Run |
|---|---|
| "Make me a donation page" | `scripts/anedot.sh CREATE_PAGE --account <slug-or-id> [--title "..."]`, then reply with the URL it prints |
| "Which accounts do I have?" | `scripts/anedot.sh ACCOUNTS` |
| "How did we do last month?" | `scripts/anedot.sh STATS --account <slug> --from YYYY-MM-DD --to YYYY-MM-DD` |
| "Any recent gifts?" | `scripts/anedot.sh RECENT --account <slug> 10` |
| "Pause / reopen that page" | `scripts/anedot.sh PAUSE\|ACTIVATE --account <slug> --page <page id>` |

`CREATE_PAGE` builds the seven configs in parallel, creates the page, activates it, checks the public page shows the form, and prints the URL and page id (about 3 seconds). It applies every default below. Options: `--slug`, `--body`, `--amounts`, `--once-only`, `--federal`, `--header-image-id`, `--logo-image-id`, `--primary`, `--button-text`, `--bg`, `--draft`.

## Rules

1. **Accounts:** match and show by `slug` (exact) then `displayName`. Never use the legal `name`. If several fit, list `displayName (slug)` and ask once. API calls take the account `id` (`a` + 10 hex), not the slug.
2. **Giving defaults, every page, every user** (unless the user asks otherwise): preset amounts ($25, $50, $100, $250, $500, $1,000 plus Other), **no amount preselected**, and both **one-time and monthly**. First and last name only.
3. **Employer and occupation: federal campaigns only** (`category: political` + `subCategory: federal`, or the user says it is a federal race or PAC), or a state that requires it. Then both are shown and required (`--federal`; auto-on for federal accounts). Otherwise off. This rule is separate from rule 2: it depends on the org, rule 2 does not.
4. **Links are always live.** Only return a page link after it is active and the public page shows the form. `CREATE_PAGE` and `ACTIVATE` enforce this. A `--draft` page gets no link.
5. Money in dollars (the API uses cents). Times in the user's zone. Never invent numbers; on a failure, give the HTTP status.
6. Fill gaps with defaults instead of questions.

## Go deeper only when needed

- Custom page edits, images, design: `references/create-donation-page.md`, `references/page-design.md`
- Donation search by donor, amount, page, status: `references/lookup-donations.md`
- Breakdowns by fund, page, month, top donors: `references/account-stats.md`
- Lapsed donors: `references/lapsed-donor-report.md`
- Endpoints, retries, quirks: `references/api.md`

## Limits

- A PAT cannot upload images. Uploaded images (`GET /org/v3/account_images`) can be used by id. New images need a one-time upload in the Anedot dashboard.
- Refunds, voids, and other donation writes need the dashboard.
