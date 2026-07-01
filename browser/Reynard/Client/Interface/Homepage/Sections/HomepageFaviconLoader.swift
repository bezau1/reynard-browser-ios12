//
//  HomepageFaviconLoader.swift
//  Reynard
//
//  Created by Minh Ton on 24/6/26.
//

import UIKit

final class HomepageFaviconLoader {
    private static let faviconStore = FaviconStore.shared
    private static let fallbackIconName = "reynard.globe"
    
    private let updateIcon: (UIImage?, UIColor?) -> Void
    private var representedURL: URL?
    private var loadToken: UUID?

    init(_ updateIcon: @escaping (UIImage?, UIColor?) -> Void) {
        self.updateIcon = updateIcon
    }

    deinit {
        loadToken = nil
    }

    func loadIcon(for url: URL) {
        representedURL = url
        loadToken = nil

        if let bundledImage = UIImage(named: Self.bundledIconName(for: url)) {
            updateIcon(bundledImage, nil)
            return
        }
        
        if let cachedImage = Self.faviconStore.cachedFavicon(for: url) {
            updateIcon(cachedImage, nil)
            return
        }
        
        applyFallbackIcon()
        let loadingURL = url
        let token = UUID()
        loadToken = token
        Self.faviconStore.favicon(for: loadingURL) { [weak self] loadedImage in
            guard let self else {
                return
            }

            guard self.loadToken == token else {
                return
            }

            guard self.representedURL == loadingURL else {
                return
            }

            self.updateIcon(
                loadedImage ?? UIImage(named: Self.fallbackIconName),
                loadedImage == nil ? .appSecondaryLabel : nil
            )
        }
    }

    func reset() {
        representedURL = nil
        loadToken = nil
        applyFallbackIcon()
    }
    
    private func applyFallbackIcon() {
        updateIcon(UIImage(named: Self.fallbackIconName), .appSecondaryLabel)
    }
    
    private static func bundledIconName(for url: URL) -> String {
        var iconName = url.absoluteString
        
        if let schemeRange = iconName.range(of: "://") {
            iconName.removeSubrange(iconName.startIndex..<schemeRange.upperBound)
        }
        
        if iconName.hasPrefix("www.") {
            iconName.removeFirst(4)
        }
        
        while iconName.hasSuffix("/") {
            iconName.removeLast()
        }
        
        return iconName
    }
}
