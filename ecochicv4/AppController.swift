//
//  AppController.swift
//  ecochicv4
//
//  Created by Manuel Teran on 2024-12-27.
//

import SwiftUI
import FirebaseAuth

enum AuthState {
    case undefined, authenticated, notAuthenticated
}
@Observable
class AppController {
    var authState: AuthState = .undefined
    
    func listenToAuthChanges() {
        Auth.auth().addStateDidChangeListener { auth, user in
            self.authState = user != nil ? .authenticated : .notAuthenticated
        }
    }
    
    func signUp(email: String, password: String) async throws {
        _ = try await Auth.auth().createUser(withEmail: email, password: password)
    }
    
    func signIn(email: String, password: String) async throws {
        _ = try await Auth.auth().signIn(withEmail: email, password: password)
    }
    
    func signOut() throws {
        try Auth.auth().signOut()
    }
}
