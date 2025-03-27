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
}

struct StoreView: View {
    @State private var stores: [Store] = []
    @State private var userPoints: Int = 0
    
    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    Text("Stores")  // Title changed to Eco Shorts
                        .font(.title)
                        .padding()
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
                    .cornerRadius(10)
                }
                .padding([.top, .leading, .trailing])  // Padding for the top row
                
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(stores) { store in
                            NavigationLink(destination: StoreDetailView(store: store, userPoints: $userPoints)) {
                                StoreRow(store: store)
                            }
                            .buttonStyle(PlainButtonStyle()) // Removes default navigation button styling
                        }
                    }
                    .padding()
                }
            }
            .onAppear {
                fetchUserPoints()
                fetchStores { fetchedStores in
                    self.stores = fetchedStores
                }
            }.background(Color(.systemGray6))
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
            
            print("Adding store: \(name), coordinate: \(coordinate != nil ? "Yes" : "No")")
            
            return Store(id: doc.documentID, name: name, location: location, coordinate: coordinate, coupons: coupons, about: about, thumbnailUrl: thumbnailUrl)
        }
        
        print("Final store count: \(stores.count)")
        completion(stores)
    }
}
