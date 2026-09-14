# Bump_Client — Inspection & UI/UX Pass

Second pass over `Bump_Client/src/Sources`. `doc/audit.md` is the first pass and is not
superseded — its B1–B7 are fixed and in tree, and this document references that numbering
rather than restarting it. Findings here are numbered C1–C12.

Scope: bugs, risks and optimisations across the whole client, plus a UI/UX pass run through
the `ui-ux-pro-max` dataset (`--domain ux`, `--stack swiftui`, and the canonical
pre-delivery checklist in `references/pro-rules.md`). Severities in **bold** are the
dataset's own ratings, not mine.

---

## 1. Correctness

### C1 — The nearby section spins forever after one cancelled load · fixed
`Features/Home/HomeViewModel.swift`

`loadInitialIfNeeded()` guarded both halves of the screen behind one condition:

```swift
guard posts.isEmpty else { return }   // returns before ever checking nearby
await reload()
if nearby == .loading { await loadNearby() }
```

`loadNearby()` deliberately leaves `nearby` on `.loading` when its request is cancelled —
leaving a tab mid-load is not a failed lookup and must not paint an error card. But the
shared guard meant the *next* visit returned early on the posts it had already fetched, so
the pending nearby state was never revisited. One tab switch during the first load and the
"Top Rated Nearby" strip showed a spinner for the life of the app.

Root cause is the shared guard, not the cancellation branch. The two checks are now
independent, and returning to the tab retries on its own.

### C2 — A photo that fails once never retries; a recycled row shows the previous photo · fixed
`Core/DesignSystem/CachedAsyncImage.swift`

Two defects in one function, both from `load()` returning early on a decode-cache hit and
leaving `phase` alone.

*Stale image.* `phase` is `@State`, keyed on the view's identity. A recycled row — an
avatar whose account just changed its photo, a carousel page whose post was edited —
arrives holding the previous URL's `.success`. `.task(id: cacheKey)` re-fired, `load()`
saw the new key already in the decode cache, and returned without touching `phase`. The
old image stayed on screen for the new URL, permanently. A cache hit is now *assigned*
rather than returned on, and a miss resets to `.empty` first.

*No retry.* `.task(id:)` only re-fires when the key changes. A row that stays on screen
never re-ran `load()`, so one dropped request painted a broken-photo glyph that survived
pull-to-refresh and the network coming back. Scrolling away and back recycled the view and
did retry, which is what masked this. There is now one automatic second attempt.

Marked `ponytail:` in tree — a failure that outlives both attempts still waits for the row
to recycle. Per-request backoff belongs in the image layer, not in a view.

### C3 — The feed dead-ends when every loaded post is from a blocked author · fixed
`Features/Home/HomeView.swift`

`isNearEnd` already uses a 3-element window specifically so a filtered *row* still pages —
that reasoning is in `Core/Models/Pagination.swift` and it holds. What it cannot cover is
an entire loaded set being filtered: `visiblePosts.isEmpty` renders `EmptyStateView`, the
`ForEach` carrying the paging trigger never renders, and the feed stops for good while the
server still has pages. A new account following two people who both get blocked reaches
this. The empty state now carries its own paging trigger, keyed on the loaded count so it
drains page after page until a visible post arrives or the server runs out.

One cosmetic edge remains: `isLoadingMore` renders its spinner only in the non-empty branch,
so during the drain the screen reads "Your feed is quiet" while pages are actively loading
behind it. Self-resolving, and not worth a second spinner in a state most users never see.

### C4 — Auth tokens ride into encrypted backups · fixed
`Core/Networking/KeychainTokenStore.swift`

Both tokens were written with `kSecAttrAccessibleAfterFirstUnlock` and no `ThisDeviceOnly`,
so they are included in encrypted backups and iCloud Keychain and can restore a live
session onto a second device. Now `…AfterFirstUnlockThisDeviceOnly` — still readable by a
background refresh, no longer portable.

The attribute is set on the **update** path as well as the add path. `SecItemUpdate` leaves
attributes it is not given alone, so without that an existing install would keep the weaker
accessibility it was first written with, for good.

### C5 — Comment like counts go stale after a refresh · fixed
`Features/PostDetail/CommentRowView.swift`

`displayedLikeCount` is seeded in `init` and SwiftUI keys the row on the comment id, which
does not change across a pull-to-refresh — so the count stayed at whatever it was when the
row was first built. Exactly B1 from the first pass, which fixed posts and left comments.

---

