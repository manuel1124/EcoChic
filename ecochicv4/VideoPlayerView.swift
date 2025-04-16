import SwiftUI
import WebKit
import FirebaseAuth
import FirebaseFirestore

struct VideoPlayerView: View {
    let video: Video
    
    @State private var quizQuestions: [QuizQuestion] = []
    @State private var isQuizEnabled   = false
    @State private var isQuizCompleted = false
    @State private var userScore: Int? = nil
    @State private var userPoints: Int = 0
    @State private var userId = Auth.auth().currentUser?.uid
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(video.title)
                .font(.title2)
                .bold()
                // Make the Text take up all available width and center its contents:
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
                .padding(.top, 10)
            
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
                Text("\(quizQuestions.count)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                
                Image(systemName: "clock.fill")
                    .foregroundColor(.blue)
                Text(video.duration)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Image("points logo") // Use your asset image
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20) // Adjust size as needed
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
                /*
                if let score = userScore {
                    Text("Your Score: \(score)%")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                 */
                //Spacer()
                //goBackButton
            } else {
                if isQuizEnabled {
                    NavigationLink(
                        destination: QuizView(
                            quiz: quizQuestions,
                            collectionId: video.id,
                            collectionPoints: video.points
                        )
                    ) {
                        Text("Start Quiz")
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color(hex: "#48CB64"))
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
                //Spacer()
                //goBackButton
            }
            if !video.about.isEmpty {
                Text(video.about)
                    .font(.body)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
        .navigationBarBackButtonHidden(true) // Hides default back button
        .background(Color(.systemGray6))
        .onAppear {
            checkIfQuizAttempted()
            fetchUserPoints()
            fetchQuizQuestions()
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
    
    private func fetchQuizQuestions() {
        let db = Firestore.firestore()
        db.collection("quizzes")
            .document(video.quizID)
            .getDocument { snapshot, error in
                guard
                    error == nil,
                    let data = snapshot?.data(),
                    let raw = data["questions"] as? [[String:Any]]
                else {
                    print("Failed to load quiz for ID \(video.quizID):", error ?? "")
                    return
                }
                
                let questions: [QuizQuestion] = raw.compactMap { dict in
                    guard
                        let text   = dict["questionText"] as? String,
                        let opts   = dict["options"] as? [String],
                        let correct = dict["correctAnswer"] as? String
                    else { return nil }
                    return QuizQuestion(
                        questionText: text,
                        options:      opts,
                        correctAnswer: correct
                    )
                }
                
                DispatchQueue.main.async {
                    self.quizQuestions = questions
                }
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
