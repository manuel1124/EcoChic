import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Privacy Policy")
                    .font(.title)
                    .bold()
                
                Text("""
This privacy policy applies to the EcoChic app (hereby referred to as "Application") for mobile devices that was created by ECOCHIC INNOVATIONS INC. as a Free service. This service is intended for use "AS IS".

**Information Collection and Use**
The Application collects information when you download and use it. This may include:
- Your device’s IP address
- Pages visited, date/time, and time spent
- Device OS and approximate location

Location data is used for:
- Geolocation Services
- Analytics and performance improvements
- (Optionally) sent to trusted third-party services

We may contact you with important info, required notices, or marketing promotions.

**Third Party Access**
Only anonymized data is shared periodically to improve our services. We may disclose data:
- As required by law
- To protect rights/safety
- To trusted service providers

**Opt-Out Rights**
You can stop info collection by uninstalling the app.

**Data Retention**
We retain data while you use the app and for a reasonable time afterward. To delete data, email info@ecochicapp.com.

**Children**
We do not knowingly collect data from children under 13. Contact us if this occurs.

**Security**
We implement physical, electronic, and procedural safeguards.

**Changes**
We may update this policy. Continued use implies consent.

**Contact Us**
info@ecochicapp.com
""")
                    .font(.body)
                    .foregroundColor(.primary)
            }
            .padding()
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }
}
