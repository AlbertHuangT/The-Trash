import SwiftUI

public struct PaperTextureView: View {
    public var baseColor: Color

    public init(baseColor: Color) {
        self.baseColor = baseColor
    }

    public var body: some View {
        baseColor
            .overlay(
                ZStack {
                    LinearGradient(
                        colors: [Color.white.opacity(0.28), Color.black.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .blendMode(.softLight)

                    PaperNoiseLayer(opacity: 0.06, densityScale: 0.7)
                        .blendMode(.multiply)
                }
            )
            .clipped()
    }
}

public struct PaperCardSurface: View {
    public var baseColor: Color
    public var roughness: CGFloat = 2.0

    public init(baseColor: Color, roughness: CGFloat = 2.0) {
        self.baseColor = baseColor
        self.roughness = roughness
    }

    public var body: some View {
        ZStack {
            TornPaperShape(roughness: roughness)
                .fill(Color.black.opacity(0.06))
                .offset(y: 1.5)

            TornPaperShape(roughness: roughness)
                .fill(baseColor)

            PaperTextureView(baseColor: baseColor)
                .clipShape(TornPaperShape(roughness: roughness))
                .opacity(0.3)
        }
    }
}

public struct TornPaperShape: Shape {
    public var tornEdges: Edge.Set
    public var roughness: CGFloat

    public init(tornEdges: Edge.Set = .all, roughness: CGFloat = 3.5) {
        self.tornEdges = tornEdges
        self.roughness = roughness
    }

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height

        let safeRect = rect.insetBy(dx: 1, dy: 1)

        path.move(to: CGPoint(x: safeRect.minX, y: safeRect.minY))

        var rng = LinearCongruentialGenerator(seed: Int(width + height))

        addTornLine(to: CGPoint(x: safeRect.maxX, y: safeRect.minY), in: &path, isTorn: tornEdges.contains(.top), roughness: roughness, rng: &rng)
        addTornLine(to: CGPoint(x: safeRect.maxX, y: safeRect.maxY), in: &path, isTorn: tornEdges.contains(.trailing), roughness: roughness, rng: &rng)
        addTornLine(to: CGPoint(x: safeRect.minX, y: safeRect.maxY), in: &path, isTorn: tornEdges.contains(.bottom), roughness: roughness, rng: &rng)
        addTornLine(to: CGPoint(x: safeRect.minX, y: safeRect.minY), in: &path, isTorn: tornEdges.contains(.leading), roughness: roughness, rng: &rng)

        path.closeSubpath()
        return path
    }

    private func addTornLine(to dest: CGPoint, in path: inout Path, isTorn: Bool, roughness: CGFloat, rng: inout LinearCongruentialGenerator) {
        let start = path.currentPoint ?? .zero
        let step: CGFloat = 8.0
        let dist = sqrt(pow(dest.x - start.x, 2) + pow(dest.y - start.y, 2))
        let segments = Int(dist / step)

        if !isTorn || segments < 2 {
            path.addLine(to: dest)
            return
        }

        for i in 1...segments {
            let t = CGFloat(i) / CGFloat(segments)
            let x = start.x + (dest.x - start.x) * t
            let y = start.y + (dest.y - start.y) * t
            let offset = CGFloat.random(in: -roughness...roughness, using: &rng)
            if start.x == dest.x { path.addLine(to: CGPoint(x: x + offset, y: y)) }
            else { path.addLine(to: CGPoint(x: x, y: y + offset)) }
        }
        path.addLine(to: dest)
    }
}

public struct RoughPaperShape: Shape {
    public var cornerRadius: CGFloat
    public init(cornerRadius: CGFloat) { self.cornerRadius = cornerRadius }
    public func path(in rect: CGRect) -> Path {
        TornPaperShape(roughness: 2.0).path(in: rect)
    }
}

private struct PaperNoiseLayer: View {
    var opacity: Double
    var densityScale: Double = 1.0

    var body: some View {
        Canvas { context, size in
            var rng = LinearCongruentialGenerator(seed: 42)
            let area = Double(size.width * size.height)
            let dotCount = Int((area / 170.0) * densityScale)
            for _ in 0..<dotCount {
                let x = Double.random(in: 0...size.width, using: &rng)
                let y = Double.random(in: 0...size.height, using: &rng)
                let w = Double.random(in: 0.45...1.3, using: &rng)
                context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: w, height: w)), with: .color(Color.black.opacity(opacity)))
            }
        }
    }
}

struct LinearCongruentialGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: Int) { state = UInt64(seed) }
    mutating func next() -> UInt64 {
        state = 2862933555777941757 &* state &+ 3037000493
        return state
    }
}
