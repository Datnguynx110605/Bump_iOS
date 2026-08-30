# API Contracts

This document is a frontend-facing contract reference for `Bump_Server`'s HTTP API and its one real-time channel. It describes what a client actually sends and receives — request/response JSON shapes, status codes, and the handful of behaviors that will silently break naive `fetch` code if you don't know about them. It does not cover the server's internal architecture (MediatR, handlers, MongoDB) — see `Bump_Server/doc/api-operation.md` for that.

Everything here was verified against the `Bump_Server` source (`src/api`, `src/app`, `src/domain`, `src/infra`) as of this writing, including two behaviors confirmed by running throwaway ASP.NET Core test hosts rather than assumed from reading code (noted inline where relevant). If server code changes, re-verify rather than trusting this file blindly.

## 0. Read this before writing any fetch code

- **CORS is not configured.** `Bump_Server`'s `AddApi`/`Program.cs` never calls `AddCors`/`UseCors`. A browser-based frontend calling this API from a different origin (a different port counts) will have every request blocked by the browser, not the server — there is no error response to catch. Until the backend adds a CORS policy, a browser client needs a same-origin deployment or a dev-time proxy (e.g. Vite/webpack dev-server proxy, or a reverse proxy in production) in front of the API. This is not something the frontend can work around with request headers.
- **Value objects serialize as wrapper objects, not raw scalars — but only in responses.** Three domain types — `Name`, `Email`, `Amount` — appear throughout response DTOs. Because the API's JSON serializer uses no custom converter for them (confirmed by running the actual `Name`/`Email`/`Amount` classes through `System.Text.Json` with ASP.NET Core's default camelCase policy), each one serializes as `{ "value": <scalar> }`, not as a bare string/number:
  ```jsonc
  // AccountSummaryDto — as actually returned
  {
    "id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
    "name": { "value": "johndoe" },
    "avatar": { "url": "https://cdn.example.com/a.jpg", "createdAt": "2026-08-01T00:00:00Z" },
    "bio": "hello",
    "followerAmount": { "value": 12 },
    "followingAmount": { "value": 4 }
  }
  ```
  Request bodies are the opposite: you send `Name`/`Email`/`Amount` fields as plain scalars (`"name": "johndoe"`, `"rate": 5`) — the server parses them into the value object at the controller boundary. **This asymmetry is real and will break a naive shared TypeScript type between request and response shapes.** Every response example below shows the wrapper explicitly; don't assume a field is a plain string/number just because it looks like one in a request body.