## 2. UI/UX pass

Run against the `ui-ux-pro-max` dataset. The app already has a coherent design system —
4pt scale, semantic tokens with documented contrast ratios, `BumpHitTarget.min` on every
icon control, `@ScaledMetric`, a reduce-motion wrapper, full en/vi coverage — so this pass
looked for **violations of that system and gaps in it**, not a new visual direction.

### C6 — A failed load claims the account or shop is empty · fixed
`Features/Profile/ProfileView.swift`, `Features/Shop/ShopDetailView.swift`
— dataset: *Forms / Error Placement*, **High**

Both view models set `errorMessage` and neither view ever rendered it. A failed profile
load left the redacted placeholder header above "No posts yet"; a failed shop lookup left
"No posts yet. Be the first to review this place." Both tell the user something false about
the data when in fact the request failed.

This is the codebase's own stated standard: §4.5 of `doc/audit.md` draws exactly this
distinction for the shop directory, and `HomeViewModel.NearbyState` draws it between
`.failed` and an empty result. These two screens were the holdouts. Both now render
`ErrorStateView` with a retry when the primary object failed to load.

### C7 — VoiceOver cannot reach the empty feed's only way out · fixed
`Core/DesignSystem/StateViews.swift`
— dataset: *Accessibility / focus order and interactive labels*, **High**

`EmptyStateView` ended with `.accessibilityElement(children: .combine)` on the whole stack,
including its optional action button. Combining absorbs interactive descendants, and an
absorbed button is not focusable — so `HomeView`'s "Discover Shops & People", the one
control that gets a new user off an empty feed, was unreachable under VoiceOver.

The combine now stops at the title/message pair, which preserves the single-announcement
intent the doc comment describes. `ErrorStateView`, three lines below in the same file, has
the same shape and never combined — it was already the working template.

### C8 — Every photo after the first is unreachable to VoiceOver · fixed
`Core/DesignSystem/PostImageCarousel.swift`
— dataset: *Accessibility / Dragging Movements*, **High** (WCAG 2.2 AA)

The carousel is swipe-only and sets `.accessibilityElement(children: .ignore)` with a label
of "N photos", so it is one element with no way to move through it. Photos 2..N were
unreachable on every multi-photo post and comment. The checklist item is explicit:
"Dragging and swipe-only interactions have button/keyboard alternatives."

Added an `accessibilityAdjustableAction` — the non-drag path VoiceOver already knows how to
drive — plus an `accessibilityValue` announcing position in the set. Both ends clamp; an
out-of-range `scrollPosition(id:)` scrolls nowhere and would strand the user mid-carousel.

**This reaches post detail and comment rows, not the feed card.** In `PostRowView` the
carousel sits *inside* a `NavigationLink`, and SwiftUI flattens a button's label into one
accessibility element — the same mechanism as C7 above, where `.combine` made the action
button unfocusable. So on the feed the card stays a single element and the adjustable action
is not exposed. Not fixed here because the two ways out both cost more than this pass
should spend unilaterally: hoisting the carousel out of the link gives up tap-the-photo-to-
open-the-post, which sighted users rely on, and re-announcing the card with custom actions
is a rewrite of the row's accessibility. VoiceOver users can still open the post and page
through the photos there. Worth revisiting as its own change.

### C9 — The sign-in flow clips at large text sizes · fixed
`Features/Onboarding/AuthFormLayout.swift` (new) + all eight onboarding screens
— dataset: *Accessibility / Support Dynamic Type*, **High**

Seven of the eight onboarding screens built the same layout by hand: `VStack { content;
Spacer(); button }`. A `VStack` has nowhere to put overflow, so at the larger Dynamic Type sizes — or
simply with the keyboard raised on a small phone — the fields, inline hints and error
banner were clipped off the bottom with no way to reach them. Every other surface in the
app scales properly; the sign-in flow was the exception, and it is the one flow a new user
cannot skip.

Eight near-identical screens is one shared container, not eight edits. `AuthFormLayout`
scrolls the content and pins the action with `safeAreaInset`. `Spacer()` could not come
along — it collapses to nothing inside a `ScrollView` — and `safeAreaInset` is what keeps
the button where it was for short content while letting tall content scroll under it.
`.scrollBounceBehavior(.basedOnSize)` keeps the short screens from rubber-banding.

`CreateAccountView` is the eighth. It already had a `ScrollView`, so it did not clip — but
its button sat inline at the end of the scroll content rather than pinned, and it carries
the most content in the flow (username, password, confirm, bio, four inline hints). Left
alone it would have been the one screen in eight where the CTA scrolls out of view, and the
screen where that costs the most. Converted with the rest.

