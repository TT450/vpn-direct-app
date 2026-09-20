import SwiftUI
import UIKit

#if os(iOS)

/// Lucide-named icons. Prefer asset catalog (`lucide-*` in app / library Assets),
/// then a matching SF Symbol so the UI never falls back to empty circles.
struct DirectLucideIcon: View {
    enum Name: String {
        case refreshCw = "refresh-cw"
        case refreshCcw = "refresh-ccw"
        case calendar
        case smartphone
        case listFilter = "list-filter"
        case clock
        case hardDrive = "hard-drive"
        case globe
        case power
        case ellipsis
        case messagesSquare = "messages-square"
        case slidersHorizontal = "sliders-horizontal"
        case x
        case arrowUpRight = "arrow-up-right"

        var systemFallback: String {
            switch self {
            case .refreshCw: return "arrow.clockwise"
            case .refreshCcw: return "arrow.triangle.2.circlepath"
            case .calendar: return "calendar"
            case .smartphone: return "iphone"
            case .listFilter: return "line.3.horizontal.decrease"
            case .clock: return "clock"
            case .hardDrive: return "externaldrive"
            case .globe: return "globe"
            case .power: return "power"
            case .ellipsis: return "ellipsis"
            case .messagesSquare: return "bubble.left.and.bubble.right"
            case .slidersHorizontal: return "slider.horizontal.3"
            case .x: return "xmark"
            case .arrowUpRight: return "arrow.up.right"
            }
        }
    }

    let name: Name
    var size: CGFloat = 20
    var color: Color = DS.ink

    var body: some View {
        Group {
            if let uiImage = Self.loadImage(named: "lucide-\(name.rawValue)"),
               uiImage.size.width > 1,
               uiImage.size.height > 1
            {
                Image(uiImage: uiImage)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: name.systemFallback)
                    .resizable()
                    .scaledToFit()
            }
        }
        .foregroundStyle(color)
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private static let imageCache = NSCache<NSString, UIImage>()

    private static func loadImage(named name: String) -> UIImage? {
        let key = name as NSString
        if let cached = imageCache.object(forKey: key) { return cached }

        var candidates: [Bundle] = [.main]
        let libraryBundle = Bundle(for: DirectLucideIconBundleToken.self)
        if libraryBundle.bundleURL != Bundle.main.bundleURL {
            candidates.append(libraryBundle)
        }
        if let frameworks = Bundle.main.privateFrameworksURL {
            let appLib = frameworks.appendingPathComponent("ApplicationLibrary.framework")
            if let bundle = Bundle(url: appLib) { candidates.append(bundle) }
        }
        // Built products path used during force_load / local Debug installs.
        let built = URL(fileURLWithPath: Bundle.main.bundlePath)
            .deletingLastPathComponent()
            .appendingPathComponent("ApplicationLibrary.framework")
        if let bundle = Bundle(url: built) { candidates.append(bundle) }

        for bundle in candidates {
            if let image = UIImage(named: name, in: bundle, compatibleWith: nil),
               image.size.width > 1
            {
                imageCache.setObject(image, forKey: key)
                return image
            }
        }
        if let image = UIImage(named: name), image.size.width > 1 {
            imageCache.setObject(image, forKey: key)
            return image
        }
        return nil
    }
}

private final class DirectLucideIconBundleToken {}

#endif
