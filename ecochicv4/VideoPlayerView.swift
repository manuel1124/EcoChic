import SwiftUI
import WebKit
import FirebaseAuth
import FirebaseFirestore

struct VideoPlayerView: View {
    let video: Video
    @State private var isQuizEnabled = false
    @State private var isQuizCompleted = false
    @State private var userScore: Int? = nil
    @State private var userId = Auth.auth().currentUser?.uid
    @State private var userPoints: Int = 0
    @Environment(\.presentationMode) var presentationMode // Allows dismissing the view

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(video.title)
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
            .padding([.top, .leading, .trailing])

            YouTubePlayer(videoID: extractYouTubeID(from: video.videoURL), onVideoFinished: {
                isQuizEnabled = true
            })
            .frame(height: 200)
            .cornerRadius(12)
            .padding(.horizontal)
            
            Text("Watch the short then answer the quiz questions.")
                .font(.system(size: 24))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)
                .padding(.horizontal, 20)
            

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
                
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                Text("\(video.points)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top)
            .padding(.horizontal)
                
                
            if isQuizCompleted {
                Text("Quiz Completed!")
                    .font(.title)
                    .foregroundColor(.green)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .center)
                if let score = userScore {
                    Text("Your Score: \(score)%")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                Spacer()
                goBackButton
            } else {
                if isQuizEnabled {
                    NavigationLink(destination: QuizView(quiz: video.quiz, videoId: video.id, videoPoints: video.points)) {
                        Text("Start Quiz")
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color(hex: "#718B6E"))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            .padding(.horizontal)
                    }
                } else {
                    Text("Start Quiz")
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.black.opacity(0.5))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .padding(.horizontal)
                        .opacity(0.7)
                }
                Spacer()
                goBackButton
            }
        }
        .navigationBarBackButtonHidden(true) // Hides default back button
        .background(Color(.systemGray6))
        .onAppear {
            checkIfQuizAttempted()
            fetchUserPoints()
        }
    }
    
    private var goBackButton: some View {
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

struct FullScreenYouTubePlayer: View {
    let videoID: String
    var onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            WebView(urlString: "https://www.youtube.com/embed/\(videoID)?autoplay=1&controls=0&modestbranding=1&rel=0")
                .ignoresSafeArea()
            
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        onDismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .resizable()
                            .frame(width: 40, height: 40)
                            .foregroundColor(.white)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    .padding()
                }
                Spacer()
            }
        }
    }
}

struct WebView: UIViewRepresentable {
    let urlString: String
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        if let url = URL(string: urlString) {
            webView.load(URLRequest(url: url))
        }
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}



struct YouTubePlayer: UIViewRepresentable {
    let videoID: String
    var onVideoFinished: () -> Void
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let contentController = WKUserContentController()
        
        contentController.add(context.coordinator, name: "videoFinished") // Add message handler
        
        configuration.userContentController = contentController
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        
        let embedHTML = """
        <html>
        <body style='margin:0px;padding:0px;'>
        <iframe id='player' type='text/html' width='100%' height='100%' 
            src='https://www.youtube.com/embed/\(videoID)?enablejsapi=1&playsinline=1'
            frameborder='0'></iframe>
        <script>
        var player;
        function onYouTubeIframeAPIReady() {
            player = new YT.Player('player', {
                events: {
                    'onStateChange': onPlayerStateChange
                }
            });
        }
        function onPlayerStateChange(event) {
            if (event.data == 0) { // Video ended
                window.webkit.messageHandlers.videoFinished.postMessage("done");
            }
        }
        </script>
        <script src='https://www.youtube.com/iframe_api'></script>
        </body>
        </html>
        """
        
        webView.loadHTMLString(embedHTML, baseURL: nil)
        return webView
    }

    
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onVideoFinished: onVideoFinished)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var onVideoFinished: () -> Void

        init(onVideoFinished: @escaping () -> Void) {
            self.onVideoFinished = onVideoFinished
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            let script = "onYouTubeIframeAPIReady();"
            webView.evaluateJavaScript(script, completionHandler: nil)
        }

        // Conform to WKScriptMessageHandler
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "videoFinished" {
                onVideoFinished()
            }
        }
    }

}


func extractYouTubeID(from url: String) -> String {
    if let url = URL(string: url), let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: true)?.queryItems {
        if let videoID = queryItems.first(where: { $0.name == "v" })?.value {
            return videoID
        }
    }
    return url.replacingOccurrences(of: "https://www.youtube.com/watch?v=", with: "")
}

struct QuizView: View {
    let quiz: [QuizQuestion]
    let videoId: String
    let videoPoints: Int
    @State private var currentQuestionIndex = 0
    @State private var correctAnswers = 0
    @State private var isQuizCompleted = false
    @State private var userId = Auth.auth().currentUser?.uid
    @State private var userScore: Int?
    @State private var isRetakePromptVisible = false
    @State private var selectedAnswers: [Int: String] = [:]  // Track selected options
    @Environment(\.presentationMode) var presentationMode  // For manual back navigation

