# Create a donation page

Default: `scripts/anedot.sh CREATE_PAGE --account <slug-or-id> [--title "..."]`. It prints the live URL and page id. Reply with the URL and one line on amounts and frequency. Use the manual steps below only for something the command does not cover.

Read `references/page-design.md` for layout, color, and copy.

## Defaults

| Setting | Default | Applies to |
|---|---|---|
| Amounts | $25, $50, $100, $250, $500, $1,000 plus Other | Every page |
| Preselected amount | None | Every page |
| Frequency | One-time and monthly (toggle starts on one-time) | Every page |
| Name fields | First and last name only | Every page |
| Employer and occupation | Shown and required | **Federal campaigns only** (or a state that requires it). Off otherwise |
| Other fields | Email and address required, phone optional | Every page |
| Limits | $1 to $25,000 | Every page |
| Fund | Active fund named like "General", else the first active fund | Every page |
| Payments | Card, Apple Pay, Google Pay, bank. PayPal, bitcoin, fee cover off | Every page |
| Title, receipt sender | "Support {displayName}", `displayName` | Every page |
| Slug | Kebab-case title. On a slug conflict, a short suffix is added | Every page |

The giving defaults (amounts, no preselect, one-time and monthly) apply to every user's pages unless the user explicitly asks for something else. Employer and occupation depend on the org: federal means `category: "political"` with `subCategory: "federal"`, or the user says it is a federal candidate, committee, or PAC. That is a legal requirement, so keep it even when unasked.

## Keys

Amount config (`POST /org/v3/action_page_amount_configurations`):

```json
{"name":"<title> - amounts <suffix>","default":false,
 "amountPresets":{"default":[{"amount":2500,"featured":false,"description":null},{"amount":5000,"featured":false,"description":null},
   {"amount":10000,"featured":false,"description":null},{"amount":25000,"featured":false,"description":null},
   {"amount":50000,"featured":false,"description":null},{"amount":100000,"featured":false,"description":null}]},
 "amountPresetsOther":true,"recurringOptions":["once","monthly"],"recurringDefaultFrequency":"once",
 "displayFrequencyAsCheckbox":false,"transactionMinimum":100,"transactionMaximum":2500000}
```

- Amounts are cents. Do not add `"default": true` to a preset; that preselects it. `featured: true` adds a "Popular" highlight.
- `recurringOptions` also accepts `quarterly`, `semiannually`, `yearly`.

Field config (`POST /org/v3/action_page_field_configurations`; unspecified keys get platform defaults):

| Field | Keys |
|---|---|
| Name, first and last only | `displayName: true`, `requireName: true`, `includeMiddleName: false`, `includeSuffix: false`, `includeTitle: false`, `requireTitle: false`, `includeOrganization: false` |
| Email, address, phone | `displayEmail`, `requireEmail`, `displayAddress`, `requireAddress`, `displayPhone`, `requirePhone` |
| Employer and occupation | `displayEmployment`, `includeEmployerName`, `requireEmployerName`, `includeOccupation`, `requireOccupation` (all `true` for federal, all `false` otherwise) |

Also send `"type":"ActionPageFieldConfigurations::Donation"`. Every config body needs a `name` that is unique in the account, plus `"default": false`.

Other configs: see `create_page` in `scripts/anedot.sh` for the exact `payment`, `general`, `confirmation`, `fund`, and `design` bodies.

Page (`POST /org/v3/action_pages`): `type: "DonationActionPage"`, `name`, `slug`, `headerTitleText`, `content`, the seven `*ConfigurationId` keys, and two keys that are required even for a live page: `pausedMessage` and `backgroundImagePosition` (`cover` or `center`). On any `422`, read `errors[].attribute`, fix it, retry.

## Activate and verify

- `PATCH /org/v3/action_pages/{id}/activate` returns 204.
- Fetch `https://secure.anedot.com/{account slug}/{page slug}` with a browser `User-Agent` (curl's default gets 403). Live means the HTML contains `<form`. A paused page also returns 200 and has no form. The `pausedMessage` text is in the page data either way, so do not test for it.
- A draft (`--draft`) has a pause window and gets no link until activated.

## Images

- The checkout renders uploaded images by id: `headerImageId` on the page, `logoImageId` on the design config. List them with `GET /org/v3/account_images?account_id=...` (each has `id` and `file.url`).
- `headerImageUrl` is stored but not shown by the current checkout. Do not rely on it.
- A PAT cannot upload (`POST /org/v3/account_images` returns 403). For a new image, prepare it (header about 2400x1000, under 1 MB), host it at a public HTTPS image URL or hand the file to the user, and ask them to upload it once in the Anedot dashboard. Then set the id.
- With no `logoImageId`, the page shows the account's logo.

## Design colors

PATCH `/org/v3/action_page_design_configurations/{id}` with only what changes: `backgroundColor`, `headerBackgroundColor`, `footerBackgroundColor`, `titleColor`, `headerColor`, `footerColor`, `bodyColor`, `captionColor`, `headline1Color`..`headline6Color`, `actionElementColorPrimary` (button), `actionElementColorSecondary` (button text). The form sits on a white card, so keep `bodyColor`, `captionColor`, and headline colors dark even on a dark page background. Check 4.5:1 contrast.

## Edits

`PATCH /org/v3/action_pages/{id}` for page fields. PATCH the matching config for amounts, fields, or design. A config can be shared (`actionPageCount` > 1); if so, create a new one and point the page at it. Re-verify the public page after edits.
