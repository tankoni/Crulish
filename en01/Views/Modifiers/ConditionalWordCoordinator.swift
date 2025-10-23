import SwiftUI

// 条件注入 WordInteractionCoordinator 的视图修饰器
struct ConditionalWordCoordinator: ViewModifier {
    let coordinator: WordInteractionCoordinator?
    
    func body(content: Content) -> some View {
        if let coordinator {
            content.environmentObject(coordinator)
        } else {
            content
        }
    }
}