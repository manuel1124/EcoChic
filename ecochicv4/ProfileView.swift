import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ProfileView: View {
    @Environment(AppController.self) private var appController
    @State private var name: String = "Loading..."
    @State private var userEmail: String = "Loading..."
    @State private var userProgress: Int = 0
    @State private var userPoints: Int = 0
    @State private var redeemedCoupons: [RedeemedCoupon] = []
    @State private var showReferralPopup = false

    

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Profile Title & Points Display
                HStack {
                    Text("Profile")
                        .font(.title)
                        .bold()
                        //.padding()

                    Spacer()

                    HStack(spacing: 4) {
                        Image("points logo") // Use your asset image
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20) // Adjust size as needed
                        Text("\(userPoints)")
                            .font(.headline)
                            .bold()
                            .foregroundColor(.black)
                    }
                    .padding(10)
                    .cornerRadius(10)
                }
                .padding([.top, .leading, .trailing])
                
                // Profile Information
                Text(name)
                    .font(.title)
                
                HStack(spacing: 20) {
                    VStack {
                        Text("Lessons\nCompleted")
                            .font(.headline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                        Text("\(userProgress)")
                            .font(.title3)
                    }
                    .frame(maxWidth: .infinity)

                    VStack {
                        Text("Redeemed\nCoupons")
                            .font(.headline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                        Text("\(redeemedCoupons.count)")
                            .font(.title3)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding()
                .background(Color.white)
                .cornerRadius(12)
                .shadow(radius: 2)
                .padding(.horizontal)
                
                // Redeemed Coupons Section
                VStack(alignment: .center, spacing: 12) {
                    Text("Redeemed Coupons")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                        .padding(.top)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.bottom, 10)
                        .overlay(
                            Rectangle()
                                .frame(height: 2)
                                .foregroundColor(.green)
                                .padding(.top, 20)
                                .padding(.horizontal, 40),
                            alignment: .bottom
                        )
                    
                    if redeemedCoupons.isEmpty {
                        Text("No redeemed coupons yet.")
                            .foregroundColor(.gray)
                            .padding()
                    } else {
                        ScrollView {
                            VStack(spacing: 10) {
                                ForEach($redeemedCoupons, id: \.coupon.id) { $redeemedCoupon in
                                    RedeemedCouponRow(
                                        coupon: redeemedCoupon.coupon,
                                        storeThumbnailUrl: redeemedCoupon.storeThumbnailUrl,
                                        isActivated: $redeemedCoupon.isActivated,
                                        activationCode: $redeemedCoupon.activationCode
                                    )
                                }
                            }
                        }
                    }
                    Spacer()
                }
                
                Spacer()

                // Invite a Friend (blue link)
                HStack(spacing: 30) {
                    // Invite a Friend (blue link)
                    if let user = Auth.auth().currentUser {
                        Button(action: {
                            showReferralPopup = true
                        }) {
                            Text("Invite a Friend")
                                .foregroundColor(.blue)
                                //.underline()
                                .font(.body)
                        }
                    }

                    // Logout (red link)
                    Button(action: {
                        do {
                            try appController.signOut()
                        } catch {
                            print("Error signing out: \(error.localizedDescription)")
                        }
                    }) {
                        Text("Logout")
                            .font(.body)
                            .foregroundColor(.red)
                            //.underline()
                    }
                }
                .padding(.bottom, 30)


            }
            .background(Color(.systemGray6))
            .onAppear(perform: fetchUserProfile)
            .overlay(
                Group {
                    if showReferralPopup {
                        ReferralPopup(
                            onRefer: {
                                showReferralPopup = false
                                shareReferralLink()
                            },
                            onCancel: {
                                showReferralPopup = false
                            }
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.spring(), value: showReferralPopup)
                    }
                }
            )

        }
    }
    
    private func shareReferralLink() {
        guard let user = Auth.auth().currentUser else { return }
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(user.uid)

        userRef.getDocument { document, error in
            if let document = document {
                var referralCode = document.data()?["referralCode"] as? String

                // If missing, generate one and save it
                if referralCode == nil {
                    referralCode = UUID().uuidString.prefix(6).uppercased()
                    userRef.setData(["referralCode": referralCode!], merge: true) { error in
                        if let error = error {
                            print("Failed to set referral code: \(error.localizedDescription)")
                            return
                        }
                        // After setting it, show the share sheet
                        presentShareSheet(with: referralCode!)
                    }
                } else {
                    // Code exists — show the share sheet
                    presentShareSheet(with: referralCode!)
                }
            } else {
                print("Error fetching user data: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }
    
    private func presentShareSheet(with referralCode: String) {
        let link = "ecochic://referral?ref=\(referralCode)"
        
        let message = """
        Hey! 🌱 I've been using EcoChic to earn rewards for sustainable choices. 
        Use my referral code **\(referralCode)** when signing up in the app to get a bonus 2,500 points!

        Tap this link to get started: \(link)
        """

        let activityVC = UIActivityViewController(activityItems: [message], applicationActivities: nil)
        
        // Must present on main thread
        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(activityVC, animated: true, completion: nil)
            }
        }
    }


    private func fetchUserProfile() {
        guard let user = Auth.auth().currentUser else { return }
        userEmail = user.email ?? "No Email"

        let db = Firestore.firestore()
        let userRef = db.collection("users").document(user.uid)

        userRef.getDocument { document, error in
            if let document = document, document.exists {
                let data = document.data()
                name = data?["name"] as? String ?? "No Name"
                userProgress = data?["progress"] as? Int ?? 0
                userPoints = data?["points"] as? Int ?? 0
                let activatedCoupons = data?["activatedCoupons"] as? [String: String] ?? [:] // Now stores activation codes

                if let redeemedDict = data?["redeemedCoupons"] as? [String: String] {
                    fetchRedeemedCoupons(redeemedDict: redeemedDict, activatedCoupons: activatedCoupons)
                }
            } else {
                print("Error fetching user profile: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }

    private func fetchRedeemedCoupons(redeemedDict: [String: String], activatedCoupons: [String: String]) {
        let db = Firestore.firestore()

        db.collection("coupons").getDocuments { couponSnapshot, error in
            if let error = error {
                print("Error fetching coupons: \(error.localizedDescription)")
                return
            }

            db.collection("stores").getDocuments { storeSnapshot, storeError in
                if let storeError = storeError {
                    print("Error fetching stores: \(storeError.localizedDescription)")
                    return
                }

                let allStores = storeSnapshot?.documents.compactMap { doc -> (couponId: String, thumbnailUrl: String)? in
                    guard let couponId = doc.data()["couponId"] as? String,
                          let thumbnailUrl = doc.data()["thumbnailUrl"] as? String else {
                        return nil
                    }
                    return (couponId, thumbnailUrl)
                } ?? []

                var fetchedCoupons: [RedeemedCoupon] = []

                for document in couponSnapshot?.documents ?? [] {
                    let data = document.data()
                    let couponId = document.documentID

                    guard let redeemedCode = redeemedDict[couponId] else { continue }

                    let requiredPoints = data["requiredPoints"] as? Int ?? 0
                    let discountAmount = data["discountAmount"] as? Double ?? 0.0
                    let available = data["available"] as? [String] ?? []

                    let storeThumbnailUrl = allStores.first(where: { $0.couponId == couponId })?.thumbnailUrl ?? ""

                    let coupon = Coupon(
                        id: couponId,
                        requiredPoints: requiredPoints,
                        discountAmount: discountAmount,
                        available: available
                    )

                    let isActivated = activatedCoupons[couponId] != nil
                    let activationCode = activatedCoupons[couponId] ?? redeemedCode

                    fetchedCoupons.append(RedeemedCoupon(
                        coupon: coupon,
                        storeThumbnailUrl: storeThumbnailUrl,
                        isActivated: isActivated,
                        activationCode: activationCode
                    ))
                }

                DispatchQueue.main.async {
                    self.redeemedCoupons = fetchedCoupons
                }
            }
        }
    }


}

// Reusable profile row component
struct ProfileRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label + ":")
                .font(.headline)
                .foregroundColor(.black)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding(.vertical, 5)
    }
}

struct RedeemedCoupon {
    var coupon: Coupon
    var storeThumbnailUrl: String
    var isActivated: Bool = false
    var activationCode: String? = nil
}

struct RedeemedCouponRow: View {
    let coupon: Coupon
    let storeThumbnailUrl: String
    @Binding var isActivated: Bool
    @Binding var activationCode: String?

    var body: some View {
        HStack {
            // Store Thumbnail
            if let url = URL(string: storeThumbnailUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 50, height: 50)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray, lineWidth: 1))
                    case .failure:
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 50, height: 50)
                            .overlay(Image(systemName: "photo").foregroundColor(.white))
                    default:
                        ProgressView()
                            .frame(width: 50, height: 50)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("\(Int(coupon.discountAmount * 100))% off")
                    .font(.headline)
                    .bold()

                Text("Valid till May 14, 2025")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            Spacer()

            // Button shows the activation code when activated, otherwise it shows "Activate"
            if isActivated {
                Text("\(activationCode ?? "N/A")")
                    .padding(.horizontal, 15)
                    .padding(.vertical, 5)
                    .background(Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            } else {
                Button(action: activateCoupon) {
                    Text("Activate")
                        .padding(.horizontal, 15)
                        .padding(.vertical, 5)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
        }
        .padding()
        .background(isActivated ? Color.clear : Color(hex: "#EAFFE4"))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isActivated ? Color.gray : Color.green, style: StrokeStyle(lineWidth: 2, dash: [6]))
        )
        .padding(.horizontal)
        .padding(.top, 20)
    }

    private func activateCoupon() {
        guard let user = Auth.auth().currentUser else { return }
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(user.uid)

        guard let existingCode = activationCode else {
            print("No redeemed code found.")
            return
        }

        isActivated = true

        userRef.updateData([
            "activatedCoupons.\(coupon.id)": existingCode
        ]) { error in
            if let error = error {
                print("Error saving activation code: \(error.localizedDescription)")
            } else {
                print("Coupon \(coupon.id) activated with code \(existingCode).")
            }
        }
    }


}

struct ReferralPopup: View {
    var onRefer: () -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "gift.fill")
                .font(.system(size: 30))
                .foregroundColor(.green)

            Text("Refer a Friend")
                .font(.headline)

            Text("You and your friend will both earn 2,500 points! 🎉")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            HStack(spacing: 16) {
                Button("Cancel") {
                    onCancel()
                }
                .font(.subheadline)
                .padding(.vertical, 8)
                .padding(.horizontal, 20)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
                .foregroundColor(.black)

                Button("Refer") {
                    onRefer()
                }
                .font(.subheadline)
                .padding(.vertical, 8)
                .padding(.horizontal, 20)
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
        .padding()
        .background(.white)
        .cornerRadius(16)
        .shadow(radius: 10)
        .frame(maxWidth: 300)
    }
}
