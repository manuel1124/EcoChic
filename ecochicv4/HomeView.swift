import SwiftUI
import FirebaseAuth
import AVKit
import FirebaseFirestore

struct HomeView: View {
    
    @State private var videos: [Video] = [] // Videos loaded from Firestore

    var body: some View {
        NavigationView {
            VStack {
                Text("Videos Available")
                    .font(.headline)
                    .padding()

                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 150), spacing: 16)],
                        spacing: 16
                    ) {
                        ForEach(videos) { video in
                            NavigationLink(destination: VideoPlayerView(video: video)) {
                                VideoCard(video: video)
                            }
                        }
                    }
                    .padding()
                }
            }
            .onAppear {
                //addNewVideoWithQuiz()
                fetchVideos()
                //addBasicVideo()
            }
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
                      let duration = data["duration"] as? String,
                      let videoURL = data["url"] as? String,
                      let thumbnailURL = data["thumbnailUrl"] as? String else {
                    return nil
                }
                
                // Safely parse the quiz data
                let quiz: [QuizQuestion] = (data["quiz"] as? [[String: Any]])?.compactMap { quizData in
                    guard let questionText = quizData["questionText"] as? String,
                          let options = quizData["options"] as? [String],
                          let correctAnswer = quizData["correctAnswer"] as? String else {
                        return nil
                    }
                    return QuizQuestion(
                        questionText: questionText,
                        options: options,
                        correctAnswer: correctAnswer
                    )
                } ?? []

                return Video(
                    id: doc.documentID,
                    title: title,
                    duration: duration,
                    videoURL: videoURL,
                    thumbnailURL: thumbnailURL,
                    quiz: quiz
                )
            }
        }
    }
     
}


struct VideoPlayerView: View {
    let video: Video
    @State private var isQuizCompleted = false
    @State private var userScore: Int? = nil
    @State private var userId = Auth.auth().currentUser?.uid
    @State private var isFullscreen = false

    var body: some View {
        Group {
            if isFullscreen {
                fullscreenVideoPlayer
            } else {
                standardVideoPlayer
            }
        }
        .onAppear {
            checkIfQuizAttempted()
        }
    }

    private var standardVideoPlayer: some View {
        VStack(spacing: 16) {
            if let videoURL = URL(string: video.videoURL) {
                ZStack(alignment: .topTrailing) {
                    VideoPlayerContainer(videoURL: videoURL, isFullscreen: $isFullscreen)

                    Button(action: {
                        withAnimation {
                            isFullscreen.toggle()
                        }
                    }) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .clipShape(Circle())
                    }
                    .padding(.top, 16)
                    .padding(.trailing, 16)
                }
            } else {
                Text("Invalid video URL")
                    .foregroundColor(.red)
                    .padding()
            }

            // Quiz and Video Details
            VStack(spacing: 16) {
                Text(video.title)
                    .font(.title)
                    .padding()

                if isQuizCompleted {
                    VStack(spacing: 8) {
                        Text("Quiz Completed!")
                            .font(.title)
                            .foregroundColor(.green)

                        if let score = userScore {
                            Text("Your Score: \(score)%")
                                .font(.headline)
                                .padding(.bottom)
                        } else {
                            Text("Score unavailable.")
                                .font(.headline)
                                .padding(.bottom)
                        }
                    }
                } else {
                    NavigationLink(destination: QuizView(quiz: video.quiz, videoId: video.id)) {
                        Text("Continue to Quiz")
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            .padding(.horizontal)
                    }
                }

                Spacer()
            }
            .padding()
        }
    }

    private var fullscreenVideoPlayer: some View {
        ZStack(alignment: .topTrailing) {
            if let videoURL = URL(string: video.videoURL) {
                VideoPlayerContainer(videoURL: videoURL, isFullscreen: $isFullscreen)

                Button(action: {
                    withAnimation {
                        isFullscreen.toggle()
                    }
                }) {
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .clipShape(Circle())
                }
                .padding(.top, 40)
                .padding(.trailing, 16)
            } else {
                Text("Invalid video URL")
                    .foregroundColor(.red)
                    .padding()
            }
        }
        .background(Color.black.edgesIgnoringSafeArea(.all))
    }

    private func checkIfQuizAttempted() {
        guard let userId = userId else { return }
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
                    if let score = completedQuizzes[video.id] {
                        isQuizCompleted = true
                        userScore = score
                    } else {
                        isQuizCompleted = false
                        userScore = nil
                    }
                }
            } else {
                DispatchQueue.main.async {
                    isQuizCompleted = false
                    userScore = nil
                }
            }
        }
    }
}


struct VideoPlayerContainer: View {
    let videoURL: URL
    @Binding var isFullscreen: Bool
    @State private var player: AVPlayer?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.edgesIgnoringSafeArea(isFullscreen ? .all : [])

                if let player = player {
                    VideoPlayer(player: player)
                        .aspectRatio(16 / 9, contentMode: .fit)
                        .frame(
                            width: isFullscreen ? geometry.size.width : geometry.size.width,
                            height: isFullscreen ? geometry.size.height : 300
                        )
                        .onAppear {
                            player.play()
                        }
                        .onDisappear {
                            player.pause()
                        }
                        .onTapGesture {
                            if isFullscreen {
                                withAnimation {
                                    isFullscreen.toggle()
                                }
                            }
                        }
                } else {
                    Text("Loading video...")
                        .foregroundColor(.white)
                }
            }
            .onAppear {
                player = AVPlayer(url: videoURL)
            }
            .onDisappear {
                player?.pause()
                player = nil // Release player resources when exiting
            }
        }
    }
}



