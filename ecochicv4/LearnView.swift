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
    //let quiz: [QuizQuestion]
    let quizID: String
    let points: Int
}

struct LearnView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var videos: [Video] = []
    @State private var userPoints: Int = 0
    @State private var currentTokens: Int = 5
    @State private var lastTokenUsed: Date?
    @State private var showTokenInfo = false


    // NEW: track which video is selected for playback
    @State private var selectedVideo: Video? = nil

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
                        
                        HStack(spacing: 6) {
                            ForEach(0..<5) { index in
                                if index < currentTokens {
                                    Image("token logo")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 16, height: 16)
                                } else {
                                    Image("token logo")
                                        .resizable()
                                        .renderingMode(.template)
                                        .scaledToFit()
                                        .frame(width: 16, height: 16)
                                        .foregroundColor(.gray.opacity(0.4))
                                }
                            }

                            Button(action: {
                                showTokenInfo = true
                            }) {
                                Image(systemName: "plus.circle")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.gray)
                            }
                            .buttonStyle(PlainButtonStyle()) // No tap highlight
                        }
                        .padding(8)
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)




                        /*
                        HStack(spacing: 4) {
                            Image("points logo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                            Text("\(userPoints)")
                                .font(.headline)
                                .bold()
                                .foregroundColor(.black)
                        }
                        .padding(10)
                        .cornerRadius(10)
                         */
                    }
                    .padding([.top, .leading, .trailing])
                         

                    // Scrollable content (list of videos)
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 16) {
                            ForEach(videos) { video in
                                // REPLACE NavigationLink with a Button that sets selectedVideo
                                Button(action: {
                                    selectedVideo = video
                                }) {
                                    VideoRow(video: video)
                                }
                                .buttonStyle(PlainButtonStyle()) // so it looks like your row
                            }
                            Spacer()
                            Text("Come back tomorrow for more!")
                                        .font(.headline)
                                        .foregroundColor(.gray)
                                        .multilineTextAlignment(.center)
                                        .padding(.top, 20)
                        }
                        .padding()
                    }
                    .simultaneousGesture(DragGesture().onEnded { gesture in
                        if gesture.translation.width > 50 {
                            presentationMode.wrappedValue.dismiss()
                        }
                    })

                    Spacer()

                    // Footer back button
                    HStack {
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Image(systemName: "arrow.left")
                                .font(.title)
                                .foregroundColor(.gray)
                                .padding(.leading, 40)
                                .padding(.bottom, 20)
                        }
                        Spacer()
                    }
                    .frame(maxHeight: 50)
                    .padding(.bottom, 10)
                    .background(Color.clear)
                }
                .toolbar(.hidden, for: .tabBar)
                .onAppear {
                    regenerateTokensIfNeeded()
                    fetchVideos()
                    fetchUserPoints()
                }
                .background(Color(.systemGray6))
            }
            .ignoresSafeArea(edges: .bottom)
            .simultaneousGesture(DragGesture().onEnded { gesture in
                if gesture.translation.width > 50 {
                    presentationMode.wrappedValue.dismiss()
                }
            })
            .sheet(item: $selectedVideo,
                   onDismiss: {
                       fetchUserPoints()
                       fetchVideos()     // ← reload all videos, which re‑triggers each row’s check
                        regenerateTokensIfNeeded()
                
                   }
            ) { video in
                NavigationStack {
                    VideoPlayerView(video: video)
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }.alert("Want more tokens?", isPresented: $showTokenInfo) {
            Button("Got it", role: .cancel) { }
        } message: {
            Text("You need tokens to attempt quizzes. Each quiz uses 1 token. Tokens regenerate every 5 hours, up to a maximum of 5.")
        }

    }
    
    func fetchVideos() {
        let db = Firestore.firestore()
        db.collection("videos").getDocuments { snapshot, error in
            if let error = error {
                print("Error fetching videos: \(error)")
                return
            }
            guard let documents = snapshot?.documents else { return }

            self.videos = documents.compactMap { doc in
                let data = doc.data()
                guard
                    let title        = data["title"]        as? String,
                    let about        = data["about"]        as? String,
                    let duration     = data["duration"]     as? String,
                    let videoURL     = data["url"]          as? String,
                    let thumbnailURL = data["thumbnailUrl"] as? String,
                    let quizID       = data["quizID"]       as? String,
                    let points       = data["points"]       as? Int
                else {
                    print("Skipping video due to missing fields")
                    return nil
                }

                return Video(
                    id:           doc.documentID,
                    title:        title,
                    about:        about,
                    duration:     duration,
                    videoURL:     videoURL,
                    thumbnailURL: thumbnailURL,
                    quizID:       quizID,
                    points:       points
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
    
    func regenerateTokensIfNeeded() {
        guard let user = Auth.auth().currentUser else { return }
        let db = Firestore.firestore()
        let userDoc = db.collection("users").document(user.uid)

        userDoc.getDocument { snapshot, error in
            if let error = error {
                print("Error fetching user data: \(error.localizedDescription)")
                return
            }

            let now = Date()
            var currentTokens = snapshot?.get("currentTokens") as? Int ?? 5
            var lastTokenUsed = snapshot?.get("lastTokenUsed") as? Timestamp ?? Timestamp(date: now)

            let lastDate = lastTokenUsed.dateValue()
            let hoursSinceLast = now.timeIntervalSince(lastDate) / 3600
            let tokensToRegenerate = Int(hoursSinceLast / 5)

            if tokensToRegenerate > 0 && currentTokens < 5 {
                let newTokenCount = min(currentTokens + tokensToRegenerate, 5)
                let timeAdded = TimeInterval(tokensToRegenerate * 5 * 3600)
                let newLastUsed = lastDate.addingTimeInterval(timeAdded)

                userDoc.updateData([
                    "currentTokens": newTokenCount,
                    "lastTokenUsed": Timestamp(date: newLastUsed)
                ]) { error in
                    if let error = error {
                        print("Error updating regenerated tokens: \(error.localizedDescription)")
                    } else {
                        print("Regenerated \(tokensToRegenerate) tokens → \(newTokenCount) total")
                        self.currentTokens = newTokenCount
                        self.lastTokenUsed = newLastUsed
                    }
                }
            } else {
                // Just sync current state if no regeneration
                self.currentTokens = currentTokens
                self.lastTokenUsed = lastDate
            }
        }
    }


    
}



struct VideoRow: View {
    let video: Video
    @State private var isQuizCompleted = false
    @State private var questionCount: Int = 0
    @State private var completionListener: ListenerRegistration? = nil
    
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
                        Text("\(questionCount)")
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
                    fetchQuestionCount()
                    startListeningForCompletion()
                }
                .onDisappear {
                    // Tear down the listener when the row scrolls off‑screen
                    completionListener?.remove()
                }
    }

    private func fetchQuestionCount() {
           let db = Firestore.firestore()
           db.collection("quizzes")
             .document(video.quizID)
             .getDocument { snapshot, error in
               guard
                 error == nil,
                 let data = snapshot?.data(),
                 let raw = data["questions"] as? [[String:Any]]
               else { return }
               DispatchQueue.main.async {
                   self.questionCount = raw.count
               }
           }
       }

       private func startListeningForCompletion() {
           guard let uid = Auth.auth().currentUser?.uid else { return }
           let userDoc = Firestore.firestore()
               .collection("users")
               .document(uid)

           // Attach a snapshot listener
           completionListener = userDoc.addSnapshotListener { snapshot, error in
               guard
                   error == nil,
                   let data = snapshot?.data(),
                   let completed = data["completedQuizzes"] as? [String: Int]
               else { return }

               DispatchQueue.main.async {
                   // Flip the checkmark on/off as soon as Firestore changes
                   self.isQuizCompleted = (completed[video.id] != nil)
               }
           }
       }
   }
