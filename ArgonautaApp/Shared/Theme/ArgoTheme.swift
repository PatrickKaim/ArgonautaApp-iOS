import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

let argoBlueNormalColor = Color(red: 0, green: 0.102, blue: 0.439)
let argoBlueLightColor = Color(red: 0.718, green: 0.796, blue: 0.918)
let argoBlueDarkColor = Color(red: 0.039, green: 0.137, blue: 0.259)

enum ArgoTheme {
    static var blueNormal: Color { argoBlueNormalColor }
    static var blueLight: Color { argoBlueLightColor }
    static var blueDark: Color { argoBlueDarkColor }

    static func font(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        switch weight {
        case .bold, .heavy, .black, .semibold:
            return .custom("Montserrat-Bold", size: size)
        default:
            return .custom("Montserrat-Regular", size: size)
        }
    }

    // MARK: - Light / Dark (system)

    /// Achtergrond voor lijsten/schermen (zoals `UITableView` grouped).
    static var groupedBackground: Color {
        #if canImport(UIKit)
        Color(UIColor.systemGroupedBackground)
        #else
        Color(white: 0.95)
        #endif
    }

    /// Velden en primaire knoppen op merk-blauw (login); volgt light/dark.
    static var adaptiveSurface: Color {
        #if canImport(UIKit)
        Color(UIColor.systemBackground)
        #else
        Color.white
        #endif
    }

    /// Subtiele rand rond velden/knoppen.
    static var adaptiveBorder: Color {
        #if canImport(UIKit)
        Color(UIColor.separator)
        #else
        Color.gray.opacity(0.35)
        #endif
    }

    /// Zachte kaart-achtige achtergrond (mededelingen op home).
    static var announcementTint: Color {
        #if canImport(UIKit)
        let brand = UIColor(red: 0, green: 0.102, blue: 0.439, alpha: 1)
        return Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? brand.withAlphaComponent(0.22)
                : brand.withAlphaComponent(0.10)
        })
        #else
        argoBlueNormalColor.opacity(0.12)
        #endif
    }

    // MARK: - Dark mode: schaduwen, accenten, oppervlakken

    /// Schaduw onder kaarten — in dark mode een zachte lichte gloed i.p.v. zwart.
    static var cardShadow: Color {
        #if canImport(UIKit)
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor.white.withAlphaComponent(0.08)
                : UIColor.black.withAlphaComponent(0.1)
        })
        #else
        Color.black.opacity(0.1)
        #endif
    }

    /// Secundaire grouped vlakken (lege secties, placeholders).
    static var secondaryGroupedSurface: Color {
        #if canImport(UIKit)
        Color(UIColor.secondarySystemGroupedBackground)
        #else
        Color(white: 0.95)
        #endif
    }

    /// Vulling voor thumbnails / afbeeldingsplaceholders.
    static var tertiaryFill: Color {
        #if canImport(UIKit)
        Color(UIColor.tertiarySystemFill)
        #else
        Color.gray.opacity(0.25)
        #endif
    }

    /// Merk-blauw voor taps en links; iets lichter in dark mode voor contrast op donkere achtergronden.
    static var interactiveAccent: Color {
        #if canImport(UIKit)
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.45, green: 0.62, blue: 0.96, alpha: 1)
                : UIColor(red: 0, green: 0.102, blue: 0.439, alpha: 1)
        })
        #else
        blueNormal
        #endif
    }

    /// Iconen in lege states op grouped background.
    static var iconAccent: Color {
        #if canImport(UIKit)
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.52, green: 0.68, blue: 0.96, alpha: 1)
                : UIColor(red: 0.718, green: 0.796, blue: 0.918, alpha: 1)
        })
        #else
        blueLight
        #endif
    }

    /// Titels in editors (was `blueDark` — op dark background nauwelijks leesbaar).
    static var editorTitle: Color {
        #if canImport(UIKit)
        Color(UIColor.label)
        #else
        Color.primary
        #endif
    }

    /// Halve overlay bij opslaan/publiceren.
    static var scrimLight: Color {
        #if canImport(UIKit)
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor.black.withAlphaComponent(0.45)
                : UIColor.black.withAlphaComponent(0.22)
        })
        #else
        Color.black.opacity(0.25)
        #endif
    }
}

extension Font {
    static let argoTitle = ArgoTheme.font(size: 28, weight: .bold)
    static let argoHeadline = ArgoTheme.font(size: 20, weight: .bold)
    static let argoSubheadline = ArgoTheme.font(size: 16)
    static let argoBody = ArgoTheme.font(size: 14)
    static let argoCaption = ArgoTheme.font(size: 12)
    static let argoLargeNumber = ArgoTheme.font(size: 48, weight: .bold)
}
