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
                    }
                    .padding([.top, .leading, .trailing])

                    // Scrollable content (list of videos)
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 16) {
                            ForEach(personalities) { personality in
                                // REPLACE NavigationLink with a Button that sets selectedVideo
                                Button(action: {
                                    selectedPersonality = personality
                                }) {
                                    PersonalityRow(personality: personality)
                                }
                                .buttonStyle(PlainButtonStyle()) // so it looks like your row
                            }
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
                }
                .background(Color(.systemGray6))
            }
            .onChange(of: selectedPersonality) { new in
              guard let p = new else { return }
              fetchQuizQuestions(for: p.quizID)
            }
            .sheet(item: $selectedPersonality,
                   onDismiss: {
                     fetchUserPoints()
                     fetchPersonalities()
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
                .presentationDetents([.height(500), .large])
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
