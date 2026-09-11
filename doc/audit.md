# Bump_Client — Audit

Scope: `Bump_Client/src/Sources` (9,186 LOC Swift / SwiftUI, iOS 18).
Reference: `Bump_Server/src` (13 controllers, 81 actions) and `Bump_Server/doc`.
Admin-only endpoints are out of scope by request.

## 1. Feature parity with Bump_Server (non-admin)

Every non-admin server endpoint, checked against `Core/Services/*.swift`.

| Controller | Non-admin actions | Covered | Gap |
| --- | --- | --- | --- |
| Account | 14 | 13 | `GET /by-name` |
| Auth | 2 | 2 | — |
| Block | 3 | 3 | — |
| Comment | 6 | 5 | `GET /{commentId}` |
| Email | 3 | 3 | — |
| Follow | 6 | 5 | `GET /me/follower` |
| Notification | 2 | 1 | `GET /{notificationId}` |
| Post | 10 | 10 | — |
| Reaction | 6 | 6 | — |
| Report | 1 | 1 | — |
| Save | 6 | 6 | — |
| Shop | 5 | 3 | `GET /` , `GET /by-name`, `GET /by-address` |

### Gaps that are not gaps

Five of the seven are reachable through an endpoint the client already calls, so
adding a service method for them would be code no screen invokes:

- `Account/by-name` and `Shop/by-name` / `Shop/by-address` — `…/search?keyword=`
  already covers these, with looser matching.
- `Follow/me/follower` — `Follow/follower/{accountId}` called with the viewer's own id
  is the same list; `FollowListView` already does this.
- `Comment/{commentId}` and `Notification/{notificationId}` — single-item fetches for
  deep links that do not exist. Verified against the server: every notification's
  `TargetId` is a **post** id, including `CommentReaction`
  (`infra/queue/reaction/ReactCommentService.cs:104` passes `comment.PostId`), so
  `NotificationType.route(for:)` mapping all three non-follow types to `.post` is correct.

### The one real gap

`GET /api/v1/Shop` — authenticated, any role, cursor-paginated, returns
`ShopSummaryDto` (`api/controller/ShopController.cs:41`). The client never calls it, and
the Search tab's Shops scope shows a dead-end empty card until the user types something.
Wiring it up turns that card into a browsable shop directory using an endpoint that
already ships. **Implemented** — see §4.

### Wire-format checks (all pass)

- `Email` / `Name` / `Amount` are serialized by ASP.NET's default reflection, **not** by
  `infra/serialization/DomainJsonOptions` (that is Redis-only — `RedisService.cs:27`), so
  they cross the wire as `{"value": …}`. The client's `Wrapped<T>` matches.
- Every `api/request/*.cs` field name matches its client `Encodable` counterpart.
- Pagination params are `cursor` / `pageSize` on both sides; response is
  `items` / `nextCursor` / `hasMore`.
- `NotificationType` has no `JsonStringEnumConverter` on either the REST or SignalR
  pipeline, so it is an integer; the client's `enum NotificationType: Int` ordering matches
  `domain/core/enum/NotificationType.cs`.
- Client validation mirrors the server validators: name lowercase-alnum ≤200, password
  10–40, bio/caption/content/reason ≤2000, rate 1–5.

## 2. Bugs and risks

### B1 — Post detail like/save state goes stale after refresh · fixed
`Features/PostDetail/PostDetailView.swift`

`PostHeaderSection` seeds `isLiked`/`isSaved` from `init` parameters, but its
`onChange(of: post)` re-reads only `displayedLikeCount`. `post` is a `PostSummaryDto`,
which carries neither flag, so no change to them can ever be observed. Pull-to-refresh
therefore updates the like *count* while the heart and bookmark keep rendering whatever
they showed on first build. `PostRowView:50` handles the same situation correctly, which
is what makes the two screens disagree.

### B2 — Follow button ignores the follow store after first render · fixed
`Features/Profile/ProfileView.swift`

`isFollowing` was `@State`, assigned once in `.task`. `FollowStore.primeIfNeeded()` runs
concurrently from `RootView` at sign-in, so a profile opened before priming finishes shows
"Follow" for an account the viewer already follows — and never corrects itself, because
nothing reassigns the state. `FollowStore` is `@Observable`; reading it directly makes the
button track priming, optimistic toggles and rollbacks alike.

### B3 — Sign-out leaves the previous account's state in memory · fixed
`Features/Root/RootView.swift`

`followStore` and `blockStore` are reset on sign-out; `reactionStore`, `saveStore`,
`accountCache` are not (`shopCache` holds only public shop rows, so it is left alone). A second account signing in on the same device
inherits the first one's liked-post and saved-post/shop sets. Feed rows re-seed themselves
from `PostFeedItemDto`, which masks it for posts currently in view, but saved *shops* have
no such correction and `SavedView` shows the previous user's bookmarks until a reload lands.

