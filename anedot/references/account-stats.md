# Account stats

There is no working summary endpoint (`/org/v3/account_summaries/{id}` returns 404). Compute stats from donation records.

## Steps

1. Window. Default: this month to date and the same span last month for comparison. Accept "this year", "last 90 days", "since launch", and so on.
2. Fetch: `scripts/anedot.sh ALL "/org/v3/donations?account_id=$ACCT&per_page=500&start_date=...&end_date=..."`.
3. Keep `status == "completed"`. Report `voided`, `refunded`, and `declined` counts separately. `start_date` and `end_date` are inclusive and use the account's local day, so a calendar month is `start_date=YYYY-MM-01&end_date=<last day>` with no zone math, as long as the user and the account share a time zone.
4. Compute what was asked. If nothing specific, give gross, count, average, unique donors, and top page.
5. Reply with the window, then the numbers. Dollars to the cent, counts as integers.

## jq patterns

Save the `ALL` output to `d.json`.

```bash
# Gross, net, count, average, unique donors (dollars)
jq '[.[]|select(.status=="completed")] |
  {count: length,
   gross: ((map(.amount)|add // 0)/100),
   net:   ((map(.netAmount)|add // 0)/100),
   fees:  ((map((.anedotFeeAmount // 0)+(.vendorFeeAmount // 0))|add // 0)/100),
   avg:   (if length>0 then (map(.amount)|add)/length/100 else 0 end),
   donors: (map(.email|ascii_downcase? // "")|unique|length)}' d.json

# By fund
jq '[.[]|select(.status=="completed")] | group_by(.fund.name) |
  map({fund: .[0].fund.name, count: length, gross: ((map(.amount)|add)/100)}) | sort_by(-.gross)' d.json

# By page
jq '[.[]|select(.status=="completed")] | group_by(.actionPageName) |
  map({page: .[0].actionPageName, count: length, gross: ((map(.amount)|add)/100)}) | sort_by(-.gross)' d.json

# By month (account-local month from donationDate)
jq '[.[]|select(.status=="completed")] | group_by(.donationDate[0:7]) |
  map({month: .[0].donationDate[0:7], count: length, gross: ((map(.amount)|add)/100)})' d.json

# Recurring versus one-time
jq '[.[]|select(.status=="completed")] | group_by(.actionPagesCommitmentId != null) |
  map({recurring: (.[0].actionPagesCommitmentId != null), count: length, gross: ((map(.amount)|add)/100)})' d.json

# Top donors
jq '[.[]|select(.status=="completed")] | group_by(.email|ascii_downcase? // "") |
  map({donor: "\(.[0].firstName) \(.[0].lastName)", gifts: length, total: ((map(.amount)|add)/100)}) |
  sort_by(-.total) | .[:10]' d.json
```

## Other counts

- Donor profiles on file: `GET /org/v3/account_donors?account_id=$ACCT&per_page=1`, read `meta.totalCount`.
- Pages: `GET /org/v3/action_pages?account_id=$ACCT&per_page=1`, read `meta.totalCount`.

## Caveats

- Donor identity here is lowercased email. Records with no email group together; call that out.
- `amount` is what the donor gave. `netAmount` is after fees.
- Recurring versus one-time: a gift with a non-null `actionPagesCommitmentId` belongs to a recurring commitment. The record has no frequency; read the commitment's `scheduleAttributes` for that.
