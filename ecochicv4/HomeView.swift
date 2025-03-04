import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import CoreLocation

struct HomeView: View {
    @State private var userPoints: Int = 0
    @State private var stores: [Store] = []  // Store full objects instead of tuples

    let columns = [GridItem(.flexible()), GridItem(.flexible())]
    
    let categories = [
        (title: "Eco Shorts", imageName: "Eco Shorts"),
        (title: "Fact or Fiction", imageName: "Fact or Fiction"),
        (title: "Blitz Round", imageName: "Blitz Round"),
        (title: "Style Persona", imageName: "Style Persona")
    ]

    var body: some View {
        NavigationStack { // Replacing NavigationView with NavigationStack
            VStack(alignment: .leading) {
                HStack {
                    Text("Home")
                        .font(.title)
                        .bold()
                        .padding()
                    
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
                .padding([.top, .leading, .trailing])
                
                Text("Your favourite stores")
                    .font(.headline)
                    .padding(.leading, 25)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(stores) { store in
                            if let url = URL(string: store.thumbnailUrl) {
                                NavigationLink(destination: StoreDetailView(store: store, userPoints: $userPoints)) {
                                    AsyncImage(url: url) { image in
                                        image.resizable()
                                            .scaledToFill()
                                            .frame(width: 60, height: 60)
                                            .clipShape(Circle())
                                            .overlay(Circle().stroke(Color.clear, lineWidth: 2))
                                    } placeholder: {
                                        Circle()
                                            .fill(Color.gray.opacity(0.2)) // Improved visibility for placeholder
                                            .frame(width: 60, height: 60)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.leading, 25)
                    .padding(.trailing, 10)
                }
                .frame(height: 80)

                //Spacer()
                
                // "Categories" heading
                Text("Categories")
                    .font(.headline)
                    .padding(.leading, 25)
                
                // Grid of category boxes
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(categories, id: \.title) { category in
                        NavigationLink(destination: LearnView().navigationBarBackButtonHidden(true)) {
                            CategoryBox(imageName: category.imageName)
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .onAppear {
                fetchUserPoints()
                fetchStores()
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
            
            DispatchQueue.main.async {
                self.userPoints = points
            }
        }
    }

    func fetchStores() {
        let db = Firestore.firestore()
        db.collection("stores").getDocuments { snapshot, error in
            if let error = error {
                print("Error fetching stores: \(error.localizedDescription)")
                return
            }

            guard let documents = snapshot?.documents else {
                print("No store documents found.")
                return
            }

            let fetchedStores: [Store] = documents.compactMap { doc in
                let data = doc.data()
                guard let name = data["name"] as? String,
                      let location = data["location"] as? String,
                      let mapData = data["map"] as? [String: Any],
                      let latitude = mapData["latitude"] as? Double,
                      let longitude = mapData["longitude"] as? Double,
                      let thumbnailUrl = data["thumbnailUrl"] as? String,
                      let couponsArray = data["coupons"] as? [[String: Any]] else {
                    print("Invalid store data for document: \(doc.documentID)")
                    return nil
                }

                let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)

                let coupons: [Coupon] = couponsArray.compactMap { couponData in
                    guard let id = couponData["id"] as? String,
                          let requiredPoints = couponData["requiredPoints"] as? Int,
                          let discountAmount = couponData["discountAmount"] as? Double,
                          let applicableItems = couponData["applicableItems"] as? [String],
                          let description = couponData["description"] as? String else {
                        print("Invalid coupon data in store: \(name)")
                        return nil
                    }
                    return Coupon(id: id, requiredPoints: requiredPoints, discountAmount: discountAmount, applicableItems: applicableItems, description: description)
                }

                return Store(id: doc.documentID, name: name, location: location, coordinate: coordinate, coupons: coupons, thumbnailUrl: thumbnailUrl)
            }

            DispatchQueue.main.async {
                self.stores = fetchedStores
            }
        }
    }

}

struct CategoryBox: View {
    let imageName: String
    
    var body: some View {
        ZStack {
            Image(imageName)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .cornerRadius(10)
                .clipped()
        }
        .frame(height: 165)
        .cornerRadius(10)
        .shadow(radius: 5)
    }
}
