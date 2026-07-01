//
//  Haptics.swift
//  Reynard
//
//  Created by Minh Ton on 18/6/26.
//

import UIKit

enum Haptics {
    // `.rigid` is iOS 13+; `.heavy` is the closest style available on iOS 12.
    private static let impactGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private static let notificationGenerator = UINotificationFeedbackGenerator()
    
    static func prepareRigid() {
        impactGenerator.prepare()
    }
    
    static func rigid() {
        impactGenerator.impactOccurred()
    }
    
    static func success() {
        notificationGenerator.notificationOccurred(.success)
    }
}