struct QuizView: View {
    let quiz: [QuizQuestion]
    let videoId: String
    @State private var currentQuestionIndex = 0
    @State private var correctAnswers = 0
    @State private var isQuizCompleted = false
    @State private var progress: Double = 0.0
    @State private var userId = Auth.auth().currentUser?.uid
    @State private var userScore: Int? // Fetch user's stored score from Firestore

    var body: some View {
        VStack {
            if isQuizCompleted {
                Text("Quiz Completed!")
                    .font(.title)
                    .foregroundColor(.green)
                    .padding()

                if let score = userScore {
                    Text("Your Score: \(score)%") // Display the stored score
                        .font(.headline)
                        .padding()
                } else {
                    Text("Calculating your score...")
                        .font(.headline)
                        .padding()
                }

                ProgressView(value: 1.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: .green))
                    .padding()

                Spacer()
            } else {
                VStack {
                    ProgressView(value: progress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                        .padding()

                    Text(quiz[currentQuestionIndex].questionText)
                        .font(.title)
                        .padding()

                    ForEach(quiz[currentQuestionIndex].options, id: \.self) { option in
                        Button(action: {
                            gradeAnswer(selectedOption: option)
                        }) {
                            Text(option)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.gray.opacity(0.2))
                                .foregroundColor(.black)
                                .cornerRadius(8)
                                .padding(.horizontal)
                        }
                    }
                }
            }
        }
        .navigationTitle("Quiz")
        .onAppear {
            checkIfQuizAttempted()
        }
    }

    private func gradeAnswer(selectedOption: String) {
        if selectedOption == quiz[currentQuestionIndex].correctAnswer {
            correctAnswers += 1
        }

        currentQuestionIndex += 1
        progress = Double(currentQuestionIndex) / Double(quiz.count)

        if currentQuestionIndex >= quiz.count {
            completeQuiz()
        }
    }

    private func completeQuiz() {
        isQuizCompleted = true

        guard let userId = userId else { return }
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(userId)

        let calculatedScore = (correctAnswers * 100) / quiz.count
        userScore = calculatedScore // Update local score for immediate display

        userRef.getDocument { document, error in
            if let error = error {
                print("Error fetching user document: \(error.localizedDescription)")
                return
            }

            if let document = document, document.exists {
                var completedQuizzes = document.data()?["completedQuizzes"] as? [String: Int] ?? [:]
                completedQuizzes[videoId] = calculatedScore // Update the score for this quiz

                // Update the number of completed quizzes as progress
                let progress = completedQuizzes.keys.count

                userRef.updateData([
                    "completedQuizzes": completedQuizzes,
                    "progress": progress
                ]) { error in
                    if let error = error {
                        print("Error updating user progress: \(error.localizedDescription)")
                    } else {
                        print("User progress updated successfully!")
                    }
                }
            }
        }
    }

    private func checkIfQuizAttempted() {
        guard let userId = userId else { return }
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(userId)

        userRef.getDocument { document, error in
            if let error = error {
                print("Error fetching user document: \(error.localizedDescription)")
                return
            }

            if let document = document, document.exists {
                let completedQuizzes = document.data()?["completedQuizzes"] as? [String: Int] ?? [:]
                if let score = completedQuizzes[videoId] {
                    isQuizCompleted = true
                    userScore = score // Fetch stored score
                }
            }
        }
    }
}




struct QuizQuestion: Identifiable {
    let id = UUID() // Unique identifier for each question
    let questionText: String
    let options: [String]
    let correctAnswer: String
}

struct Video: Identifiable {
    let id: String
    let title: String
    let duration: String
    let videoURL: String
    let thumbnailURL: String
    let quiz: [QuizQuestion] // Array of QuizQuestion objects
}


struct VideoCard: View {
    let video: Video

    var body: some View {
        VStack(alignment: .leading) {
            ZStack(alignment: .topLeading) {
                if let url = URL(string: video.thumbnailURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            Color.gray.opacity(0.2) // Placeholder color
                                .frame(width: 180, height: 150) // Increased size
                                .cornerRadius(12)
                        case .success(let image):
                            image.resizable()
                                .scaledToFill()
                                .frame(width: 180, height: 150) // Increased size
                                .clipped() // Ensure no overflow
                                .cornerRadius(12)
                        case .failure:
                            Color.red.opacity(0.2) // Error placeholder
                                .frame(width: 180, height: 150) // Increased size
                                .cornerRadius(12)
                        @unknown default:
                            Color.gray.opacity(0.2)
                                .frame(width: 180, height: 150) // Increased size
                                .cornerRadius(12)
                        }
                    }
                } else {
                    Color.gray.opacity(0.2) // Fallback for invalid URL
                        .frame(width: 180, height: 150) // Increased size
                        .cornerRadius(12)
                }

                Text(video.duration)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(5)
                    .background(Color.green.opacity(0.8))
                    .cornerRadius(6)
                    .padding(6)
            }

            Text(video.title)
                .font(.headline)
                .lineLimit(1)
                .padding(.horizontal, 8)
        }
        .frame(width: 180) // Increased width for alignment
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.gray.opacity(0.4), radius: 4, x: 0, y: 2)
    }
}



func addNewVideoWithQuiz() {
    let db = Firestore.firestore()
    
    let videoData: [String: Any] = [
        "title": "Ocean reafs",
        "duration": "10:32",
        "url": "https://example.com/sample-video.mp4", // Replace with actual URL
        "thumbnailUrl": "https://static.dw.com/image/38934276_605.jpg", // Replace with actual URL
        "uploadedAt": FieldValue.serverTimestamp(),
        "quiz": [
            [
                "questionText": "What is the capital of France?",
                "options": ["Paris", "London", "Berlin", "Madrid"],
                "correctAnswer": "Paris"
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


