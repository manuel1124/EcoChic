import SwiftUI
import MapKit
import FirebaseFirestore
import CoreLocation

struct DiscoverView: View {
    @State private var stores: [Store] = []
    @StateObject private var locationManager = LocationManager()
    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 53.5461, longitude: -113.4938),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    )

    @State private var isExpanded = false
    @State private var sheetHeight: CGFloat = 70
    private let collapsedHeight: CGFloat = 75
    private let expandedHeight: CGFloat = 490
    @State private var selectedStore: Store?
    @State private var showAlert = false
    @State private var userHasInteracted = false
    @State private var wasSheetExpandedBeforeSelection = false
    @State private var searchText = ""
    @State private var selectedCategory: String? = "Stores"
    
    let categories = ["Stores", "Events", "Recycling", "Donations"]

    var body: some View {
        
        ZStack(alignment: .bottom) {
            
            Map(position: $position) {
                if let userLocation = locationManager.userLocation {
                    Annotation("You", coordinate: userLocation) {
                        Button(action: {
                            snapToLocation(userLocation)
                        }) {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(.blue)
                                .font(.largeTitle)
                        }
                    }
                }
                
                ForEach(stores) { store in
                    if let coordinate = store.coordinate {
                        Annotation(store.name, coordinate: coordinate) {
                            Button(action: {
                                wasSheetExpandedBeforeSelection = isExpanded
                                selectStore(store)
                            }) {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundColor(.red)
                                    .font(.largeTitle)
                            }
                        }
                    }
                }
            }
            .edgesIgnoringSafeArea(.all)
            .onMapCameraChange { _ in
                userHasInteracted = true
            }
            
            VStack {
                HStack {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                            .padding(.leading, 8)
                        
                        TextField("Search", text: $searchText)
                            .foregroundColor(.black)
                            .padding(8)
                    }
                    .background(Color.white)
                    .cornerRadius(10)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.clear) // Transparent background
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.top, 10) // Moves it closer to the top
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(categories, id: \.self) { category in
                            Button(action: {
                                selectedCategory = category
                            }) {
                                Text(category)
                                    .padding(8)
                                    .background(selectedCategory == category ? Color.blue : Color.white)
                                    .foregroundColor(selectedCategory == category ? .white : .black)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                Spacer() // Pushes everything up
            }
            .padding(.horizontal, 16) // Adds padding on the sides
            
            //Spacer() // Pushes the search bar to the top
            
            if selectedCategory == "Stores" {
                
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
                                wasSheetExpandedBeforeSelection = isExpanded
                                selectStore(store)
                            }) {
                                StoreRow(store: store)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 16)
                        }
                        .listStyle(PlainListStyle())
                        .scrollContentBackground(.hidden)
                        
                        // This ensures the sheet extends fully
                        Spacer()
                    }
                    .frame(maxHeight: isExpanded ? expandedHeight : collapsedHeight)
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                    .shadow(radius: 5)
                    .ignoresSafeArea(edges: .bottom)
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
                            closeStoreDetails()
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
                        Text("Location: \(selectedStore.location)")
                            .font(.subheadline)
                        
                        // Only show 'Get Directions' if the store has coordinates
                        if let coordinate = selectedStore.coordinate {
                            Button(action: {
                                openMaps(for: selectedStore)
                            }) {
                                HStack {
                                    Image(systemName: "map.fill")
                                    Text("Get Directions")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                        }
                        
                        Text("Available Coupons:")
                            .font(.headline)
                            .padding(.top, 8)
                        
                        ForEach(selectedStore.coupons) { coupon in
                            VStack(alignment: .leading) {
                                Text("\(coupon.description)")
                                    .font(.subheadline)
                                Text("Requires: \(coupon.requiredPoints) points")
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
            } else if selectedCategory == "Events" {
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
                    
                    Text("Events")
                        .font(.system(size: 20, weight: .bold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 4)
                    
                    //Spacer()
                    
                    Text("Coming Soon")
                                .font(.title2)
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity, alignment: .center)
                            
                    Spacer()
                }
                .frame(maxHeight: isExpanded ? expandedHeight : collapsedHeight)
                .background(Color(.systemGray6))
                .cornerRadius(16)
                .shadow(radius: 5)
                .ignoresSafeArea(edges: .bottom)
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
            } else if selectedCategory == "Recycling" {
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
                    
                    Text("Recycling")
                        .font(.system(size: 20, weight: .bold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 4)
                    
                    Text("Coming Soon")
                                .font(.title2)
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity, alignment: .center)
                            
                    Spacer()
                }
                .frame(maxHeight: isExpanded ? expandedHeight : collapsedHeight)
                .background(Color(.systemGray6))
                .cornerRadius(16)
                .shadow(radius: 5)
                .ignoresSafeArea(edges: .bottom)
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
            } else if selectedCategory == "Donations" {
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
                    
                    Text("Donations")
                        .font(.system(size: 20, weight: .bold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 4)
                    
                    Text("Coming Soon")
                                .font(.title2)
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity, alignment: .center)
                            
                    Spacer()
                }
                .frame(maxHeight: isExpanded ? expandedHeight : collapsedHeight)
                .background(Color(.systemGray6))
                .cornerRadius(16)
                .shadow(radius: 5)
                .ignoresSafeArea(edges: .bottom)
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
        } .onAppear {
                fetchStores { fetchedStores in
                    self.stores = fetchedStores
                }
                
                if let userLocation = locationManager.userLocation {
                    position = .region(MKCoordinateRegion(
                        center: userLocation,
                        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                    ))
                }
            }
            .onReceive(locationManager.$userLocation) { userLocation in
                if let userLocation = userLocation, !userHasInteracted {
                    position = .region(MKCoordinateRegion(
                        center: userLocation,
                        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                    ))
                }
            }
            .alert("Location Access Needed", isPresented: $showAlert) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Please enable location services in Settings to see stores near you.")
            }
        }

    private func selectStore(_ store: Store) {
        withAnimation {
            selectedStore = store
            if let coordinate = store.coordinate {
                position = .region(MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                ))
            }
            sheetHeight = 0
        }
    }

    private func closeStoreDetails() {
        withAnimation {
            selectedStore = nil
            sheetHeight = wasSheetExpandedBeforeSelection ? expandedHeight : collapsedHeight
        }
    }
    private func snapToLocation(_ coordinate: CLLocationCoordinate2D) {
        withAnimation {
            position = .region(MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            ))
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
            sheetHeight = collapsedHeight
        }
    }

    private func openMaps(for store: Store) {
        // Safely unwrap the coordinate
        if let coordinate = store.coordinate {
            let latitude = coordinate.latitude
            let longitude = coordinate.longitude
            if let url = URL(string: "http://maps.apple.com/?daddr=\(latitude),\(longitude)") {
                UIApplication.shared.open(url)
            }
        } else {
            // Handle case where coordinate is nil (if needed)
            print("Store does not have coordinates.")
        }
    }
}

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private var locationManager = CLLocationManager()
    
    @Published var userLocation: CLLocationCoordinate2D?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    override init() {
        super.init()
        locationManager.delegate = self
        requestPermission()
    }
    
    func requestPermission() {
        authorizationStatus = locationManager.authorizationStatus
        if authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            locationManager.startUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        DispatchQueue.main.async {
            self.authorizationStatus = status
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                self.locationManager.startUpdatingLocation()
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        DispatchQueue.main.async {
            self.userLocation = location.coordinate
        }
    }
}
