import UIKit

#if os(iOS)

enum DirectSharePresenter {
    static func share(_ items: [Any]) {
        guard !items.isEmpty else { return }
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.keyWindow?.rootViewController
        else { return }

        var topViewController = rootViewController
        while let presented = topViewController.presentedViewController {
            topViewController = presented
        }

        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if let popover = controller.popoverPresentationController {
            popover.sourceView = topViewController.view
            popover.sourceRect = CGRect(
                x: topViewController.view.bounds.midX,
                y: topViewController.view.bounds.midY,
                width: 0,
                height: 0
            )
        }
        topViewController.present(controller, animated: true)
    }
}

#endif
