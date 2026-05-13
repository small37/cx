import Foundation
import CoreGraphics

enum LayoutColor: String {
    case white
    case yellow
    case green
    case red
    case gray
}

enum LayoutNode {
    case text(color: LayoutColor, value: String)
    case tag(String)
    case button(title: String, action: String, color: String?)
    case icon(path: String, size: CGFloat?)
    case flex
    case space(CGFloat)
}
