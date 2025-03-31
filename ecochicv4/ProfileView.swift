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
                
                // Lessons Completed & Coupons Redeemed
                HStack(spacing: 20) {
                    VStack {
                        Text("Lessons Completed")
                            .font(.headline)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                        Text("\(userProgress)")
                            .font(.title3)
                    }
                    VStack {
                        Text("Redeemed Coupons")
                            .font(.headline)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                        Text("\(redeemedCoupons.count)")
                            .font(.title3)
                    }
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
                
                // Logout Button
                Button(action: {
                    do {
                        try appController.signOut()
                    } catch {
                        print("Error signing out: \(error.localizedDescription)")
                    }
                }) {
                    Text("Logout")
                        .fontWeight(.bold)
                        .frame(maxWidth: 150)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 20)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(25)
                }
                .padding(.bottom, 20)
            }
            .background(Color(.systemGray6))
            .onAppear(perform: fetchUserProfile)
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

                if let redeemedCouponIds = data?["redeemedCoupons"] as? [String] {
                    fetchRedeemedCoupons(redeemedCouponIds: redeemedCouponIds)
                }
            } else {
                print("Error fetching user profile: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }

    private func fetchRedeemedCoupons(redeemedCouponIds: [String]) {
        let db = Firestore.firestore()
        db.collection("stores").getDocuments { snapshot, error in
            if let error = error {
                print("Error fetching stores: \(error.localizedDescription)")
                return
            }

            var fetchedCoupons: [RedeemedCoupon] = []

            for document in snapshot?.documents ?? [] {
                let storeData = document.data()
                if let couponsArray = storeData["coupons"] as? [[String: Any]],
                   let storeThumbnailUrl = storeData["thumbnailUrl"] as? String {
                    for couponData in couponsArray {
                        if let couponId = couponData["id"] as? String,
                           redeemedCouponIds.contains(couponId) {
                            
                            let coupon = Coupon(
                                id: couponId,
                                requiredPoints: couponData["requiredPoints"] as? Int ?? 0,
                                discountAmount: couponData["discountAmount"] as? Double ?? 0.0,
                                applicableItems: couponData["applicableItems"] as? [String] ?? [],
                                description: couponData["description"] as? String ?? ""
                            )
                            
                            fetchedCoupons.append(RedeemedCoupon(coupon: coupon, storeThumbnailUrl: storeThumbnailUrl))
                        }
                    }
                }
            }

            DispatchQueue.main.async {
                self.redeemedCoupons = fetchedCoupons
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

                Text("Valid till Apr 07, 2025")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            Spacer()

            // Button shows the activation code when activated, otherwise it shows "Activate"
            if isActivated {
                Text("\(activationCode ?? "N/A")")
                    .padding(.horizontal, 15)
                    .padding(.vertical, 5)
                    .background(Color.blue)
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
        .background(isActivated ? Color.gray.opacity(0.3) : Color(hex: "#EAFFE4")) // Light green background
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isActivated ? Color.gray : Color.green, style: StrokeStyle(lineWidth: 2, dash: [6]))
        )
        .padding(.horizontal)
        .padding(.top, 20)
    }

    private func activateCoupon() {
        activationCode = String((0..<5).map { _ in "ABCDEFGHIJKLMNOPQRSTUVWXYZ".randomElement()! })
        isActivated = true
    }
}
