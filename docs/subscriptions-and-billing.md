# Abonnements et facturation MedLink DZ

## Plans catalogue
- `manual`: 2 500 DZD / mois
- `ai`: 5 000 DZD / mois
- `premium`: 8 000 DZD / mois

The database catalogue (`subscription_plans`) is authoritative for price and feature entitlements. The UI must never decide a user's plan from local state.

## Lifecycle
- A doctor submits a plan request through `POST /api/professional/subscriptions`.
- The database function creates a `pending` subscription and a matching invoice atomically.
- Pending subscriptions grant no features.
- A verified payment provider webhook must validate its signature and amount, then invoke the private `confirm_doctor_subscription_payment` function using a server-only service-role client. Never expose this function through a public route or browser.
- Payment confirmation marks the invoice paid, records a unique provider reference, cancels the previous active plan and activates the pending plan.
- Cancellation is scheduled at period end. The hourly cron job changes expired active subscriptions to `past_due` or `cancelled` when cancellation was requested.
- A doctor can request a renewal after expiry or a plan change while an existing plan remains active. The old plan remains effective until the new payment is confirmed.

## Payment provider integration contract
The webhook adapter must:
1. Verify provider signature/authenticity before trusting the payload.
2. Resolve the subscription and invoice server-side; never trust amount, currency, doctor ID or plan code from a browser request.
3. Confirm exact amount and currency (DZD), successful/settled state and unique provider reference.
4. Call the private confirmation function once; retries are safe for the same confirmed reference.
5. Persist only necessary provider metadata; avoid storing card or sensitive payment credentials.
6. Return 2xx only after the database transaction succeeds.

No online payment provider is configured yet. The app intentionally records pending requests and invoices without activating paid access.

## Security
- RLS is enabled on all four billing tables.
- Doctors can read only their own subscription, invoice and payment rows.
- Authenticated users cannot directly insert/update/delete billing state.
- Plan request/cancellation use narrow authenticated database functions. Their privileged implementations live in the non-exposed `private` schema.
- Payment activation is callable only by `service_role`; webhook signature validation remains mandatory.
- Feature access is checked server-side against an active subscription whose period has not expired.

## Operational notes
- Renewal is currently user-initiated; there is no automatic recurring charge.
- Invoices are billing records, not yet downloadable tax-compliant PDF invoices.
- The current cancellation flow schedules cancellation at the period end; it does not refund or immediately terminate paid time.
- A real provider integration, reconciliation process, PDF invoice renderer and finance/legal review are required before commercial launch.
