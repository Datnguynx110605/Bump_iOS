import SwiftUI

/// Square, horizontally-paged image carousel shared by feed rows, post detail, and
/// comment images so multi-photo posts and comments all page the same way.
///
/// Defaults to **radius 0**: in an editorial layout the photo runs to the screen edges and
/// is clipped by the screen itself. Hosts that are genuinely inset (a comment attachment)
/// pass a radius explicitly.
///
/// Pages are sized from a measured width, but photos are always *decoded* at one fixed
/// size. Feeding the measured width into the decode target makes the decode cache key vary
/// with layout, so the same photo gets downsampled and cached more than once.
struct PostImageCarousel: View {
    let imageURLs: [String]
    /// 0 for full-bleed feed and detail photos; set only by inset hosts.
    var cornerRadius: CGFloat = 0
    @State private var currentIndex: Int?

    private var pageIndex: Int { currentIndex ?? 0 }

    /// Past this many photos a dot row stops being scannable and starts being a smear,
    /// so the indicator falls back to a count.
    private static let maxDots = 6

    var body: some View {
        // The pages need the carousel's own width, and that width differs per host, so it
        // has to be measured. What the GeometryReader no longer feeds is the *decode*
        // size — that's fixed below, so the same photo can't land in the decode cache
        // several times over under near-identical measured widths.
        GeometryReader { proxy in
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(Array(imageURLs.enumerated()), id: \.offset) { index, urlString in
                        CachedAsyncImage(url: URL(string: urlString), targetSize: Self.decodeSize) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                            case .empty:
                                BumpColor.fill
                            case .failure:
                                BumpColor.fill.overlay(
                                    Image(systemName: "photo")
                                        .font(.title2)
                                        .foregroundStyle(BumpColor.textTertiary)
                                )
                            }
                        }
                        .frame(width: proxy.size.width, height: proxy.size.width)
                        .clipped()
                        .id(index)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $currentIndex)
            .scrollIndicators(.hidden)
            .scrollDisabled(imageURLs.count <= 1)
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(alignment: .bottom) {
            if imageURLs.count > 1 {
                indicator
                    .padding(.bottom, BumpSpacing.ms)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            imageURLs.count > 1
                ? String(localized: "\(imageURLs.count) photos")
                : String(localized: "Photo")
        )
        // Paging was swipe-only, and `children: .ignore` collapses the whole carousel into
        // one element — so every photo after the first was unreachable to VoiceOver on
        // every multi-photo post and comment. WCAG 2.2 AA requires a non-drag alternative
        // for an author-controlled drag; an adjustable action is the one VoiceOver already
        // knows how to drive, and it announces where in the set the user is.
        .accessibilityValue(
            imageURLs.count > 1
                ? String(localized: "Photo \(pageIndex + 1) of \(imageURLs.count)")
                : ""
        )
        .accessibilityAdjustableAction { direction in
            guard imageURLs.count > 1 else { return }
            switch direction {
            case .increment: currentIndex = min(pageIndex + 1, imageURLs.count - 1)
            case .decrement: currentIndex = max(pageIndex - 1, 0)
            default: break
            }
        }
    }

    /// A feed photo is drawn at roughly full screen width; one fixed decode size keeps a
    /// single cache entry per photo instead of one per measured row width.
    private static let decodeSize: CGSize = {
        let side = UIScreen.main.bounds.width
        return CGSize(width: side, height: side)
    }()

    @ViewBuilder
    private var indicator: some View {
        if imageURLs.count <= Self.maxDots {
            // Dots sit on their own scrim rather than directly on the photo: a white dot
            // on a white plate is invisible, and the 3:1 non-text requirement can't be met
            // against "whatever pixel happens to be underneath".
            HStack(spacing: 5) {
                ForEach(0..<imageURLs.count, id: \.self) { index in
                    Circle()
                        .fill(.white)
                        .opacity(index == pageIndex ? 1 : 0.45)
                        .frame(width: 6, height: 6)
                        .scaleEffect(index == pageIndex ? 1.15 : 1)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, BumpSpacing.s)
            .background(BumpColor.overlayChrome, in: Capsule())
            .bumpAnimation(BumpMotion.standard, value: pageIndex)
            .accessibilityHidden(true)
        } else {
            Text("\(pageIndex + 1)/\(imageURLs.count)")
                .font(.system(.caption2, design: .rounded, weight: .semibold).monospacedDigit())
                .foregroundStyle(.white)
                .padding(.vertical, BumpSpacing.xs)
                .padding(.horizontal, BumpSpacing.s)
                .background(BumpColor.overlayChrome, in: Capsule())
                .accessibilityHidden(true)
        }
    }
}
