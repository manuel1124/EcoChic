import SwiftUI
import WebKit
import FirebaseAuth
import FirebaseFirestore

struct QuizQuestion: Identifiable {
    let id = UUID()
    let questionText: String
    let options: [String]
    let correctAnswer: String
}

struct Video: Identifiable {
    let id: String
    let title: String
    let about: String // Added about field
    let duration: String
    let videoURL: String
    let thumbnailURL: String
    let quiz: [QuizQuestion]
    let points: Int
}


struct LearnView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var videos: [Video] = []
    @State private var userPoints: Int = 0  // State to store user's points

    var body: some View {
        NavigationView {
            VStack {
                // Top row with title and user points
                HStack {
                    Text("Eco Shorts")  // Title changed to Eco Shorts
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

                // ScrollView for videos
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 16) {
                        ForEach(videos) { video in
                            NavigationLink(destination: VideoPlayerView(video: video)) {
                                VideoRow(video: video)
                            }
                        }
                    }
                    .padding()
                    //.background(Color.blue.opacity(0.1))
                    
                }
            
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "arrow.left")
                            .font(.title) // Adjust size if needed
                            .foregroundColor(.gray)
                            .padding(.leading, 40) // Moves it slightly to the right
                            .padding(.vertical, 20) // Adds vertical padding for better touch area
                    }
                    Spacer() // Keeps it left-aligned without sticking to the edge
                }
                .background(Color(.systemGray6)) // Matches the background
            }
            .toolbar(.hidden, for: .tabBar)
            .onAppear {
                fetchVideos()
                fetchUserPoints()  // Fetch user points when the view appears
            }.background(Color(.systemGray6))
        }
    }
    
    func fetchVideos() {
        let db = Firestore.firestore()
        db.collection("videos").getDocuments { snapshot, error in
            if let error = error {
                print("Error fetching videos: \(error.localizedDescription)")
                return
            }
            
            guard let documents = snapshot?.documents else { return }
            
            self.videos = documents.compactMap { doc in
                let data = doc.data()
                
                guard let title = data["title"] as? String,
                      let about = data["about"] as? String, // Fetch about field
                      let duration = data["duration"] as? String,
                      let videoURL = data["url"] as? String,
                      let thumbnailURL = data["thumbnailUrl"] as? String,
                      let quizData = data["quiz"] as? [[String: Any]] else {
                    print("Skipping video due to missing or invalid fields")
                    return nil
                }
                
                let points = data["points"] as? Int ?? 0
                let quizQuestions = quizData.compactMap { q -> QuizQuestion? in
                    guard let questionText = q["questionText"] as? String,
                          let options = q["options"] as? [String],
                          let correctAnswer = q["correctAnswer"] as? String else {
                        print("Skipping a quiz question due to missing fields")
                        return nil
                    }
                    return QuizQuestion(questionText: questionText, options: options, correctAnswer: correctAnswer)
                }
                
                return Video(
                    id: doc.documentID,
                    title: title,
                    about: about, // Store about field
                    duration: duration,
                    videoURL: videoURL,
                    thumbnailURL: thumbnailURL,
                    quiz: quizQuestions,
                    points: points
                )
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
            
            self.userPoints = points  // Update the user points
        }
    }
    
}

struct VideoRow: View {
    let video: Video
    @State private var isQuizCompleted = false
    
    var body: some View {
        VStack {
            HStack(spacing: 12) {
                if let url = URL(string: video.thumbnailURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            Color.gray.opacity(0.2)
                        case .success(let image):
                            image.resizable()
                        case .failure:
                            Color.red.opacity(0.2)
                        @unknown default:
                            Color.gray.opacity(0.2)
                        }
                    }
                    .frame(width: 75, height: 75)
                    .cornerRadius(8)
                    .clipped()
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(video.title)
                        .font(.system(size: 20))
                        .foregroundColor(.primary)
                        .padding(.bottom, 2)
                    
                    Text(video.about)
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            
            // 🔹 This HStack is now INSIDE the white box
            HStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .foregroundColor(.orange)
                Text("\(video.quiz.count)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Image(systemName: "clock.fill")
                    .foregroundColor(.blue)
                Text(video.duration)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                Image(systemName: isQuizCompleted ? "checkmark.circle.fill" : "checkmark.circle")
                    .foregroundColor(isQuizCompleted ? .green : .gray)
            }
            .padding(.top, 8) // Add a bit of spacing within the box
            
        }
        .padding()
        .background(Color(.systemBackground)) // White box
        .cornerRadius(12)
        .shadow(color: Color.gray.opacity(0.2), radius: 2, x: 0, y: 1)
        .onAppear {
            checkIfQuizCompleted()
        }
    }


    
    private func checkIfQuizCompleted() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(userId)
        
        userRef.getDocument { document, error in
            if let error = error {
                print("Error fetching user document: \(error.localizedDescription)")
                return
            }
            
            if let document = document, document.exists {
                let completedQuizzes = document.data()?["completedQuizzes"] as? [String: Int] ?? [:]
                
                DispatchQueue.main.async {
                    isQuizCompleted = completedQuizzes[video.id] != nil
                }
            }
        }
    }
}

func addNewStoreWithCoupons() {
    let db = Firestore.firestore()
    
    let storeData: [String: Any] = [
        "name": "Patagonia",
        "location": "Edmonton, AB",
        "coupons": [
            [
                "requiredPoints": 50,
                "discountAmount": 0.2, // 20% off
                "applicableItems": ["Shirts", "Jackets"],
                "description": "Get 20% off any shirt or jacket!"
            ]
        ],
        "map": [
            "latitude": 53.5464,
            "longitude": -113.5231
        ],
        "thumbnailUrl": "https://wallpapers.com/images/hd/patagonia-logo-background-hf8e8q261zgmad5s.jpg"
    ]
    
    db.collection("stores").addDocument(data: storeData) { error in
        if let error = error {
            print("Error adding store: \(error.localizedDescription)")
        } else {
            print("New store added successfully!")
        }
    }
}
