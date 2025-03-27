import SwiftUI
import FirebaseFirestore
import FirebaseAuth

extension Notification.Name {
    static let couponRedeemed = Notification.Name("couponRedeemed")
}

struct StoreDetailView: View {
    let store: Store
    @Binding var userPoints: Int  // Binding for user's points
    @State private var redeemedCoupons: [String] = [] // Track redeemed coupons
    @State private var selectedTab: String = "Rewards" // Default to Rewards

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
                TabButton(title: "Rewards", selectedTab: $selectedTab)
                TabButton(title: "About", selectedTab: $selectedTab)
            }
            .background(Color(UIColor.systemGray6))
            
            // Tab Content
            ScrollView {
                if selectedTab == "Rewards" {
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
    
    // About Section
    @ViewBuilder
    private func AboutSection() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(store.about.isEmpty ? "No description available." : store.about)
                .font(.body)
                .padding()
        }
    }
    
    // Rewards Section
    @ViewBuilder
    private func RewardsSection() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            
            ForEach(store.coupons) { coupon in
                let isRedeemed = redeemedCoupons.contains(coupon.id)
                CouponRow(coupon: coupon, userPoints: $userPoints, storeId: store.id, isRedeemed: isRedeemed)
            }
        }
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

struct TabButton: View {
    let title: String
    @Binding var selectedTab: String
    
    var body: some View {
        Button(action: { selectedTab = title }) {
            VStack {
                Text(title)
                    .font(.headline)
                    .foregroundColor(selectedTab == title ? .black : .gray)
                Rectangle()
                    .frame(height: 2)
                    .foregroundColor(selectedTab == title ? .green : .clear)
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
    let isRedeemed: Bool
    @State private var isProcessing = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(Int(coupon.discountAmount * 100))% off")
                    .font(.headline)
                    .bold()

                Text("Valid till Apr 07, 2025")
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
                    Image(systemName: "star.fill")
                        .foregroundColor(.green)
                    Text("\(coupon.requiredPoints)")
                        .bold()
                }

                Button(action: redeemCoupon) {
                    Text("Redeem")
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(userPoints >= coupon.requiredPoints ? Color.green : Color.gray)
                        .cornerRadius(10)
                }
                .disabled(userPoints < coupon.requiredPoints)
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
    }

    private func redeemCoupon() {
        guard let user = Auth.auth().currentUser, userPoints >= coupon.requiredPoints else { return }

        isProcessing = true

        let db = Firestore.firestore()
        let userRef = db.collection("users").document(user.uid)

        db.runTransaction({ (transaction, errorPointer) -> Any? in
            let userDocument: DocumentSnapshot
            do {
                userDocument = try transaction.getDocument(userRef)
            } catch {
                errorPointer?.pointee = NSError(domain: "Firestore", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch user document"])
                return nil
            }

            guard let currentPoints = userDocument.data()?["points"] as? Int, currentPoints >= coupon.requiredPoints else {
                errorPointer?.pointee = NSError(domain: "Firestore", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not enough points"])
                return nil
            }

            let newPoints = currentPoints - coupon.requiredPoints
            
            // Fetch the existing redeemedCoupons array
            var redeemedCoupons = userDocument.data()?["redeemedCoupons"] as? [String] ?? []

            // Add the current coupon's ID to the redeemedCoupons array
            redeemedCoupons.append(coupon.id)

            // Update the user's document with new points and redeemedCoupons array
            transaction.updateData([
                "points": newPoints,
                "redeemedCoupons": redeemedCoupons
            ], forDocument: userRef)
            
            return newPoints
        }) { (newPoints, error) in
            DispatchQueue.main.async {
                isProcessing = false
                if let newPoints = newPoints as? Int {
                    userPoints = newPoints // Update points in UI

                    NotificationCenter.default.post(name: .couponRedeemed, object: coupon.id)
                } else if let error = error {
                    print("Transaction failed: \(error.localizedDescription)")
                }
            }
        }
    }
}
