//
//  ShareSheet.swift
//  Hunch
//
//  Presents the system share sheet reliably on BOTH iPhone and iPad.
//
//  On iPad a share sheet is a popover and must be anchored, or iPadOS renders
//  it truncated / partially off-screen (this caused an App Store rejection).
//  We anchor it to the center of the top view controller with no arrow, so it
//  always appears fully on-screen regardless of which button triggered it.
//

import UIKit

enum ShareSheet {
    static func present(_ items: [Any]) {
        guard let scene = activeScene,
              let root = scene.keyWindow?.rootViewController else { return }

        var top = root
        while let presented = top.presentedViewController { top = presented }

        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)

        // iPad: anchor the popover to the center of the screen, no arrow.
        if let pop = vc.popoverPresentationController {
            pop.sourceView = top.view
            pop.sourceRect = CGRect(x: top.view.bounds.midX,
                                    y: top.view.bounds.midY,
                                    width: 0, height: 0)
            pop.permittedArrowDirections = []
        }

        top.present(vc, animated: true)
    }

    private static var activeScene: UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
    }
}
