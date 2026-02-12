import SwiftUI

extension View {
    @ViewBuilder
    func optionalNavigationTitle(_ title: String?) -> some View {
        if let title {
            self.navigationTitle(title)
        } else {
            self
        }
    }
}
