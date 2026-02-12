import SwiftUI

struct PaperTextureView: View {
    var body: some View {
        Rectangle()
            .fill(Color(red: 0.95, green: 0.92, blue: 0.85))
            .overlay(
                PaperNoiseLayer()
                    .blendMode(.multiply)
                    .opacity(0.18)
            )
            .overlay(
                PaperFiberLayer()
                    .blendMode(.overlay)
                    .opacity(0.25)
            )
    }
}

private struct PaperNoiseLayer: View {
    var body: some View {
        Canvas { context, size in
            let density = Int(size.width * size.height / 3000)
            for _ in 0..<density {
                let x = Double.random(in: 0...size.width)
                let y = Double.random(in: 0...size.height)
                let diameter = Double.random(in: 0.4...1.5)
                let rect = CGRect(x: x, y: y, width: diameter, height: diameter)
                let opacity = Double.random(in: 0.05...0.18)
                let color = Color(red: 0.8 + Double.random(in: -0.08...0.08),
                                  green: 0.75 + Double.random(in: -0.08...0.08),
                                  blue: 0.68 + Double.random(in: -0.08...0.08),
                                  opacity: opacity)
                context.fill(Path(ellipseIn: rect), with: .color(color))
            }
        }
    }
}

private struct PaperFiberLayer: View {
    var body: some View {
        Canvas { context, size in
            let fiberCount = Int(size.width / 18)
            for _ in 0..<fiberCount {
                var path = Path()
                let startY = Double.random(in: 0...size.height)
                let length = Double.random(in: size.width * 0.4...size.width * 0.9)
                let amplitude = Double.random(in: -6...6)
                let segments = 6
                let step = length / Double(segments)
                let thickness = Double.random(in: 0.3...0.6)

                path.move(to: CGPoint(x: 0, y: startY))
                for i in 1...segments {
                    let x = Double(i) * step
                    let y = startY + sin(Double(i) * .pi / 3.0) * amplitude
                    path.addLine(to: CGPoint(x: x, y: y))
                }

                let strokeColor = Color(red: 0.72 + Double.random(in: -0.04...0.04),
                                        green: 0.65 + Double.random(in: -0.04...0.04),
                                        blue: 0.56 + Double.random(in: -0.04...0.04),
                                        opacity: 0.25)
                context.stroke(path, with: .color(strokeColor), lineWidth: thickness)
            }
        }
    }
}
