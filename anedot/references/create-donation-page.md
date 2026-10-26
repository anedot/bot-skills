# Create a donation page

Goal: one request in, one live public link out. Build the seven configs, create the page, activate it, confirm it loads.

Before you design, read `references/page-design.md` and apply it. Its numbers and its never-invent rule matter; the amount figures in it are examples, so use the org's real giving data when you have it. One exception: that doc says not to collect employer; for federal (FEC) campaign pages, employer and occupation ARE required by law (see Compliance below), and that requirement wins.

## Defaults

Use these unless the user says otherwise. Do not ask about them.

| Setting | Default |
|---|---|
| Amounts | $25, $50 (preselected), $100, $250, plus a custom amount |
| Frequency | One-time and monthly, one-time preselected |
| Limits | $1 minimum, $25,000 maximum |
| Fund | The account's active fund named like "General", else the first active fund |
| Payments | Card, Apple Pay, Google Pay, bank debit. PayPal and bitcoin off. Fee cover off |
| Name fields | First name and last name ONLY. Turn off middle name/initial, prefix, suffix, and any other name field |
| Other fields | Email and address required. Phone shown, optional |
| FEC compliance | If the page is for a federal (FEC-regulated) campaign, employer and occupation are REQUIRED. See Compliance |
| Title | "Support {account name}" |
| Body | One short paragraph inviting a one-time or monthly gift |
| Slug | Kebab-case of the title. If create fails on the slug, add a short suffix and retry (exact error not yet observed) |
| Live | Yes, activate at the end. Leave it paused only if the user says "draft" |

## Compliance (federal campaigns)

Federal campaigns are regulated by the FEC. If the page is for a federal candidate or committee (House, Senate, presidential, or a federal PAC), U.S. law requires collecting each donor's **employer** and **occupation**. So for any FEC/federal campaign page:

- Set the **employer** and **occupation** fields to shown AND required in the field config.
- Keep them even if the user doesn't mention compliance; it's a legal requirement, not a preference.

Decide "is this federal?" from what the user says (e.g. "for my congressional race", "Senate campaign", "federal PAC") or ask one quick question only if it's genuinely unclear. For non-federal pages (state/local campaigns, nonprofits, churches, general fundraising), leave employer and occupation OFF by default unless the user asks for them.

## Steps

`$ACCT` is the account `id`. Write each JSON body to a file and send it with `scripts/anedot.sh`. Keep each returned `id`.

1. **Account.** `GET /org/v3/accounts/$ACCT`. Keep `slug` and `name`.
2. **Fund.** `GET /org/v3/action_pages_funds?account_id=$ACCT`. Pick the fund per the defaults.
3. **Configs.** `POST /org/v3/action_page_{type}_configurations?account_id=$ACCT` for each type. Every body takes `"name"` and `"default": false`.
   - `amount`:
     ```json
     {"name":"<title> - amounts","default":false,
      "amountPresets":{"default":[{"amount":2500,"id":"p25"},{"amount":5000,"default":true,"id":"p50"},{"amount":10000,"id":"p100"},{"amount":25000,"id":"p250"}]},
      "amountPresetsOther":true,"recurringOptions":["once","monthly"],"recurringDefaultFrequency":"once",
      "displayFrequencyAsCheckbox":false,"transactionMinimum":100,"transactionMaximum":2500000}
     ```
   - `fund`: `{"name":"...","default":false,"multiFundExpanded":true,"multiFundModifiable":false,"fundSelectionsAttributes":[{"fundId":"<fund id>","percentage":100,"position":0,"shown":true}]}`
   - `payment`: `{"name":"...","default":false,"creditCardEnabled":true,"applepayEnabled":true,"googlepayEnabled":true,"anedotEnabled":true,"personalDirectDebitEnabled":true,"businessDirectDebitEnabled":true,"paypalEnabled":false,"bitcoinOpenNodeEnabled":false,"feeCoverType":"disabled"}`
   - `general`: `{"name":"...","default":false,"acceptsDonationsForAllPurchaseTypes":true,"externalRaisedAmount":0}`
   - `confirmation`: `{"name":"...","default":false,"emailFromName":"<account name>","subjectLine":"Donation Receipt","content":[{"type":"text","content":{"text":"<p>Thank you for your donation, {{first_name}}!</p>","hasSecondColumn":null,"secondColumnText":null}}]}`
   - `field`: start from `GET` of an existing page's field config and drop `id`, `accountId`, timestamps, and counts. Set `"type":"ActionPageFieldConfigurations::Donation"`. Then apply the name-field and compliance defaults:
     - Show **first name** and **last name** only. Turn OFF middle name/initial, prefix (Mr./Mrs.), suffix, and any other name field.
     - Email and address shown/required; phone shown/optional.
     - If this is a federal (FEC) campaign page, set **employer** and **occupation** to shown AND required. Otherwise leave them off.
   - `design`: same approach, from an existing design config. Then set colors (see Design below).

   Cloning from an existing page keeps the account's own conventions. Find one with `GET /org/v3/action_pages?account_id=$ACCT&per_page=1` and read its `*ConfigurationId` fields.
