---
name: Anedot
description: When the user asks, by voice or text, to create or change an Anedot donation page, look up donations, get account stats, or run donor reports such as lapsed donors.
---
# Anedot

Drive the user's Anedot account through the Anedot v3 API: build and launch donation pages, look up donations, report account stats, and run donor reports. Voice and typed requests are handled the same way.

## Setup (once per installer)

1. The user creates a personal access token (PAT) in their Anedot dashboard.
2. Store it as a secret, never in chat or files. Expose it to the helper as `ANEDOT_TOKEN`, or set `ANEDOT_TOKEN_CMD` to a command that prints it (for example a vault CLI read).
3. Never print, echo, or repeat the token.

## Every request

1. Load `references/api.md` for auth, retries, and paths. Use `scripts/anedot.sh` for every call.
2. Resolve the account. `GET /user/v3/accounts`. One account: use it. Several: match the name the user said. Still unclear: ask once, then remember the choice for this session. Pass the account `id` (for example `a1b2c3d4e5f`) as `account_id`. The slug only builds public URLs.
3. Route by intent and follow that reference:
   - Create, edit, launch, pause a page: `references/create-donation-page.md`, and `references/page-design.md` for how to make it beautiful.
   - Find donations by donor, date, amount, page, or status: `references/lookup-donations.md`
   - Totals, counts, averages, by fund, page, or period: `references/account-stats.md`
   - Lapsed donors: `references/lapsed-donor-report.md`
   - Anything else: compose from the donations list (`lookup-donations.md`) and the aggregation patterns in `account-stats.md`. Say which records and filters you used.
4. Fill gaps with defaults instead of questions. Ask only for what has no sane default, such as which of several accounts to use.
5. Report:
   - Money in dollars. The API returns cents.
   - Times in the user's time zone. API timestamps are UTC (`Z`).
   - For pages, the live public link, and confirm it loads.
   - For reports, the window, the filters, and the record count behind each number.
6. Never invent numbers. If an endpoint fails or returns nothing, say so and show the HTTP status.

## Page-building defaults (good taste + compliance)

When building a donation page, apply these unless the user says otherwise:

- **Design:** follow `references/page-design.md` for layout, color, contrast (WCAG 2.2 AA), type, imagery, suggested amounts, and copy. Clean, high-contrast, brand-matched, one accent color on the give button, one clear headline plus a short supporting line. Never invent stats, quotes, logos, or impact numbers.
- **Name fields:** show first name and last name ONLY. Turn off middle name/initial, prefix, suffix, and any other name field.
- **FEC / federal campaigns:** if the page is for a federal candidate, committee, or PAC, collecting **employer** and **occupation** is required by law — set both to shown AND required. (This overrides the design doc's minimize-fields guidance.) For non-federal pages (state/local, nonprofits, churches, general fundraising), leave them off by default.
- Full page-build detail is in `references/create-donation-page.md`.

## Limits to tell the user about

- A PAT cannot upload images. Set header images with `headerImageUrl` (any public image URL). A logo needs a one-time upload in the Anedot dashboard.
- Refunds, voids, and other donation writes are not available to a PAT. Send the user to the dashboard.
