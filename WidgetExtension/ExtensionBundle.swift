import SwiftUI
import WidgetKit

@main
struct ExtensionBundle: WidgetBundle {
    var body: some Widget {
        // Control Center entry first — gallery indexing is more reliable this way.
        ServiceToggleControl()
        StatusHomeWidget()
    }
}