    var body: some View {
        VStack {
            if isQuizCompleted {
                Text("Quiz Completed!")
                    .font(.title)
                    .foregroundColor(.green)
                    .padding()

                if let score = userScore {
                    Text("Your Score: \(score)%")
                        .font(.headline)
                        .padding()
                }

                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Text("Go Back")
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.black)
                        .cornerRadius(8)
                        .padding(.horizontal)
                }
            } else if isRetakePromptVisible {
                VStack {
                    Text("Your Score: \(correctAnswers * 100 / quiz.count)%")
                        .font(.title)
                        .foregroundColor(.red)
                        .padding()

                    Text("You need 80% to complete the quiz.")
                        .font(.headline)
                        .padding()

                    Button(action: resetQuiz) {
                        Text("Retake Quiz")
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color(hex: "#718B6E"))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            .padding(.horizontal)
                    }

                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Text("Go Back")
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.gray.opacity(0.2))
                            .foregroundColor(.black)
                            .cornerRadius(8)
                            .padding(.horizontal)
                    }
                }
            } else {
                VStack {
                    Text("Question \(currentQuestionIndex + 1) of \(quiz.count)")
                        .font(.headline)
                        .padding()

                    if currentQuestionIndex < quiz.count {
                        Text(quiz[currentQuestionIndex].questionText)
                            .font(.title)
                            .padding()
                        
                        ForEach(quiz[currentQuestionIndex].options, id: \.self) { option in
                            Button(action: {
                                selectedAnswers[currentQuestionIndex] = option
                            }) {
                                Text(option)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(selectedAnswers[currentQuestionIndex] == option ? Color.blue : Color.gray.opacity(0.2))
                                    .foregroundColor(selectedAnswers[currentQuestionIndex] == option ? .white : .black)
                                    .cornerRadius(8)
                                    .padding(.horizontal)
                            }
                        }
                        // Automatically go to the next question
                        /*
                        ForEach(quiz[currentQuestionIndex].options, id: \.self) { option in
                            Button(action: {
                                selectedAnswers[currentQuestionIndex] = option
                                if currentQuestionIndex < quiz.count - 1 {
                                    currentQuestionIndex += 1  // Move to next question automatically
                                }
                            }) {
                                Text(option)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(selectedAnswers[currentQuestionIndex] == option ? Color.blue : Color.gray.opacity(0.2))
                                    .foregroundColor(selectedAnswers[currentQuestionIndex] == option ? .white : .black)
                                    .cornerRadius(8)
                                    .padding(.horizontal)
                            }
                        }
                         */

                    }

                    Spacer()

                    HStack {
                        Button(action: {
                            if currentQuestionIndex > 0 {
                                currentQuestionIndex -= 1
                            }
                        }) {
                            Image(systemName: "arrow.left")
                                .padding()
                                .foregroundColor(currentQuestionIndex > 0 ? .blue : .clear)
                        }
                        .disabled(currentQuestionIndex == 0)

                        Spacer()

                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Text("CANCEL")
                                .font(.headline)
                                .foregroundColor(.red)
                        }

                        Spacer()

                        Button(action: completeQuiz) {
                            Text("SUBMIT")
                                .font(.headline)
                                .foregroundColor(.green)
                        }

                        Spacer()

                        Button(action: {
                            if currentQuestionIndex < quiz.count - 1 {
                                currentQuestionIndex += 1
                            }
                        }) {
                            Image(systemName: "arrow.right")
                                .padding()
                                .foregroundColor(currentQuestionIndex < quiz.count - 1 ? .blue : .clear)
                        }
                        .disabled(currentQuestionIndex >= quiz.count - 1)
                    }
                    .padding()
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationTitle("Quiz")
        .onAppear {
            checkIfQuizAttempted()
        }
    }

    private func completeQuiz() {
        correctAnswers = quiz.indices.reduce(0) { count, index in
            count + (selectedAnswers[index] == quiz[index].correctAnswer ? 1 : 0)
        }

        let calculatedScore = (correctAnswers * 100) / quiz.count
        userScore = calculatedScore

        if calculatedScore >= 80 {
            isQuizCompleted = true
            updateFirestoreScore(calculatedScore)
        } else {
            isRetakePromptVisible = true
        }
    }

    private func resetQuiz() {
        currentQuestionIndex = 0
        correctAnswers = 0
        selectedAnswers = [:]
        isRetakePromptVisible = false
    }
    
    private func updateFirestoreScore(_ score: Int) {
        guard let userId = userId else { return }
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(userId)
        
        userRef.getDocument { document, error in
            if let error = error {
                print("Error fetching user document: \(error.localizedDescription)")
                return
            }
            
            if let document = document, document.exists {
                var completedQuizzes = document.data()?["completedQuizzes"] as? [String: Int] ?? [:]
                var currentPoints = document.data()?["points"] as? Int ?? 0
                
                if completedQuizzes[videoId] == nil {
                    currentPoints += videoPoints
                }
                
                completedQuizzes[videoId] = score
                
                userRef.updateData([
                    "completedQuizzes": completedQuizzes,
                    "points": currentPoints,
                    "progress": completedQuizzes.keys.count
                ]) { error in
                    if let error = error {
                        print("Error updating user progress: \(error.localizedDescription)")
                    } else {
                        print("User progress and points updated successfully!")
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
                    userScore = score
                }
            }
        }
    }
}
