# Lapsed donor report

A lapsed donor gave in the lookback window but not in the recent window.

## Default definition

- Lookback: the 12 months before the recent window.
- Recent window: the last 90 days.
- Lapsed: at least one completed gift in the lookback, none in the recent window.

Accept overrides like "haven't given in 6 months" or "gave last year but not this year". State the definition you used in the reply.

## Steps

1. Dates, in the user's zone: `today`, `recent_start = today - 90d`, `lookback_start = recent_start - 12 months`.
2. Fetch everything from `lookback_start` to `today` (both filter dates are inclusive):
   `scripts/anedot.sh ALL "/org/v3/donations?account_id=$ACCT&per_page=500&start_date=$LOOKBACK_START&end_date=$TODAY" > d.json`
3. Compute:
   ```bash
   jq --arg recent "$RECENT_START" '
     [.[]|select(.status=="completed" and (.email // "") != "")]
     | group_by(.email|ascii_downcase)
     | map({email: .[0].email, name: "\(.[0].firstName) \(.[0].lastName)",
            last_gift: (map(.donationDate[0:10])|max), gifts: length,
            total: ((map(.amount)|add)/100),
            last_amount: ((max_by(.donationDate)).amount/100),
            recurring: (map(.actionPagesCommitmentId != null)|any)})
     | map(select(.last_gift < $recent))
     | sort_by(-.total)' d.json > lapsed.json
   ```
   `$RECENT_START` is `YYYY-MM-DD`. `donationDate` is in the account's time zone, the same day boundary the `start_date` and `end_date` filters use, so a string compare on its first 10 characters is exact. Write `d.json` and `lapsed.json` to a temp directory, not into the skill folder: they hold donor personal data.
4. Reply with: the definition, how many lapsed donors, their combined giving in the lookback, and the top 10 by total (name, last gift date, gifts, total). Leave out emails unless asked.
5. Offer a CSV. Write it on request: `jq -r '(.[0]|keys_unsorted), (.[]|[.[]])|@csv' lapsed.json > lapsed.csv`.

## Caveats

- Donors without an email cannot be matched across gifts. Report how many such records were skipped.
- A donor who switched email shows as two people.
- An active monthly donor whose last charge failed can look lapsed. Gifts with a non-null `actionPagesCommitmentId` are recurring (`recurring: true` above). For those donors, check `GET /org/v3/action_pages_commitments?account_id=$ACCT` for an `active` commitment and say so rather than calling them lapsed.
- Count only `completed` gifts. Report `declined`, `voided`, and `refunded` records separately if they matter.
