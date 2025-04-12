import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import CoreLocation

struct StreakBoxView: View {
    var streak: Int
    @State private var showInfo = false

    // Updated dailyPoints formula:
    private func dailyPoints(for day: Int) -> Int {
        // Multiply day by 100; adjust as needed.
        var points = 100
        if day == 5 {
            points += 1000
        } else if day == 15 {
            points += 5000
        } else if day == 0 {
            points = 0
        }
        return points
    }

    private var nextMilestone: Int {
        return streak < 5 ? 5 : 15
    }

    private var milestonePoints: Int {
        return nextMilestone == 5 ? 1000 : 5000
    }

    // Determine the appropriate range of days for display.
    // For streak < 5, show 0...5; for streak ≥ 5, start at the largest multiple of 5 ≤ streak.
    private var dotRange: [Int] {
        if streak < 5 {
            return Array(0...5)
        } else {
            let start = (streak / 5) * 5
            return Array(start...start+5)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header: Streak title and info toggle button.
            HStack {
                Text("\(streak) Day Streak")
                    .font(.headline)
                    .bold()
                Spacer()
                Button(action: {
                    withAnimation {
                        showInfo.toggle()
                    }
                }) {
                    Image(systemName: showInfo ? "chevron.up" : "chevron.down")
                        .foregroundColor(.black)
                }
            }

            GeometryReader { geometry in
                // Layout constants
                let dotSize: CGFloat = 14
                // Base label width from the dot size (might be too narrow on its own)
                let baseLabelWidth: CGFloat = dotSize * 1.8
                // Increase the desired slot width to allow longer numbers to fit comfortably
                let desiredSlotWidth: CGFloat = 70
                // Use the maximum of the two.
                let slotWidth: CGFloat = max(baseLabelWidth, desiredSlotWidth)
                
                let totalDots = CGFloat(dotRange.count)
                // Compute spacing based on the total width allocated for the dots.
                // Here we use the entire available width of the GeometryReader.
                let spacing = (geometry.size.width - (totalDots * slotWidth)) / (totalDots - 1)
                
                // Compute the total width of the dots row so that the green bar exactly matches.
                let dotsTotalWidth = totalDots * slotWidth + (totalDots - 1) * spacing
                
                VStack(spacing: 4) {
                    // First row: green bar and dots.
                    ZStack {
                        // Set the rounded rectangle to have the exact width of the dots row.
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.green.opacity(0.15))
                            .frame(width: dotsTotalWidth, height: 28)
                        HStack(spacing: spacing) {
                            ForEach(dotRange, id: \.self) { day in
                                // Fill dot green if the dot's value is less than or equal to the current streak.
                                Circle()
                                    .fill(day <= streak ? Color.green : Color.gray)
                                    .frame(width: dotSize, height: dotSize)
                                    .frame(width: slotWidth, alignment: .center)
                                    .overlay(
                                        Group {
                                            if day <= streak {
                                                Circle()
                                                    .fill(Color(hex: "#2B4452"))
                                                    .frame(width: dotSize / 2, height: dotSize / 2)
                                            }
                                        }
                                    )
                }
                        }
                    }
                    
                    // Second row: day number or bubble for the current day.
                    HStack(spacing: spacing) {
                        ForEach(dotRange, id: \.self) { day in
                            if day == streak {
                                // Current day's bubble.
                                HStack(spacing: 4) {
                                    Image("points logo") // Your asset image.
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 14, height: 14)
                                    Text("\(dailyPoints(for: day))")
                                        .font(.subheadline)
                                        .foregroundColor(.white)
                                        .minimumScaleFactor(0.8)
                                }
                                .font(.subheadline)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(hex: "#2B4452"))
                                .cornerRadius(12)
                                // Set the bubble to use the same fixed slot width.
                                .frame(width: slotWidth, alignment: .center)
                            } else {
                                Text("\(day)")
                                    .font(.system(size: 16, weight: .regular))
                                    .frame(width: slotWidth, alignment: .center)
                            }
                        }
                    }
                    // Also constrain the second row to the same total width.
                    .frame(width: dotsTotalWidth, alignment: .center)
                    .padding(.top, 6)
                    //.padding(.bottom, 6)
                }
                // Center the dots block inside the available width.
                .frame(width: geometry.size.width, alignment: .center)
            }
            .frame(height: 56)

            // Expandable info bubble.
            if showInfo {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Earn 100 points every day you continue your streak, and earn even more points for reaching milestones!")
                    Text(" ")
                    Text("Reach day \(nextMilestone) to earn a bonus \(milestonePoints) points.")
                }
                .font(.subheadline)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.gray.opacity(0.3), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
    }
}