### B4 — OTP fields block iOS AutoFill · fixed
`Onboarding/OtpVerifyView.swift`, `Onboarding/RecoveryOtpVerifyView.swift`,
`Settings/ChangeEmailView.swift`

All three set `.keyboardType(.numberPad)` but none set
`.textContentType(.oneTimeCode)`, so iOS never offers the code above the keyboard and the
user must transcribe six digits by hand. WCAG 2.2 AA *Accessible Authentication* — the
ui-ux-pro-max dataset rates this **Critical**: "Don't block paste or require manual OTP
transcription with no alternative."

### B5 — Over-length caption is only caught after the upload · fixed
`Features/CreatePost/CreatePostViewModel.swift`, `CreatePostView.swift`

`FreeTextRule` (2000 chars, already used by `EditPostSheet` and `EditCommentSheet`) was not
applied on the compose screen. A too-long caption stayed submittable: every photo uploaded,
then the server answered 400 "Caption is too long". Same for shop name and address, which
the server caps at 200 (`CreatePostValidator`).

### B6 — "Log Out" had no confirmation · fixed
`Features/Settings/SettingsView.swift`

The one destructive action in the app without a confirmation step, sitting directly above
"Delete Account", which has one.

### B7 — "Resend code" was not a 44pt target · fixed
`Onboarding/OtpVerifyView.swift`, `Onboarding/RecoveryOtpVerifyView.swift`

A bare `Button` with no `buttonStyle`, so it got neither the app's text-button treatment
nor the guaranteed `BumpHitTarget.min` height every other text button has.

## 3. Observations not acted on

Left alone deliberately — each is either correct as written, or a change wider than this pass.

- **`SearchViewModel.scope` didSet doesn't cancel the pending debounce task.** Switching
  scope mid-type can let the 350ms task land after the scope search. Both write to
  different arrays, so nothing is corrupted; the only symptom is one wasted request.
- **`CreatePostViewModel.isValid` checks `rating >= 0`** while the server requires 1–5.
  Dead guard, not a bug: `RatingPickerView` clamps to `1...maxRating` and the default is 5,
  so 0 is unreachable.
- **`SquareCropView.confirm()` falls back to full-resolution JPEG** when `frameSide == 0`
  (container never laid out). A 48MP source could exceed the server's 5MB cap. Requires the
  crop sheet to render at zero size, which it does not in practice.
- **SignalR's `accessTokenProvider` returns whatever `AuthSession` holds at reconnect time.**
  If the access token expired while backgrounded, auto-reconnect retries with a stale token
  until some REST call refreshes it. Correct fix is a token refresh inside the provider;
  that is a networking change, not a UI one.
- **`FollowStore` / `BlockStore` prime at most 5 pages of 100.** Already marked
  `ponytail:` in-tree with the upgrade path (an `isFollowing` flag on the account payload).
- **`maxCount: 6` photos** against the server's 10. Product decision — the footer copy says
  "Up to 6 photos" — not a parity bug.
- **No unread badge on the Alerts tab.** `Notification` has `IsSent` but no read state, so
  this needs a server field first.
- **Server-side, out of scope:** `CommentController.CreateComment` never calls
  `ImageUpload.Validate`, unlike `PostController.CreatePost`. Comment image uploads skip the
  size, extension and magic-byte checks.

## 4. UI/UX pass

Run through the ui-ux-pro-max pre-delivery checklist (`references/pro-rules.md`) plus
targeted `--domain ux` and `--stack swiftui` queries.

Already in place before this pass, and left untouched: 4pt spacing scale, semantic color
tokens with documented contrast ratios (`brandFill` at 4.9:1 for white-on-fill, `textTertiary`
restricted to decorative glyphs), `BumpHitTarget.min` on every icon control, `@ScaledMetric`
on icon sizes and card widths, a reduce-motion animation wrapper, shared empty/error/hint
components, decorative icons hidden from the accessibility tree, and full `String(localized:)`
coverage across two locales.

Changes made:

1. **Accessible authentication** (B4) — `.textContentType(.oneTimeCode)` on all three OTP
   fields. Critical severity in the dataset; the highest-value item in this pass.
2. **Touch target** (B7) — `.buttonStyle(.bumpText)` on both "Resend code" buttons.
3. **Destructive-action confirmation** (B6) — confirmation dialog on Log Out.
4. **Form feedback** (B5) — live character counter on the caption field and inline hints on
   shop name and address, using the existing `FieldHint` / `FreeTextRule` components, so the
   limit is visible while typing instead of arriving as a server error after the upload.
