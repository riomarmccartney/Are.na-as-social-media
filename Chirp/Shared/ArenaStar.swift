import SwiftUI

/// One star from the Are.na mark: six tapered rays every 60°, pointing up and
/// down. The app icon is drawn from the same geometry in
/// scripts/make-app-icon.swift.
struct ArenaStar: Shape {
    func path(in rect: CGRect) -> Path {
        let radius = min(rect.height / 2, rect.width / (2 * cos(.pi / 6)))
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let valley = radius * 0.36
        let tipWidth = radius * 0.03

        var path = Path()
        for ray in 0..<6 {
            let angle = (-90 + Double(ray) * 60) * .pi / 180
            let tip = CGPoint(x: center.x + (radius - tipWidth) * cos(angle), y: center.y + (radius - tipWidth) * sin(angle))
            let before = angle - .pi / 6
            let valleyBefore = CGPoint(x: center.x + valley * cos(before), y: center.y + valley * sin(before))
            if ray == 0 {
                path.move(to: valleyBefore)
            } else {
                path.addLine(to: valleyBefore)
            }
            path.addLine(to: CGPoint(x: tip.x + tipWidth * sin(angle), y: tip.y - tipWidth * cos(angle)))
            path.addArc(
                center: tip, radius: tipWidth,
                startAngle: .radians(angle - .pi / 2), endAngle: .radians(angle + .pi / 2), clockwise: false
            )
        }
        path.closeSubpath()
        return path
    }
}

#Preview {
    ArenaStar()
        .frame(width: 120, height: 120)
}
