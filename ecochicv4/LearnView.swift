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
    @State private var userPoints: Int = 0

    var body: some View {
        NavigationView {
            ZStack {
                VStack {
                    // Header with title and points
                    HStack(alignment: .top) {
                        Text("Eco Shorts")
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

                    // Scrollable content (list of videos)
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 16) {
                            ForEach(videos) { video in
                                NavigationLink(destination: VideoPlayerView(video: video)) {
                                    VideoRow(video: video)
                                }
                            }
                        }
                        .padding()
                    }
                    .simultaneousGesture(DragGesture().onEnded { gesture in
                        if gesture.translation.width > 50 { // Detect right swipe
                            presentationMode.wrappedValue.dismiss()
                        }
                    }) // Allows both scrolling and swipe gestures
                    
                    Spacer() // Pushes footer to the bottom
                    
                    HStack {
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Image(systemName: "arrow.left")
                                .font(.title)
                                .foregroundColor(.gray)
                                .padding(.leading, 40)
                                .padding(.bottom, 20) // Moves the arrow UP
                        }
                        Spacer()
                    }
                    .frame(maxHeight: 50) // Allows movement without restricting too much
                    .padding(.bottom, 10) // Moves the entire HStack lower
                    .background(.clear)
                }
                .toolbar(.hidden, for: .tabBar)
                .onAppear {
                    fetchVideos()
                    fetchUserPoints()  // Fetch user points when the view appears
                }
                .background(Color(.systemGray6))
            }
            .ignoresSafeArea(edges: .bottom)
            .simultaneousGesture(DragGesture().onEnded { gesture in
                if gesture.translation.width > 50 { // Detect right swipe
                    presentationMode.wrappedValue.dismiss()
                }
            })
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
                            HStack {
                                Text(video.title)
                                    .font(.system(size: 20))
                                    .foregroundColor(.primary)

                                Spacer() // Pushes points all the way right

                                HStack(spacing: 4) {
                                    Image("points logo") // Use your asset image
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 20, height: 20) // Adjust size as needed
                                    Text("\(video.points)")
                                        .font(.subheadline)
                                        .foregroundColor(.black)
                                        .bold()
                                }
                            }
                            .padding(.top, 8)
                            
                            Text(video.about)
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                                .lineLimit(2)
                                .truncationMode(.tail)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    
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
                    .padding(.top, 8)
            
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
