import SwiftUI

// MARK: - Icon geometry
//
// Every Bump glyph, drawn on one 24×24 grid. This file is deliberately free of UIKit so
// `Tools/RenderIconSheet` can compile it on macOS and render the whole family to a PNG —
// hand-drawn vectors are proofed by looking at them, not by trusting the coordinates.
//
// Construction rules, applied to every glyph without exception:
//
// * **Optical bounds, not mathematical ones.** Glyphs fill roughly 17 of the 24 units and
//   sit centred on (12, 12). Leaving the outer ring empty is what lets an icon sit beside
//   text without its corners colliding with the line above.
// * **Round cap, round join, one weight.** Terminals are never square and never mixed.
//   The weight is a fraction of the rendered size, so a 13pt glyph and a 40pt glyph are
//   the same drawing rather than the same numbers.
// * **Fill is a state.** A `.filled` glyph is the identical silhouette, filled. Nothing
//   changes shape when it turns on, so a like reads as the same object gaining weight.
// * **Detail is knocked out, never overdrawn.** The lens inside a filled camera is a hole
//   punched through it, so it stays correct on any background the app has.

/// The glyphs the app draws. One case per *concept* — fill, slash and circle are
/// variants, not separate entries, which is what stops the family drifting back into
/// "outline here, solid there".
enum BumpGlyph: String, CaseIterable, Sendable {
    // Navigation
    case home, search, plus, bell, person, people
    // Post actions
    case heart, bookmark, comment, comments, ellipsis, share
    // Movement
    case chevronRight, chevronLeft, arrowUp, xmark, check, directions
    // Content
    case camera, photo, photos, cup, storefront, forkKnife, star, sparkle, textLines, copy
    // Place & time
    case mappin, location, clock, history
    // Account & system
    case gear, envelope, document, lock, handRaised, flag, signal
    // Status
    case exclamation, warning, seal, checkbox
}

/// How a glyph is drawn. Modifiers compose onto the base silhouette rather than being
/// redrawn per icon, so every slashed or circled glyph in the app is built identically.
enum BumpGlyphVariant: Sendable {
    /// The default: stroked silhouette.
    case outline
    /// The same silhouette, filled. Used for an *on* state.
    case filled
    /// Outline plus a diagonal rule, with the rule's channel knocked out of the glyph
    /// beneath so the two never merge into an unreadable blob.
    case slashed
    /// The glyph at half scale inside a stroked ring.
    case circled
    /// The glyph knocked out of a solid disc.
    case circledFilled
}

enum BumpIconGeometry {
    /// The grid every path below is drawn on.
    static let grid: CGFloat = 24
    /// Stroke weight as a fraction of the rendered size — 1.8pt on the 24pt grid.
    static let strokeFraction: CGFloat = 0.075

    // MARK: Drawing

    static func draw(glyph: BumpGlyph, variant: BumpGlyphVariant, in size: CGSize, context: inout GraphicsContext) {
        let side = min(size.width, size.height)
        guard side > 0 else { return }
        let unit = side / grid
        let weight = side * strokeFraction
        // Centres the square drawing inside a non-square frame.
        let origin = CGPoint(x: (size.width - side) / 2, y: (size.height - side) / 2)
        let transform = CGAffineTransform(translationX: origin.x, y: origin.y).scaledBy(x: unit, y: unit)

        switch variant {
        case .outline, .filled:
            paint(glyph, filled: variant == .filled, transform: transform, weight: weight, context: &context)

        case .slashed:
            // The glyph and the channel are one layer: the knockout has to remove part of
            // the glyph, not part of everything drawn so far.
            context.drawLayer { layer in
                paint(glyph, filled: false, transform: transform, weight: weight, context: &layer)
                layer.blendMode = .destinationOut
                layer.stroke(
                    slashPath.applying(transform),
                    with: .color(.black),
                    style: StrokeStyle(lineWidth: weight * 2.7, lineCap: .round)
                )
            }
            context.stroke(
                slashPath.applying(transform),
                with: .foreground,
                style: StrokeStyle(lineWidth: weight, lineCap: .round)
            )

        case .circled, .circledFilled:
            let ring = Path(ellipseIn: CGRect(x: 1.5, y: 1.5, width: 21, height: 21)).applying(transform)
            // The inner glyph is scaled about the grid's centre so it stays concentric
            // with the ring at every size.
            let inner = transform
                .translatedBy(x: grid / 2, y: grid / 2)
                .scaledBy(x: innerScale, y: innerScale)
                .translatedBy(x: -grid / 2, y: -grid / 2)

            if variant == .circled {
                context.stroke(ring, with: .foreground, style: StrokeStyle(lineWidth: weight))
                paint(glyph, filled: false, transform: inner, weight: weight / innerScale * 0.86, context: &context)
            } else {
                context.drawLayer { layer in
                    layer.fill(ring, with: .foreground)
                    layer.blendMode = .destinationOut
                    paint(glyph, filled: false, transform: inner, weight: weight / innerScale * 0.92, context: &layer)
                }
            }
        }
    }

    /// How much of the ring's interior the inner glyph occupies. 0.52 keeps a full
    /// stroke-width of clear space between glyph and ring at every size.
    private static let innerScale: CGFloat = 0.52

