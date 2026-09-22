import SwiftUI

/// Read-only re-view of the EULA a user already accepted during onboarding.
struct LicenseAgreementView: View {
    var body: some View {
        ScrollView {
            Text(eulaText)
                .font(BumpFont.callout)
                .foregroundStyle(BumpColor.textSecondary)
                .padding(BumpSpacing.l)
        }
        .background(BumpColor.surface)
        .navigationTitle("License Agreement")
        .navigationBarTitleDisplayMode(.inline)
    }
}
