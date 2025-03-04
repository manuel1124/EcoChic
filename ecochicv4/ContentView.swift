//
//  ContentView.swift
//  ecochicv4
//
//  Created by Manuel Teran on 2024-12-27.
//

import SwiftUI

struct ContentView: View {
    @Environment(AppController.self) private var appController
    
    var body: some View {
        Group {
            switch appController.authState {
            case .undefined:
                ProgressView()
            case .notAuthenticated:
                SignInView()
            case .authenticated:
                FooterView()
            }
        }
    }
}
