import SwiftUI
import FirebaseAuth

struct SignInView: View {
    @Environment(AppController.self) private var appController
    
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var showPassword: Bool = false // State to control password visibility
    @State private var showResetPasswordAlert: Bool = false
    @State private var resetEmailSent: Bool = false
    @State private var errorMessage: String? = nil
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                // Logo
                Image("horizontal logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 180, height: 60)
                    .padding(.top, 40)
                    .padding(.leading, 18)
                
                Text("Welcome back!")
                    .font(.largeTitle).bold()
                    .padding(.leading, 20)
                
                Text("Please enter your details.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding(.leading, 21)
                
                // Input Fields
                VStack(spacing: 12) {
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                        .padding(.horizontal, 20)
                    
                    ZStack {
                        if showPassword {
                            TextField("Password", text: $password) // TextField for visible password
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(10)
                                .padding(.horizontal, 20)
                        } else {
                            SecureField("Password", text: $password) // SecureField for hidden password
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(10)
                                .padding(.horizontal, 20)
                        }
                        
                        // Eye icon inside the text field
                        HStack {
                            Spacer()
                            Button(action: {
                                showPassword.toggle() // Toggle password visibility
                            }) {
                                Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                    .foregroundColor(.gray)
                                    .padding()
                            }
                            
                        }.padding(.trailing, 20)
                    }
                    
                    // Error message
                    if let error = errorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundColor(.red)
                            .padding(.horizontal, 20)
                    }
                }
                
                // Forgot Password
                Button("Forgot Password?") {
                    showResetPasswordAlert = true
                }
                .font(.subheadline)
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 20)
                
                // Sign Up Link
                NavigationLink(destination: SignUpView().navigationBarBackButtonHidden(true)) {
                    Text("Don't have an account? Sign up.")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
                .padding(.horizontal, 20)
                
                // Sign In Button
                Button(action: signIn) {
                    Text("Sign In")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(hex: "#98BE8E"))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)

                Spacer()
            }
        }
        .alert("Reset Password", isPresented: $showResetPasswordAlert) {
            VStack {
                TextField("Email", text: $email)
                    .textInputAutocapitalization(.none)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                
                VStack {
                    Button("Cancel", role: .cancel) {
                        showResetPasswordAlert = false
                    }
                    .fontWeight(.regular)
                    
                    Button("Send Reset Link") {
                        resetPassword()
                    }
                    .fontWeight(.regular)
                }
            }
        }
        .alert("Reset Email Sent", isPresented: $resetEmailSent) {
            Button("OK", role: .cancel) { }
        }
    }
    
    func signIn() {
        Task {
            do {
                // Try to sign in the user
                let _ = try await Auth.auth().signIn(withEmail: email, password: password)
                print("Sign In Successful")
                errorMessage = nil // Clear any previous error messages
            } catch let error as NSError {
                // Check for invalid credentials error
                errorMessage = "Incorrect username or password."
            }
        }
    }
    
    func resetPassword() {
        Task {
            do {
                try await Auth.auth().sendPasswordReset(withEmail: email)
                resetEmailSent = true
            } catch {
                print("Reset Password Error: \(error.localizedDescription)")
            }
        }
    }
}
