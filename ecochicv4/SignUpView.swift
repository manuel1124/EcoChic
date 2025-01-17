import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct SignUpView: View {
    @Environment(AppController.self) private var appController // Use @Environment
    
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    
    var body: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 10)
            
            // Logo
            Image("mainlogo")
                .resizable()
                .scaledToFit()
                .frame(width: 300, height: 300)
            
            // Title
            //Text("Create New Account")
             //   .font(.system(size: 42, weight: .bold))
               // .foregroundColor(.green)
                //.multilineTextAlignment(.center)
                //.padding(.bottom, 10)
                //.offset(y: -30)

            // Name, Email, and Password Fields
            VStack(spacing: 16) {
                // Name Field
                HStack {
                    Image(systemName: "person")
                        .foregroundColor(.green)
                        .frame(width: 24, height: 24)
                    TextField("Name", text: $name)
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding(12)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(12)
                }
                
                // Email Field
                HStack {
                    Image(systemName: "envelope")
                        .foregroundColor(.green)
                        .frame(width: 24, height: 24)
                    TextField("Email", text: $email)
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding(12)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(12)
                }
                
                // Password Field
                HStack {
                    Image(systemName: "lock")
                        .foregroundColor(.green)
                        .frame(width: 24, height: 24)
                    SecureField("Password", text: $password)
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding(12)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal, 16)
            .offset(y: -10)

            // Sign-Up Button
            Button(action: {
                signUp()
            }) {
                Text("SIGN UP")
                    .fontWeight(.bold)
                    .frame(width: 200)
                    .padding()
                    .background(.green)
                    .foregroundColor(.white)
                    .cornerRadius(25)
            }
            .padding(.horizontal, 8)
            
            Spacer()
        }
        .padding()
    }
    
    func signUp() {
        Task {
            do {
                // Create user in Firebase Auth
                let authResult = try await Auth.auth().createUser(withEmail: email, password: password)
                let userId = authResult.user.uid
                
                // Save additional user data to Firestore
                let db = Firestore.firestore()
                try await db.collection("users").document(userId).setData([
                    "name": name,
                    "email": email,
                    "progress": 0, // Initial progress
                    "createdAt": FieldValue.serverTimestamp()
                ])
                
                // Update Firebase Auth user profile with name
                let changeRequest = authResult.user.createProfileChangeRequest()
                changeRequest.displayName = name
                try await changeRequest.commitChanges()
                
                print("Sign Up Successful: User data saved")
            } catch {
                print("Sign Up Error: \(error.localizedDescription)")
            }
        }
    }
}
