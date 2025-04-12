import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import CoreLocation

struct HomeView: View {
    @State private var userPoints: Int = 0
    @State private var stores: [Store] = []  // Store full objects instead of tuples
    @State private var streak: Int = 0
    
    @State private var showPointsPopup: Bool = false
    @State private var newPointsEarned: Int = 0

    let columns = [GridItem(.flexible()), GridItem(.flexible())]
    
    let categories = [
        (title: "Eco Shorts", imageName: "Eco Shorts"),
        (title: "Fact or Fiction", imageName: "Fact or Fiction"),
        (title: "Blitz Round", imageName: "Blitz Round"),
        (title: "Style Persona", imageName: "Style Persona")
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Main content
                ScrollView(.vertical, showsIndicators: false) { // Make everything scrollable
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Home")
                                .font(.title)
                                .bold()
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
                            NavigationLink {
                              // destination builder
                              if category.title == "Eco Shorts" {
                                LearnView()
                                  .navigationBarBackButtonHidden(true)
                              } else if category.title == "Style Persona" {
                                StylePersonaQuizView()
                                  .navigationBarBackButtonHidden(true)
                              } else {
                                ComingSoonView()
                              }
                            } label: {
                              CategoryBox(imageName: category.imageName)
                            }
                          }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 20) // Extra padding at bottom for smooth scrolling
                }
                .background(Color(.systemGray6))
                .onAppear {
                    fetchUserPoints()
                    fetchStores()
                    //seedStylePersonaTypes()
                    updateUserStreak { updatedStreak, pointsEarned in
                        DispatchQueue.main.async {
                            self.streak = updatedStreak
                            if pointsEarned > 0 {
                                self.newPointsEarned = pointsEarned
                                self.showPointsPopup = true
                                self.userPoints += pointsEarned
                            }
                        }
                    }
                }
                
                // The overlay popup, centered on the screen:
                if showPointsPopup {
                    ZStack {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                        
                        PointsEarnedPopupView(streak: streak, pointsEarned: newPointsEarned) {
                            withAnimation {
                                self.showPointsPopup = false
                            }
                        }
                        .padding(40)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        
                        // Add the confetti effect; it can be placed behind or in front of your popup.
                        ConfettiView()
                            .allowsHitTesting(false) // so it doesn't intercept taps
                    }
                    .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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

func addNewQuiz() {
    let db = Firestore.firestore()
    
    // Prepare the quiz data as an array of dictionaries.
    let quizData: [[String: Any]] = [
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
    
    // Add a new document to the "quizzes" collection with the quiz data.
    db.collection("quizzes").addDocument(data: ["questions": quizData]) { error in
        if let error = error {
            print("Error adding quiz: \(error.localizedDescription)")
        } else {
            print("New quiz added successfully!")
        }
    }
}

//import FirebaseFirestore

/// Call this once to seed the "Style Persona" quiz into Firestore.
func addStylePersonaQuiz() {
    let db = Firestore.firestore()
    
    // 1) Build your question array
    let quizData: [[String: Any]] = [
        [
            "questionText": "When you go shopping, you usually…",
            "options": [
                "A) Buy trendy pieces I saw on TikTok.",
                "B) Thrift or buy from sustainable brands.",
                "C) Stick to timeless basics that last forever.",
                "D) I barely shop—I’m all about reworking what I have."
            ]
        ],
        [
            "questionText": "How often do you clean out your closet?",
            "options": [
                "A) Every season to make space for new stuff.",
                "B) Every few years—I don’t shop that much.",
                "C) Only when my clothes are worn out.",
                "D) I constantly upcycle and repurpose pieces!"
            ]
        ],
        [
            "questionText": "How do you feel about fast fashion?",
            "options": [
                "A) It’s cheap and convenient—I can’t resist.",
                "B) I avoid it whenever possible.",
                "C) I only buy from ethical brands or secondhand.",
                "D) I prefer DIY-ing my clothes instead of buying."
            ]
        ],
        [
            "questionText": "Your dream wardrobe is…",
            "options": [
                "A) Full of trendy statement pieces.",
                "B) A mix of secondhand, reworked, and ethical fashion.",
                "C) Minimalist and high-quality.",
                "D) Made up of things I designed or customized myself."
            ]
        ]
    ]
    
    // 2) Write to a fixed document ID "stylePersona"
    db.collection("quizzes")
      .document("stylePersona1")
      .setData(["questions": quizData]) { error in
        if let error = error {
            print("Error adding Style Persona quiz: \(error.localizedDescription)")
        } else {
            print("Style Persona quiz successfully seeded!")
        }
    }
}

func seedStylePersonaTypes() {
    let db = Firestore.firestore()
    let docRef = db.collection("personalities").document("Lyey8vsI1pC09VYPch9J")
    
    // Build your array of trait‑maps
    let typeData: [[String: Any]] = [
        [
            "title": "The Trend Chaser",
            "description": "You love staying on top of trends, but fast fashion can be wasteful.",
            "tip": "Try investing in timeless pieces and explore secondhand options!"
        ],
        [
            "title": "The Conscious Shopper",
            "description": "You’re making mindful choices! Here’s how to level up your sustainability game.",
            "tip": "Keep discovering new sustainable brands & thrifting gems!"
        ],
        [
            "title": "The Minimalist Stylist",
            "description": "You’ve mastered the art of a timeless wardrobe—here’s what’s next!",
            "tip": "Focus on garment care to make your pieces last even longer!"
        ],
        [
            "title": "The Creative Reworker",
            "description": "You’re a DIY master! Let’s take your skills even further.",
            "tip": "Share your DIYs with the EcoChic community!"
        ]
    ]
    
    // Write (or overwrite) the `type` field on that document
    docRef.updateData([
        "type": typeData
    ]) { error in
        if let error = error {
            print("❌ Failed to seed types:", error.localizedDescription)
        } else {
            print("✅ Successfully wrote `type` array to Style Persona document.")
        }
    }
}
