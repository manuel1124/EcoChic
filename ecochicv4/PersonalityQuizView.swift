import SwiftUI
import WebKit
import FirebaseAuth
import FirebaseFirestore

struct PersonalityQuizView: View {
    let quiz: [QuizQuestion]
    let traits: [PersonalityTrait]
    let collectionId: String
    let collectionPoints: Int
    @State private var userId = Auth.auth().currentUser?.uid

    @Environment(\.dismiss) private var dismiss

    @State private var currentQuestionIndex = 0
    @State private var selectedOptionIndices: [Int: Int] = [:]
    @State private var isQuizCompleted = false
    private var selectedTraitIndex: Int {
            let freq = selectedOptionIndices.values.reduce(into: [Int:Int]()) { acc, idx in
                acc[idx, default: 0] += 1
            }
            return freq.max(by: { $0.value < $1.value })?.key ?? 0
        }
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack {
            if !isQuizCompleted {
                VStack {
                    Text("Quiz")
                        .font(.title2)
                        .bold()
                        // Make the Text take up all available width and center its contents:
                        .frame(maxWidth: .infinity, alignment: .center)
                        //.padding()
                        .padding(.top, 30)
                    
                    Text("Question \(currentQuestionIndex + 1) of \(quiz.count)")
                        .font(.headline)
                        //.padding()
                        .padding(.top, 10)
                    
                    if currentQuestionIndex < quiz.count {
                        Text(quiz[currentQuestionIndex].questionText)
                            .font(.title)
                            .padding()
                        
                        // Options
                        ForEach(quiz[currentQuestionIndex].options.indices, id: \.self) { idx in
                            let option = quiz[currentQuestionIndex].options[idx]
                            Button {
                                selectedOptionIndices[currentQuestionIndex] = idx
                            } label: {
                                Text(option)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        selectedOptionIndices[currentQuestionIndex] == idx
                                        ? Color.green.opacity(0.7)
                                        : Color.gray.opacity(0.2)
                                    )
                                    .foregroundColor(.primary)
                                    .cornerRadius(8)
                                    .padding(.horizontal)
                            }
                        }
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
                                // gray out unless we’re on the last page *and* every question has an answer
                                .foregroundColor(
                                    (selectedOptionIndices.count != quiz.count)
                                    ? Color.gray.opacity(0.5)
                                    : Color.green
                                )
                        }
                        // disable if not on last question OR not all questions answered
                        .disabled(
                            selectedOptionIndices.count != quiz.count
                        )


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
            } else {
                // MARK: Result view
                let trait = selectedTrait
                VStack(spacing: 16) {
                    Text(trait.title)
                        .font(.largeTitle)
                        .bold()
                        .multilineTextAlignment(.center)
                        .padding(.top)

                    Text(trait.description)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Text("Tip:")
                        .font(.headline)
                    Text(trait.tip)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    //Spacer()
                }
                .padding()
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            checkIfQuizAttempted()
        }
    }
    
    private func completeQuiz() {
            // simply flip into the result view
            isQuizCompleted = true
            updateFirestoreScore()
        }

    /// Tally the selected option‐indices and pick the most frequent one.
    private var selectedTrait: PersonalityTrait {
        // Build frequency map: [optionIndex: count]
        let freq = selectedOptionIndices.values.reduce(into: [Int:Int]()) { acc, idx in
            acc[idx, default: 0] += 1
        }
        // Pick the index with the highest count
        let bestIndex = freq.max(by: { $0.value < $1.value })?.key ?? 0
        // Guard against out‑of‑bounds
        if bestIndex >= 0 && bestIndex < traits.count {
            return traits[bestIndex]
        } else {
            return traits.first!
        }
    }
    
    private func updateFirestoreScore() {
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
                
                if completedQuizzes[collectionId] == nil {
                    currentPoints += collectionPoints
                }
                
                completedQuizzes[collectionId] = selectedTraitIndex
                
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
                if let score = completedQuizzes[collectionId] {
                    isQuizCompleted = true
                    //userScore = score
                }
            }
        }
    }
}
