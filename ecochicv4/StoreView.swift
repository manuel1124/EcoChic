import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import MapKit
import CoreLocation

struct Coupon: Identifiable {
    let id: String   // Change this to String to match the Firestore document ID
    let requiredPoints: Int
    let discountAmount: Double
    let applicableItems: [String]
    let description: String
}

struct Store: Identifiable {
    var id: String
    var name: String
    var location: String
    let coordinate: CLLocationCoordinate2D?
    var coupons: [Coupon]
    var about: String
    var thumbnailUrl: String
    var website: String?
    var instagram: String?
    var tiktok: String?
    var facebook: String?
}

import SwiftUI

struct StoreView: View {
    @State private var stores: [Store] = []
    @State private var userPoints: Int = 0
    
    var body: some View {
        NavigationView {
            VStack {
                // Title and Points UI
                HStack {
                    Text("Rewards Store")
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
                
                // **Top Deals Section**
                VStack(alignment: .leading) {
                    HStack {
                        Text("Top Deals")
                            .font(.title2)
                            //.bold()
                        
                        Spacer()
                        
                        /*
                        NavigationLink(destination: Text("See all stores")) {
                            Text("See all")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                         */
                    }
                    .padding(.horizontal)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(0..<stores.count, id: \.self) { index in
                                let store = stores[index]
                                if let coupon = store.coupons.first { // Take the first coupon
                                    let dealImageName = "top deals \(index + 1)" // Matching image from assets
                                    NavigationLink(destination: StoreDetailView(store: store, userPoints: $userPoints)) {
                                        ZStack(alignment: .bottomLeading) {
                                            Image(dealImageName)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 230, height: 180)
                                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                                .shadow(radius: 2)
                                            
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("\(Int(coupon.discountAmount * 100))% Off")
                                                    .font(.title)
                                                    .bold()
                                                    .foregroundColor(.white)
                                                    .shadow(radius: 5)

                                                HStack {
                                                    if let url = URL(string: store.thumbnailUrl) {
                                                        AsyncImage(url: url) { phase in
                                                            switch phase {
                                                            case .success(let image):
                                                                image
                                                                    .resizable()
                                                                    .scaledToFill()
                                                                    .frame(width: 30, height: 30) // Small thumbnail size
                                                                    .clipShape(Circle()) // Rounded thumbnail
                                                            case .failure:
                                                                Color.gray
                                                                    .frame(width: 30, height: 30)
                                                                    .clipShape(Circle())
                                                            default:
                                                                ProgressView()
                                                                    .frame(width: 30, height: 30)
                                                            }
                                                        }
                                                    }

                                                    Text(store.name)
                                                        .font(.headline)
                                                        .foregroundColor(.white)
                                                        .shadow(radius: 5)
                                                }
                                            }
                                            .padding(12)
                                        }
                                    }.buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
                
                // **Partnered Stores**
                VStack(alignment: .leading) {
                    HStack {
                        Text("Partnered Stores")
                            .font(.title2)
                            //.bold()
                        
                        Spacer()
                        /*
                        NavigationLink(destination: Text("See all stores")) {
                            Text("See all")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                         */
                    }
                    .padding(.horizontal)
                    
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(stores) { store in
                                NavigationLink(destination: StoreDetailView(store: store, userPoints: $userPoints)) {
                                    StoreRow(store: store)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding()
                    }
                }
            }
            .onAppear {
                fetchUserPoints()
                fetchStores { fetchedStores in
                    self.stores = fetchedStores
                }
            }
            .background(Color(.systemGray6))
        }
    }
    
    func fetchUserPoints() {
        guard let user = Auth.auth().currentUser else { return }
        let db = Firestore.firestore()
        db.collection("users").document(user.uid).getDocument { snapshot, error in
            if let error = error {
                print("Error fetching user points: \(error.localizedDescription)")
                return
            }
            
            guard let data = snapshot?.data(),
                  let points = data["points"] as? Int else {
                print("User points not found")
                return
            }
            
            self.userPoints = points  // Update the user points
        }
    }
}

struct StoreRow: View {
    let store: Store

    var body: some View {
        HStack {
            // Store Thumbnail (Circular Image)
            if let url = URL(string: store.thumbnailUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 50, height: 50) // Adjust size
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.gray, lineWidth: 1))
                    case .failure:
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 50, height: 50)
                            .overlay(Image(systemName: "photo").foregroundColor(.white))
                    default:
                        ProgressView()
                            .frame(width: 50, height: 50)
                    }
                }
            }

            // Store Name and Location
            VStack(alignment: .leading) {
                Text(store.name)
                    .font(.headline)
                Text(store.location)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }

            Spacer()

        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}


func fetchStores(completion: @escaping ([Store]) -> Void) {
    let db = Firestore.firestore()
    db.collection("stores").getDocuments { snapshot, error in
        if let error = error {
            print("Error fetching stores: \(error.localizedDescription)")
            completion([])
            return
        }
        
        guard let documents = snapshot?.documents else {
            print("No documents found")
            completion([])
            return
        }
        
        let stores = documents.compactMap { doc -> Store? in
            let data = doc.data()
            
            print("Fetched data:", data) // Debugging print
            
            guard let name = data["name"] as? String,
                  let location = data["location"] as? String,
                  let thumbnailUrl = data["thumbnailUrl"] as? String,
                  let about = data["about"] as? String,
                  let couponsArray = data["coupons"] as? [[String: Any]] else {
                print("Skipping document due to missing fields")
                return nil
            }
            
            // Handle optional map data
            let coordinate: CLLocationCoordinate2D? // ✅ Make it optional
            if let mapData = data["map"] as? [String: Any],
               let latitude = mapData["latitude"] as? Double,
               let longitude = mapData["longitude"] as? Double {
                coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            } else {
                coordinate = nil
            }
            
            let coupons = couponsArray.compactMap { couponData -> Coupon? in
                guard let id = couponData["id"] as? String,
                      let requiredPoints = couponData["requiredPoints"] as? Int,
                      let discountAmount = couponData["discountAmount"] as? Double,
                      let applicableItems = couponData["applicableItems"] as? [String],
                      let description = couponData["description"] as? String else {
                    print("Skipping coupon due to missing fields")
                    return nil
                }
                
                return Coupon(id: id, requiredPoints: requiredPoints, discountAmount: discountAmount, applicableItems: applicableItems, description: description)
            }

            // ✅ Fetch optional social media fields
            let website = data["website"] as? String
            let instagram = data["instagram"] as? String
            let facebook = data["facebook"] as? String
            let tiktok = data["tiktok"] as? String
            
            print("Adding store: \(name), coordinate: \(coordinate != nil ? "Yes" : "No")")
            
            return Store(
                id: doc.documentID,
                name: name,
                location: location,
                coordinate: coordinate,
                coupons: coupons,
                about: about,
                thumbnailUrl: thumbnailUrl,
                website: website,
                instagram: instagram,
                tiktok: tiktok,
                facebook: facebook
            )
        }
        
        print("Final store count: \(stores.count)")
        completion(stores)
    }
}
