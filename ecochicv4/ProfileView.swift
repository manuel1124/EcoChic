import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ProfileView: View {
    @Environment(AppController.self) private var appController
    @State private var name: String = "Loading..."
    @State private var userEmail: String = "Loading..."
    @State private var progress: Int = 0

    var body: some View {
        VStack(spacing: 20) {
            Text("Profile")
                .font(.largeTitle)
                .padding(.bottom, 10)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Name:")
                        .font(.headline)
                    Spacer()
                    Text(name)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }

                HStack {
                    Text("Email:")
                        .font(.headline)
                    Spacer()
                    Text(userEmail)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }

                HStack {
                    Text("Progress:")
                        .font(.headline)
                    Spacer()
                    Text("\(progress) quizzes completed")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 16)

            Button(action: {
                do {
                    try appController.signOut()
                } catch {
                    print("Error signing out: \(error.localizedDescription)")
                }
            }) {
                Text("Logout")
                    .fontWeight(.bold)
                    .frame(width: 200)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(25)
            }
            .padding(.horizontal, 8)

            Spacer()
        }
        .padding()
        .onAppear(perform: fetchUserProfile)
    }

    private func fetchUserProfile() {
        guard let user = Auth.auth().currentUser else { return }
        userEmail = user.email ?? "No Email"

        let db = Firestore.firestore()
        let userRef = db.collection("users").document(user.uid)

        userRef.getDocument { document, error in
            if let document = document, document.exists {
                name = document.data()?["name"] as? String ?? "No Name"
                progress = document.data()?["progress"] as? Int ?? 0
            } else {
                print("Error fetching user profile: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }
}

#Preview {
    ProfileView()
}
