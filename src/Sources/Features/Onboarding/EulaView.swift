import SwiftUI

/// Apple's standard EULA (the Minimum Terms every app implicitly agrees to unless a
/// custom one is supplied): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
let eulaText = """
This application is licensed to You for use only under the terms of this License Agreement. \
The Application is licensed, not sold, to You by Bump for use strictly in accordance with the \
terms of this Agreement.

1. The Application may be used only on Apple-branded products or devices that run iOS, \
as applicable, and are owned or controlled by You, and as permitted by the Usage Rules set \
forth in the App Store Terms of Service.

2. You shall not, and shall not permit any third party, to copy, modify, or create derivative \
works of the Application, in whole or in part; or decompile, reverse engineer, disassemble, \
attempt to derive the source code of, decrypt, or otherwise attempt to derive the source code \
of the Application, except as permitted by applicable law.

3. You shall not rent, lease, lend, sell, redistribute, or sublicense the Application, and if \
You sell your device to a third party, you must remove the Application before doing so.

4. Bump is responsible for addressing any claims by You or any third party relating to the \
Application, including product liability claims, claims under consumer protection law, and \
claims under intellectual property law.

5. In the event of any failure of the Application to conform to any applicable warranty, You \
may notify Apple, and Apple will refund the purchase price (if any) for the Application; to \
the maximum extent permitted by law, Apple has no other warranty obligation with respect to \
the Application, and any other claims, losses, liabilities, damages, costs, or expenses \
attributable to any failure to conform to any warranty will be solely governed by this \
Agreement.

6. Bump, not Apple, is responsible for addressing any claims by You relating to the \
Application or Your possession and/or use of the Application, including: (i) product \
liability claims; (ii) any claim that the Application fails to conform to any applicable \
legal or regulatory requirement; and (iii) claims arising under consumer protection or \
similar legislation.

7. In the event of any third-party claim that the Application or Your possession and use of \
the Application infringes that third party's intellectual property rights, Bump, not Apple, \
will be solely responsible for the investigation, defense, settlement, and discharge of any \
such claim.

8. You represent and warrant that You are not located in a country subject to a U.S. \
Government embargo, and that You are not listed on any U.S. Government list of prohibited or \
restricted parties.

9. Apple and Apple's subsidiaries are third-party beneficiaries of this Agreement, and upon \
Your acceptance, Apple will have the right to enforce this Agreement against You as a \
third-party beneficiary.

By tapping Accept, you acknowledge that you have read and agree to be bound by this License \
Agreement.
"""

/// Gate shown before a user can register or log in, as required by App Store guidelines
/// for apps with user-generated content. Not dismissible without a choice.
struct EulaView: View {
    var onAccept: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: BumpSpacing.m) {
                    Text("License Agreement")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(BumpColor.textPrimary)

                    Text(eulaText)
                        .font(BumpFont.callout)
                        .foregroundStyle(BumpColor.textSecondary)
                }
                .padding(BumpSpacing.l)
            }

            VStack(spacing: BumpSpacing.m) {
                Button("Accept") {
                    EulaAcceptance.shared.hasAccepted = true
                    onAccept()
                }
                .buttonStyle(.bumpPrimary)

                Button("Decline", role: .destructive) {
                    exit(0)
                }
                .buttonStyle(.bumpText)
            }
            .padding(.horizontal, BumpSpacing.l)
            .padding(.bottom, BumpSpacing.l)
        }
        .background(BumpColor.surface)
        .interactiveDismissDisabled(true)
    }
}
