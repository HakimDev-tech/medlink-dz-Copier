# Professional operations

This feature set extends the doctor workspace with scheduling, clinic team administration, home-visit workflow visibility, and refund review.

## Doctor availability

Routes:
- `/[locale]/professional/availability`
- `/[locale]/professional` (dashboard links)

Doctors configure recurring weekly windows, slot duration (15/20/30/45/60 minutes), validity dates, and date exceptions (closed days or exceptional opening hours).

Patient booking uses `get_medlink_available_slots(doctor_id, date)`. The function returns only future, unoccupied slots for verified doctors and does not expose patient identities. The database trigger independently validates every requested/confirmed appointment against the active schedule, checks slot alignment and rejects overlaps. A per-doctor advisory transaction lock serializes competing bookings.

All scheduling is interpreted in `Africa/Algiers`. The public slot query is limited to the next 90 days. Doctors must configure at least one weekly rule before accepting normal appointment requests; date exceptions can override a configured day.

## Clinics and membership

Route: `/[locale]/professional/clinic`.

A doctor or clinic-admin account can create a clinic. Newly created clinics start with `verification_status='pending'`; creation does not imply external regulatory verification.

Clinic membership roles use the existing database contract:
- `owner`
- `manager`
- `receptionist`
- `doctor`

Only owners/managers can issue invitations. The invitation token is random, stored as a SHA-256 hash, expires after seven days, and can be accepted only by a signed-in account whose email matches the invitation. The invited account role must match the requested membership category. Membership writes are performed by guarded database functions; clients cannot directly assign themselves clinic roles.

The UI displays the invitation link once so the clinic manager can copy and send it. **Automatic invitation email delivery is not wired yet.**

## Home visits

The existing patient request and doctor response workflow remains the source of truth:
- patient creates a request for a verified doctor;
- assigned doctor accepts or rejects;
- accepted visit can be marked completed;
- the database validates allowed transitions and emits internal notifications.

This work does not claim real-time dispatch, GPS tracking, payment collection, or emergency response.

## Refund management

Routes:
- `/[locale]/professional/refunds`: doctors can view requests associated with their appointments.
- `/[locale]/admin/refunds`: platform administrators can review and update requests.

Allowed state transitions:
- `requested → under_review | rejected`
- `under_review → approved | rejected`
- `approved → processing | failed`
- `processing → refunded | failed`

Every transition is checked by a database trigger and restricted to platform administrators. Internal review notes live in `refund_admin_notes`, a separate RLS-protected table; they are not exposed through the patient/doctor refund records.

The current workflow records administrative decisions. It does **not** initiate a bank/card transfer or payment-provider refund: no appointment-payment provider is currently integrated. The final `refunded` state must therefore be set only after an administrator confirms the refund through the actual payment channel.

## Security and operational boundaries

- RLS is enabled for new tables.
- Clinic membership writes are limited to database RPCs and invitation acceptance.
- Clinic RLS helper is SECURITY DEFINER in the non-exposed `private` schema and granted only for policy evaluation by authenticated sessions.
- Public availability RPC returns only bookable time slots, never appointment or patient details.
- Refund internal notes are separated from user-visible refund data.
- Provider/API credentials are not needed for these workflows.

## Verification checklist before public launch

1. Create a synthetic doctor account, verify it, and configure weekly hours.
2. Confirm that the patient booking UI only displays returned slots.
3. Submit two concurrent requests for one slot and confirm only one succeeds.
4. Test closed-day and exceptional-opening overrides.
5. Create a clinic, invite a test account, accept once, then test expired, wrong-email and reused tokens.
6. Verify clinic manager cannot promote themselves or another user to owner.
7. Test every refund state transition with an administrator and attempt the same update as a doctor/patient.
8. Verify doctors and patients cannot read `refund_admin_notes`.
9. Test home-visit requested → accepted/rejected → completed transitions.
10. Run the complete FR/EN/AR browser pass at desktop and mobile widths.
