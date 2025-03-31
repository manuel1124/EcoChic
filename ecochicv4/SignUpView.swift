import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct SignUpView: View {
    @Environment(AppController.self) private var appController
    
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var passwordsMatch: Bool = true
    @State private var passwordError: String? = nil
    @State private var nameError: String? = nil
    @State private var emailError: String? = nil
    @State private var emailAlreadyExistsError: String? = nil
    @State private var showVerificationAlert: Bool = false
    @State private var showSignInView: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Logo
            Image("horizontal logo")
                .resizable()
                .scaledToFit()
                .frame(width: 180, height: 60)
                .padding(.top, 40)
                .padding(.leading, 18)
            
            Text("Welcome!")
                .font(.largeTitle).bold()
                .padding(.leading, 20)
            
            Text("Please enter your details to create an account.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .padding(.leading, 21)
            
            // Input Fields
            VStack(spacing: 12) {
                TextField("Name", text: $name)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(10)
                
                if let nameError = nameError {
                    Text(nameError)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .padding(.leading, 20)
                }
                
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(10)
                
                if let emailError = emailError {
                    Text(emailError)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .padding(.leading, 20)
                }
                
                SecureField("Create Password", text: $password)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(10)
                    .onChange(of: password) { checkPasswordsMatch() }
                
                SecureField("Confirm Password", text: $confirmPassword)
                    .padding()
                    .background(passwordsMatch ? Color.gray.opacity(0.2) : Color.red.opacity(0.2))
                    .cornerRadius(10)
                    .onChange(of: confirmPassword) { checkPasswordsMatch() }
                
                if let error = passwordError {
                    Text(error)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .padding(.leading, 20)
                }
                
                if let emailAlreadyExistsError = emailAlreadyExistsError {
                    Text(emailAlreadyExistsError)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .padding(.leading, 20)
                }
            }
            .padding(.horizontal)
            
            NavigationLink(destination: SignInView().navigationBarBackButtonHidden(true)) {
                Text("Already have an account? Sign In.")
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
            .padding(.horizontal, 20)
            
            // Sign Up Button
            Button(action: signUp) {
                Text("Sign Up")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(passwordsMatch && !password.isEmpty && !name.isEmpty && !email.isEmpty ? Color(hex: "#48CB64") : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.horizontal, 20)
            .disabled(!passwordsMatch || password.isEmpty || name.isEmpty || email.isEmpty)

            Spacer()
        }
        .padding()
    }
    
    func checkPasswordsMatch() {
        if password != confirmPassword {
            passwordError = "Passwords must match."
            passwordsMatch = false
        } else if password.count < 6 {
            passwordError = "Password must be at least 6 characters."
            passwordsMatch = false
        } else {
            passwordError = nil
            passwordsMatch = true
        }
    }
    
    func validateInputs() {
        // Validate name and email
        nameError = name.isEmpty ? "Name cannot be empty" : nil
        emailError = isValidEmail(email) ? nil : "Invalid email address"
        
        // Check if the email already has an account
        Task {
            do {
                // Check if the email is already registered
                let methods = try await Auth.auth().fetchSignInMethods(forEmail: email)
                
                if !methods.isEmpty {
                    emailAlreadyExistsError = "Email is already registered"
                } else {
                    emailAlreadyExistsError = nil
                }
            } catch {
                print("Error checking email: \(error.localizedDescription)")
            }
        }
    }
    
    func isValidEmail(_ email: String) -> Bool {
        // Simple email validation regex
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        let emailTest = NSPredicate(format: "SELF MATCHES %@", emailRegEx)
        return emailTest.evaluate(with: email)
    }
    
    func signUp() {
        // First, validate inputs
        validateInputs()
        
        // Check if there are any errors
        if nameError != nil || emailError != nil || emailAlreadyExistsError != nil || !passwordsMatch {
            // Display errors or handle invalid state
            return
        }
        
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
                    "createdAt": FieldValue.serverTimestamp(),
                    "points": 0
                ])
                
                // Update Firebase Auth user profile with name
                let changeRequest = authResult.user.createProfileChangeRequest()
                changeRequest.displayName = name
                try await changeRequest.commitChanges()
                
                // Store user details locally (optional)
                UserDefaults.standard.set(email, forKey: "PendingEmail")
                UserDefaults.standard.set(name, forKey: "PendingName")
                UserDefaults.standard.set(password, forKey: "PendingPassword")
                
                // Show verification alert or continue with app flow
                showVerificationAlert = true
                
                print("Sign Up Successful: User data saved")

            } catch {
                print("Sign Up Error: \(error.localizedDescription)")
                // Handle error, display message to user
            }
        }
    }
}
