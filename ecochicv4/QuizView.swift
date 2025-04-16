import SwiftUI
import WebKit
import FirebaseAuth
import FirebaseFirestore

struct QuizView: View {
    let quiz: [QuizQuestion]
    let collectionId: String
    let collectionPoints: Int
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
                ZStack {
                    // Confetti in the background
                    ConfettiView()
                        .ignoresSafeArea()
                    
                    // Centered completion content
                    VStack {

                        Text("Quiz Completed!")
                            .font(.title)
                            .foregroundColor(.green)
                            .padding()
                        
                        if let score = userScore {
                            Text("Your Score: \(score)%")
                                .font(.headline)
                                .padding()
                        }
                        
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Text("Go Back")
                                .padding()
                                .frame(maxWidth: 200) // Fixed width so it's not too wide.
                                .background(Color.gray.opacity(0.2))
                                .foregroundColor(.black)
                                .cornerRadius(8)
                        }
                        .padding(.horizontal)
                        
                        //Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .transition(.opacity)
                
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
                            .background(Color(hex: "#48CB64"))
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
        //.navigationTitle("Quiz")
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
                
                if completedQuizzes[collectionId] == nil {
                    currentPoints += collectionPoints
                }
                
                completedQuizzes[collectionId] = score
                
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
                    userScore = score
                }
            }
        }
    }
}
