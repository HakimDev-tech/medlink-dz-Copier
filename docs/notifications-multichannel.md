# Multichannel notifications

## Architecture

MedLink keeps the in-app notification as the canonical record. An insert into `public.notifications` creates independent delivery jobs for each external channel explicitly enabled by that user: email, SMS, and WhatsApp.

The database queue is processed by the Supabase Edge Function `medlink-notification-dispatch`, invoked every minute by Supabase Cron through `pg_net`. Queue claiming uses `FOR UPDATE SKIP LOCKED`; jobs are idempotent per notification/channel. A provider failure does not affect the in-app notification or another channel.

## Provider configuration

Set these values in **Supabase Dashboard → Edge Functions → Secrets**. Never put provider credentials in browser variables or commit them.

| Secret | Purpose |
|---|---|
| `RESEND_API_KEY` | Resend API key |
| `MEDLINK_EMAIL_FROM` | Verified sender, e.g. `MedLink DZ <notifications@your-domain>` |
| `TWILIO_ACCOUNT_SID` | Twilio account |
| `TWILIO_AUTH_TOKEN` | Twilio secret |
| `TWILIO_SMS_FROM` | Active Twilio SMS sender |
| `WHATSAPP_ACCESS_TOKEN` | WhatsApp Cloud API token |
| `WHATSAPP_PHONE_NUMBER_ID` | WhatsApp Business phone-number ID |
| `WHATSAPP_TEMPLATE_NAME` | Approved, parameter-free notification template name |
| `WHATSAPP_GRAPH_VERSION` | Supported Graph API version |
| `MEDLINK_APP_URL` | Canonical public MedLink URL |

A channel remains unavailable in the preference UI until its required secrets exist. For WhatsApp, the configured template must be approved for the `fr`, `en_US`, and `ar` language variants. The dispatcher sends a template message, not unrestricted free-form content.

Resend requires a verified sender domain/address. Twilio requires an enabled sender and destination-country coverage. Confirm delivery permissions and pricing for Algeria with the chosen provider before enabling production traffic.

## User consent and verification

External channels are opt-in and disabled by default. The preferences endpoint calls the authenticated `set_notification_preferences` RPC. The database verifies that the email/phone belongs to the authenticated account and is verified by Supabase Auth. Phone delivery additionally requires the profile phone to match the verified E.164 phone number.

Disabling a channel cancels pending jobs. The worker checks current consent immediately before sending, so a claimed job is not sent after withdrawal when the worker observes the change.

## Privacy

External messages contain generic event text and a link to the authenticated MedLink patient space. They never include a diagnosis, medication, dosage, consultation summary, patient instruction, or event label. Providers receive only the destination and generic message.

## Delivery lifecycle

- Maximum 5 attempts.
- Retry delays: 1 minute, 5 minutes, 15 minutes, and 1 hour; the fifth failure is terminal.
- A processing lease older than 5 minutes can be reclaimed after a worker crash.
- Each attempt is recorded in `notification_delivery_logs`; the latest state is visible to the owner through `notification_delivery_jobs`.
- Provider message IDs are retained for reconciliation. Provider response bodies and medical content are not stored.

The delivery guarantee is **at-least-once**, not exactly-once: a provider may accept a request just before a network timeout. Resend receives an idempotency key; other providers may not offer equivalent deduplication for every API operation.

## Operational checks

1. Confirm Supabase Cron job `medlink-multichannel-delivery` is active.
2. Confirm the Edge Function `medlink-notification-dispatch` is active.
3. Configure provider secrets and verify the channel availability endpoint.
4. Enable one channel on a verified test account.
5. Create a synthetic notification and inspect `notification_delivery_jobs`, `notification_delivery_logs`, and the provider dashboard.
6. Test provider rejection, timeout, retry, opt-out during processing, and unverified destination.
7. Use synthetic recipients until privacy/legal review and provider agreements are complete.
