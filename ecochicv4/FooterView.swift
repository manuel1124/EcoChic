//
//  Footer.swift
//  ecochicv4
//
//  Created by Manuel Teran on 2024-12-27.
//

import SwiftUI

struct FooterView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Image(systemName: "house")
                    Text("Home")
                }

            StoreView()
                .tabItem {
                    Image(systemName: "cart")
                    Text("Store")
                }

            SearchView()
                .tabItem {
                    Image(systemName: "magnifyingglass")
                    Text("Search")
                }

            NotificationView()
                .tabItem {
                    Image(systemName: "bell")
                    Text("Notifications")
                }

            ProfileView()
                .tabItem {
                    Image(systemName: "person")
                    Text("Profile")
                }
        }
    }
}

#Preview {
    FooterView()
}
