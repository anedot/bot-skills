# Look up donations

`GET /org/v3/donations?account_id=$ACCT` plus filters. Use `scripts/anedot.sh ALL` when you need every match.

## Map the request to filters

| User says | Query |
|---|---|
| "recent", "latest", "last few" | `sort=-created_at&per_page=10` |
| "today", "this week", "in September" | `start_date=YYYY-MM-DD&end_date=YYYY-MM-DD` in the user's time zone |
| "from Jane Smith" | `last_name=Smith`, then keep rows whose `firstName` matches |
| "from jane@..." | `email=jane@...` (partial match) |
| "over $100" | `amount_gteq=10000` (cents) |
| "under $20" | `amount_lt=2000` |
| "on the Spring page" | find the page id in `GET /org/v3/action_pages`, then `action_page_ids=<id>` |
| "refunded", "voided" | `status=voided` and similar. Seen values: `completed`, `voided` |

Verified: `sort=-created_at`, `start_date`, `end_date`, `amount_gteq`, `email`, `per_page`, `page`. The rest come from the API implementation; if one seems ignored, fetch the window and filter locally.

## Steps

1. Build the query. Default window when the user gives none: last 30 days.
2. Fetch. For "show me" requests, one page of 10 to 25 is enough. For counts or totals, use `ALL` with `per_page=500`.
3. Check edges. Date-filter boundary behavior is unverified, so drop rows whose `createdAt`, converted to the user's zone, falls outside the window.
4. Reply with a short list: date and time (user's zone), donor name, amount in dollars, page, status. Say how many matched. Offer more only if the list was cut.

## Privacy

Donor emails, phones, and addresses are personal data. Show them only when the user asked for them or needs them to act.
