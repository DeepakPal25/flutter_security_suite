import UIKit

/// Manages screenshot protection using a secure text field overlay technique.
class ScreenshotHandler {

    private var secureField: UITextField?

    func enable() {
        DispatchQueue.main.async { [weak self] in
            guard let window = self?.getKeyWindow() else { return }
            if self?.secureField == nil {
                let field = UITextField()
                field.isSecureTextEntry = true
                field.isUserInteractionEnabled = false
                window.addSubview(field)
                field.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    field.centerXAnchor.constraint(equalTo: window.centerXAnchor),
                    field.centerYAnchor.constraint(equalTo: window.centerYAnchor)
                ])
                field.layer.sublayers?.first?.addSublayer(window.layer)
                self?.secureField = field
            }
            self?.secureField?.isSecureTextEntry = true
        }
    }

    func disable() {
        DispatchQueue.main.async { [weak self] in
            self?.secureField?.isSecureTextEntry = false
            self?.secureField?.removeFromSuperview()
            self?.secureField = nil
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