func updateUserStreak(completion: @escaping (Int, Int) -> Void) {
    guard let user = Auth.auth().currentUser else {
        completion(0, 0)
        return
    }
    let db = Firestore.firestore()
    let userRef = db.collection("users").document(user.uid)
    
    userRef.getDocument { snapshot, error in
        if let error = error {
            print("Error fetching user data: \(error.localizedDescription)")
            completion(0, 0)
            return
        }
        
        guard let data = snapshot?.data(),
              let lastLogin = data["lastLogin"] as? Timestamp,
              let streak = data["streak"] as? Int,
              var points = data["points"] as? Int else {
            print("No last login found, initializing streak and points.")
            userRef.setData([
                "streak": 1,
                "lastLogin": Timestamp(date: Date()),
                "points": 100
            ], merge: true)
            // First-time user: new streak = 1, earned 100 points.
            completion(1, 100) // <<< ADDED OR MODIFIED >>>
            return
        }
        
        let lastLoginDate = lastLogin.dateValue()
        let currentDate = Date()
        let calendar = Calendar.current
        
        let lastLoginDay = calendar.startOfDay(for: lastLoginDate)
        let currentDay = calendar.startOfDay(for: currentDate)
        let daysDifference = calendar.dateComponents([.day], from: lastLoginDay, to: currentDay).day ?? 0
        
        if daysDifference == 1 {
            // The user logged in the next day; increase streak
            var newStreak = streak + 1
            var dailyPoints = 100

            // Check for milestone bonuses
            if newStreak == 5 {
                dailyPoints += 1000
            } else if newStreak == 15 {
                dailyPoints += 5000
            }

            points += dailyPoints
            userRef.updateData([
                "streak": newStreak,
                "lastLogin": Timestamp(date: currentDate),
                "points": points
            ]) { error in
                if let error = error {
                    print("Error updating streak: \(error.localizedDescription)")
                }
            }
            completion(newStreak, dailyPoints) // <<< ADDED OR MODIFIED >>>
        } else if daysDifference > 1 {
            // Missed a day, reset streak
            userRef.updateData([
                "streak": 0,
                "lastLogin": Timestamp(date: currentDate)
            ]) { error in
                if let error = error {
                    print("Error resetting streak: \(error.localizedDescription)")
                }
            }
            completion(0, 0) // no new points
        } else {
            // Already logged in today or no day difference, do nothing
            completion(streak, 0) // no new points
        }
    }
}

struct PointsEarnedPopupView: View {
    let streak: Int
    let pointsEarned: Int
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                Text("+ \(pointsEarned)")
                    // Make the points text a little bigger.
                    .font(.title2)
                    .bold()
                    .foregroundColor(.black)
                Image("points logo") // Your asset image
                    .resizable()
                    .scaledToFit()
                    .frame(width: 25, height: 25)
            }
            .padding([.top, .leading, .trailing])
            
            Text("Congratulations on your \(streak) day streak! 🔥")
                .font(.headline)
                .bold()
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Text("Keep it up to earn even more points and reach milestones!")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: {
                onClose()
            }) {
                Text("Close")
                    // Make the close button text a bit smaller.
                    .font(.subheadline)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 20)
                    .bold()
                    //.frame(maxWidth: .infinity)
                    .background(Color.green.opacity(0.9))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    //.padding(.horizontal)
            }
        }
        .padding()
        // Wrap the entire content in a white RoundedRectangle for more rounded edges.
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
        )
    }
}

struct ConfettiView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        DispatchQueue.main.async {
            let emitter = CAEmitterLayer()
            emitter.emitterPosition = CGPoint(x: view.bounds.midX, y: -10)
            emitter.emitterShape = .line
            emitter.emitterSize = CGSize(width: view.bounds.size.width, height: 1)
            emitter.emitterCells = generateEmitterCells(in: view)
            view.layer.addSublayer(emitter)
            
            // Stop the confetti emission after a couple of seconds.
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                emitter.birthRate = 0
            }
        }
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Nothing to update.
    }
    
    // Function to generate a white circle image
    private func generateConfettiImage(diameter: CGFloat) -> UIImage? {
        let size = CGSize(width: diameter, height: diameter)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            // Fill a circle with white color.
            ctx.cgContext.setFillColor(UIColor.white.cgColor)
            ctx.cgContext.fillEllipse(in: CGRect(origin: .zero, size: size))
        }
    }
    
    private func generateEmitterCells(in view: UIView) -> [CAEmitterCell] {
        var cells: [CAEmitterCell] = []
        // Define an array of vibrant colors.
        let colors: [UIColor] = [
            .red, .blue, .green, .yellow, .purple, .orange
        ]
        
        // Generate a white confetti image with a chosen diameter.
        let confettiDiameter: CGFloat = 15  // adjust as needed
        guard let confettiImage = generateConfettiImage(diameter: confettiDiameter)?.cgImage else {
            return cells
        }
        
        for color in colors {
            let cell = CAEmitterCell()
            cell.birthRate = 3
            cell.lifetime = 7.0
            cell.lifetimeRange = 1.5
            cell.velocity = 150
            cell.velocityRange = 50
            cell.emissionLongitude = .pi  // particles go downward
            cell.emissionRange = .pi / 4   // vary the angle a bit
            cell.spin = 3.5
            cell.spinRange = 1.0
            cell.scale = 0.1
            cell.scaleRange = 0.2
            // Use our generated white confetti image.
            cell.contents = confettiImage
            // Tint the white image with the current color.
            cell.color = color.cgColor
            
            cells.append(cell)
        }
        return cells
    }
}
