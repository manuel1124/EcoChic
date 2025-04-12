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
        (title: "Style Persona", imageName: "Style Persona"),
        (title: "Fact or Fiction", imageName: "Fact or Fiction"),
        (title: "Blitz Round", imageName: "Blitz Round")
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
                    fetchStores { fetchedStores in
                        self.stores = fetchedStores
                    }
                    //seedStylePersonaDocument()
                    //seedStyleQuiz()
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
                          let discountAmount = couponData["discountAmount"] as? Double else {
                        print("Skipping coupon due to missing fields")
                        return nil
                    }
                    
                    return Coupon(id: id, requiredPoints: requiredPoints, discountAmount: discountAmount)
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

func seedStylePersonaDocument() {
    let db = Firestore.firestore()
    
    // ▶️ Pick your personality document ID
    let docID = "FastFashionPersona1"
    // ▶️ This must match the quizDocID below
    let quizID = "fastFashionQuiz1"
    
    // Build your trait array
    let typeData: [[String: Any]] = [
      [
        "title":       "Fast Fashion Addict 🚨",
        "description": "We get it—fast fashion is tempting. But let’s slow it down and shop smarter!",
        "tip":         "Start small: Try one month of no fast fashion purchases. Instead of trends, invest in timeless pieces. Find sustainable alternatives—many ethical brands are just as affordable. 🔗 EcoChic Tip: Check out our beginner’s guide to breaking up with fast fashion!"
      ],
      [
        "title":       "Sustainability Beginner 🌱",
        "description": "You’re making progress! Let’s keep up the momentum.",
        "tip":         "Research brands before buying—are they truly sustainable or greenwashing? Try thrifting or secondhand for your next fashion find. Reduce waste: Donate or repurpose clothes instead of tossing them. 🔗 EcoChic Tip: Explore our top tips for sustainable shopping!"
      ],
      [
        "title":       "Conscious Fashion Guru 🌎",
        "description": "You’re ahead of the game—let’s amplify your impact!",
        "tip":         "Encourage your friends to adopt sustainable fashion habits. Experiment with renting or swapping clothes instead of buying. Discover ethical fashion innovations—support emerging brands. 🔗 EcoChic Tip: Read our feature on next‑gen sustainable fashion brands!"
      ]
    ]
    
    // Build your personality document
    let personalityData: [String: Any] = [
      "about":  "Encourages self‑reflection & provides sustainability tips.",
      "title":  "Are You a Fast Fashion Offender or a Sustainability Star?",
      "quizID": quizID,
      "points": 500,
      "type":   typeData
    ]
    
    // Write (or overwrite) that document
    db.collection("personalities")
      .document(docID)
      .setData(personalityData) { error in
        if let error = error {
          print("❌ Error seeding fast‑fashion persona doc:", error.localizedDescription)
        } else {
          print("✅ Fast‑fashion persona doc seeded successfully!")
        }
    }
}

/// 2) Seed the corresponding quiz under `quizzes/fastFashionQuiz1`
func seedStyleQuiz() {
    let db = Firestore.firestore()
    
    // Must match the quizID above
    let quizDocID = "fastFashionQuiz1"
    
    // Build your question array
    let quizData: [[String: Any]] = [
      [
        "questionText": "How often do you buy new clothes?",
        "options": [
          "A) Every week—gotta keep up with trends!",
          "B) A few times a year, when I need something.",
          "C) Rarely—I prefer quality over quantity."
        ]
      ],
      [
        "questionText": "Do you know what materials your clothes are made of?",
        "options": [
          "A) No idea, I just check the style.",
          "B) Sometimes, especially for basics.",
          "C) Always—I check for organic and sustainable fabrics."
        ]
      ],
      [
        "questionText": "What do you do when you’re bored of your clothes?",
        "options": [
          "A) Buy new ones.",
          "B) Sell or donate them.",
          "C) Upcycle or swap them with friends."
        ]
      ],
      [
        "questionText": "Your ideal fashion purchase is…",
        "options": [
          "A) Cheap and trendy—fast fashion all the way.",
          "B) Thrifted or made by an ethical brand.",
          "C) Handmade, reworked, or vintage."
        ]
      ]
    ]
    
    // Write to quizzes collection
    db.collection("quizzes")
      .document(quizDocID)
      .setData(["questions": quizData]) { error in
        if let error = error {
          print("❌ Error seeding fast‑fashion quiz:", error.localizedDescription)
        } else {
          print("✅ Fast‑fashion quiz seeded successfully!")
        }
    }
}