### C10 — The only design-token violation in the tree · fixed
`Features/Settings/ChangePasswordView.swift`
— dataset: *Accessibility / Color Contrast* and *Color Only*, **High**

`.foregroundStyle(newPassword == confirmPassword ? .green : .red)` — the single raw-color
use in 114 source files. System `.green` measures roughly 1.4:1 on a light card, well under
the 4.5:1 body threshold the palette is otherwise tuned to, and the tone rested on color
alone.

Both hints in that footer now go through `FieldHint`, which pairs the semantic token with an
icon so the tone is not carried by color. The length hint above it was already on a semantic
token but still color-only, and leaving a bare `Text` beside a `FieldHint` in one footer
reads as two different components. `ResetPasswordView`, the onboarding twin of this screen,
has used `FieldHint` for both all along.

### C11 — Three text fields hit the server's 2000-character cap without warning · fixed
`Features/Onboarding/CreateAccountView.swift`, `Features/Settings/EditProfileView.swift`,
`Features/Report/ReportSheet.swift`
— dataset: *Forms / Inline Validation*, **Medium**

B5 in the first pass fixed this for the caption and the two edit sheets, and left three
fields behind. Bio on sign-up carried a permanent `0/2000` that cost attention from the
first keystroke and gated nothing — `isValid` never looked at it. Bio on Edit Profile and
the report reason had neither counter nor check. All three were submittable over the limit
and came back a 400 after the round trip.

All three now use the existing `FreeTextRule.remaining` near-limit counter and include the
field in their submit guard, matching the caption field exactly.

### C12 — Cancel threw away a fully composed post · fixed
`Features/CreatePost/CreatePostView.swift`, `CreatePostViewModel.swift`
— dataset: *Interaction / Confirmation Dialogs*, **High**

Composing a post is the most expensive thing in the app — up to six photos, each picked,
pinched and confirmed by hand. Both Cancel and the downward dismissal swipe discarded all
of it silently. The first pass added a confirmation to Log Out (B6) on exactly this
reasoning, for a far cheaper action.

Cancel now confirms when there is work to lose. The swipe is *blocked* rather than
confirmed (`interactiveDismissDisabled`), because a sheet dismissal has no point at which
to interpose a dialog. Whitespace does not count as work, or an untouched compose screen
would nag on every close.

---

## 3. Looked at, deliberately not changed

- **`UIScreen.main.bounds` in the two `decodeSize` statics** (`PostImageCarousel`,
  `PostThumbnailGrid`). Deprecated, and wrong under iPad multitasking. But it is a decode
  *quality* hint, not layout, and fixing it properly means threading a size through both
  call sites — more code and more surface than the problem.
- **SignalR reconnects with whatever token `AuthSession` holds**, and `decodeClaims` never
  reads `exp`. §3 of the first pass deferred this as a networking change; that judgement
  still holds and this was a UI pass.
- **`SavedView`'s `.tint(.red)`** on the unsave swipe action. Red on a trailing swipe is the
  platform convention, not a token violation.
- **The C3 shape also exists in `SearchView` (posts, accounts) and `SavedView`.** Same
  one-`task` remedy. Not applied: those lists are keyword- or bookmark-driven and a user can
  retype or pull to refresh, whereas the Home feed is the landing screen and dead-ends with
  no way forward. Worth doing if it ever shows up in practice.
- **`MainTabView` renders nothing when `authSession.accountId` is nil.** Verified against
  the server rather than guessed: `Bump_Server/src/infra/service/JwtService.cs:13` emits the
  claim as the literal string `accountId`, which is exactly what `decodeClaims` reads, so
  the blank-tab state is unreachable with any token this server issues. Left alone rather
  than adding a fallback for a state that cannot occur.
- **`OtpVerifyView` re-arms its 60-second resend cooldown on every `onAppear`**, so
  navigating forward and back restarts the wait. Mildly annoying, never incorrect.
- **`EditProfileView`'s username hint reads "Looks good." past 200 characters** while Save
  is disabled with no explanation. Requires a 200-character username to reach.

---

## 4. Verification

No simulator was booted, no application was run, nothing was installed.

