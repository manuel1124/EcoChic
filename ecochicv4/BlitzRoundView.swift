import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct BlitzRoundView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var currentTokens: Int = 5
    @State private var lastTokenUsed: Date?
    @State private var showTokenInfo = false
    @State private var showQuiz = false
    @State private var quizQuestions: [QuizQuestion] = []
    @State private var isLoadingQuiz = false
    @State private var navigateToQuiz = false



    var body: some View {
        NavigationView {
            VStack {
                // Header with title + tokens
                HStack(alignment: .top) {
                    Text("Blitz Round")
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

                        Button(action: { showTokenInfo = true }) {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.gray)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(8)
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                }
                .padding([.top, .leading, .trailing])
                
                NavigationLink(destination:
                    BlitzQuizView(quiz: quizQuestions) {
                        navigateToQuiz = false
                    },
                    isActive: $navigateToQuiz
                ) {
                    EmptyView()
                }
                .hidden()


                ScrollView {
                    Button(action: handleBlitzTap) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Are you ready to test out your skills on the blitz round?")
                                    .font(.system(size: 20))
                                    .foregroundColor(.primary)

                                Spacer()

                                HStack(spacing: 4) {
                                    Image("points logo")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 20, height: 20)
                                    Text("250")
                                        .font(.subheadline)
                                        .bold()
                                        .foregroundColor(.black)
                                }
                            }

                            Text("Practice 5 random questions throughout the videos.")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                                .lineLimit(2)
                                .truncationMode(.tail)

                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(color: Color.gray.opacity(0.2), radius: 2, x: 0, y: 1)
                    }
                    .padding()
                    .padding(.top, 20)
                }

                Spacer()

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
            }
            .background(Color(.systemGray6))
            .simultaneousGesture(DragGesture().onEnded { gesture in
                if gesture.translation.width > 50 {
                    presentationMode.wrappedValue.dismiss()
                }
            })
            .onAppear {
                regenerateTokensIfNeeded()
            }
            .toolbar(.hidden, for: .tabBar)
            .background(Color(.systemGray6))
            .simultaneousGesture(DragGesture().onEnded { gesture in
                if gesture.translation.width > 50 {
                    presentationMode.wrappedValue.dismiss()
                }
            })
            .alert("Want more tokens?", isPresented: $showTokenInfo) {
                Button("Got it", role: .cancel) {}
            } message: {
                Text("You need tokens to attempt quizzes. Each quiz uses 1 token. Tokens regenerate every 5 hours, up to a maximum of 5.")
            }
        }
    }

    private func handleBlitzTap() {
        guard currentTokens > 0 else {
            print("Not enough tokens to attempt blitz round.")
            return
        }

        guard let user = Auth.auth().currentUser else { return }
        let db = Firestore.firestore()
        let userDoc = db.collection("users").document(user.uid)

        let now = Date()
        let newTokenCount = currentTokens - 1

        // Deduct token first
        userDoc.updateData([
            "currentTokens": newTokenCount,
            "lastTokenUsed": Timestamp(date: now)
        ]) { error in
            if let error = error {
                print("Error deducting token: \(error.localizedDescription)")
            } else {
                self.currentTokens = newTokenCount
                self.lastTokenUsed = now

                // 🟢 Fetch quiz AFTER token deducted
                fetchBlitzQuestions { fetchedQuestions in
                    DispatchQueue.main.async {
                        self.quizQuestions = fetchedQuestions
                        self.showQuiz = true
                    }
                }
            }
        }
    }


    private func fetchBlitzQuestions(completion: @escaping ([QuizQuestion]) -> Void) {
        let db = Firestore.firestore()
        db.collection("quizzes").document("blitzRoundMadness").getDocument { snapshot, error in
            guard let data = snapshot?.data(),
                  let allQuestions = data["questions"] as? [[String: Any]] else {
                print("❌ Failed to load blitz questions.")
                completion([])
                return
            }

            let shuffled = allQuestions.shuffled().prefix(5)

            let questions: [QuizQuestion] = shuffled.compactMap { dict in
                guard let q = dict["questionText"] as? String,
                      let opts = dict["options"] as? [String],
                      let correct = dict["correctAnswer"] as? String else { return nil }

                return QuizQuestion(questionText: q, options: opts, correctAnswer: correct)
            }

            DispatchQueue.main.async {
                self.quizQuestions = questions
                self.navigateToQuiz = true
            }

        }
    }



    private func regenerateTokensIfNeeded() {
        guard let user = Auth.auth().currentUser else { return }
        let db = Firestore.firestore()
        let userDoc = db.collection("users").document(user.uid)

        userDoc.getDocument { snapshot, error in
            if let error = error {
                print("Error fetching token data: \(error.localizedDescription)")
                return
            }

            let now = Date()
            var currentTokens = snapshot?.get("currentTokens") as? Int ?? 5
            var lastUsed = snapshot?.get("lastTokenUsed") as? Timestamp ?? Timestamp(date: now)

            let hoursSinceLast = now.timeIntervalSince(lastUsed.dateValue()) / 3600
            let tokensToRegenerate = Int(hoursSinceLast / 5)

            if tokensToRegenerate > 0 && currentTokens < 5 {
                let newCount = min(currentTokens + tokensToRegenerate, 5)
                let newLastUsed = lastUsed.dateValue().addingTimeInterval(Double(tokensToRegenerate * 5 * 3600))

                userDoc.updateData([
                    "currentTokens": newCount,
                    "lastTokenUsed": Timestamp(date: newLastUsed)
                ]) { error in
                    if error == nil {
                        self.currentTokens = newCount
                        self.lastTokenUsed = newLastUsed
                    }
                }
            } else {
                self.currentTokens = currentTokens
                self.lastTokenUsed = lastUsed.dateValue()
            }
        }
    }
}


