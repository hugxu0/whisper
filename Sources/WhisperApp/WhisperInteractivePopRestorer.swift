#if os(iOS)
import SwiftUI
import UIKit

struct WhisperInteractivePopRestorer: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> RestorerViewController {
        RestorerViewController()
    }

    func updateUIViewController(_ uiViewController: RestorerViewController, context: Context) {
        uiViewController.restoreGestureWhenReady()
    }

    final class RestorerViewController: UIViewController {
        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            restoreGestureWhenReady()
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            restoreGestureWhenReady()
        }

        func restoreGestureWhenReady() {
            guard let navigationController else { return }
            navigationController.interactivePopGestureRecognizer?.delegate = nil
            navigationController.interactivePopGestureRecognizer?.isEnabled =
                navigationController.viewControllers.count > 1
        }
    }
}
#endif
