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
        //(title: "Green Choices", imageName: "Green Choices"),
        //(title: "Tag Check", imageName: "Tag Check"),
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

                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 16) {
                                StreakBoxView(streak: streak)
                            }
                        }


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
                                NavigationLink(destination: category.title == "Eco Shorts" ? AnyView(LearnView().navigationBarBackButtonHidden(true)) : AnyView(ComingSoonView())) {
                                    CategoryBox(imageName: category.imageName)
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
                          let discountAmount = couponData["discountAmount"] as? Double else {
                        print("Invalid coupon data in store: \(name)")
                        return nil
                    }
                    return Coupon(id: id, requiredPoints: requiredPoints, discountAmount: discountAmount)
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
    @State private var showInfo = false

    private var nextMilestone: Int {
        return streak < 5 ? 5 : 15
    }

    private var milestonePoints: Int {
        return nextMilestone == 5 ? 1000 : 5000
    }

    private var dotRange: [Int] {
        return streak < 5 ? Array(0...5) : Array(5...15)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("\(streak) Day Streak")
                    .font(.headline)
                    .bold()
                
                Spacer()
                
                // Info bubble toggle button (top-right)
                HStack {
                    Spacer()
                    Button(action: {
                        withAnimation {
                            showInfo.toggle()
                        }
                    }) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.black)
                            .padding(.trailing, 4)
                    }
                }
            }

            // Dots with background bar and info button
            GeometryReader { geometry in
                let dotSize: CGFloat = 14
                let spacing = (geometry.size.width - (dotSize * CGFloat(dotRange.count))) / CGFloat(dotRange.count - 1)

                ZStack(alignment: .leading) {
                    // Background bar
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.green.opacity(0.15))
                        .frame(height: 28)

                    // Dots
                    HStack(spacing: spacing) {
                        ForEach(dotRange, id: \.self) { day in
                            Circle()
                                .fill(day <= streak ? Color.green : Color.gray)
                                .frame(width: dotSize, height: dotSize)
                        }
                    }

                }
            }
            .frame(height: 28)

            // Expandable info bubble
            if showInfo {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Earn 100 points every day you continue your streak, and earn even more points for reaching milestones!")
                    Text(" ")
                    Text("Reach day \(nextMilestone) to earn a bonus \(milestonePoints) points.")
                }
                .font(.subheadline)
                //.padding(10)
                //.background(Color.green.opacity(0.1))
                .cornerRadius(8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
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
            completion(0)
            return
        }
        
        guard let data = snapshot?.data(),
              let lastLogin = data["lastLogin"] as? Timestamp,
              let streak = data["streak"] as? Int,
              var points = data["points"] as? Int else {
            print("No last login found, initializing streak and points.")
            userRef.setData(["streak": 1, "lastLogin": Timestamp(date: Date()), "points": 100], merge: true)
            completion(1)
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
            var newStreak = streak + 1
            var dailyPoints = 100

            // Check for milestone bonuses
            if newStreak == 5 {
                dailyPoints += 1000 // Bonus for reaching day 5
            } else if newStreak == 15 {
                dailyPoints += 5000 // Bonus for reaching day 15
            }

            points += dailyPoints // Add the earned points

            userRef.updateData([
                "streak": newStreak,
                "lastLogin": Timestamp(date: currentDate),
                "points": points
            ]) { error in
                if let error = error {
                    print("Error updating streak: \(error.localizedDescription)")
                }
            }
            completion(newStreak)
        } else if daysDifference > 1 {
            // User missed a day, reset streak
            userRef.updateData([
                "streak": 0,
                "lastLogin": Timestamp(date: currentDate)
            ]) { error in
                if let error = error {
                    print("Error resetting streak: \(error.localizedDescription)")
                }
            }
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

struct ComingSoonView: View {
    var body: some View {
        VStack {
            Spacer()
            Text("Coming Soon")
                .font(.title)
                .bold()
                .foregroundColor(.gray)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }
}