- **Typecheck.** `swiftc -typecheck` for `arm64-apple-ios18.0` over the app target's 114
  sources — 113 compiled directly, plus a throwaway stub standing in for the 114th.
  `NotificationHubClient.swift` is that exception: its `SignalRClient` import is resolved by
  SwiftPM and a standalone typecheck cannot reach it. That file is untouched by this pass.
  Run on the pristine tree first to establish a baseline, then after every batch: **clean
  throughout, no errors or warnings**. (114, not the 116 quoted in the first pass — the
  count is taken from the same glob the script runs.) The available SDK is now iOS 26.5; the
  *deployment target* is still pinned to 18.0, matching `project.yml`.
- **Self-check.** `Tools/UxPassCheck/main.swift` is written **and run** — it compiles and
  all assertions pass. It covers the three pieces of this pass that are branching logic
  rather than markup: the C1 state machine across three visits, `hasUnsavedWork` including
  the whitespace case, and the C8 clamp at both ends of the carousel. Its header carries the
  exact `swiftc -o … && …` invocation, matching the three existing checks. `Tools/` is
  outside the `sources:` list in `project.yml`, so it is not compiled into the app target.
- **Localization.** 4 new keys, each with both `en` and `vi`. All **259** keys now carry a
  `vi` localization. Three further strings this pass needed (`%lld characters left`,
  `Passwords match.`, `Passwords don't match.`) were already in the catalog and are reused
  rather than duplicated. The diff is pure insertion — no reordering churn.

  The keys were hand-written, and a hand-written key that does not match what the compiler
  extracts does not error — it silently adds a second, untranslated entry and the `vi` build
  falls back to English for that string. So the extraction was run rather than assumed:
  compiling with `-emit-localized-strings` (what `SWIFT_EMIT_LOC_STRINGS: YES` turns on)
  produces **258 keys, every one of them present in the catalog, zero orphans** — including
  the interpolated `Photo %lld of %lld`.
- **Project file.** `AuthFormLayout.swift` is the one new app source, hand-registered in all
  four places `project.pbxproj` requires. Verified by generating a throwaway project with
  `xcodegen` and diffing the compiled source list against the committed one: **114 files,
  identical**.

**What still needs a device.** C9 is the largest change here — eight screens restructured —
and a typecheck proves nothing about layout. The interaction to exercise first is the OTP
screens at the AX text sizes with the keyboard raised: they combine `safeAreaInset` with an
`onAppear` that focuses the field immediately, and that pairing is the one thing in this
pass with no static check behind it. C7 and C8 likewise need a VoiceOver pass to confirm the
focus order they were written for.

## 5. Files changed

One new app source, one new check, 24 modified (22 Swift sources plus the project file and the string catalog).

| File | Change |
| --- | --- |
| `Core/DesignSystem/CachedAsyncImage.swift` | cache-hit assignment + one retry (C2) |
| `Core/DesignSystem/PostImageCarousel.swift` | adjustable action, page value (C8) |
| `Core/DesignSystem/StateViews.swift` | combine stops at the text (C7) |
| `Core/Networking/KeychainTokenStore.swift` | `ThisDeviceOnly`, add + update paths (C4) |
| `Features/Home/HomeViewModel.swift` | independent guards (C1) |
| `Features/Home/HomeView.swift` | paging trigger on the empty state (C3) |
| `Features/PostDetail/CommentRowView.swift` | observe the comment (C5) |
| `Features/Profile/ProfileView.swift` | error state (C6) |
| `Features/Shop/ShopDetailView.swift` | error state (C6) |
| `Features/Onboarding/AuthFormLayout.swift` | **new** — scrolling form, pinned CTA (C9) |
| `Features/Onboarding/*View.swift` (×7) | adopt `AuthFormLayout` (C9) |
| `Features/Onboarding/CreateAccountView.swift` | adopt `AuthFormLayout` (C9), bio counter + submit guard (C11) |
| `Features/Settings/EditProfileView.swift` | bio counter + submit guard (C11) |
| `Features/Report/ReportSheet.swift` | reason counter + submit guard (C11) |
| `Features/Settings/ChangePasswordView.swift` | semantic tokens via `FieldHint` (C10) |
| `Features/CreatePost/CreatePostView.swift` | discard confirmation (C12) |
| `Features/CreatePost/CreatePostViewModel.swift` | `hasUnsavedWork` (C12) |
| `Resources/Localizable.xcstrings` | 4 new keys, en + vi |
| `Bump.xcodeproj/project.pbxproj` | register `AuthFormLayout.swift` |
| `Tools/UxPassCheck/main.swift` | **new** — self-check, run and passing |

No commits were made.
