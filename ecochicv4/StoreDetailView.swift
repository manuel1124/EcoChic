import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import SafariServices

extension Notification.Name {
    static let couponRedeemed = Notification.Name("couponRedeemed")
}

struct StoreDetailView: View {
    let store: Store
    @Binding var userPoints: Int  // Binding for user's points
    //@Binding var selectedTab: Tab
    @State private var redeemedCoupons: [String] = [] // Track redeemed coupons
    @State private var selectedSection: String = "Rewards" // Default to Rewards

    var body: some View {
        VStack(spacing: 0) {
            // Store Image & Header
            VStack {
                if let url = URL(string: store.thumbnailUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        case .failure:
                            Color.gray
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        default:
                            ProgressView()
                                .frame(width: 80, height: 80)
                        }
                    }
                }
                
                VStack(spacing: 4) {
                    Text(store.name)
                        .font(.title2)
                        .bold()
                    Text(store.location)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding()

            
            // Tabs
            HStack {
                TabButton(title: "Rewards", selectedSection: $selectedSection)
                TabButton(title: "About", selectedSection: $selectedSection)
            }
            .background(Color(UIColor.systemGray6))
            
            // Tab Content
            ScrollView {
                if selectedSection == "Rewards" {
                    RewardsSection()
                } else {
                    AboutSection()
                }
            }
        }
        .onAppear {
            fetchRedeemedCoupons()
            NotificationCenter.default.addObserver(forName: .couponRedeemed, object: nil, queue: .main) { notification in
                if let couponId = notification.object as? String {
                    redeemedCoupons.append(couponId) // Update state immediately
                }
            }
        }
    }

    @ViewBuilder
    private func AboutSection() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(store.about.isEmpty ? "No description available." : store.about)
                .font(.body)
                .padding(.bottom)

            // Show on Map Button (only if store has a location)
            if let coordinate = store.coordinate {
                Button(action: {
                    openMaps(for: store)
                }) {
                    HStack {
                        Image(systemName: "map.fill")
                        Text("Get Directions")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            }


            // Social Media Links
            if store.website != nil || store.instagram != nil || store.tiktok != nil || store.facebook != nil {
                Text("Follow us on:")
                    .font(.headline)
                    .padding(.top)

                VStack(alignment: .leading, spacing: 8) {
                    if let website = store.website, !website.isEmpty {
                        Link(destination: URL(string: website)!) {
                            Label("Website", systemImage: "globe")
                        }
                    }
                    if let instagram = store.instagram, !instagram.isEmpty {
                        Link(destination: URL(string: instagram)!) {
                            Label("Instagram", systemImage: "camera")
                        }
                    }
                    if let facebook = store.facebook, !facebook.isEmpty {
                        Link(destination: URL(string: facebook)!) {
                            Label("Facebook", systemImage: "f.circle.fill")
                        }
                    }
                    if let tiktok = store.tiktok, !tiktok.isEmpty {
                        Link(destination: URL(string: tiktok)!) {
                            Label("TikTok", systemImage: "music.note")
                        }
                    }
                }
                .font(.body)
                .foregroundColor(.blue)
                .padding(.top, 5)
            }
        }
        .padding()
    }

    
    @ViewBuilder
    private func RewardsSection() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(store.coupons) { coupon in
                CouponRowWrapper(
                    coupon: coupon,
                    userPoints: $userPoints,
                    storeId: store.id,
                    redeemedCoupons: redeemedCoupons
                )
            }
        }
        .id(redeemedCoupons) // ✅ forces re-render when list changes
    }
    
    private func fetchRedeemedCoupons() {
        guard let user = Auth.auth().currentUser else { return }
        let db = Firestore.firestore()
        db.collection("users").document(user.uid).getDocument { snapshot, error in
            if let error = error {
                print("Error fetching redeemed coupons: \(error.localizedDescription)")
                return
            }
            redeemedCoupons = snapshot?.data()?["redeemedCoupons"] as? [String] ?? []
        }
    }
}

struct CouponRowWrapper: View {
    let coupon: Coupon
    @Binding var userPoints: Int
    let storeId: String
    let redeemedCoupons: [String]

    var body: some View {
        let isRedeemed = redeemedCoupons.contains(coupon.id)
        return CouponRow(
            coupon: coupon,
            userPoints: $userPoints,
            storeId: storeId
        )
    }
}


struct TabButton: View {
    let title: String
    @Binding var selectedSection: String
    