- **All property names are camelCase** (ASP.NET Core's default `System.Text.Json` policy) in both directions — `registrationToken`, `followerAmount`, `nextCursor`, etc.
- **`/api/v1/Email/verify` needs an explicit `Accept: application/json` header, or you will get a bare unquoted string, not JSON.** This endpoint returns a raw `string` (the registration token). Verified empirically: hitting it without an `Accept` header returns `Content-Type: text/plain` with a body like `Xy8fk2...` (no quotes) — `response.json()` will throw a `SyntaxError` on that. Sending `Accept: application/json` gets you `Content-Type: application/json` with the value properly quoted (`"Xy8fk2..."`). **Recommendation: send `Accept: application/json` on every request to this API**, not just this one — it costs nothing and removes this footgun entirely.
- **No endpoint returns `201 Created`.** Successful creates (`POST /api/v1/Account`, `POST /api/v1/Post`, `POST /api/v1/Comment`, `POST /api/v1/Report`) return `200 OK` with the created resource in the body, not `201` with a `Location` header.
- **`202 Accepted` means "queued," not "done."** Six endpoints (follow/unfollow, react/unreact on posts and comments) publish to a queue and return `202` immediately, before the mutation is applied. See §4.

## 1. Base URL, headers, content types

- Local dev: `http://localhost:5294` (or `https://localhost:7191` over HTTPS) — from `Bump_Server/src/api/Properties/launchSettings.json`. No production base URL is committed to the repo; get it from deployment config.
- Send `Accept: application/json` on every request (see §0).
- JSON request bodies: `Content-Type: application/json`.
- File-upload endpoints (`POST /api/v1/Account/me/avatar`, `POST /api/v1/Post`, `POST /api/v1/Comment`) take `multipart/form-data`, **not JSON** — see §5.
- Authenticated requests: `Authorization: Bearer <accessToken>` (JWT). See §2.
- Every response (success or error) echoes an `X-Correlation-ID` header — a value you sent (if 1–64 chars of `[a-zA-Z0-9-]`) or a server-generated GUID otherwise. Useful to attach to bug reports/support requests since it's the same ID the server logs against.
- **`GET /health`** — anonymous, unauthenticated, not rate-limited beyond the global tier. Returns `200` (plain text `Healthy`) if MongoDB, Redis, and RabbitMQ are all reachable, `503` otherwise. Useful for a pre-flight check ("is the backend up") before showing an error state, but it does not tell you anything about R2/email/individual endpoint health.

## 2. Authentication

JWT bearer tokens. The access token is a signed JWT carrying two claims read by both the API and the SignalR hub:

| Claim | Value |
|---|---|
| `accountId` | the caller's account GUID |
| `role` | `"User"` or `"Admin"` |

- **Access token** — short-lived (server-configured expiry, not fixed in the repo). Send it as `Authorization: Bearer <accessToken>` on every authenticated request.
- **Refresh token** — opaque random string, 7-day expiry, single-use: calling `POST /api/v1/Auth/refresh` **revokes the token you sent and issues a new access token + a new refresh token** (rotation, not reuse). Store the new refresh token and discard the old one after every refresh call.
- There is no logout endpoint — "logging out" is a client-side concern (discard both tokens). A revoked/expired refresh token simply fails on next use.

### Endpoints

**`POST /api/v1/Account`** — create account (see §3 for the registration handshake this depends on) — anonymous, rate-limited 10/min/IP
Request:
```json
{ "registrationToken": "string", "name": "johndoe", "password": "string (10-40 chars)", "bio": "string? (max 2000 chars)" }
```
Success `200`:
```json
{
  "id": "guid",
  "email": { "value": "user@example.com" },
  "name": { "value": "johndoe" },
  "avatars": [],
  "bio": "string?",
  "followerAmount": { "value": 0 },
  "followingAmount": { "value": 0 },
  "createdAt": "2026-08-29T00:00:00Z"
}
```

**`POST /api/v1/Auth/login`** — anonymous, rate-limited 10/min/IP
Request: `{ "email": "user@example.com", "password": "string" }`
Success `200`: `{ "accessToken": "jwt", "refreshToken": "opaque-string" }`
Failure: any bad credential (unknown email or wrong password) returns the same message, `"Invalid credentials"` → `401` — the API deliberately doesn't reveal which one was wrong.

**`POST /api/v1/Auth/refresh`** — anonymous, rate-limited 10/min/IP
Request: `{ "refreshToken": "opaque-string" }`
Success `200`: `{ "accessToken": "jwt", "refreshToken": "opaque-string" }` (new pair — see rotation note above)

**`GET /api/v1/Account/me`** — authenticated
Success `200`: `AccountSummaryDto` (id, name, avatar, bio, followerAmount, followingAmount — see §0's example)

`name`/`Name` values are constrained by the server: **lowercase letters and digits only**, no spaces or symbols, ≤ 200 chars (`Name.Create` in `domain`). A name like `"John Doe"` will be rejected — normalize to something like `"johndoe123"` before submitting, or surface the constraint in your signup form directly.

## 3. Registration and email-change (OTP) flow

Both account creation and changing an account's email route through the same three-step OTP → registration-token → consume handshake. This is the mechanism as implemented; read the constraints literally rather than assuming intent.

**Sign-up:**
1. `POST /api/v1/Email/send-for-register` `{ "email": "..." }` (anonymous, 5/min) — sends a 6-digit OTP by email. Fails `"Email already exists"` (`409`) if an account with that email already exists.
2. `POST /api/v1/Email/verify` `{ "email": "...", "otp": "123456" }` (anonymous, 5/min) — verifies the OTP and returns a **registration token** as a bare JSON string (remember §0's `Accept` header note). OTP is exactly 6 digits, expires after 10 minutes, and allows at most 3 wrong attempts before the OTP itself is invalidated server-side (each failed attempt is tracked; on the 3rd wrong guess the OTP can no longer succeed even with the right code — request a new one via step 1). **The OTP is also consumed on a successful verify, not just after 3 failures** — it's read-and-deleted from the server the moment it's checked, correct or not. If your UI retries `/verify` after a network blip (the first call actually succeeded server-side but the client never saw the response), the retry will fail with `"Otp is incorrect"` even though the code was right — treat that specific failure after a possible-duplicate submit as "check whether step 3 already has a usable token" rather than "the user mistyped."
3. `POST /api/v1/Account` with that `registrationToken` (§2) — creates the account. The registration token is single-use and expires after 10 minutes; a missing/expired/already-consumed token fails with `"Unauthenticated"` (classified `401` — see §6's quirk about this wording).

**Change email** (`PUT /api/v1/Account/me/email`, authenticated):
1. `POST /api/v1/Email/send-for-verify` `{ "email": "target@example.com" }` (anonymous, 5/min) — sends an OTP. **Fails `"Email not found"` (`404`) unless `target@example.com` already belongs to some existing, non-deleted account** — this is not a typo; the handler explicitly requires the address to already exist in the system before it will send an OTP to it.
2. `POST /api/v1/Email/verify` `{ "email": "target@example.com", "otp": "..." }` — same as above, returns a registration token.
3. `PUT /api/v1/Account/me/email` `{ "registrationToken": "..." }` (authenticated, no email field — the token alone carries the email) — sets the caller's account email to whatever email the token was issued for. Fails `"New email must be different"` (`409`) if it equals the caller's current email.

Because step 1 requires the target email to already have an account, this flow as it exists today cannot be used to move a user onto a genuinely brand-new address that has never been registered — plan your product UX around that constraint or flag it back to the backend team if it doesn't match intended behavior.

## 4. Response envelope, pagination, and the 202 boundary

### Success shapes

| Server pattern | HTTP status | Body |
|---|---|---|
| `Result<T>` success | `200 OK` | `T`, serialized directly (no `{data: ...}` wrapper) |
| `Result` success (void) | `204 No Content` | empty |
| Queue-publish success | `202 Accepted` | empty |

### Cursor pagination

Every list endpoint takes the same two query parameters and returns the same shape:

- Query: `?cursor=<opaque-string>&pageSize=<int>` — both optional, `pageSize` defaults to `20` if omitted and is **clamped server-side to the range 1-100** (`Math.Clamp`, confirmed in `CursorPaginator`/`EmbeddedArrayPaginator`, which every list endpoint routes through) — asking for `pageSize=500` silently gets you 100 items back, not an error; asking for `0` or a negative number silently gets you 1.
- Default order is always **newest first** (descending `createdAt`, tiebroken by descending `id`) — there is no `sort`/`order` query parameter on any endpoint to change this.
- Response:
  ```json
  {
    "items": [ /* array of the endpoint's DTO */ ],
    "nextCursor": "opaque-string-or-null",
    "hasMore": true
  }
  ```
- To fetch the next page, pass `nextCursor` back as `cursor` on the next request. `nextCursor: null` / `hasMore: false` means you've reached the end. Treat the cursor as opaque — do not parse or construct it client-side.

### The `202 Accepted` boundary (follow/unfollow, react/unreact, save/unsave)

`POST/DELETE /api/v1/Follow/{followingId}`, `POST/DELETE /api/v1/Reaction/post/{postId}`, `POST/DELETE /api/v1/Reaction/comment/{commentId}`, `POST/DELETE /api/v1/Save/post/{postId}`, `POST/DELETE /api/v1/Save/shop/{shopId}` don't mutate anything synchronously — they publish a message to a queue and return `202` immediately. The actual follow/reaction/save row is written by a background consumer moments later.

**Consequence: a `202` response tells you the request was accepted for processing, not that it will succeed.** Failures like `"Already following"`, `"Cannot follow yourself"`, `"Not following this account"`, or `"Already reacted to this post"` happen inside that background consumer, *after* your HTTP response has already been sent — they are never returned to the caller. The only thing that fails synchronously (as a normal `4xx`) is a structurally invalid request, e.g. an empty-GUID route segment.

Design around this rather than against it:
- Don't write code that expects a `409` on "already following" — it can't arrive.
- Use optimistic UI (flip the follow/react/save button immediately on `202`) and reconcile with the real state on your next read of that resource (`GET /api/v1/Follow/me/following`, `GET /api/v1/Reaction/post/{postId}`, `GET /api/v1/Save/me/post`, etc.) rather than trusting the mutation call's response.
- There is no webhook/callback for "the queued action failed" — silent no-ops (e.g. double-clicking follow) are invisible by design.
- Same as reactions, no DTO exposes "did I save this" on a list item (`PostSummaryDto`/`ShopSummaryDto` have no `isSaved` field) — a client has to track saved state itself (session-optimistic, or seeded from `GET /api/v1/Save/me/post`/`GET /api/v1/Save/me/shop`).

## 5. File uploads (multipart/form-data)

Three endpoints take files. All three: `Content-Type: multipart/form-data` (not JSON), rate-limited 10/min, and **the server enforces no file size limit and no MIME-type/extension allow-list** — validation is limited to "a file/filename was provided," so any client-side restriction (size, image-only) is your own to enforce for UX; the server will accept whatever you send and store it as-is (Cloudflare R2).

| Endpoint | Fields | Notes |
|---|---|---|
| `POST /api/v1/Account/me/avatar` | `avatar` (single file) | Success `204`. Old avatar isn't deleted from storage by this call (confirmed in `ChangeAvatarHandler` — no delete call) — `avatars` is an append-only history list; `AccountSummaryDto.avatar` is just the most recent entry. To actually delete one from storage, call `DELETE /api/v1/Account/me/avatar?url=<exact avatar url>` — it requires an exact match against an entry already in the account's `avatars` list (`404` `"Avatar not found"` otherwise) and does delete the underlying file. |
| `POST /api/v1/Post` | `shopName`, `shopAddress`, `caption` (optional), `rate` (int), `images` (0+ files) | Success `200` → `PostDto`. `images` field can be repeated for multiple files or omitted entirely. |
| `POST /api/v1/Comment` | `postId` (guid), `content` (optional), `images` (0+ files) | Success `200` → `CommentDto`. |

Example (`fetch`):
```js
const form = new FormData();
form.append("shopName", "Cafe X");
form.append("shopAddress", "123 Main St");
form.append("rate", "5");
for (const file of selectedFiles) form.append("images", file);

await fetch(`${baseUrl}/api/v1/Post`, {
  method: "POST",
  headers: { Authorization: `Bearer ${accessToken}`, Accept: "application/json" },
  body: form // do NOT set Content-Type yourself — let the browser set the multipart boundary
});
```

## 6. Errors

Every non-2xx response (except a `429` rate-limit rejection and a raw ASP.NET Core 404/400 short-circuit — see below) is one of two RFC 7807 `ProblemDetails` shapes, `Content-Type: application/problem+json`.

**Single-error shape** (the normal case — a handler stops at its first failure):
```json
{ "title": "Not Found", "status": 404, "detail": "Post not found" }
```
`type` and `instance` are never present in the body (confirmed empirically — they're omitted, not `null`).

**Multi-error shape** — only when server-side input validation (not a business-rule handler) rejects the request with more than one simultaneous violation. Always `400`, and **every message is folded under one empty-string key**, `errors[""]`, regardless of which field it was about — there is no per-field key to switch on:
```json
{
  "title": "Bad Request",
  "status": 400,
  "errors": { "": ["Name is required", "Password is too short, minimum length is 10 characters"] }
}
```
If you want per-field inline errors in a form, you'll need to pattern-match `detail`/`errors[""]` text against known substrings (see the table below), or ask the backend team for field-tagged errors — the current shape doesn't support it.

### Status code derivation

The server has **no fixed table of error codes** — every failure message is classified by keyword at serialization time (`ResultStatusMapper`, checked in this order, case-insensitive):

| Message contains | Status |
|---|---|
| `"not found"` | `404` |
| `"already"` or `"must be different"` | `409` |
| `"unauthoriz"`, `"unauthentic"`, `"credentials"`, `"revoked"`, or `"token"` | `401` |
| (none of the above) | `400` |

**This means status codes are wording-derived, not semantically curated — two quirks worth knowing before you branch UI logic on a status code:**
- On `POST /api/v1/Auth/refresh`, an **expired** refresh token fails with `"Expired"` → classified `400` (no keyword match), while a **revoked** or **unrecognized** refresh token fails with `"Refresh token has been revoked"` / `"Invalid refresh token"` → `401` (matches `"revoked"`/`"token"`). The same logical failure family ("your refresh token doesn't work, log in again") splits across two status codes — don't rely on `401` alone to detect "refresh token is dead," check the response body text too, or just treat any `4xx` from this endpoint as "re-authenticate."
- A conflicting soft-delete operation (deleting an already-deleted account, recovering a non-deleted one, etc.) fails with `"Operation is invalid"` → `400`, not `409`, even though it's a state conflict.
- A request missing `RegistrationToken`/`RefreshToken` entirely fails validation with a message containing the word `"token"` (`"RegistrationToken is required"` / `"RefreshToken is required"`) → classified `401`, not `400`, even though nothing about the request was actually unauthenticated. If you see a `401` immediately on submitting the registration/refresh form with an empty token field, this is why — it is not an auth problem.

### Known failure messages by category (not exhaustive — new handlers can introduce new wording, but new wording is expected to follow this same vocabulary)

| Category | Example messages | Status |
|---|---|---|
| Resource missing | `"Account not found"`, `"Post not found"`, `"Comment not found"`, `"Shop not found"`, `"Report not found"`, `"Notification not found"`, `"Avatar not found"`, `"RefreshToken not found"`, `"Email not found"` | `404` |
| Duplicate / no-op conflict | `"Email already exists"`, `"Already following"`, `"Already reacted to this post"`, `"New email must be different"`, `"New name must be different"`, `"New password must be different"`, `"New avatar must be different"` | `409` |
| Auth / credentials | `"Invalid credentials"`, `"Invalid refresh token"`, `"Refresh token has been revoked"`, `"Unauthenticated"`, `"Unauthorized"` | `401` |
| Validation / business rule | `"Current password is incorrect"`, `"Otp is incorrect"`, `"Cannot follow yourself"`, `"Cannot unfollow yourself"`, `"Not following this account"`, `"Operation is invalid"`, `"Expired"`, field-length/required messages (e.g. `"Bio is too long, maximum length is 2000 characters"`) | `400` |

### What never produces a `ProblemDetails` body

- **`400`/malformed body**: a request body that fails JSON model binding (e.g. missing required field with the wrong type) is rejected by ASP.NET Core itself before your handler code runs — still `400`, but the body shape is ASP.NET Core's own default `ValidationProblemDetails`-like output, not guaranteed identical to §6's shapes.
- **`404`**: a non-GUID value in a route segment typed as a GUID (e.g. `GET /api/v1/Post/not-a-guid`) doesn't match the route at all → plain ASP.NET Core `404`, no JSON body guaranteed.
- **`401`/`403`**: missing/expired/invalid bearer token → `401`; valid token but wrong role (a non-admin hitting an admin-only endpoint) → `403`. Both are produced by JWT middleware before any handler runs, not by `ResultExtensions`.
- **`429`**: rate limit exceeded (see §7) — still `application/problem+json`, but built directly by the rate limiter, e.g. `{ "status": 429, "title": "Too Many Requests", "detail": "Rate limit exceeded. Please retry later." }`. A `Retry-After` header (seconds) is included when available.
- **`5xx`**: the server has no global exception handler. An unhandled exception is not translated into a documented shape at all — treat any `5xx` as "something broke server-side, no contract on the body."

## 7. Rate limits

All limits are enforced server-side and rejected with `429` (see §6) before your request reaches business logic. `Retry-After` (seconds) is included in the response when available.

| Scope | Limit | Applies to |
|---|---|---|
| Global (every request) | 200/min, per authenticated account or per IP if anonymous | everything |
| `Auth` | 10/min per IP | `POST /api/v1/Account` (create), `POST /api/v1/Auth/login`, `POST /api/v1/Auth/refresh` |
| `Email` | 5/min per IP | all three `EmailController` endpoints |
| `Search` | 20/min, per account or IP | `GET /api/v1/Account/search`, `GET /api/v1/Post/search`, `GET /api/v1/Shop/search` |
| `Upload` | 10/min, per account or IP | `POST /api/v1/Account/me/avatar`, `POST /api/v1/Post`, `POST /api/v1/Comment` |

Design implication: don't call the three `Auth`-tier endpoints or the search/upload endpoints in a tight retry loop — 10-20 requests/minute is easy to exhaust from aggressive client-side retry logic, especially the 5/min `Email` tier during OTP resend flows.

## 8. Access levels

Every endpoint requires a valid bearer token **except** the six explicitly listed below, which are anonymous (this is exactly the pre-login bootstrap sequence — you cannot reach anything else without a token):

- `POST /api/v1/Account` (create account)
- `POST /api/v1/Auth/login`
- `POST /api/v1/Auth/refresh`
- `POST /api/v1/Email/send-for-register`
- `POST /api/v1/Email/send-for-verify`
- `POST /api/v1/Email/verify`

A further set of endpoints require the caller's JWT to carry `role: "Admin"` — an authenticated non-admin gets `403` (not `404`) on these:

- `GET /api/v1/Account` (list all), `GET /api/v1/Account/by-email`
- `GET /api/v1/Auth/refresh-token`, `GET /api/v1/Auth/refresh-token/{id}`
- `GET /api/v1/Report`, `GET /api/v1/Report/{id}`, `GET /api/v1/Report/target`
- `DELETE /api/v1/Shop/{shopId}`

Everything else just needs a valid, non-expired access token — no per-resource ownership check is surfaced differently from a generic auth failure (e.g. editing someone else's post fails the same way a missing post would, per each handler's own logic — check the specific endpoint's failure message if you need to distinguish "not yours" from "doesn't exist").

## 9. Endpoint reference

Every endpoint below is authenticated unless marked **Anonymous**; assume `200`/`204`/`202` per the "Success" column and the §6 error contract otherwise. DTO shapes referenced here are defined in full in §10.

### Account — `api/v1/Account`

| Method + path | Request body / query | Success |
|---|---|---|
| `POST /` — **Anonymous**, `Auth` limit | `{ registrationToken, name, password, bio? }` | `200` `AccountDto` |
| `GET /me` | — | `200` `AccountSummaryDto` |
| `PUT /me/name` | `{ name }` (lowercase+digits, ≤200 chars) | `204` |
| `PUT /me/bio` | `{ bio? }` (≤2000 chars) | `204` |
| `PUT /me/password` | `{ currentPassword, newPassword }` (new: 10-40 chars) | `204` |
| `PUT /me/email` | `{ registrationToken }` — see §3 | `204` |
| `POST /me/avatar` — `Upload` limit | multipart, field `avatar` | `204` |
| `DELETE /me/avatar` | query `?url=<avatarUrl>` | `204` |
| `DELETE /me` | — (soft-delete) | `204` |
| `POST /me/recover` | — (undo soft-delete) | `204` |
| `GET /` — **Admin** | `?cursor&pageSize` | `200` `CursorPageResult<AccountSummaryDto>` |
| `GET /{accountId}` | — | `200` `AccountSummaryDto` |
| `GET /by-email` — **Admin** | `?email=` | `200` `AccountSummaryDto` |
| `GET /by-name` | `?name=&cursor&pageSize` (exact, case-sensitive match on the normalized `Name` — confirmed `Filter.Eq`, not a regex) | `200` `CursorPageResult<AccountSummaryDto>` |
| `GET /search` — `Search` limit | `?keyword=&cursor&pageSize` (case-insensitive substring match) | `200` `CursorPageResult<AccountSummaryDto>` |

### Auth — `api/v1/Auth`

| Method + path | Request | Success |
|---|---|---|
| `POST /login` — **Anonymous**, `Auth` limit | `{ email, password }` | `200` `{ accessToken, refreshToken }` |
| `POST /refresh` — **Anonymous**, `Auth` limit | `{ refreshToken }` | `200` `{ accessToken, refreshToken }` |
| `GET /refresh-token` — **Admin** | `?cursor&pageSize` | `200` `CursorPageResult<RefreshTokenDto>` |
| `GET /refresh-token/{id}` — **Admin** | — | `200` `RefreshTokenDto` |

### Comment — `api/v1/Comment`

| Method + path | Request | Success |
|---|---|---|
| `POST /` — `Upload` limit | multipart: `postId`, `content?`, `images?[]` | `200` `CommentDto` |
| `PUT /{commentId}` | `{ content }` (≤2000 chars) | `204` |
| `DELETE /{commentId}` | — | `204` |
| `GET /{commentId}` | — | `200` `CommentSummaryDto` |
| `GET /post/{postId}` | `?cursor&pageSize` | `200` `CursorPageResult<CommentSummaryDto>` |
| `GET /mine` | `?cursor&pageSize` | `200` `CursorPageResult<CommentSummaryDto>` |

### Email — `api/v1/Email` (all three: **Anonymous**, `Email` limit — see §3 for the flow)

| Method + path | Request | Success |
|---|---|---|
| `POST /send-for-register` | `{ email }` | `204` |
| `POST /send-for-verify` | `{ email }` | `204` |
| `POST /verify` | `{ email, otp }` | `200` bare JSON string (registration token) — **send `Accept: application/json`, see §0** |

### Follow — `api/v1/Follow` (see §4 for the `202` semantics)

| Method + path | Request | Success |
|---|---|---|
| `POST /{followingId}` | — | `202` |
| `DELETE /{followingId}` | — | `202` |
| `GET /follower/{accountId}` | `?cursor&pageSize` | `200` `CursorPageResult<FollowerDto>` |
| `GET /following/{accountId}` | `?cursor&pageSize` | `200` `CursorPageResult<FollowingDto>` |
| `GET /me/follower` | `?cursor&pageSize` | `200` `CursorPageResult<FollowerDto>` |
| `GET /me/following` | `?cursor&pageSize` | `200` `CursorPageResult<FollowingDto>` |

### Notification — `api/v1/Notification`

Read-only — a `Notification` is created internally as a side effect of other actions (follow/react/comment), never through a client-facing endpoint. Real-time delivery is over SignalR (§11), not polling; these two `GET`s are for history/backfill.

| Method + path | Request | Success |
|---|---|---|
| `GET /{notificationId}` | — | `200` `NotificationSummaryDto` |
| `GET /mine` | `?cursor&pageSize` | `200` `CursorPageResult<NotificationSummaryDto>` |

### Post — `api/v1/Post`

| Method + path | Request | Success |
|---|---|---|
| `POST /` — `Upload` limit | multipart: `shopName`, `shopAddress`, `caption?`, `rate` (int ≥0), `images?[]` | `200` `PostDto` |
| `PUT /{postId}/caption` | `{ caption }` | `204` |
| `PUT /{postId}/rate` | `{ rate }` (int ≥0) | `204` |
| `DELETE /{postId}` | — | `204` |
| `GET /{postId}` | — | `200` `PostFeedItemDto` (see §10 — carries the caller's own `isReacted`/`isSaved`) |
| `GET /mine` | `?cursor&pageSize` | `200` `CursorPageResult<PostSummaryDto>` |
| `GET /account/{accountId}` | `?cursor&pageSize` | `200` `CursorPageResult<PostSummaryDto>` |
| `GET /shop/{shopId}` | `?cursor&pageSize` | `200` `CursorPageResult<PostSummaryDto>` |
| `GET /search` — `Search` limit | `?keyword=&cursor&pageSize` | `200` `CursorPageResult<PostFeedItemDto>` |
| `GET /latest` | `?cursor&pageSize` | `200` `CursorPageResult<PostFeedItemDto>` |
| `GET /most-reacted` | `?cursor&pageSize` | `200` `CursorPageResult<PostFeedItemDto>` |

`{postId}`, `search`, `latest`, and `most-reacted` are the endpoints whose results render a heart/bookmark control client-side (post detail, feed, search) — those four return the `PostFeedItemDto` wrapper. `mine`, `account/{accountId}`, and `shop/{shopId}` feed thumbnail grids with no per-item reaction/save affordance, so they're unchanged and still return bare `PostSummaryDto`. `GET /api/v1/Save/me/post` (§9 Save) is unchanged too, for the same reason.

`POST /` creates the `Shop` too, if `shopName`+`shopAddress` don't exactly match an existing one — there is no separate "create shop" endpoint (see §12).

### Reaction — `api/v1/Reaction` (see §4 for the `202` semantics; no "like type" — a reaction is boolean present/absent)

| Method + path | Request | Success |
|---|---|---|
| `POST /post/{postId}` | — | `202` |
| `DELETE /post/{postId}` | — | `202` |
| `POST /comment/{commentId}` | — | `202` |
| `DELETE /comment/{commentId}` | — | `202` |
| `GET /post/{postId}` | `?cursor&pageSize` | `200` `CursorPageResult<ReactionDto>` |
| `GET /comment/{commentId}` | `?cursor&pageSize` | `200` `CursorPageResult<ReactionDto>` |

### Report — `api/v1/Report`

| Method + path | Request | Success |
|---|---|---|
| `POST /` | `{ postId?, commentId?, accountId?, reason }` | `200` `ReportDto` |
| `GET /` — **Admin** | `?cursor&pageSize` | `200` `CursorPageResult<ReportDto>` |
| `GET /{reportId}` — **Admin** | — | `200` `ReportDto` |
| `GET /target` — **Admin** | `?target=Post\|Comment\|Account\|Reporter&targetId=&cursor&pageSize` | `200` `CursorPageResult<ReportDto>` |

`POST /` is open to any authenticated user (reporting isn't admin-only — reviewing reports is). **The server does not enforce that exactly one of `postId`/`commentId`/`accountId` is set** — you can submit all three null, or more than one non-null; only `reason` is required (non-empty). Enforce "pick exactly one target" in your UI, since the API won't reject a malformed combination.

### Save — `api/v1/Save` (see §4 for the `202` semantics)

| Method + path | Request | Success |
|---|---|---|
| `POST /post/{postId}` | — | `202` |
| `DELETE /post/{postId}` | — | `202` |
| `POST /shop/{shopId}` | — | `202` |
| `DELETE /shop/{shopId}` | — | `202` |
| `GET /me/post` | `?cursor&pageSize` | `200` `CursorPageResult<PostSummaryDto>` |
| `GET /me/shop` | `?cursor&pageSize` | `200` `CursorPageResult<ShopSummaryDto>` |

### Shop — `api/v1/Shop`

| Method + path | Request | Success |
|---|---|---|
| `DELETE /{shopId}` — **Admin** | — | `204` |
| `GET /{shopId}` | — | `200` `ShopDetailDto` (see §10 — carries the caller's own `isSaved`) |
| `GET /` | `?cursor&pageSize` | `200` `CursorPageResult<ShopSummaryDto>` |
| `GET /search` — `Search` limit | `?keyword=&cursor&pageSize` | `200` `CursorPageResult<ShopSummaryDto>` |
| `GET /by-name` | `?name=&cursor&pageSize` (exact, case-sensitive match — `Filter.Eq` on the raw string, unlike Account's `by-name` this isn't parsed through a `Name` value object at all) | `200` `CursorPageResult<ShopSummaryDto>` |
| `GET /by-address` | `?address=&cursor&pageSize` (exact, case-sensitive match, same as `by-name`) | `200` `CursorPageResult<ShopSummaryDto>` |
| `GET /most-rated` | `?cursor&pageSize` | `200` `CursorPageResult<ShopSummaryDto>` |

No `POST /api/v1/Shop` — shops only come into existence as a side effect of `POST /api/v1/Post` (§12).

## 10. DTO reference

`Guid` → JSON string. `DateTime` → ISO-8601 string (UTC). Remember §0: `Name`/`Email`/`Amount` fields are `{ "value": <scalar> }` objects, marked below with a †.

```ts
// Shared wrapper shape for Name / Email / Amount fields, marked †
type Wrapped<T> = { value: T };

type AvatarDto = { url: string; createdAt: string };
type ImageDto = { url: string; uploadedAt: string };

type AccountDto = {
  id: string;
  email: Wrapped<string>;      // †
  name: Wrapped<string>;       // †
  avatars: AvatarDto[];        // full history; empty on fresh account
  bio: string | null;
  followerAmount: Wrapped<number>;  // †
  followingAmount: Wrapped<number>; // †
  createdAt: string;
};

type AccountSummaryDto = {
  id: string;
  name: Wrapped<string>;       // †
  avatar: AvatarDto | null;    // most recent avatar only
  bio: string | null;
  followerAmount: Wrapped<number>;  // †
  followingAmount: Wrapped<number>; // †
};

type PostDto = {
  id: string; accountId: string; shopId: string;
  images: ImageDto[];
  caption: string | null;
  rate: Wrapped<number>;            // †  0-based non-negative integer
  reactions: ReactionDto[];         // full list — only on the non-summary DTO
  reactionAmount: Wrapped<number>;  // †
  commentAmount: Wrapped<number>;   // †
  createdAt: string;
};

type PostSummaryDto = Omit<PostDto, "reactions">; // no `reactions` array — fetch via GET /api/v1/Reaction/post/{id}

// Wraps PostSummaryDto with the caller's own state for this post. Computed
// fresh per request from Post.Reactions / Account.SavePosts (both embedded
// arrays) — never cached alongside PostSummaryDto itself, so it's always
// current as of this response, not a snapshot from whenever the post was
// last cached. See GET /{postId}, /search, /latest, /most-reacted above.
type PostFeedItemDto = { post: PostSummaryDto; isReacted: boolean; isSaved: boolean };

type CommentDto = {
  id: string; accountId: string;
  content: string | null;
  images: ImageDto[];
  reactions: ReactionDto[];         // full list — only on the non-summary DTO
  reactionAmount: Wrapped<number>;  // †
  createdAt: string;
};

type CommentSummaryDto = Omit<CommentDto, "reactions">;

type ReactionDto = { accountId: string; name: Wrapped<string>; avatar: AvatarDto | null; reactedAt: string }; // †
type FollowerDto = { accountId: string; name: Wrapped<string>; avatar: AvatarDto | null; followedAt: string }; // †
type FollowingDto = { accountId: string; name: Wrapped<string>; avatar: AvatarDto | null; followedAt: string }; // †

type ShopDto = { id: string; name: string; address: string; rate: Wrapped<number>; createdAt: string }; // † (name/address are plain strings here — Shop has no Name/Email value object, unlike Account)
type ShopSummaryDto = { id: string; name: string; address: string; rate: Wrapped<number> }; // †

// Wraps ShopDto with the caller's own save state, computed fresh per request
// from Account.SaveShops — same reasoning as PostFeedItemDto. See GET /{shopId} above.
type ShopDetailDto = { shop: ShopDto; isSaved: boolean };

type NotificationSummaryDto = {
  id: string; toAccountId: string;
  title: string; content: string;
  isSent: boolean;   // whether it was pushed over SignalR at write time — not a "read" flag
  createdAt: string;
};

type ReportDto = {
  id: string; reporterId: string;
  postId: string | null; commentId: string | null; accountId: string | null;
  reason: string; createdAt: string;
};

type RefreshTokenDto = { id: string; accountId: string; isRevoked: boolean; expiryDate: string; createdAt: string };

type CursorPageResult<T> = { items: T[]; nextCursor: string | null; hasMore: boolean };
```

Note `ShopDto`/`ShopSummaryDto.name`/`.address` are **plain strings**, unlike `AccountDto.name` — `Shop` has no `Name`/`Email` domain value object, so no `{ value }` wrapper applies there. Double-check §0's wrapper rule per-field rather than assuming every "name"-looking field behaves the same way across DTOs.

## 11. Real-time notifications (SignalR)

Hub endpoint: `/hubs/notification` (same base URL as the REST API). `[Authorize]`-protected — the same JWT as REST calls, but since SignalR's WebSocket handshake can't carry a header on every client, pass it as a query parameter instead: `?access_token=<accessToken>` (the server explicitly reads this only on requests under `/hubs`).

```js
const connection = new signalR.HubConnectionBuilder()
  .withUrl(`${baseUrl}/hubs/notification`, { accessTokenFactory: () => accessToken })
  .withAutomaticReconnect()
  .build();

connection.on("ReceiveNotification", (payload) => {
  // payload fields: Id, Title, Content, CreatedAt — plain scalars (this is a plain anonymous
  // object on the server, not a DTO with Name/Email/Amount fields, so no † wrapper here).
  // Casing is expected to be camelCase (SignalR's default JsonHubProtocol policy, same as the
  // REST API) but this was not empirically verified the way the REST responses were — confirm
  // against a live connection before hard-coding a field name.
});

await connection.start();
```

- The server only pushes over `ReceiveNotification` if you're currently connected when the notification is created — there's no queued replay for a disconnected client. On reconnect (or initial load), backfill via `GET /api/v1/Notification/mine`.
- One connection per account is assumed by the online/offline tracking the server uses internally (it counts connections per `accountId`, not per tab/device) — opening multiple tabs is fine (each increments the count), but don't rely on receiving a push in every tab if any one of them shows delivery state to the user.
- Reconnect after any network blip / token refresh — a stale connection stops counting as "online" only after its underlying transport actually drops, which can lag a real disconnect.

## 12. Behaviors worth knowing that aren't obvious from the endpoint list

- **Shops have no create endpoint.** `POST /api/v1/Post` looks up an existing, non-deleted `Shop` by an *exact* `name` + `address` match; if none matches, it silently creates a new one and attaches the post to it. Two posts with slightly different shop address strings (extra whitespace, different capitalization of a street suffix, etc.) will create two separate shops — there's no fuzzy dedup. If your UI lets users free-type a shop address per post, consider an autocomplete against `GET /api/v1/Shop/search` to steer them onto an existing shop rather than fragmenting the shop list.
- **Deletes are soft.** `DELETE` on an account/post/comment/shop sets a deleted flag rather than removing the row; a deleted account can be restored via `POST /api/v1/Account/me/recover`. There's no restore for posts/comments/shops through this API. Deleted resources behave as "not found" (`404`) to reads.
- **`PostSummaryDto`/`CommentSummaryDto` omit the `reactions` list** (only the summary count, `reactionAmount`) — if you need to render who reacted, call `GET /api/v1/Reaction/post/{id}` or `GET /api/v1/Reaction/comment/{id}` separately; only the non-summary `PostDto`/`CommentDto` (returned once, at creation) embed the full list.
- **Search (`?keyword=`) is a case-insensitive substring regex match**, not full-text/tokenized search — `"caf"` matches `"Cafe X"`, but word-order or typo tolerance isn't implemented.
- **`by-name`/`by-address` (Account and Shop) are exact, case-sensitive matches**, not a search — for `Account`, this means the raw name you pass must already satisfy the lowercase+digits constraint, since it's parsed through the same `Name.Create` as everywhere else; for `Shop`, `name`/`address` are passed through as raw strings with no normalization at all, so `"Cafe X"` and `"cafe x"` are different queries.
