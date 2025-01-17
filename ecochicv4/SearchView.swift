import SwiftUI
import MapKit

struct SearchView: View {
    @State private var cameraPosition: MapCameraPosition = .region(.init(
        center: CLLocationCoordinate2D(latitude: 53.5461, longitude: -113.4938), // Edmonton
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    ))
    @State private var searchText: String = ""
    @State private var results: [MKMapItem] = []
    @State private var mapSelection: MKMapItem?

    var body: some View {
        ZStack {
            // Map with annotations
            Map(position: $cameraPosition, selection: $mapSelection) {
                ForEach(results, id: \.self) { item in
                    let placemark = item.placemark
                    Marker(placemark.name ?? "", coordinate: placemark.coordinate)
                }
            }

            // Compact search bar overlay
            VStack {
                TextField("Search...", text: $searchText)
                    .font(.footnote) // Smaller font
                    .padding(8) // Reduced padding
                    .background(Color.white.opacity(0.9)) // Slightly transparent for better visibility
                    .cornerRadius(10) // Rounded corners
                    .padding(.horizontal, 24) // Horizontal padding to center the bar
                    .shadow(radius: 5) // Subtle shadow
                    .onSubmit {
                        Task {
                            await searchPlaces()
                        }
                    }
                Spacer()
            }
            .padding(.top, 16) // Add some padding at the top to avoid overlapping with the status bar
        }
    }

    // Search for places matching the query
    func searchPlaces() async {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText

        let search = MKLocalSearch(request: request)
        do {
            let response = try await search.start()
            results = response.mapItems

            // Move map to the first result if available
            if let firstItem = results.first {
                cameraPosition = .region(MKCoordinateRegion(center: firstItem.placemark.coordinate,
                                                             span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)))
            }
        } catch {
            print("Search failed: \(error.localizedDescription)")
        }
    }
}
