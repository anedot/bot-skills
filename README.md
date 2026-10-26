# Anedot bot skills

Open-source skills that let an AI assistant run your [Anedot](https://anedot.com) account from plain requests, spoken or typed:

- "Make me a donation page for the fall drive, $25 to $250, monthly too." → a live page link
- "Who gave over $100 this month?"
- "How much did we raise in Q3, by fund?"
- "Who are my lapsed donors?"

Each skill talks to the Anedot v3 API with **your own Anedot personal access token**. Nothing about any one organization is built in.

## Skills

| Skill | What it does |
|---|---|
| [`anedot/`](anedot/) | Create and launch donation pages, look up donations, report account stats, and run donor reports such as lapsed donors. |

More skills may be added as folders next to `anedot/`.

## What's inside `anedot/`

```
anedot/
  SKILL.md                            entry point: when to use it and how to route a request
  references/api.md                   auth, retries, endpoints, known limits
  references/create-donation-page.md  build, launch, and verify a donation page
  references/page-design.md           design principles for donation pages
  references/lookup-donations.md      find donations by donor, date, amount, page, or status
  references/account-stats.md         totals, counts, averages, by fund, page, or period
  references/lapsed-donor-report.md   donors who gave before but not recently
  scripts/anedot.sh                   curl helper: auth, retries, pagination, account lookup
```

## Install

1. Add the skill to your assistant. Either point it at this repo and the `anedot/` folder, or copy the `anedot/` folder into your assistant's skills directory. If your assistant reads skills from a repo, track the `main` branch to pick up improvements. The entry point is [`anedot/SKILL.md`](anedot/SKILL.md) ([raw](https://raw.githubusercontent.com/anedot/bot-skills/main/anedot/SKILL.md)).
2. Create a personal access token in your Anedot dashboard. You need your own token; this repo does not include one.
3. Store the token as a secret in your assistant's vault or secret store. Do not paste it into chat or commit it to a file.
4. Make it available to the helper script as either:
   - `ANEDOT_TOKEN`, an environment variable, or
   - `ANEDOT_TOKEN_CMD`, a command that prints the token, for example `op read "op://<vault>/<item>/credential"`.
5. Ask your assistant something like "list my Anedot accounts" to check the connection. On first run the skill checks the token, lists your accounts by display name and slug (never the legal name), reads the org type (federal accounts need employer and occupation on donation pages), and offers a first task. From a shell, `anedot/scripts/anedot.sh ACCOUNTS` does the same lookup.

Requirements: `bash`, `curl`, and `jq`. If your copy lost the executable bit, run `chmod +x anedot/scripts/anedot.sh`.

## Known limits

- Personal access tokens cannot upload images. Upload header images and your logo once in the Anedot dashboard; the skill then uses them by id.
- Refunds, voids, and other donation edits are not available to a personal access token.
- Some filters and endpoints are marked **Unverified** in [`anedot/references/api.md`](anedot/references/api.md). Help confirm them.

## Contributing

Improvements are welcome by pull request.

1. Fork, branch, edit.
2. Verify any API claim against a real account before marking it verified. Mark anything you could not test as **Unverified**.
3. Never commit tokens, account ids, donor data, or anything specific to your organization.
4. Keep each `SKILL.md` short. Put detail in its `references/` folder.
5. Open a pull request describing what you changed and how you tested it.

## License

[MIT](LICENSE)
