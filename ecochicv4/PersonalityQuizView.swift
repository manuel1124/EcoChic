import SwiftUI
import WebKit
import FirebaseAuth
import FirebaseFirestore

struct PersonalityQuizView: View {
    let quiz: [QuizQuestion]
    let traits: [PersonalityTrait]
    let collectionId: String
    let collectionPoints: Int
    @State private var showConfetti = false

    @State private var userId = Auth.auth().currentUser?.uid
    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentationMode) var presentationMode

    @State private var currentQuestionIndex = 0
    @State private var selectedOptionIndices: [Int: Int] = [:]

    // ← NEW: store the Firestore‐loaded trait index
    @State private var loadedTraitIndex: Int? = nil

    // we’re done when we either load a previous result or complete now
    private var isQuizCompleted: Bool {
    return loadedTraitIndex != nil
      || (selectedOptionIndices.count == quiz.count && currentQuestionIndex >= quiz.count)
    }

    // pick the trait to display
    private var displayTrait: PersonalityTrait {
    // 1) if we loaded one, use it
    if let idx = loadedTraitIndex, idx >= 0, idx < traits.count {
      return traits[idx]
    }
    // 2) otherwise fall back to “most‐selected” logic
    let freq = selectedOptionIndices.values.reduce(into: [Int:Int]()) { acc, idx in
      acc[idx, default: 0] += 1
    }
    let best = freq.max(by: { $0.value < $1.value })?.key ?? 0
    return (best >= 0 && best < traits.count) ? traits[best] : traits.first!
    }

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
                            .multilineTextAlignment(.center)
                        
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
                ZStack {
                    if showConfetti {
                        ConfettiView()
                            .ignoresSafeArea()
                    }
                    let trait = displayTrait
                    VStack(spacing: 16) {
                      Text(trait.title)
                        .font(.largeTitle).bold()
                        .multilineTextAlignment(.center)
                        .padding(.top)

                      Text(trait.description)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                      Text("Tip:")
                        .font(.headline)
                        VStack(alignment: .leading, spacing: 4) {
                          ForEach(trait.tip.components(separatedBy: "\\n"), id: \.self) { line in
                            Text(line)
                              .font(.body)
                          }
                        }
                        .padding(.horizontal)
                      //Spacer()
                    }
                    .padding()
                }
                .transition(.opacity)
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            checkIfQuizAttempted()
        }
    }
    
    private func completeQuiz() {
        showConfetti = true
        // store locally so `isQuizCompleted` flips
        loadedTraitIndex = selectedOptionIndices.values
          .reduce(into: [Int:Int]()) { $0[$1, default:0] += 1 }
          .max(by: { $0.value < $1.value })?.key ?? 0

        // award points + write to Firestore
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
        guard let uid = userId,
              let idx = loadedTraitIndex
        else { return }

        let userRef = Firestore.firestore().collection("users").document(uid)
        userRef.getDocument { snap, err in
          guard let data = snap?.data(), err == nil else { return }

          var completed = data["completedQuizzes"] as? [String:Int] ?? [:]
          var points    = data["points"] as? Int           ?? 0

          if completed[collectionId] == nil {
            points += collectionPoints
          }
          completed[collectionId] = idx

          userRef.updateData([
            "completedQuizzes": completed,
            "points": points,
            "progress": completed.keys.count
          ])
        }
      }

      private func checkIfQuizAttempted() {
        guard let uid = userId else { return }

        Firestore.firestore()
          .collection("users")
          .document(uid)
          .getDocument { snap, err in
            guard err == nil,
                  let data = snap?.data(),
                  let completed = data["completedQuizzes"] as? [String:Int],
                  let idx = completed[collectionId]
            else { return }

            // load it so the view shows the right trait
            loadedTraitIndex = idx
          }
      }
    }