    /// Top-left to bottom-right, matching the direction the platform uses for "not
    /// available" so the meaning is one users already have.
    private static let slashPath: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 4.6, y: 4.6))
        p.addLine(to: CGPoint(x: 19.4, y: 19.4))
        return p
    }()

    private static func paint(
        _ glyph: BumpGlyph,
        filled: Bool,
        transform: CGAffineTransform,
        weight: CGFloat,
        context: inout GraphicsContext
    ) {
        let drawing = drawing(for: glyph)
        let style = StrokeStyle(lineWidth: weight, lineCap: .round, lineJoin: .round)

        // A glyph with no closed silhouette (a checkmark, a chevron) has nothing to fill,
        // so `.filled` falls back to the outline rather than rendering nothing.
        let canFill = filled && drawing.silhouette != nil

        let paintDetail = { (ctx: inout GraphicsContext) in
            for detail in drawing.details {
                ctx.stroke(detail.applying(transform), with: .foreground, style: style)
            }
            for dot in drawing.dots {
                let r = dot.radius
                let rect = CGRect(x: dot.center.x - r, y: dot.center.y - r, width: r * 2, height: r * 2)
                ctx.fill(Path(ellipseIn: rect).applying(transform), with: .foreground)
            }
        }

        guard canFill, let silhouette = drawing.silhouette else {
            // Outline: silhouette and detail are both stroked, at one weight.
            if let silhouette = drawing.silhouette {
                context.stroke(silhouette.applying(transform), with: .foreground, style: style)
            }
            paintDetail(&context)
            return
        }

        // Filled: the body and its knockouts have to share one layer. `destinationOut`
        // erases what is already in the *current* layer, so opening a fresh layer just to
        // punch holes erases nothing — the new layer starts empty and then composites
        // over the body untouched. Filling inside the layer is what makes the lens of a
        // camera and the tick in a checkbox real holes rather than invisible overdraw.
        context.drawLayer { layer in
            layer.fill(silhouette.applying(transform), with: .foreground)
            layer.blendMode = .destinationOut
            paintDetail(&layer)
        }
    }

    // MARK: Glyph definitions

    private struct Dot {
        let center: CGPoint
        let radius: CGFloat
    }

    private struct Drawing {
        /// The closed outer shape. `nil` for glyphs that are pure strokes.
        var silhouette: Path?
        /// Interior strokes — a clock's hands, a photo's horizon.
        var details: [Path] = []
        /// Interior solid dots — an ellipsis, a warning's point.
        var dots: [Dot] = []
    }

    private static func drawing(for glyph: BumpGlyph) -> Drawing {
        switch glyph {

        case .home:
            // Pitched roof over a square body. The eaves overhang the walls slightly,
            // which is what stops a stroked house reading as an arrow on a box.
            return Drawing(silhouette: path {
                $0.move(to: CGPoint(x: 3.4, y: 10.6))
                $0.addLine(to: CGPoint(x: 12, y: 3.3))
                $0.addLine(to: CGPoint(x: 20.6, y: 10.6))
                $0.addLine(to: CGPoint(x: 20.6, y: 20.4))
                $0.addLine(to: CGPoint(x: 3.4, y: 20.4))
                $0.closeSubpath()
            })

        case .search:
            return Drawing(
                silhouette: Path(ellipseIn: CGRect(x: 3.6, y: 3.6, width: 13.2, height: 13.2)),
                details: [path {
                    $0.move(to: CGPoint(x: 16.6, y: 16.6))
                    $0.addLine(to: CGPoint(x: 20.6, y: 20.6))
                }]
            )

        case .plus:
            return Drawing(details: [
                path {
                    $0.move(to: CGPoint(x: 12, y: 4.6))
                    $0.addLine(to: CGPoint(x: 12, y: 19.4))
                },
                path {
                    $0.move(to: CGPoint(x: 4.6, y: 12))
                    $0.addLine(to: CGPoint(x: 19.4, y: 12))
                }
            ])

        case .bell:
            // Dome on a flared skirt. The clapper is a separate arc so the filled variant
            // still shows a notch at the bottom rather than becoming a solid blob.
            return Drawing(
                silhouette: path {
                    $0.move(to: CGPoint(x: 5.1, y: 17.1))
                    $0.addCurve(
                        to: CGPoint(x: 6.9, y: 11.2),
                        control1: CGPoint(x: 6.3, y: 15.6),
                        control2: CGPoint(x: 6.9, y: 13.6)
                    )
                    $0.addCurve(
                        to: CGPoint(x: 17.1, y: 11.2),
                        control1: CGPoint(x: 6.9, y: 4.5),
                        control2: CGPoint(x: 17.1, y: 4.5)
                    )
                    $0.addCurve(
                        to: CGPoint(x: 18.9, y: 17.1),
                        control1: CGPoint(x: 17.1, y: 13.6),
                        control2: CGPoint(x: 17.7, y: 15.6)
                    )
                    $0.closeSubpath()
                },
                details: [path {
                    $0.move(to: CGPoint(x: 9.9, y: 19.9))
                    $0.addCurve(
                        to: CGPoint(x: 14.1, y: 19.9),
                        control1: CGPoint(x: 10.7, y: 21.4),
                        control2: CGPoint(x: 13.3, y: 21.4)
                    )
                }]
            )

        case .person:
            // Head and shoulders as one closed silhouette so the filled variant is a
            // single solid figure rather than a disc floating above an arc.
            return Drawing(
                silhouette: personSilhouette(center: 12, headRadius: 3.7, headY: 8.1, shoulderY: 20.4, halfWidth: 6.6),
                details: []
            )

        case .people:
            // Two figures at different scales rather than two identical stamps, which is
            // what gives the pair depth at 17pt. Both belong to the silhouette, not one
            // to the detail layer: a detail is *knocked out* when filled, which would
            // have left the solid variant showing a single person.
            return Drawing(silhouette: path {
                $0.addPath(personSilhouette(center: 9.3, headRadius: 3.3, headY: 9, shoulderY: 20.4, halfWidth: 5.9))
                $0.addPath(personSilhouette(center: 17, headRadius: 2.6, headY: 7.8, shoulderY: 20.4, halfWidth: 4.6))
            })

        case .heart:
            // Two lobes meeting at a point. The tip sits at y=20.4 rather than the grid
            // edge so the stroke's round cap stays inside the optical bounds.
            return Drawing(silhouette: path {
                $0.move(to: CGPoint(x: 12, y: 20.4))
                $0.addCurve(
                    to: CGPoint(x: 3.2, y: 9.9),
                    control1: CGPoint(x: 6.5, y: 16.4),
                    control2: CGPoint(x: 3.2, y: 13.3)
                )
                $0.addCurve(
                    to: CGPoint(x: 12, y: 7.6),
                    control1: CGPoint(x: 3.2, y: 5.6),
                    control2: CGPoint(x: 9.3, y: 4.6)
                )
                $0.addCurve(
                    to: CGPoint(x: 20.8, y: 9.9),
                    control1: CGPoint(x: 14.7, y: 4.6),
                    control2: CGPoint(x: 20.8, y: 5.6)
                )
                $0.addCurve(
                    to: CGPoint(x: 12, y: 20.4),
                    control1: CGPoint(x: 20.8, y: 13.3),
                    control2: CGPoint(x: 17.5, y: 16.4)
                )
                $0.closeSubpath()
            })

        case .bookmark:
            // Ribbon with a notched foot. Shoulders are rounded by a short curve rather
            // than a corner radius so it matches the round join everywhere else.
            return Drawing(silhouette: path {
                $0.move(to: CGPoint(x: 5.6, y: 6.2))
                $0.addCurve(
                    to: CGPoint(x: 8.2, y: 3.6),
                    control1: CGPoint(x: 5.6, y: 4.8),
                    control2: CGPoint(x: 6.8, y: 3.6)
                )
                $0.addLine(to: CGPoint(x: 15.8, y: 3.6))
                $0.addCurve(
                    to: CGPoint(x: 18.4, y: 6.2),
                    control1: CGPoint(x: 17.2, y: 3.6),
                    control2: CGPoint(x: 18.4, y: 4.8)
                )
                $0.addLine(to: CGPoint(x: 18.4, y: 20.4))
                $0.addLine(to: CGPoint(x: 12, y: 15.9))
                $0.addLine(to: CGPoint(x: 5.6, y: 20.4))
                $0.closeSubpath()
            })

        case .comment:
            // Rounded bubble with the tail on the leading edge, dropped from the body's
            // lower-left so it reads as spoken rather than as a pointer.
            return Drawing(silhouette: path {
                $0.move(to: CGPoint(x: 7.4, y: 17.6))
                $0.addLine(to: CGPoint(x: 7.4, y: 20.8))
                $0.addLine(to: CGPoint(x: 11.2, y: 17.6))
                $0.addLine(to: CGPoint(x: 17.2, y: 17.6))
                $0.addCurve(
                    to: CGPoint(x: 20.4, y: 14.4),
                    control1: CGPoint(x: 19, y: 17.6),
                    control2: CGPoint(x: 20.4, y: 16.2)
                )
                $0.addLine(to: CGPoint(x: 20.4, y: 7.2))
                $0.addCurve(
                    to: CGPoint(x: 17.2, y: 4),
                    control1: CGPoint(x: 20.4, y: 5.4),
                    control2: CGPoint(x: 19, y: 4)
                )
                $0.addLine(to: CGPoint(x: 6.8, y: 4))
                $0.addCurve(
                    to: CGPoint(x: 3.6, y: 7.2),
                    control1: CGPoint(x: 5, y: 4),
                    control2: CGPoint(x: 3.6, y: 5.4)
                )
                $0.addLine(to: CGPoint(x: 3.6, y: 14.4))
                $0.addCurve(
                    to: CGPoint(x: 6.8, y: 17.6),
                    control1: CGPoint(x: 3.6, y: 16.2),
                    control2: CGPoint(x: 5, y: 17.6)
                )
                $0.closeSubpath()
            })

        case .comments:
            // A conversation: one bubble behind another. The rear bubble is only
            // partially visible, which says "thread" in less space than two full bubbles.
            return Drawing(
                silhouette: roundedBubble(x: 2.6, y: 3.4, width: 13.6, height: 10.6, radius: 3, tailX: 6.2, tailDrop: 3.1),
                details: [path {
                    $0.move(to: CGPoint(x: 10.4, y: 17.2))
                    $0.addLine(to: CGPoint(x: 18.2, y: 17.2))
                    $0.addCurve(
                        to: CGPoint(x: 21.2, y: 14.2),
                        control1: CGPoint(x: 19.9, y: 17.2),
                        control2: CGPoint(x: 21.2, y: 15.9)
                    )
                    $0.addLine(to: CGPoint(x: 21.2, y: 10.6))
                }]
            )

        case .ellipsis:
            return Drawing(dots: [
                Dot(center: CGPoint(x: 5.6, y: 12), radius: 1.55),
                Dot(center: CGPoint(x: 12, y: 12), radius: 1.55),
                Dot(center: CGPoint(x: 18.4, y: 12), radius: 1.55)
            ])

        case .share:
            // Arrow leaving a tray — the platform's own share idiom, redrawn at this
            // family's weight.
            return Drawing(details: [
                path {
                    $0.move(to: CGPoint(x: 12, y: 3.8))
                    $0.addLine(to: CGPoint(x: 12, y: 14.8))
                },
                path {
                    $0.move(to: CGPoint(x: 7.9, y: 7.9))
                    $0.addLine(to: CGPoint(x: 12, y: 3.8))
                    $0.addLine(to: CGPoint(x: 16.1, y: 7.9))
                },
                path {
                    $0.move(to: CGPoint(x: 6.8, y: 10.6))
                    $0.addLine(to: CGPoint(x: 4.8, y: 10.6))
                    $0.addLine(to: CGPoint(x: 4.8, y: 20.4))
                    $0.addLine(to: CGPoint(x: 19.2, y: 20.4))
                    $0.addLine(to: CGPoint(x: 19.2, y: 10.6))
                    $0.addLine(to: CGPoint(x: 17.2, y: 10.6))
                }
            ])

        case .chevronRight:
            return Drawing(details: [path {
                $0.move(to: CGPoint(x: 9.2, y: 4.8))
                $0.addLine(to: CGPoint(x: 16.4, y: 12))
                $0.addLine(to: CGPoint(x: 9.2, y: 19.2))
            }])

        case .chevronLeft:
            return Drawing(details: [path {
                $0.move(to: CGPoint(x: 14.8, y: 4.8))
                $0.addLine(to: CGPoint(x: 7.6, y: 12))
                $0.addLine(to: CGPoint(x: 14.8, y: 19.2))
            }])

        case .arrowUp:
            return Drawing(details: [
                path {
                    $0.move(to: CGPoint(x: 12, y: 20))
                    $0.addLine(to: CGPoint(x: 12, y: 4.6))
                },
                path {
                    $0.move(to: CGPoint(x: 5.6, y: 11))
                    $0.addLine(to: CGPoint(x: 12, y: 4.6))
                    $0.addLine(to: CGPoint(x: 18.4, y: 11))
                }
            ])

        case .xmark:
            return Drawing(details: [
                path {
                    $0.move(to: CGPoint(x: 5.8, y: 5.8))
                    $0.addLine(to: CGPoint(x: 18.2, y: 18.2))
                },
                path {
                    $0.move(to: CGPoint(x: 18.2, y: 5.8))
                    $0.addLine(to: CGPoint(x: 5.8, y: 18.2))
                }
            ])

        case .check:
            return Drawing(details: [path {
                $0.move(to: CGPoint(x: 4.6, y: 12.6))
                $0.addLine(to: CGPoint(x: 9.7, y: 17.7))
                $0.addLine(to: CGPoint(x: 19.4, y: 6.7))
            }])

        case .directions:
            // A route turning up and to the right — the action is "take me there", so the
            // glyph is a path with a decision in it, not a compass needle.
            return Drawing(details: [
                path {
                    $0.move(to: CGPoint(x: 5.2, y: 20.2))
                    $0.addLine(to: CGPoint(x: 5.2, y: 13.4))
                    $0.addCurve(
                        to: CGPoint(x: 9.2, y: 9.4),
                        control1: CGPoint(x: 5.2, y: 11.2),
                        control2: CGPoint(x: 7, y: 9.4)
                    )
                    $0.addLine(to: CGPoint(x: 17.6, y: 9.4))
                },
                path {
                    $0.move(to: CGPoint(x: 14, y: 5.6))
                    $0.addLine(to: CGPoint(x: 18.8, y: 9.4))
                    $0.addLine(to: CGPoint(x: 14, y: 13.2))
                }
            ])

        case .camera:
            return Drawing(
                silhouette: path {
                    $0.move(to: CGPoint(x: 6.2, y: 7.4))
                    $0.addLine(to: CGPoint(x: 8.1, y: 4.2))
                    $0.addLine(to: CGPoint(x: 15.9, y: 4.2))
                    $0.addLine(to: CGPoint(x: 17.8, y: 7.4))
                    $0.addLine(to: CGPoint(x: 19.6, y: 7.4))
                    $0.addCurve(
                        to: CGPoint(x: 22, y: 9.8),
                        control1: CGPoint(x: 20.9, y: 7.4),
                        control2: CGPoint(x: 22, y: 8.5)
                    )
                    $0.addLine(to: CGPoint(x: 22, y: 17.6))
                    $0.addCurve(
                        to: CGPoint(x: 19.6, y: 20),
                        control1: CGPoint(x: 22, y: 18.9),
                        control2: CGPoint(x: 20.9, y: 20)
                    )
                    $0.addLine(to: CGPoint(x: 4.4, y: 20))
                    $0.addCurve(
                        to: CGPoint(x: 2, y: 17.6),
                        control1: CGPoint(x: 3.1, y: 20),
                        control2: CGPoint(x: 2, y: 18.9)
                    )
                    $0.addLine(to: CGPoint(x: 2, y: 9.8))
                    $0.addCurve(
                        to: CGPoint(x: 4.4, y: 7.4),
                        control1: CGPoint(x: 2, y: 8.5),
                        control2: CGPoint(x: 3.1, y: 7.4)
                    )
                    $0.closeSubpath()
                },
                details: [Path(ellipseIn: CGRect(x: 8.3, y: 10.1, width: 7.4, height: 7.4))]
            )

        case .photo:
            // Frame, sun, and a two-peak horizon. The horizon starts below the frame's
            // mid-line so the filled variant still reads as a landscape once inverted.
            return Drawing(
                silhouette: roundedRect(x: 2.8, y: 4.6, width: 18.4, height: 14.8, radius: 3),
                details: [path {
                    $0.move(to: CGPoint(x: 3.4, y: 17.4))
                    $0.addLine(to: CGPoint(x: 9, y: 11.8))
                    $0.addLine(to: CGPoint(x: 13.4, y: 16.2))
                    $0.addLine(to: CGPoint(x: 15.8, y: 13.8))
                    $0.addLine(to: CGPoint(x: 20.6, y: 18.6))
                }],
                dots: [Dot(center: CGPoint(x: 8.6, y: 9.4), radius: 1.5)]
            )

        case .photos:
            // A picked photo on top of the roll beneath it.
            return Drawing(
                silhouette: roundedRect(x: 6.6, y: 3.4, width: 15, height: 12.4, radius: 2.6),
                details: [
                    path {
                        $0.move(to: CGPoint(x: 7.1, y: 14.2))
                        $0.addLine(to: CGPoint(x: 11.4, y: 9.9))
                        $0.addLine(to: CGPoint(x: 15, y: 13.5))
                        $0.addLine(to: CGPoint(x: 16.9, y: 11.6))
                        $0.addLine(to: CGPoint(x: 21.1, y: 15.3))
                    },
                    path {
                        $0.move(to: CGPoint(x: 17.4, y: 19.2))
                        $0.addLine(to: CGPoint(x: 5, y: 19.2))
                        $0.addCurve(
                            to: CGPoint(x: 2.4, y: 16.6),
                            control1: CGPoint(x: 3.6, y: 19.2),
                            control2: CGPoint(x: 2.4, y: 18)
                        )
                        $0.addLine(to: CGPoint(x: 2.4, y: 7.6))
                    }
                ],
                dots: [Dot(center: CGPoint(x: 11.1, y: 7.7), radius: 1.3)]
            )

        case .cup:
            // Bump's own mark, essentially: a cup on a saucer. The handle is a detail
            // stroke so the filled variant keeps a visible loop instead of a solid stub.
            return Drawing(
                silhouette: path {
                    $0.move(to: CGPoint(x: 4.2, y: 6.6))
                    $0.addLine(to: CGPoint(x: 16.2, y: 6.6))
                    $0.addLine(to: CGPoint(x: 16.2, y: 12.4))
                    $0.addCurve(
                        to: CGPoint(x: 10.2, y: 18.4),
                        control1: CGPoint(x: 16.2, y: 15.7),
                        control2: CGPoint(x: 13.5, y: 18.4)
                    )
                    $0.addCurve(
                        to: CGPoint(x: 4.2, y: 12.4),
                        control1: CGPoint(x: 6.9, y: 18.4),
                        control2: CGPoint(x: 4.2, y: 15.7)
                    )
                    $0.closeSubpath()
                },
                details: [
                    path {
                        $0.move(to: CGPoint(x: 16.2, y: 8.6))
                        $0.addLine(to: CGPoint(x: 18.2, y: 8.6))
                        $0.addCurve(
                            to: CGPoint(x: 18.2, y: 14),
                            control1: CGPoint(x: 20.2, y: 8.6),
                            control2: CGPoint(x: 20.2, y: 14)
                        )
                        $0.addLine(to: CGPoint(x: 16.05, y: 14))
                    },
                    path {
                        $0.move(to: CGPoint(x: 3, y: 21))
                        $0.addLine(to: CGPoint(x: 17.4, y: 21))
                    }
                ]
            )

        case .storefront:
            // *The* shop glyph. The app used to draw a shop as a coffee cup in list rows
            // and as a storefront in empty states — two answers to one concept, on
            // screens a user moves between. A Bump shop can be a bakery or a ramen bar,
            // so the awning is the honest one and the cup stays the brand's own mark.
            return Drawing(
                silhouette: path {
                    $0.move(to: CGPoint(x: 3.2, y: 9.2))
                    $0.addLine(to: CGPoint(x: 5.4, y: 3.8))
                    $0.addLine(to: CGPoint(x: 18.6, y: 3.8))
                    $0.addLine(to: CGPoint(x: 20.8, y: 9.2))
                    $0.addLine(to: CGPoint(x: 20.8, y: 20.4))
                    $0.addLine(to: CGPoint(x: 3.2, y: 20.4))
                    $0.closeSubpath()
                },
                details: [
                    line(y: 9.2, from: 3.2, to: 20.8),
                    path {
                        $0.move(to: CGPoint(x: 9.6, y: 20.4))
                        $0.addLine(to: CGPoint(x: 9.6, y: 14.4))
                        $0.addLine(to: CGPoint(x: 14.4, y: 14.4))
                        $0.addLine(to: CGPoint(x: 14.4, y: 20.4))
                    }
                ]
            )

        case .sparkle:
            // Discovery. Two four-pointed stars at different scales — concave points
            // rather than the five-pointed `star`, so "something new here" is never
            // confused with the rating beside it.
            return Drawing(silhouette: path {
                $0.addPath(star(points: 4, outer: 8, inner: 2.1, center: CGPoint(x: 10.2, y: 13.4)))
                $0.addPath(star(points: 4, outer: 4.3, inner: 1.15, center: CGPoint(x: 18.2, y: 6)))
            })

        case .forkKnife:
            return Drawing(details: [
                // Fork: three tines converging into a stem.
                path {
                    $0.move(to: CGPoint(x: 6, y: 3.4))
                    $0.addLine(to: CGPoint(x: 6, y: 8.4))
                },
                path {
                    $0.move(to: CGPoint(x: 9.8, y: 3.4))
                    $0.addLine(to: CGPoint(x: 9.8, y: 8.4))
                },
                path {
                    $0.move(to: CGPoint(x: 3.6, y: 3.4))
                    $0.addLine(to: CGPoint(x: 3.6, y: 8.4))
                    $0.addCurve(
                        to: CGPoint(x: 6.7, y: 11.5),
                        control1: CGPoint(x: 3.6, y: 10.1),
                        control2: CGPoint(x: 5, y: 11.5)
                    )
                    $0.addLine(to: CGPoint(x: 9.1, y: 11.5))
                    $0.addCurve(
                        to: CGPoint(x: 12.2, y: 8.4),
                        control1: CGPoint(x: 10.8, y: 11.5),
                        control2: CGPoint(x: 12.2, y: 10.1)
                    )
                    $0.addLine(to: CGPoint(x: 12.2, y: 3.4))
                },
                path {
                    $0.move(to: CGPoint(x: 7.9, y: 11.8))
                    $0.addLine(to: CGPoint(x: 7.9, y: 20.6))
                },
                // Knife: a blade tapering into its own handle.
                path {
                    $0.move(to: CGPoint(x: 17.6, y: 20.6))
                    $0.addLine(to: CGPoint(x: 17.6, y: 3.4))
                    $0.addCurve(
                        to: CGPoint(x: 17.6, y: 13.6),
                        control1: CGPoint(x: 21.6, y: 5.6),
                        control2: CGPoint(x: 21.6, y: 13.6)
                    )
                }
            ])

        case .star:
            return Drawing(silhouette: star(points: 5, outer: 9.1, inner: 3.95, center: CGPoint(x: 12, y: 12.4)))

        case .textLines:
            // Left-aligned running text: four rules, the last one short, so it reads as a
            // paragraph rather than as a list.
            return Drawing(details: [
                line(y: 5.4, from: 3.6, to: 20.4),
                line(y: 10, from: 3.6, to: 20.4),
                line(y: 14.6, from: 3.6, to: 20.4),
                line(y: 19.2, from: 3.6, to: 13.8)
            ])

        case .copy:
            return Drawing(
                silhouette: roundedRect(x: 8.2, y: 3.2, width: 12.6, height: 12.6, radius: 2.8),
                details: [path {
                    $0.move(to: CGPoint(x: 15.8, y: 20.8))
                    $0.addLine(to: CGPoint(x: 6, y: 20.8))
                    $0.addCurve(
                        to: CGPoint(x: 3.2, y: 18),
                        control1: CGPoint(x: 4.5, y: 20.8),
                        control2: CGPoint(x: 3.2, y: 19.5)
                    )
                    $0.addLine(to: CGPoint(x: 3.2, y: 8.2))
                }]
            )

        case .mappin:
            // Teardrop with a punched eye. The eye is a detail, so a filled pin shows a
            // hole rather than going solid and losing its identity.
            return Drawing(
                silhouette: path {
                    $0.move(to: CGPoint(x: 12, y: 21))
                    $0.addCurve(
                        to: CGPoint(x: 19, y: 10.2),
                        control1: CGPoint(x: 16.7, y: 15.6),
                        control2: CGPoint(x: 19, y: 12.4)
                    )
                    $0.addCurve(
                        to: CGPoint(x: 5, y: 10.2),
                        control1: CGPoint(x: 19, y: 3.1),
                        control2: CGPoint(x: 5, y: 3.1)
                    )
                    $0.addCurve(
                        to: CGPoint(x: 12, y: 21),
                        control1: CGPoint(x: 5, y: 12.4),
                        control2: CGPoint(x: 7.3, y: 15.6)
                    )
                    $0.closeSubpath()
                },
                details: [Path(ellipseIn: CGRect(x: 9.4, y: 7.6, width: 5.2, height: 5.2))]
            )

        case .location:
            // The send/navigate dart, with a notched tail so it is never mistaken for a
            // play triangle.
            return Drawing(silhouette: path {
                $0.move(to: CGPoint(x: 20.6, y: 3.4))
                $0.addLine(to: CGPoint(x: 3.4, y: 10.6))
                $0.addLine(to: CGPoint(x: 11.2, y: 12.8))
                $0.addLine(to: CGPoint(x: 13.4, y: 20.6))
                $0.closeSubpath()
            })

        case .clock:
            return Drawing(
                silhouette: Path(ellipseIn: CGRect(x: 3, y: 3, width: 18, height: 18)),
                details: [path {
                    $0.move(to: CGPoint(x: 12, y: 7.2))
                    $0.addLine(to: CGPoint(x: 12, y: 12.4))
                    $0.addLine(to: CGPoint(x: 15.8, y: 14.6))
                }]
            )

        case .history:
            // A clock whose dial is an arrow coming back round — "what already happened".
            return Drawing(details: [
                path {
                    $0.addArc(
                        center: CGPoint(x: 12, y: 12),
                        radius: 8.6,
                        startAngle: .degrees(-55),
                        endAngle: .degrees(190),
                        clockwise: false
                    )
                },
                path {
                    $0.move(to: CGPoint(x: 3.4, y: 8.2))
                    $0.addLine(to: CGPoint(x: 3.4, y: 13.2))
                    $0.addLine(to: CGPoint(x: 8.4, y: 13.2))
                },
                path {
                    $0.move(to: CGPoint(x: 12, y: 7.6))
                    $0.addLine(to: CGPoint(x: 12, y: 12.3))
                    $0.addLine(to: CGPoint(x: 15.4, y: 14.3))
                }
            ])

        case .gear:
            return Drawing(
                silhouette: cog(teeth: 8, outer: 9.9, root: 7.5, toothWidth: 0.42, center: CGPoint(x: 12, y: 12)),
                details: [Path(ellipseIn: CGRect(x: 8.6, y: 8.6, width: 6.8, height: 6.8))]
            )

        case .envelope:
            return Drawing(
                silhouette: roundedRect(x: 2.6, y: 5, width: 18.8, height: 14, radius: 2.8),
                details: [path {
                    $0.move(to: CGPoint(x: 3.4, y: 7))
                    $0.addLine(to: CGPoint(x: 12, y: 13.4))
                    $0.addLine(to: CGPoint(x: 20.6, y: 7))
                }]
            )

        case .document:
            // Page with a turned corner, and ruled lines that stop short of it.
            return Drawing(
                silhouette: path {
                    $0.move(to: CGPoint(x: 13.6, y: 2.8))
                    $0.addLine(to: CGPoint(x: 6.6, y: 2.8))
                    $0.addCurve(
                        to: CGPoint(x: 4.4, y: 5),
                        control1: CGPoint(x: 5.4, y: 2.8),
                        control2: CGPoint(x: 4.4, y: 3.8)
                    )
                    $0.addLine(to: CGPoint(x: 4.4, y: 19))
                    $0.addCurve(
                        to: CGPoint(x: 6.6, y: 21.2),
                        control1: CGPoint(x: 4.4, y: 20.2),
                        control2: CGPoint(x: 5.4, y: 21.2)
                    )
                    $0.addLine(to: CGPoint(x: 17.4, y: 21.2))
                    $0.addCurve(
                        to: CGPoint(x: 19.6, y: 19),
                        control1: CGPoint(x: 18.6, y: 21.2),
                        control2: CGPoint(x: 19.6, y: 20.2)
                    )
                    $0.addLine(to: CGPoint(x: 19.6, y: 8.8))
                    $0.closeSubpath()
                },
                details: [
                    path {
                        $0.move(to: CGPoint(x: 13.6, y: 2.8))
                        $0.addLine(to: CGPoint(x: 13.6, y: 8.8))
                        $0.addLine(to: CGPoint(x: 19.6, y: 8.8))
                    },
                    line(y: 13.4, from: 8, to: 16),
                    line(y: 17, from: 8, to: 16)
                ]
            )

        case .lock:
            return Drawing(
                silhouette: roundedRect(x: 4.4, y: 10.4, width: 15.2, height: 10.8, radius: 2.8),
                details: [path {
                    $0.move(to: CGPoint(x: 7.8, y: 10.4))
                    $0.addLine(to: CGPoint(x: 7.8, y: 7.4))
                    $0.addCurve(
                        to: CGPoint(x: 16.2, y: 7.4),
                        control1: CGPoint(x: 7.8, y: 1.8),
                        control2: CGPoint(x: 16.2, y: 1.8)
                    )
                    $0.addLine(to: CGPoint(x: 16.2, y: 10.4))
                }]
            )

        case .handRaised:
            // An open palm. Blocking is a human gesture, so the glyph is a hand rather
            // than a prohibition sign — the slash variant supplies the "no".
            return Drawing(silhouette: path {
                $0.move(to: CGPoint(x: 7, y: 12.2))
                $0.addLine(to: CGPoint(x: 7, y: 5.4))
                $0.addCurve(
                    to: CGPoint(x: 9.8, y: 5.4),
                    control1: CGPoint(x: 7, y: 3.5),
                    control2: CGPoint(x: 9.8, y: 3.5)
                )
                $0.addLine(to: CGPoint(x: 9.8, y: 11))
                $0.addLine(to: CGPoint(x: 9.8, y: 4.2))
                $0.addCurve(
                    to: CGPoint(x: 12.6, y: 4.2),
                    control1: CGPoint(x: 9.8, y: 2.3),
                    control2: CGPoint(x: 12.6, y: 2.3)
                )
                $0.addLine(to: CGPoint(x: 12.6, y: 11))
                $0.addLine(to: CGPoint(x: 12.6, y: 5))
                $0.addCurve(
                    to: CGPoint(x: 15.4, y: 5),
                    control1: CGPoint(x: 12.6, y: 3.1),
                    control2: CGPoint(x: 15.4, y: 3.1)
                )
                $0.addLine(to: CGPoint(x: 15.4, y: 11.8))
                $0.addLine(to: CGPoint(x: 15.4, y: 8.4))
                $0.addCurve(
                    to: CGPoint(x: 18.2, y: 8.4),
                    control1: CGPoint(x: 15.4, y: 6.5),
                    control2: CGPoint(x: 18.2, y: 6.5)
                )
                $0.addLine(to: CGPoint(x: 18.2, y: 15))
                $0.addCurve(
                    to: CGPoint(x: 11.8, y: 21.4),
                    control1: CGPoint(x: 18.2, y: 18.6),
                    control2: CGPoint(x: 15.4, y: 21.4)
                )
                $0.addCurve(
                    to: CGPoint(x: 6.2, y: 17.4),
                    control1: CGPoint(x: 9.2, y: 21.4),
                    control2: CGPoint(x: 7.2, y: 19.8)
                )
                $0.addLine(to: CGPoint(x: 4.6, y: 13.8))
                $0.addCurve(
                    to: CGPoint(x: 7, y: 12.2),
                    control1: CGPoint(x: 3.8, y: 12),
                    control2: CGPoint(x: 6.2, y: 10.6)
                )
                $0.closeSubpath()
            })

        case .flag:
            // Pennant on a staff. The fly is notched so it reads as a flag at 13pt, where
            // a plain rectangle would read as a rule.
            return Drawing(
                silhouette: path {
                    $0.move(to: CGPoint(x: 5.6, y: 4))
                    $0.addLine(to: CGPoint(x: 18.6, y: 4))
                    $0.addLine(to: CGPoint(x: 15.6, y: 8.9))
                    $0.addLine(to: CGPoint(x: 18.6, y: 13.8))
                    $0.addLine(to: CGPoint(x: 5.6, y: 13.8))
                    $0.closeSubpath()
                },
                details: [path {
                    $0.move(to: CGPoint(x: 5.6, y: 3.2))
                    $0.addLine(to: CGPoint(x: 5.6, y: 20.8))
                }]
            )

        case .signal:
            // Broadcast arcs. Paired with `.slashed` this is the offline state, which is
            // why the arcs are open rather than a filled wedge.
            return Drawing(
                details: [
                    arc(radius: 4.4, spread: 52),
                    arc(radius: 8, spread: 52),
                    arc(radius: 11.6, spread: 52)
                ],
                dots: [Dot(center: CGPoint(x: 12, y: 18.2), radius: 1.7)]
            )

        case .exclamation:
            return Drawing(
                details: [path {
                    $0.move(to: CGPoint(x: 12, y: 5.6))
                    $0.addLine(to: CGPoint(x: 12, y: 13.8))
                }],
                dots: [Dot(center: CGPoint(x: 12, y: 18.2), radius: 1.55)]
            )

        case .warning:
            // Triangle with softened vertices — the round join everywhere else in the
            // family would look wrong against three sharp corners.
            return Drawing(
                silhouette: path {
                    $0.move(to: CGPoint(x: 12, y: 3.4))
                    $0.addLine(to: CGPoint(x: 21.4, y: 19.6))
                    $0.addLine(to: CGPoint(x: 2.6, y: 19.6))
                    $0.closeSubpath()
                },
                details: [path {
                    $0.move(to: CGPoint(x: 12, y: 9.8))
                    $0.addLine(to: CGPoint(x: 12, y: 14.4))
                }],
                dots: [Dot(center: CGPoint(x: 12, y: 17.3), radius: 1.35)]
            )

        case .seal:
            // Scalloped rosette with a check inside: the verified mark.
            return Drawing(
                silhouette: scallop(lobes: 11, outer: 9.8, inner: 8.1, center: CGPoint(x: 12, y: 12)),
                details: [path {
                    $0.move(to: CGPoint(x: 7.8, y: 12.2))
                    $0.addLine(to: CGPoint(x: 10.8, y: 15.2))
                    $0.addLine(to: CGPoint(x: 16.2, y: 9))
                }]
            )

        case .checkbox:
            return Drawing(
                silhouette: roundedRect(x: 3.4, y: 3.4, width: 17.2, height: 17.2, radius: 4.4),
                details: [path {
                    $0.move(to: CGPoint(x: 7.6, y: 12.2))
                    $0.addLine(to: CGPoint(x: 10.7, y: 15.3))
                    $0.addLine(to: CGPoint(x: 16.4, y: 8.8))
                }]
            )
        }
    }

    // MARK: Path helpers

    private static func path(_ build: (inout Path) -> Void) -> Path {
        var p = Path()
        build(&p)
        return p
    }

    private static func line(y: CGFloat, from x0: CGFloat, to x1: CGFloat) -> Path {
        path {
            $0.move(to: CGPoint(x: x0, y: y))
            $0.addLine(to: CGPoint(x: x1, y: y))
        }
    }

    private static func roundedRect(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, radius: CGFloat) -> Path {
        Path(roundedRect: CGRect(x: x, y: y, width: width, height: height), cornerRadius: radius, style: .continuous)
    }

    /// Head and shoulders as one closed outline, so `.filled` yields a solid figure.
    private static func personSilhouette(
        center: CGFloat,
        headRadius: CGFloat,
        headY: CGFloat,
        shoulderY: CGFloat,
        halfWidth: CGFloat
    ) -> Path {
        path {
            $0.addEllipse(in: CGRect(
                x: center - headRadius,
                y: headY - headRadius,
                width: headRadius * 2,
                height: headRadius * 2
            ))
            // The torso is a separate closed subpath rather than a continuation, which
            // keeps the neck from pinching when the shape is filled.
            $0.move(to: CGPoint(x: center - halfWidth, y: shoulderY))
            $0.addCurve(
                to: CGPoint(x: center + halfWidth, y: shoulderY),
                control1: CGPoint(x: center - halfWidth, y: shoulderY - 7.4),
                control2: CGPoint(x: center + halfWidth, y: shoulderY - 7.4)
            )
            $0.closeSubpath()
        }
    }

    /// Rounded speech bubble with a tail dropped from its lower-left.
    private static func roundedBubble(
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        height: CGFloat,
        radius: CGFloat,
        tailX: CGFloat,
        tailDrop: CGFloat
    ) -> Path {
        path {
            $0.addPath(roundedRect(x: x, y: y, width: width, height: height, radius: radius))
            $0.move(to: CGPoint(x: tailX, y: y + height - 0.4))
            $0.addLine(to: CGPoint(x: tailX, y: y + height + tailDrop))
            $0.addLine(to: CGPoint(x: tailX + tailDrop * 1.25, y: y + height - 0.4))
            $0.closeSubpath()
        }
    }

    private static func star(points: Int, outer: CGFloat, inner: CGFloat, center: CGPoint) -> Path {
        path {
            for i in 0..<(points * 2) {
                let radius = i.isMultiple(of: 2) ? outer : inner
                let angle = -CGFloat.pi / 2 + CGFloat(i) * .pi / CGFloat(points)
                let point = CGPoint(
                    x: center.x + cos(angle) * radius,
                    y: center.y + sin(angle) * radius
                )
                i == 0 ? $0.move(to: point) : $0.addLine(to: point)
            }
            $0.closeSubpath()
        }
    }

    /// Cog outline: alternating tooth crests and roots around the centre.
    private static func cog(teeth: Int, outer: CGFloat, root: CGFloat, toothWidth: CGFloat, center: CGPoint) -> Path {
        path {
            let step = 2 * CGFloat.pi / CGFloat(teeth)
            for i in 0..<teeth {
                let mid = -CGFloat.pi / 2 + CGFloat(i) * step
                let half = step * toothWidth / 2
                let gap = step * (1 - toothWidth) / 2
                let corners = [
                    (mid - half, outer), (mid + half, outer),
                    (mid + half + gap, root), (mid + step - half - gap, root)
                ]
                for (index, corner) in corners.enumerated() {
                    let point = CGPoint(
                        x: center.x + cos(corner.0) * corner.1,
                        y: center.y + sin(corner.0) * corner.1
                    )
                    (i == 0 && index == 0) ? $0.move(to: point) : $0.addLine(to: point)
                }
            }
            $0.closeSubpath()
        }
    }

    /// Scalloped disc used for the verification seal.
    private static func scallop(lobes: Int, outer: CGFloat, inner: CGFloat, center: CGPoint) -> Path {
        path {
            let step = 2 * CGFloat.pi / CGFloat(lobes)
            for i in 0..<lobes {
                let angle = -CGFloat.pi / 2 + CGFloat(i) * step
                let next = angle + step
                let crest = CGPoint(x: center.x + cos(angle) * outer, y: center.y + sin(angle) * outer)
                let nextCrest = CGPoint(x: center.x + cos(next) * outer, y: center.y + sin(next) * outer)
                let valley = angle + step / 2
                let control = CGPoint(
                    x: center.x + cos(valley) * inner * 0.92,
                    y: center.y + sin(valley) * inner * 0.92
                )
                i == 0 ? $0.move(to: crest) : ()
                $0.addQuadCurve(to: nextCrest, control: control)
            }
            $0.closeSubpath()
        }
    }

    /// One broadcast arc, opening upward from the source dot.
    private static func arc(radius: CGFloat, spread: CGFloat) -> Path {
        path {
            $0.addArc(
                center: CGPoint(x: 12, y: 18.2),
                radius: radius,
                startAngle: .degrees(180 + spread),
                endAngle: .degrees(360 - spread),
                clockwise: false
            )
        }
    }
}
