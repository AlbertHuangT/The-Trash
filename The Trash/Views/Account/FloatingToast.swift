import SwiftUI

struct FloatingToast: View {
    @Binding var message: String?

    var body: some View {
        if let text = message {
            Text(text)
                .font(.caption)
                .trashOnAccentForeground()
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.8))
                )
                .padding(.top, 60)
                .padding(.horizontal, 16)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation {
                            message = nil
                        }
                    }
                }
        }
    }
}
