import SwiftUI

struct SignInView: View {
    @Environment(AppController.self) private var appController // Use @Environment
    
    @State private var email: String = ""
    @State private var password: String = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Spacer().frame(height: 20)

                // Logo
                Image("mainlogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 300, height: 300)

                // Title
                Text("Welcome Back")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundColor(.green)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 10)
                    .offset(y: -20)

                // Email and password fields
                VStack(spacing: 16) {
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

                // Sign-In Button
                Button(action: {
                    signIn()
                }) {
                    Text("SIGN IN")
                        .fontWeight(.bold)
                        .frame(width: 200)
                        .padding()
                        .background(.green)
                        .foregroundColor(.white)
                        .cornerRadius(25)
                }
                .padding(.horizontal, 8)

                // Navigate to Sign-Up
                NavigationLink(destination: SignUpView()) {
                    Text("Don't have an account? Sign up")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.green)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 10)

                Spacer()
            }
            .padding()
        }
    }
    
    func signIn() {
        Task {
            do {
                try await appController.signIn(email: email, password: password)
                print("Sign In Successful")
            } catch {
                print("Sign In Error: \(error.localizedDescription)")
            }
        }
    }
}
