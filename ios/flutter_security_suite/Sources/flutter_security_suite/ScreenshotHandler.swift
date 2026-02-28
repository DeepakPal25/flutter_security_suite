import UIKit

/// Manages screenshot protection using a secure text field overlay technique.
///
/// A `UITextField` with `isSecureTextEntry = true` placed in the window
/// hierarchy causes UIKit to exclude the window's content from screenshots
/// and screen recordings. No layer manipulation is needed beyond adding the
/// field as a subview.
class ScreenshotHandler {

    private var secureField: UITextField?

    /// Enables screenshot protection and calls [completion] once the protection
    /// is active. The completion is invoked on the main thread.
    func enable(completion: (() -> Void)? = nil) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.secureField == nil {
                guard let window = self.getKeyWindow() else {
                    completion?()
                    return
                }
                let field = UITextField()
                field.isSecureTextEntry = true
                field.isUserInteractionEnabled = false
                window.addSubview(field)
                field.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    field.centerXAnchor.constraint(equalTo: window.centerXAnchor),
                    field.centerYAnchor.constraint(equalTo: window.centerYAnchor)
                ])
                self.secureField = field
            }
            self.secureField?.isSecureTextEntry = true
            completion?()
        }
    }

    /// Disables screenshot protection and calls [completion] once done.
    func disable(completion: (() -> Void)? = nil) {
        DispatchQueue.main.async { [weak self] in
            self?.secureField?.isSecureTextEntry = false
            self?.secureField?.removeFromSuperview()
            self?.secureField = nil
            completion?()
        }
    }

    private func getKeyWindow() -> UIWindow? {
        if #available(iOS 15.0, *) {
            return UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }
        } else {
            return UIApplication.shared.windows.first { $0.isKeyWindow }
        }
    }
}
