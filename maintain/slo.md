# Service level objectives

<!-- One row per user journey that matters. An SLO is a promise about what users experience, a
     target below 100%, and the error budget is the gap: how much failure you can afford before
     reliability work takes priority over new features. -->

| Service / journey | SLI (what we measure) | Target | Window | Error budget | Data source (CSV of timestamp,good,total) |
|-------------------|------------------------|--------|--------|--------------|-------------------------------------------|
| Example: submit contact form | Requests that return 2xx in under 1s / all requests | 99.5% | 28 days | 0.5% (about 3.4 hours) | exports/contact-form.csv |

## Error budget policy
- **Budget healthy (over 50% left):** ship as normal.
- **Budget at risk (under 50%):** prefer reliability fixes; risky releases need the service owner's OK.
- **Budget spent:** stop feature releases for this journey until the budget recovers, except fixes.
- Every burn alert at tier 2 or 3 creates a work item (maintain/detect.py does this).
- Every incident that spends more than 20% of the budget gets a blameless incident review
  (`.sdlc/templates/incident-review.md`).

## Checking
    python3 maintain/detect.py --metric contact-form --slo 99.5 --file exports/contact-form.csv