4. **Page.** `POST /org/v3/action_pages?account_id=$ACCT`:
   ```json
   {"type":"DonationActionPage","name":"<title>","slug":"<slug>",
    "headerTitleText":"<title>","headerTitleAlignment":"center",
    "formAlignment":"center","formLayout":"standard","formStyle":"one_column",
    "goal":0,"footerShowAccountName":true,"showShareButtons":true,"recoveryEnabled":true,
    "metaPageTitle":"<title>","metaPageDescription":"<one line>",
    "content":[{"type":"text","content":{"text":"<h2><title></h2><p><body></p>","hasSecondColumn":null,"secondColumnText":null}}],
    "headerImagePosition":"center",
    "amountConfigurationId":"...","confirmationConfigurationId":"...","designConfigurationId":"...",
    "fieldConfigurationId":"...","fundConfigurationId":"...","generalConfigurationId":"...","paymentConfigurationId":"..."}
   ```
   For a draft, add `"pausedMessage"`, `"pauseStartAt"` (now, UTC) and `"pauseEndAt"` (far future).
5. **Header image** (optional). PATCH it on after create; see Header image below.
6. **Activate.** `PATCH /org/v3/action_pages/{page id}/activate?account_id=$ACCT`. Expect 204.
7. **Verify.** `GET` the page and check `status` is `active`. Fetch `https://secure.anedot.com/{account slug}/{page slug}` and expect 200.
8. **Reply** with the link, then one line on amounts, frequency, and anything you defaulted. If it's a federal page, confirm employer and occupation are required.

## Design

Follow `references/page-design.md` for layout, color, contrast (WCAG 2.2 AA), type, imagery, amounts, and copy. Then set the colors in the config:

PATCH `/org/v3/action_page_design_configurations/{design id}?account_id=$ACCT` with only the keys you change:

- Page: `backgroundColor`, `headerBackgroundColor`, `footerBackgroundColor`
- Text: `titleColor`, `headerColor`, `footerColor`, `bodyColor`, `captionColor`, `headline1Color` through `headline6Color`
- Buttons: `actionElementColorPrimary`, `actionElementColorSecondary`

Turn a named palette ("navy and gold", "match my site") into hex values. Keep body text dark on light backgrounds, or light on dark, for contrast.

## Header image

- `PATCH /org/v3/action_pages/{id}` with `{"headerImageUrl":"<url>","headerImagePosition":"center"}`.
- The URL must be public and stable. If you generate an image, host it somewhere public first.
- A PAT cannot upload, so `headerImageId` and the logo are out of reach. Tell the user the logo is a one-time dashboard upload.

## Edits after launch

`PATCH /org/v3/action_pages/{id}` for page fields (title, content, header image, slug). PATCH the matching config for amounts, funds, payments, or fields (verified for design configs only; others follow the same route pattern). Confirm the public page after each change.
