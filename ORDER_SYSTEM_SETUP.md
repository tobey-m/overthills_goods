# OVERTHILL / Order Management — staging
This branch intentionally does **not** open sales. The public home page remains the existing DROP 01 shortlist.

## Current flow audit
- Public home `/`: two conceptual products (Road / Trail), provisional Black/White sizes S–XL, indicative THB 590.
- Cart is stored only in browser localStorage and copied to Instagram DM; **not a purchase**.
- No customer records, payments, shipping, or transactional email service existed in the inspected code.

## Implemented in this branch
- `/admin/`: owner email/password login, RLS-restricted order list, search/filter, compact order rows with expanded detail, payment/fulfillment updates, manual Instagram order creation, courier/tracking entry, manual/etrackings preference, and mailto draft.
- `/checkout/`: customer form reading existing shortlist, with a **hard-disabled launch flag**.
- `supabase/overthill_orders.sql`: namespaced database tables, owner-only RLS, checkout RPC that calculates product price on server. Database migration is NOT automatically deployed.

## Before enabling checkout
1. Confirm final products, stock, size/color variants, selling price, shipping fees, returns, payment instructions, and customer privacy notice.
2. Add abuse prevention (rate limiting / CAPTCHA or server-side verification) to the public order endpoint before granting anonymous checkout. Anonymous RPC alone can be spammed.
3. In existing Supabase project, review and execute SQL, then create owner in Supabase Auth and insert the owner's user UUID in `ovth_owners`. Do not enable public signups for owner access. Use an isolated namespace; existing Wealth/ourbills tables are not changed.
4. Verify order creation, RLS (anon cannot read orders; non-owner authenticated cannot read/update), and owner updates on desktop and mobile.
5. Only then change `CHECKOUT_ENABLED` in checkout page and add an explicit Checkout link on home page. Current public home must retain its no-order wording until then.

## Planned integrations (NOT implemented)
- ETrackings: needs a registered account, documented API endpoint, and server-side secret. Never place its key in browser JS. Until verified, tracking mode is a preference only; no API calls.
- Automatic email: needs verified sender domain / email provider and secure server-side delivery, templates, idempotency and delivery logs. Currently owner can open a prefilled email draft using `mailto:` only.
- Receipt upload, payment verification, delivery webhook/polling, stock reservations, and customer order tracking are not yet connected.
- Shipment completion is manual; never automatically mark delivered without verified carrier data.

## Costs
Existing Vercel and Supabase free tiers may be sufficient at small scale, subject to usage limits. ETrackings and email quotas/eligibility must be checked before enabling integrations.

## Privacy/security
Never expose service-role, email provider, or ETrackings secrets in client code. Only Supabase publishable key is public. Collect only necessary customer data, keep owner-only access enforced by RLS, and publish privacy/retention information before launch.
