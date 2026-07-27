# sync-storekit-membership contract

This Edge Function is intentionally not deployed with placeholder Apple credentials.
The iOS client invokes the configured function with an authenticated Supabase JWT and:

```json
{
  "product_id": "com.fumiakiMogi777.poco.member.monthly",
  "original_transaction_id": "1234567890",
  "signed_transaction_info": "eyJ..."
}
```

The production implementation must:

1. Require a non-anonymous authenticated Supabase user.
2. Verify `signed_transaction_info` with Apple's official App Store Server Library and trusted Apple root certificates.
3. Verify Bundle ID, App Apple ID in Production, Environment and the allowed Product ID.
4. Derive the original transaction ID, expiration, revocation and ownership from the verified JWS. Never trust the other request fields as authority.
5. Upsert `public.memberships` with a service-role Supabase client only after verification.
6. Make the operation idempotent on `original_transaction_id` and reject attempts to bind one original transaction to another user.
7. Return 2xx only after the entitlement is durable.

Configure App Store Server Notifications V2 to use the same verification and upsert path so renewals, expiration, refunds and revocations update membership without launching the app. Keep `SUPABASE_SERVICE_ROLE_KEY`, App Store credentials and certificate material in Supabase Function secrets, never in `Config/*.xcconfig`.
