import SwiftUI
import MapKit
import FirebaseFirestore

struct DiscoverView: View {
    @State private var stores: [Store] = []
    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 53.5461, longitude: -113.4938),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    )
    
    @State private var isExpanded = false
    @State private var sheetHeight: CGFloat = 70
    private let collapsedHeight: CGFloat = 70
    private let expandedHeight: CGFloat = 450
    @State private var selectedStore: Store?
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Map(position: $position) {
                ForEach(stores) { store in
                    Marker(store.name, coordinate: store.coordinate)
                }
            }
            .edgesIgnoringSafeArea(.all)
            
            if selectedStore == nil {
                VStack(alignment: .leading) {
                    Capsule()
                        .frame(width: 50, height: 5)
                        .foregroundColor(.gray.opacity(0.7))
                        .padding(.top, 24)
                        .padding(.bottom, 4)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .onTapGesture {
                            toggleSheet()
                        }
                    
                    Text("Thrift Stores")
                        .font(.system(size: 20, weight: .bold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 4)
                    
                    List(stores) { store in
                        Button(action: {
                            selectStore(store)
                        }) {
                            StoreRow(store: store)
                                .frame(maxWidth: .infinity) // Ensure it takes full width
                        }
                        .buttonStyle(PlainButtonStyle())
                        .listRowInsets(EdgeInsets()) // Remove default insets
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                    }
                    .listStyle(PlainListStyle()) // Make it behave more like ScrollView
                    .scrollContentBackground(.hidden) // Remove default background
                    //.padding()
                }
                .frame(height: sheetHeight)
                .background(Color(.systemGray6))
                .cornerRadius(16)
                .shadow(radius: 5)
                .gesture(
                    DragGesture()
                        .onEnded { value in
                            if value.translation.height < -50 {
                                expandSheet()
                            } else if value.translation.height > 50 {
                                collapseSheet()
                            }
                        }
                )
            }
            
            if let selectedStore = selectedStore {
                VStack(alignment: .leading, spacing: 8) {
                    Button(action: {
                        collapseSheet()
                    }) {
                        HStack {
                            Image(systemName: "arrow.left.circle.fill")
                                .foregroundColor(.blue)
                            Text("Back")
                                .foregroundColor(.blue)
                                .font(.headline)
                        }
                        .padding(.top, 10)
                    }
                    
                    Text(selectedStore.name)
                        .font(.title)
                        .bold()
                    Text("📍 Location: \(selectedStore.location)")
                        .font(.subheadline)
                    
                    Text("Available Coupons:")
                        .font(.headline)
                        .padding(.top, 8)
                    
                    ForEach(selectedStore.coupons) { coupon in
                        VStack(alignment: .leading) {
                            Text("\(coupon.description)")
                                .font(.subheadline)
                            Text("🎟 Requires: \(coupon.requiredPoints) points")
                                .font(.footnote)
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(10)
                        .shadow(radius: 2)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white)
                .cornerRadius(16)
                .shadow(radius: 5)
                .transition(.move(edge: .bottom))
            }
        }
        .onAppear {
            fetchStores { fetchedStores in
                self.stores = fetchedStores
            }
        }
    }
    
    private func selectStore(_ store: Store) {
        withAnimation {
            selectedStore = store
            position = .region(MKCoordinateRegion(
                center: store.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            ))
            sheetHeight = 0 // Hide the thrift store slider when selecting a store
        }
    }
    
    private func toggleSheet() {
        withAnimation {
            isExpanded.toggle()
            sheetHeight = isExpanded ? expandedHeight : collapsedHeight
        }
    }
    
    private func expandSheet() {
        withAnimation {
            isExpanded = true
            sheetHeight = expandedHeight
        }
    }
    
    private func collapseSheet() {
        withAnimation {
            isExpanded = false
            sheetHeight = expandedHeight // Restore the thrift store slider
            selectedStore = nil
        }
    }
}
