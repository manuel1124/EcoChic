import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import CoreLocation

struct HomeView: View {
    @State private var userPoints: Int = 0
    @State private var stores: [Store] = []  // Store full objects instead of tuples
    @State private var streak: Int = 0

    let columns = [GridItem(.flexible()), GridItem(.flexible())]
    
    let categories = [
        (title: "Eco Shorts", imageName: "Eco Shorts"),
        (title: "Fact or Fiction", imageName: "Fact or Fiction"),
        (title: "Blitz Round", imageName: "Blitz Round"),
        (title: "Green Choices", imageName: "Green Choices"),
        (title: "Tag Check", imageName: "Tag Check"),
        (title: "Style Persona", imageName: "Style Persona")
    ]
    var body: some View {
            NavigationStack {
                ScrollView(.vertical, showsIndicators: false) { // Make everything scrollable
                    VStack(alignment: .leading, spacing: 16) {
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

                        StreakBoxView(streak: streak)

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
                                                    .fill(Color.gray.opacity(0.2))
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

                        Text("Categories")
                            .font(.headline)
                            .padding(.leading, 25)

                        LazyVGrid(columns: columns, spacing: 0) {
                            ForEach(categories, id: \.title) { category in
                                NavigationLink(destination: LearnView().navigationBarBackButtonHidden(true)) {
                                    CategoryBox(imageName: category.imageName)
                                        //.frame(height: 180)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 20) // Extra padding at bottom for smooth scrolling
                }
                .onAppear {
                    fetchUserPoints()
                    //addNewStoreWithCoupons()
                    fetchStores()
                    updateUserStreak { updatedStreak in
                        DispatchQueue.main.async {
                            self.streak = updatedStreak
                        }
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
                      let about = data["about"] as? String,
                      let thumbnailUrl = data["thumbnailUrl"] as? String,
                      let couponsArray = data["coupons"] as? [[String: Any]] else {
                    print("Invalid store data for document: \(doc.documentID)")
                    return nil
                }

                // Safely handle optional map data for coordinates
                var coordinate: CLLocationCoordinate2D? = nil
                if let mapData = data["map"] as? [String: Any],
                   let latitude = mapData["latitude"] as? Double,
                   let longitude = mapData["longitude"] as? Double {
                    coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                }

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

                // Return the Store object, passing nil for coordinate if it's unavailable
                return Store(id: doc.documentID, name: name, location: location, coordinate: coordinate, coupons: coupons, about: about, thumbnailUrl: thumbnailUrl)
            }

            DispatchQueue.main.async {
                self.stores = fetchedStores
            }
        }
    }

}

struct StreakBoxView: View {
    var streak: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(streak) Day Streak")
                .font(.headline)
                .bold()

            Text("Lorem ipsum dolor sit amet, consectetur adipiscing elit. Ut et massa mi.")
                .font(.subheadline)
                .foregroundColor(.black.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true) // Ensures text wraps properly

            Button(action: {
                // No action for now
            }) {
                Text("Next Milestone")
                    .font(.body)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(hex: "#718B6E")) // Ensure this color exists
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .padding()
        .frame(maxWidth: .infinity) // Ensures the whole box can expand properly
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .gray.opacity(0.3), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
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
        .frame(height: 195)
        .cornerRadius(10)
        .shadow(radius: 2)
    }
}

func updateUserStreak(completion: @escaping (Int) -> Void) {
    guard let user = Auth.auth().currentUser else { return }
    let db = Firestore.firestore()
    let userRef = db.collection("users").document(user.uid)
    
    userRef.getDocument { snapshot, error in
        if let error = error {
            print("Error fetching user data: \(error.localizedDescription)")
            completion(0) // Return default streak of 0 on error
            return
        }
        
        guard let data = snapshot?.data(),
              let lastLogin = data["lastLogin"] as? Timestamp,
              let streak = data["streak"] as? Int else {
            print("No last login found, setting streak to 0")
            userRef.setData(["streak": 0, "lastLogin": Timestamp(date: Date())], merge: true)
            completion(0)
            return
        }
        
        let lastLoginDate = lastLogin.dateValue()
        let currentDate = Date()
        let calendar = Calendar.current

        let lastLoginDay = calendar.startOfDay(for: lastLoginDate)
        let currentDay = calendar.startOfDay(for: currentDate)
        
        let daysDifference = calendar.dateComponents([.day], from: lastLoginDay, to: currentDay).day ?? 0
        
        if daysDifference == 1 {
            // User logged in on the next day, increase streak
            let newStreak = streak + 1
            userRef.updateData([
                "streak": newStreak,
                "lastLogin": Timestamp(date: currentDate)
            ])
            completion(newStreak)
        } else if daysDifference > 1 {
            // User missed a day, reset streak
            userRef.updateData([
                "streak": 0,
                "lastLogin": Timestamp(date: currentDate)
            ])
            completion(0)
        } else {
            // User already logged in today, do nothing
            completion(streak)
        }
    }
}

// Functions to add new items in firestore

func addNewStoreWithCoupons() {
    let db = Firestore.firestore()
    
    let storeData: [String: Any] = [
        "name": "Last Call",
        "about": "At LastCall, our mission is to redefine fashion through sustainability and affordability. We curate quality secondhand pieces, empowering individuals to express their unique style while reducing their environmental footprint. Through ethical practices and community engagement, we strive to inspire conscious consumption and foster a more eco-conscious fashion culture.",
        "location": "Edmonton, AB",
        "coupons": [
            [
                "requiredPoints": 7500,
                "discountAmount": 0.05, // 20% off
                "applicableItems": ["Shirts", "Jackets"],
                "description": "Get 5% off any shirt or jacket!",
                "id": "lastcall_coupon1"
            ]
        ],
        "thumbnailUrl": "https://cdn.shopify.com/s/files/1/0639/1273/9016/files/image0_1_200x60@2x.jpg?v=1728076027.webp"
    ]
    
    db.collection("stores").addDocument(data: storeData) { error in
        if let error = error {
            print("Error adding store: \(error.localizedDescription)")
        } else {
            print("New store added successfully!")
        }
    }
}

func addNewVideoWithQuiz() {
    let db = Firestore.firestore()
    
    let videoData: [String: Any] = [
        "title": "Landfills",
        "about": "Lorem ipsum dolor sit amet, consectetur adipiscing elit.",
        "points": 1500,
        "duration": "7:24",
        "url": "Vl6VhCAeEfQ", // Replace with actual URL
        "thumbnailUrl": "https://www.litterbins.co.uk/cdn/shop/articles/Landfill_That_is_Full_c0f5581d-43de-4822-ac8b-c86264e79e12.webp?v=1692560108", // Replace with actual URL
        "uploadedAt": FieldValue.serverTimestamp(),
        "quiz": [
            [
                "questionText": "What is the capital of France?",
                "options": ["Paris", "London", "Berlin", "Madrid"],
                "correctAnswer": "Paris"
            ],
            [
                "questionText": "What is the capital of Alberta?",
                "options": ["Calgary", "Edmonton", "Red Deer", "Grande Prairie"],
                "correctAnswer": "Edmonton"
            ],
            [
                "questionText": "What is the best University in Alberta?",
                "options": ["UofA", "UofC", "UofL", "UBC"],
                "correctAnswer": "UofA"
            ],
            [
                "questionText": "Which planet is known as the Red Planet?",
                "options": ["Earth", "Mars", "Jupiter", "Venus"],
                "correctAnswer": "Mars"
            ]
        ]
    ]
    
    db.collection("videos").addDocument(data: videoData) { error in
        if let error = error {
            print("Error adding video: \(error.localizedDescription)")
        } else {
            print("New video added successfully!")
        }
    }
}