    var body: some View {
        Button(action: { selectedSection = title }) {
            VStack {
                Text(title)
                    .font(.headline)
                    .foregroundColor(selectedSection == title ? .black : .gray)
                Rectangle()
                    .frame(height: 2)
                    .foregroundColor(selectedSection == title ? .green : .clear)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
    }
}


struct CouponRow: View {
    let coupon: Coupon
    @Binding var userPoints: Int
    let storeId: String
    @State private var isRedeemed = false
    @State private var isProcessing = false

    private var buttonColor: Color {
        if coupon.available.isEmpty {
            return .gray
        } else {
            return userPoints >= coupon.requiredPoints ? .green : .gray
        }
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(Int(coupon.discountAmount * 100))% off")
                    .font(.headline)
                    .bold()

                Text("Valid till May 14, 2025")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }

            Spacer()

            if isRedeemed {
                Button(action: {}) {
                    Text("Redeemed")
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.gray)
                        .cornerRadius(10)
                }
                .disabled(true)
            } else {
                HStack {
                    Image("points logo") // Use your asset image
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20) // Adjust size as needed
                    Text("\(coupon.requiredPoints)")
                        .bold()
                }

                Button(action: redeemCoupon) {
                    Text(coupon.available.isEmpty ? "Unavailable" : "Redeem")
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(buttonColor)
                        .cornerRadius(10)
                }
                .disabled(coupon.available.isEmpty || userPoints < coupon.requiredPoints)

            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isRedeemed ? Color(hex: "#EAFFE4") : Color(UIColor.systemGray6))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.green, style: StrokeStyle(lineWidth: 2, dash: [6]))
        )
        .padding(.horizontal)
        .padding(.top, 20)
        .onAppear {
                checkIfRedeemed()
            }
    }
    
    private func checkIfRedeemed() {
        guard let user = Auth.auth().currentUser else { return }

        let db = Firestore.firestore()
        db.collection("users").document(user.uid).getDocument { snapshot, error in
            if let error = error {
                print("Error checking redemption: \(error.localizedDescription)")
                return
            }

            if let redeemedDict = snapshot?.data()?["redeemedCoupons"] as? [String: String] {
                if redeemedDict[coupon.id] != nil {
                    isRedeemed = true
                }
            }
        }
    }

    private func redeemCoupon() {
        guard let user = Auth.auth().currentUser, userPoints >= coupon.requiredPoints else { return }
        guard !coupon.available.isEmpty else {
            print("No codes available.")
            return
        }

        isProcessing = true

        let db = Firestore.firestore()
        let userRef = db.collection("users").document(user.uid)
        let couponRef = db.collection("coupons").document(coupon.id)

        db.runTransaction({ (transaction, errorPointer) -> Any? in
            // Fetch user doc
            let userDoc: DocumentSnapshot
            do {
                userDoc = try transaction.getDocument(userRef)
            } catch {
                errorPointer?.pointee = NSError(domain: "Firestore", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch user document"])
                return nil
            }

            guard let currentPoints = userDoc.data()?["points"] as? Int, currentPoints >= coupon.requiredPoints else {
                errorPointer?.pointee = NSError(domain: "Firestore", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not enough points"])
                return nil
            }

            // Fetch coupon doc
            let couponDoc: DocumentSnapshot
            do {
                couponDoc = try transaction.getDocument(couponRef)
            } catch {
                errorPointer?.pointee = NSError(domain: "Firestore", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch coupon document"])
                return nil
            }

            var availableCodes = couponDoc.data()?["available"] as? [String] ?? []
            guard !availableCodes.isEmpty else {
                errorPointer?.pointee = NSError(domain: "Firestore", code: -1, userInfo: [NSLocalizedDescriptionKey: "No coupon codes available"])
                return nil
            }

            // Pop first available code
            let redeemedCode = availableCodes.removeFirst()

            // Update user's redeemedCoupons as a dictionary
            var redeemedCoupons = userDoc.data()?["redeemedCoupons"] as? [String: String] ?? [:]
            redeemedCoupons[coupon.id] = redeemedCode

            // Update both documents
            transaction.updateData([
                "points": currentPoints - coupon.requiredPoints,
                "redeemedCoupons": redeemedCoupons
            ], forDocument: userRef)

            transaction.updateData([
                "available": availableCodes
            ], forDocument: couponRef)

            return currentPoints - coupon.requiredPoints
        }) { result, error in
            DispatchQueue.main.async {
                isProcessing = false
                if let newPoints = result as? Int {
                    userPoints = newPoints
                    isRedeemed = true
                    NotificationCenter.default.post(name: .couponRedeemed, object: coupon.id)
                } else {
                    print("Transaction failed: \(error?.localizedDescription ?? "Unknown error")")
                }
            }
        }
    }

}