5. **Empty-state dead end** (§1) — the Shops scope of Search now lists the shop directory
   when no query is typed, with its own header, instead of a static "Search Bump" card.
   This is the `GET /Shop` parity gap and the information-architecture gap in one change.
   Three details the first cut got wrong and this one handles:
   - The loader is keyed on *whether the directory is on screen*, not on the scope. Scope
     alone misses the second way in — clearing the query while already on Shops changes no
     scope, so a directory whose first load had failed would never retry.
   - A failed load renders `ErrorStateView` with a retry, not `EmptyStateView`. Collapsing
     the two would tell the user the app has no shops when the request simply failed —
     the same distinction `HomeViewModel.NearbyState` already draws for the nearby strip.
     A *cancelled* load stays silent and retries on the next appearance, since
     `APIError.userMessage(for:)` returns nil for cancellation.
   - Directory paging uses its own in-flight flag. The directory and the Shops search
     results can both be live in one view model, and a shared flag lets one refuse the
     other's page.

## 5. Verification

No simulator was booted, no application was run and nothing was installed.

- `swiftc -typecheck` over all 116 app sources for `arm64-apple-ios18.0` against the iOS 18
  SDK: **clean, no errors or warnings**. `NotificationHubClient.swift` was excluded and
  replaced by a throwaway stub outside the repository, because its `SignalRClient` import
  is resolved by SwiftPM and a standalone typecheck cannot reach it; that file was not
  modified by this pass.
- `swiftc -typecheck` over `Tools/ShopBrowseCheck/main.swift` with its four dependencies:
  **clean**.
- `Resources/Localizable.xcstrings`: 6 new keys added with Vietnamese translations
  alongside English. All 255 keys now carry a `vi` localization — verified
  programmatically, so the Vietnamese build does not regress. Three further strings this
  pass needed (`Log Out`, `%lld characters left`, `Resend code`) were already in the
  catalog and are reused rather than duplicated.

`Tools/ShopBrowseCheck/main.swift` is written but **not executed** — it is a host
command-line binary, not a simulator, but running it was not authorised. Its header carries
the exact `swiftc -o … && …` invocation, matching `BlockAndEditCheck` and
`NotificationRouteCheck`. It compiles the real shipping model files rather than copies, and
asserts:

1. `CursorPage<ShopSummaryDto>` decoding, pinning the wire-shape asymmetry that
   `ShopSummaryDto` has — `rate` arrives wrapped as `{"value": Int}` while its sibling
   `name` and `address` are bare strings.
2. The directory paging state machine: once-only first load, append-not-replace on page
   two, no request spent past `hasMore == false`, guard release so a cancelled first load
   stays retryable, a real failure staying distinguishable from an empty directory, and
   the error state's retry bypassing the once-only guard.
3. `ShopFieldRule` against `CreatePostValidator` — inclusive 200, non-empty after
   trimming, and trailing whitespace not counted toward the cap — plus the `FreeTextRule`
   boundaries the caption counter depends on.

`Tools/` is outside the `sources:` list in `project.yml`, so this file is not compiled into
the app target, matching the two existing checks.

## 6. Files changed

16 source files, +215/−17, plus the localization catalog and this document.

| File | Change |
| --- | --- |
| `Core/Services/ReactionStore.swift` | `reset()` (B3) |
| `Core/Services/SaveStore.swift` | `reset()` (B3) |
| `Core/Services/AccountCache.swift` | `reset()` (B3) |
| `Core/Services/ShopService.swift` | `all(cursor:pageSize:)` for `GET /Shop` (§1) |
| `Core/Utilities/Validation.swift` | `ShopFieldRule` (B5) |
| `Features/Root/RootView.swift` | reset the three stores on sign-out (B3) |
| `Features/PostDetail/PostDetailView.swift` | observe `isReacted` / `isSaved` (B1) |
| `Features/Profile/ProfileView.swift` | read `FollowStore` directly (B2) |
| `Features/CreatePost/CreatePostViewModel.swift` | validation mirrors the server (B5) |
| `Features/CreatePost/CreatePostView.swift` | caption counter, name/address hints (B5) |
| `Features/Search/SearchViewModel.swift` | shop directory paging (§1) |
| `Features/Search/SearchView.swift` | browse-all-shops empty state (§1, §4.5) |
| `Features/Settings/SettingsView.swift` | log-out confirmation (B6) |
| `Features/Settings/ChangeEmailView.swift` | OTP AutoFill (B4) |
| `Features/Onboarding/OtpVerifyView.swift` | OTP AutoFill, resend hit target (B4, B7) |
| `Features/Onboarding/RecoveryOtpVerifyView.swift` | OTP AutoFill, resend hit target (B4, B7) |
| `Resources/Localizable.xcstrings` | 6 new keys, en + vi |
| `Tools/ShopBrowseCheck/main.swift` | new self-check |

No commits were made, per `Bump_Server/AGENTS.md`.