struct BlitzQuizView: View {
    let quiz: [QuizQuestion]
    let onDismiss: () -> Void

    @State private var currentQuestionIndex = 0
    @State private var correctAnswers = 0
    @State private var isQuizCompleted = false
    @State private var userScore: Int?
    @State private var selectedAnswers: [Int: String] = [:]
    @Environment(\.presentationMode) var presentationMode


    var body: some View {
        VStack {
            if quiz.isEmpty {
                VStack {
                    ProgressView("Loading questions...")
                        .padding()
                    Button("Back") {
                        onDismiss()
                    }
                    .padding()
                }
            } else if isQuizCompleted {
                ZStack {
                    if let score = userScore, score >= 80 {
                        ConfettiView()
                            .ignoresSafeArea()
                    }

                    VStack(spacing: 16) {
                        if let score = userScore, score >= 80 {
                            Text("Blitz Round Complete!")
                                .font(.title)
                                .foregroundColor(.green)
                        }

                        if let score = userScore {
                            Text("Your Score: \(score)%")
                                .font(.headline)

                            if score >= 80 {
                                Text("+5 points awarded!")
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                            } else {
                                Text("Score at least 80% to earn points.")
                                    .font(.subheadline)
                                    .foregroundColor(.red)
                            }
                        }

                        Button("Go Back") {
                            presentationMode.wrappedValue.dismiss()
                        }
                        .padding()
                        .frame(maxWidth: 200)
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.black)
                        .cornerRadius(8)
                    }
                }
            } else {
                VStack {
                    Text("Blitz Round")
                        .font(.title2)
                        .bold()
                        .padding(.top, 30)

                    Text("Question \(currentQuestionIndex + 1) of \(quiz.count)")
                        .font(.headline)
                        .padding(.top, 10)

                    if currentQuestionIndex < quiz.count {
                        Text(quiz[currentQuestionIndex].questionText)
                            .font(.title)
                            .padding()
                            .multilineTextAlignment(.center)

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
                    } else {
                        Text("No questions found.")
                            .foregroundColor(.red)
                            .padding()
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

                        Button(action: {
                            completeQuiz()
                        }) {
                            Text("SUBMIT")
                                .font(.headline)
                                .foregroundColor(currentQuestionIndex < quiz.count - 1 ? Color.gray.opacity(0.5) : Color.green)
                        }
                        .disabled(currentQuestionIndex < quiz.count - 1)

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
    }

    private func completeQuiz() {
        correctAnswers = quiz.indices.reduce(0) { count, index in
            count + (selectedAnswers[index] == quiz[index].correctAnswer ? 1 : 0)
        }

        let score = (correctAnswers * 100) / quiz.count
        userScore = score
        isQuizCompleted = true

        if score >= 80 {
            awardBlitzPoints()
        }
    }

    private func awardBlitzPoints() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(uid)

        userRef.getDocument { snapshot, error in
            guard error == nil,
                  let data = snapshot?.data(),
                  let currentPoints = data["points"] as? Int else {
                print("Error fetching user points")
                return
            }

            userRef.updateData([
                "points": currentPoints + 250
            ]) { err in
                if let err = err {
                    print("❌ Error awarding Blitz Round points: \(err.localizedDescription)")
                } else {
                    print("✅ Awarded 250 Blitz Round points")
                }
            }
        }
    }

}
