//
//  AvailabilityCompat.swift
//  Orange Cloud
//
//  集中存放跨 iOS 版本的 SwiftUI 兼容封装：基线 iOS 17，对 iOS 18+ 专属 API
//  统一在此降级，避免在各视图里散落 #available 守卫。
//

import SwiftUI
import UIKit
import TipKit

extension ProcessInfo {
    /// 当前系统是否落在 iOS 17.0.x（17.0 / 17.0.1 / 17.0.2 / 17.0.3）。
    /// 这一窄段的 TipKit 把 popover 锚定到导航栏 bar button 时，会在
    /// `-[UINavigationBar layoutSubviews]` 阶段抛未捕获异常导致崩溃，Apple 自 17.1 起修复。
    /// 仅用于对这段版本做最小化 UI 降级，勿扩大到 17.1+。
    nonisolated static var isBuggyTipKitNavBar: Bool {
        let v = processInfo.operatingSystemVersion
        return v.majorVersion == 17 && v.minorVersion == 0
    }
}

extension View {
    /// `popoverTip` 的安全封装：iOS 17.0.x 上跳过（见 ``ProcessInfo/isBuggyTipKitNavBar``），
    /// 避免导航栏锚定的 TipKit popover 崩溃；17.1+ 与更高版本行为不变，正常展示气泡提示。
    /// 适用于挂在工具栏 bar button 上的提示；非导航栏场景同样安全（17.0.x 仅少展示一次提示）。
    @ViewBuilder
    func safePopoverTip<T: Tip>(_ tip: T) -> some View {
        if ProcessInfo.isBuggyTipKitNavBar {
            self
        } else {
            popoverTip(tip)
        }
    }
}

extension View {
    /// 详情页：iOS 18+ 应用 Zoom 导航转场；iOS 17 原样返回（标准 push）。
    @ViewBuilder
    func zoomNavigationTransition(sourceID: some Hashable, in namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            navigationTransition(.zoom(sourceID: sourceID, in: namespace))
        } else {
            self
        }
    }

    /// 源视图（列表行）：iOS 18+ 标记 Zoom 转场源；iOS 17 无操作。
    @ViewBuilder
    func zoomTransitionSource(id: some Hashable, in namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
    }

    /// 刷新中持续动画：iOS 18+ 用 .rotate 旋转；iOS 17 回退 .pulse
    /// （.rotate 的“持续效果”conformance 自 iOS 18 起才有）。
    @ViewBuilder
    func loadingSpinSymbolEffect(isActive: Bool) -> some View {
        if #available(iOS 18.0, *) {
            symbolEffect(.rotate, isActive: isActive)
        } else {
            symbolEffect(.pulse, isActive: isActive)
        }
    }

    /// 出现时弹一下（一次性 bounce）：iOS 18+ 用 .nonRepeating 持续效果；
    /// iOS 17 静态显示（.bounce 的“持续效果”conformance 自 iOS 18 起才有）。
    @ViewBuilder
    func oneShotBounceSymbolEffect() -> some View {
        if #available(iOS 18.0, *) {
            symbolEffect(.bounce, options: .nonRepeating)
        } else {
            self
        }
    }
}

extension Color {
    /// Color.mix(with:by:) 的兼容封装：iOS 18+ 用系统实现；iOS 17 回退 UIColor 的 RGB 线性插值。
    nonisolated func mixed(with other: Color, by amount: Double) -> Color {
        if #available(iOS 18.0, *) {
            return mix(with: other, by: amount)
        }
        let t = max(0, min(1, amount))
        var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        UIColor(self).getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
        UIColor(other).getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        return Color(
            .sRGB,
            red:   Double(ar + (br - ar) * t),
            green: Double(ag + (bg - ag) * t),
            blue:  Double(ab + (bb - ab) * t),
            opacity: Double(aa + (ba - aa) * t)
        )
    }
}
