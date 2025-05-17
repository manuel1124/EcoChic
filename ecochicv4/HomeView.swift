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
        (title: "Blitz Round", imageName: "Blitz Round"),
        (title: "Fact or Fiction", imageName: "Fact or Fiction")
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
                              } else if category.title == "Blitz Round" {
                                BlitzRoundView()
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
                    //addAvailableCouponCodes()
                    //seedStylePersonaDocument()
                    //addNewQuiz()
                    //addNewVideo()
                    //grant5000PointsToAllUsers()
                    //subtract5000PointsFromAllUsers()
                    //addLastCallCouponsToStore(storeId: "Hrb3AW8ddDWOFQ9GHwob")
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
                    startPointsListener()
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
    
    func startPointsListener() {
        guard let user = Auth.auth().currentUser else { return }
        Firestore.firestore().collection("users").document(user.uid)
            .addSnapshotListener { snapshot, error in
                if let points = snapshot?.data()?["points"] as? Int {
                    self.userPoints = points
                }
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

func generateBlitzRoundMadness() {
    let db = Firestore.firestore()
    let quizzesRef = db.collection("quizzes")
    var allBlitzQuestions: [[String: Any]] = []

    quizzesRef.getDocuments { snapshot, error in
        if let error = error {
            print("❌ Error fetching quizzes: \(error.localizedDescription)")
            return
        }

        guard let documents = snapshot?.documents else {
            print("❌ No quizzes found.")
            return
        }

        for doc in documents {
            if let questions = doc.data()["questions"] as? [[String: Any]] {
                for question in questions {
                    // Ensure each question has the required fields
                    if let questionText = question["questionText"] as? String,
                       let options = question["options"] as? [String],
                       let correctAnswer = question["correctAnswer"] as? String {

                        allBlitzQuestions.append([
                            "questionText": questionText,
                            "options": options,
                            "correctAnswer": correctAnswer
                        ])
                    }
                }
            }
        }

        // Save to blitzRoundMadness
        db.collection("quizzes").document("blitzRoundMadness").setData([
            "questions": allBlitzQuestions
        ]) { error in
            if let error = error {
                print("❌ Error saving Blitz Round: \(error.localizedDescription)")
            } else {
                print("✅ BlitzRoundMadness generated with \(allBlitzQuestions.count) questions.")
            }
        }
    }
}


func addNewQuiz() {
    let db = Firestore.firestore()
    let quizID = "shoppingSustainably_quiz1"

    let quizData: [String: Any] = [
        "questions": [
            [
                "questionText": "What are sustainable brands?",
                "options": [
                    "Brands that are only good for the environment",
                    "Brands that are doing their part to ensure safe working conditions, have a limited impact on the planet, and are good for your health",
                    "Brands that produce sustainable quantities of clothing",
                    "Brands that consider the planet and people"
                ],
                "correctAnswer": "Brands that are doing their part to ensure safe working conditions, have a limited impact on the planet, and are good for your health"
            ],
            [
                "questionText": "What does the Good On You app do?",
                "options": [
                    "An app that indicates which brands are fast fashion",
                    "An app for purchasing sustainable clothing",
                    "An app that ranks brands based on environmental, social, and economic factors",
                    "An app that provides sustainable fashion education"
                ],
                "correctAnswer": "An app that ranks brands based on environmental, social, and economic factors"
            ],
            [
                "questionText": "What are B-Corp Certified Companies?",
                "options": [
                    "Companies that pay to get certified without following ethical practices",
                    "Companies that implement high social and environmental standards once to receive this certification",
                    "Companies that follow all of the United Nations Sustainable Development Goals",
                    "Companies must go through an annual and rigorous process to ensure their business practices are held to high social and environmental standards"
                ],
                "correctAnswer": "Companies must go through an annual and rigorous process to ensure their business practices are held to high social and environmental standards"
            ],
            [
                "questionText": "Shopping from sustainable brands…",
                "options": [
                    "Puts money into the pockets of fast fashion companies",
                    "Increases the longevity of your closest",
                    "Decreases the social and environmental impact of the clothes you purchase",
                    "Makes you a good person"
                ],
                "correctAnswer": "Decreases the social and environmental impact of the clothes you purchase"
            ],
            [
                "questionText": "Your values can be communicated to the fashion industry by…",
                "options": [
                    "Emailing them directly",
                    "Purchasing from sustainable brands",
                    "Chatting with retail workers",
                    "Making your own clothes"
                ],
                "correctAnswer": "Purchasing from sustainable brands"
            ]
        ]
    ]

    db.collection("quizzes").document(quizID).setData(quizData) { error in
        if let error = error {
            print("❌ Error adding 'Shopping Sustainably' quiz: \(error.localizedDescription)")
        } else {
            print("✅ Quiz 'Shopping Sustainably' added successfully!")
        }
    }
}

func addNewVideo() {
    let db = Firestore.firestore()

    let videoData: [String: Any] = [
        "title": "Shopping Sustainably",
        "about": "Shopping sustainably can significantly decrease the negative social and environmental impacts of your fashion purchases! In this video, we discuss what shopping sustainability looks like and what tools and options are available.",
        "points": 2500,
        "duration": "1:26",
        "url": "smr1uEi1Dro",
        "thumbnailUrl": "https://media.licdn.com/dms/image/v2/D4D12AQFr9iTXSpV_vQ/article-cover_image-shrink_600_2000/B4DZUFQ0LeG8Ac-/0/1739550049970?e=2147483647&v=beta&t=7vxSjVnFkWElnM63imgVhh-8JqOZRATesYgGYcbo_80",
        "uploadedAt": FieldValue.serverTimestamp(),
        "quizID": "shoppingSustainably_quiz1"
    ]

    db.collection("videos").addDocument(data: videoData) { error in
        if let error = error {
            print("❌ Error adding video: \(error.localizedDescription)")
        } else {
            print("✅ New video 'Shopping Sustainably' added successfully!")
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
        "title":       "Fast Fashion Addict",
        "description": "We get it—fast fashion is tempting. But let’s slow it down and shop smarter!",
        "tip":         "✅ Start small: Try one month of no fast fashion purchases.\n✅ Instead of trends, invest in timeless pieces that last longer.\n✅ Find sustainable alternatives—many ethical brands are just as affordable."
      ],
      [
        "title":       "Sustainability Beginner",
        "description": "You’re making progress! Let’s keep up the momentum.",
        "tip":         "✅ Research brands before buying—are they truly sustainable or greenwashing?\n✅ Try thrifting or secondhand for your next fashion find.\n✅ Reduce waste: Donate or repurpose clothes instead of tossing them."
      ],
      [
        "title":       "Conscious Fashion Guru",
        "description": "You’re ahead of the game—let’s amplify your impact!",
        "tip":         "✅ Encourage your friends to adopt sustainable fashion habits.\n✅ Experiment with renting or swapping clothes instead of buying.\n✅ Discover ethical fashion innovations—support emerging brands."
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

import FirebaseFirestore

func addAvailableCouponCodes() {
    let db = Firestore.firestore()
    let couponId = "lastcall_coupon3"

    let couponCodes = [
        "LSTCCBM5M25",
        "LSTCCADS625",
        "LSTCCTPW225",
        "LSTCCFGRF25",
        "LSTCCTCPQ25"
    ]

    let couponRef = db.collection("coupons").document(couponId)

    couponRef.updateData([
        "available": couponCodes
    ]) { error in
        if let error = error {
            print("Error updating coupon codes: \(error.localizedDescription)")
        } else {
            print("Successfully added coupon codes to \(couponId)")
        }
    }
}


func grant5000PointsToAllUsers() {
    let db = Firestore.firestore()
    db.collection("users").getDocuments { (snapshot, error) in
        if let error = error {
            print("❌ Error fetching users: \(error.localizedDescription)")
            return
        }

        guard let documents = snapshot?.documents else { return }

        for document in documents {
            let userRef = document.reference
            userRef.updateData(["points": FieldValue.increment(Int64(7000))]) { error in
                if let error = error {
                    print("❌ Error updating user \(document.documentID): \(error.localizedDescription)")
                } else {
                    print("✅ User \(document.documentID) has been awarded 5000 points.")
                }
            }
        }
    }
}

func subtract5000PointsFromAllUsers() {
    let db = Firestore.firestore()
    db.collection("users").getDocuments { (snapshot, error) in
        if let error = error {
            print("❌ Error fetching users: \(error.localizedDescription)")
            return
        }

        guard let documents = snapshot?.documents else { return }

        for document in documents {
            let userRef = document.reference
            userRef.updateData(["points": FieldValue.increment(Int64(-5000))]) { error in
                if let error = error {
                    print("❌ Error updating user \(document.documentID): \(error.localizedDescription)")
                } else {
                    print("✅ User \(document.documentID) has been deducted 5000 points.")
                }
            }
        }
    }
}

func addLastCallCouponsToStore(storeId: String) {
    let db = Firestore.firestore()
    
    // Define the new coupons
    let newCoupons = [
        [
            "id": "lastcall_coupon2",
            "discountAmount": 0.20,  // 20% discount
            "requiredPoints": 25000,
        ],
        [
            "id": "lastcall_coupon3",
            "discountAmount": 0.25,  // 25% discount
            "requiredPoints": 40000,
        ]
    ]
    
    // Update the store with the new coupons
    db.collection("stores").document(storeId).updateData([
        "coupons": FieldValue.arrayUnion(newCoupons)
    ]) { error in
        if let error = error {
            print("Error adding coupons: \(error.localizedDescription)")
        } else {
            print("Successfully added lastcall coupons to the store.")
        }
    }
}
