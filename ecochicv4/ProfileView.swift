import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ProfileView: View {
    @Environment(AppController.self) private var appController
    @State private var name: String = "Loading..."
    @State private var userEmail: String = "Loading..."
    @State private var userPoints: Int = 0
    @State private var redeemedCoupons: [(coupon: Coupon, storeThumbnailUrl: String)] = []

    var body: some View {
        VStack(spacing: 20) {
            // Profile Title & Points Display
            HStack {
                Text("Profile")
                    .font(.title)
                    .bold()
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                    Text("\(userPoints)")
                        .font(.headline)
                        .bold()
                        .foregroundColor(.black)
                }
                .padding(10)
            }
            .padding(.horizontal)
            
            // Profile Information
            VStack(alignment: .leading, spacing: 12) {
                ProfileRow(label: "Name", value: name)
                ProfileRow(label: "Email", value: userEmail)
                ProfileRow(label: "Points", value: "\(userPoints)")
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .shadow(radius: 3)
            .padding(.horizontal)
            
            // Redeemed Coupons Section
            VStack(alignment: .center, spacing: 12) {
                Text("Redeemed Coupons")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                    .padding(.top)
                    .multilineTextAlignment(.center)  // Center the text
                    .frame(maxWidth: .infinity, alignment: .center) // Center the text horizontally
                    .padding(.bottom, 10)
                    .overlay(
                            Rectangle()
                                .frame(height: 2)  // Green underline
                                .foregroundColor(.green)
                                .padding(.top, 20)  // Add padding to move the underline below the text
                                .padding(.horizontal, 40) // Optional: Adjust the width of the underline
                            , alignment: .bottom // Position the underline at the bottom of the text
                        )
                
                if redeemedCoupons.isEmpty {
                    Text("No redeemed coupons yet.")
                        .foregroundColor(.gray)
                        .padding()
                } else {
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(redeemedCoupons, id: \.coupon.id) { redeemedCoupon in
                                RedeemedCouponRow(coupon: redeemedCoupon.coupon, storeThumbnailUrl: redeemedCoupon.storeThumbnailUrl)
                            }
                        }
                    }
                }
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
                    .frame(maxWidth: 150)  // Adjust width to make it smaller
                    .padding(.vertical, 10)  // Reduce vertical padding
                    .padding(.horizontal, 20)  // Adjust horizontal padding
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(25)
            }
            .padding(.bottom, 20)  // Add space from the bottom
            
        }
        .padding()
        .background(Color(.systemGray6))
        .onAppear(perform: fetchUserProfile)
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

            var fetchedCoupons: [(coupon: Coupon, storeThumbnailUrl: String)] = []

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
                            
                            // Add the coupon with the store's thumbnail URL to the array
                            fetchedCoupons.append((coupon: coupon, storeThumbnailUrl: storeThumbnailUrl))
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

struct RedeemedCouponRow: View {
    let coupon: Coupon
    let storeThumbnailUrl: String

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
                
                // Additional info can go here, such as expiration date
                Text("Valid till Apr 07, 2025")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            Spacer()
        }
        .padding()
        .background(Color(hex: "#EAFFE4")) // Light green background
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.green, style: StrokeStyle(lineWidth: 2, dash: [6]))
        )
        .padding(.horizontal)
        .padding(.top, 20)
    }
}

