import SwiftUI
import WebKit
import FirebaseAuth
import FirebaseFirestore

struct PersonalityTrait: Identifiable, Equatable {
    let id = UUID()         // or you could pull an `"id"` out of your map if you have one
    let title: String
    let description: String
    let tip: String
}

struct Personality: Identifiable, Equatable {
    let id: String
    let title: String
    let about: String
    let quizID: String
    let points: Int
    let traits: [PersonalityTrait]
}


struct StylePersonaQuizView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var personalities: [Personality] = []
    @State private var userPoints: Int = 0
    @State private var quizQuestions: [QuizQuestion] = []

    @State private var selectedPersonality: Personality? = nil
    @State private var currentTokens: Int = 5
    @State private var lastTokenUsed: Date?
    @State private var showTokenInfo = false

    var body: some View {
        NavigationView {
            ZStack {
                VStack {
                    // Header with title and points
                    HStack(alignment: .top) {
                        Text("Style Persona")
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
                            ForEach(personalities) { personality in
                                Button(action: {
                                    handlePersonalityTap(personality)
                                }) {
                                    PersonalityRow(personality: personality)
                                }
                                .buttonStyle(PlainButtonStyle())
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
                    fetchPersonalities()
                    fetchUserPoints()
                    regenerateTokensIfNeeded()
                }
                .background(Color(.systemGray6))
            }.alert("Want more tokens?", isPresented: $showTokenInfo) {
                Button("Got it", role: .cancel) { }
            } message: {
                Text("You need tokens to attempt quizzes. Each quiz uses 1 token. Tokens regenerate every 5 hours, up to a maximum of 5.")
            }
            .onChange(of: selectedPersonality) { new in
              guard let p = new else { return }
              fetchQuizQuestions(for: p.quizID)
            }
            .sheet(item: $selectedPersonality,
                   onDismiss: {
                     fetchUserPoints()
                     fetchPersonalities()
                    regenerateTokensIfNeeded()
                   }
            ) { personality in
            NavigationStack {
                    PersonalityQuizView(
                        quiz: quizQuestions,
                        traits: personality.traits,
                        collectionId: personality.id,
                        collectionPoints: personality.points
                    )
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
          }
        }
    
    private func handlePersonalityTap(_ personality: Personality) {
        guard currentTokens > 0 else {
            print("Not enough tokens to attempt quiz.")
            return
        }

        guard let user = Auth.auth().currentUser else { return }
        let db = Firestore.firestore()
        let userDoc = db.collection("users").document(user.uid)

        let now = Date()
        let newTokenCount = currentTokens - 1

        userDoc.updateData([
            "currentTokens": newTokenCount,
            "lastTokenUsed": Timestamp(date: now)
        ]) { error in
            if let error = error {
                print("Error deducting token: \(error.localizedDescription)")
            } else {
                print("Token deducted. New total: \(newTokenCount)")
                self.currentTokens = newTokenCount
                self.lastTokenUsed = now
                self.selectedPersonality = personality
            }
        }
    }

    
    private func fetchQuizQuestions(for quizID: String) {
            let db = Firestore.firestore()
            db.collection("quizzes").document(quizID)
              .getDocument { snap, err in
                guard
                  err == nil,
                  let data = snap?.data(),
                  let raw = data["questions"] as? [[String:Any]]
                else {
                  print("Failed to load quiz \(quizID):", err ?? "")
                  return
                }
                let qs = raw.compactMap { dict -> QuizQuestion? in
                    guard
                      let text = dict["questionText"] as? String,
                      let opts = dict["options"]     as? [String]
                    else { return nil }
                    return QuizQuestion(questionText: text, options: opts, correctAnswer: "")
                }
                DispatchQueue.main.async {
                    self.quizQuestions = qs
                }
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
    
    func fetchPersonalities() {
        let db = Firestore.firestore()
        db.collection("personalities").getDocuments { snapshot, error in
            if let error = error {
                print("Error fetching personalities:", error)
                return
            }
            guard let documents = snapshot?.documents else { return }

            self.personalities = documents.compactMap { doc in
                let data = doc.data()
                guard
                    let title    = data["title"]    as? String,
                    let about    = data["about"]    as? String,
                    let quizID   = data["quizID"]   as? String,
                    let points   = data["points"]   as? Int,
                    let rawTraits = data["type"]    as? [[String:Any]]
                else {
                    print("Skipping \(doc.documentID) due to missing fields")
                    return nil
                }

                // Build your traits array
                let traits: [PersonalityTrait] = rawTraits.compactMap { dict in
                    guard
                        let tTitle = dict["title"]       as? String,
                        let desc   = dict["description"] as? String,
                        let tip    = dict["tip"]         as? String
                    else {
                        return nil
                    }
                    return PersonalityTrait(
                        title: tTitle,
                        description: desc,
                        tip: tip
                    )
                }

                return Personality(
                    id:     doc.documentID,
                    title:  title,
                    about:  about,
                    quizID: quizID,
                    points: points,
                    traits: traits     // ← new
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

struct PersonalityRow: View {
    let personality: Personality

    @State private var isQuizCompleted = false
    @State private var questionCount: Int = 0
    @State private var completionListener: ListenerRegistration? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 1) Title + points
            HStack {
                Text(personality.title)
                    .font(.system(size: 20))
                    .foregroundColor(.primary)

                Spacer()

                HStack(spacing: 4) {
                    Image("points logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                    Text("\(personality.points)")
                        .font(.subheadline)
                        .bold()
                        .foregroundColor(.black)
                }
            }

            // 2) About description
            Text(personality.about)
                .font(.system(size: 16))
                .foregroundColor(.gray)
                .lineLimit(2)
                .truncationMode(.tail)

            // 3) Completion checkmark
            HStack {
                Spacer()
                Image(systemName: isQuizCompleted
                      ? "checkmark.circle.fill"
                      : "checkmark.circle")
                    .foregroundColor(isQuizCompleted ? .green : .gray)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.gray.opacity(0.2), radius: 2, x: 0, y: 1)
        .onAppear {
            fetchQuestionCount()
            startListeningForCompletion()
        }
        .onDisappear {
            completionListener?.remove()
        }
    }

    private func fetchQuestionCount() {
        let db = Firestore.firestore()
        db.collection("quizzes")
          .document(personality.quizID)
          .getDocument { snap, err in
            guard
              err == nil,
              let data = snap?.data(),
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

        completionListener = userDoc.addSnapshotListener { snap, err in
            guard
              err == nil,
              let data = snap?.data(),
              let completed = data["completedQuizzes"] as? [String:Int]
            else { return }

            DispatchQueue.main.async {
                self.isQuizCompleted = (completed[personality.id] != nil)
            }
        }
    }
}
