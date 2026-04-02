import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

extension View {
    /// Locks a SwiftUI ScrollView to a single axis per gesture (horizontal OR vertical, not diagonal).
    @ViewBuilder
    func directionalScrollLock() -> some View {
        #if canImport(UIKit)
        background(DirectionalScrollLockModifier())
        #else
        self
        #endif
    }

    @ViewBuilder
    func platformInlineNavigationTitle() -> some View {
        #if os(iOS)
        navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }

    @ViewBuilder
    func platformNonAutocorrectingTextInput() -> some View {
        #if os(iOS)
        textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        #else
        self
        #endif
    }

    @ViewBuilder
    func platformURLKeyboard() -> some View {
        #if os(iOS)
        keyboardType(.URL)
        #else
        self
        #endif
    }
}

#if canImport(UIKit)
private struct DirectionalScrollLockModifier: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            var parent = uiView.superview
            while let current = parent {
                if let scrollView = current as? UIScrollView {
                    scrollView.isDirectionalLockEnabled = true
                    return
                }
                parent = current.superview
            }
        }
    }
}
#endif

enum PlatformToolbarPlacement {
    static var leading: ToolbarItemPlacement {
        #if os(iOS)
        .topBarLeading
        #else
        .navigation
        #endif
    }

    static var trailing: ToolbarItemPlacement {
        #if os(iOS)
        .topBarTrailing
        #else
        .automatic
        #endif
    }
}
