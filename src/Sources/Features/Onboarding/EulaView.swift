import SwiftUI

/// Apple's standard EULA (the Minimum Terms every app implicitly agrees to unless a
/// custom one is supplied): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
let eulaText = """
a. Scope of License: Licensor grants to you a nontransferable license to use the Application \
on any Apple-branded Products that you own or control and as permitted by the Usage Rules set \
forth in the App Store Terms of Service. This license does not allow you to use the \
Application on any Apple-branded Product that you do not own or control, and, except as \
permitted by the Usage Rules, you may not distribute or make the Application available over a \
network where it could be used by multiple devices at the same time. You may not transfer, \
redistribute or sublicense the Application and, if you sell your Apple Device to a third \
party, you must remove the Application from the Apple Device before doing so. You may not \
copy (except as permitted by this license and the Usage Rules), reverse-engineer, \
disassemble, attempt to derive the source code of, modify, or create derivative works of the \
Application, any updates, or any part thereof (except as and only to the extent any foregoing \
restriction is prohibited by applicable law or to the extent as may be permitted by the \
licensing terms governing use of any open-sourced components included with the Application).

b. Consent to Use of Data: You agree that Licensor may collect and use technical data and \
related information, including but not limited to technical information about your device, \
system and application software, and peripherals, that is gathered periodically to \
facilitate the provision of software updates, product support, and other services to you \
(if any) related to the Application. Licensor may use this information, as long as it is in a \
form that does not personally identify you, to improve its products or to provide services or \
technologies to you.

c. Termination: This license is effective until terminated by you or Licensor. Your rights \
under this license will terminate automatically if you fail to comply with any of its terms.

d. External Services: The Application may enable access to Licensor's and/or third-party \
services and websites (collectively and individually, "External Services"). You agree to use \
the External Services at your sole risk. Licensor is not responsible for examining or \
evaluating the content or accuracy of any third-party External Services, and shall not be \
liable for any such third-party External Services.

e. NO WARRANTY: YOU EXPRESSLY ACKNOWLEDGE AND AGREE THAT USE OF THE APPLICATION IS AT YOUR \
SOLE RISK. TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE LAW, THE APPLICATION AND ANY SERVICES \
PERFORMED OR PROVIDED BY THE APPLICATION ARE PROVIDED "AS IS" AND "AS AVAILABLE", WITH ALL \
FAULTS AND WITHOUT WARRANTY OF ANY KIND, AND LICENSOR HEREBY DISCLAIMS ALL WARRANTIES AND \
CONDITIONS WITH RESPECT TO THE APPLICATION, EITHER EXPRESS, IMPLIED OR STATUTORY.

f. Limitation of Liability: TO THE EXTENT NOT PROHIBITED BY LAW, IN NO EVENT SHALL LICENSOR BE \
LIABLE FOR PERSONAL INJURY, OR ANY INCIDENTAL, SPECIAL, INDIRECT OR CONSEQUENTIAL DAMAGES \
WHATSOEVER, ARISING OUT OF OR RELATED TO YOUR USE OF OR INABILITY TO USE THE APPLICATION. IN \
NO EVENT SHALL LICENSOR'S TOTAL LIABILITY TO YOU FOR ALL DAMAGES EXCEED THE AMOUNT OF FIFTY \
DOLLARS ($50.00). THE FOREGOING LIMITATIONS WILL APPLY EVEN IF THE ABOVE STATED REMEDY FAILS \
OF ITS ESSENTIAL PURPOSE.

g. Export Restrictions: You may not use or otherwise export or reexport the Application \
except as authorized by United States law and the laws of the jurisdiction in which the \
Application was obtained. In particular, the Application may not be exported or re-exported \
into any U.S. embargoed countries, or to anyone on the U.S. Treasury Department's Specially \
Designated Nationals List or the U.S. Department of Commerce Denied Persons List or Entity \
List. By using the Application, you represent and warrant that you are not located in any \
such country or on any such list.

h. Government End Users: The Application and related documentation are "Commercial Items", \
consisting of "Commercial Computer Software" and "Commercial Computer Software Documentation", \
and are being licensed to U.S. Government end users only as Commercial Items, with only those \
rights granted to all other end users under these terms.

i. Governing Law: Except to the extent expressly provided in the paragraph above, this \
Agreement and the relationship between you and Licensor shall be governed by the laws of the \
State of California, excluding its conflicts of law provisions. You and Licensor agree to \
submit to the personal and exclusive jurisdiction of the courts located within the county of \
Santa Clara, California, to resolve any dispute or claim arising from this Agreement, except \
that if you are a consumer residing in a jurisdiction of the European Union, the foregoing \
governing law and forum selection provisions may not apply to you, and you may be able to \
bring a claim in your local courts and be entitled to the protection of the mandatory \
provisions of the law of your country of residence.

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
