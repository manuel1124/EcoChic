import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ProfileView: View {
    @Environment(AppController.self) private var appController
    @State private var name: String = "Loading..."
    @State private var userEmail: String = "Loading..."
    @State private var progress: Int = 0
    @State private var userPoints: Int = 0  // Added user points

    var body: some View {
        VStack(spacing: 20) {
            // Profile title with points (like Eco Shorts)
            HStack {
                Text("Profile")
                    .font(.title)
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
            .padding(.top)
            .padding(.horizontal)

            // Profile Info Card
            VStack(alignment: .leading, spacing: 12) {
                ProfileRow(label: "Name", value: name)
                ProfileRow(label: "Email", value: userEmail)
                ProfileRow(label: "Points", value: "\(userPoints)")
                //ProfileRow(label: "Progress", value: "\(progress) quizzes completed")
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .shadow(radius: 3)
            .padding(.horizontal)

            // Logout Button
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
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(25)
            }
            .padding(.top, 20)

            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
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
                //progress = document.data()?["progress"] as? Int ?? 0
                userPoints = document.data()?["points"] as? Int ?? 0 // Fetch user points
            } else {
                print("Error fetching user profile: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }
}

// Reusable profile row component
struct ProfileRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label + ":")
                .font(.headline)
                .foregroundColor(.black)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding(.vertical, 5)
    }
}
