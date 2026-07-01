//
//  SelectionActionDelegate.swift
//  Reynard
//
//  Created by Minh Ton on 26/5/26.
//

import Foundation

// MARK: - Selection Action Delegate

public protocol SelectionActionDelegate: AnyObject {
    
    func onShowSelectionAction(session: GeckoSession, request: SelectionActionRequest)
    
    func onHideSelectionAction(session: GeckoSession)
}

public extension SelectionActionDelegate {
    
    func onShowSelectionAction(session: GeckoSession, request: SelectionActionRequest) {}
    
    
    func onHideSelectionAction(session: GeckoSession) {}
}

// MARK: - Selection Action Events

private enum SelectionActionEvent: String, CaseIterable {
    case show = "GeckoView:ShowSelectionAction"
    case hide = "GeckoView:HideSelectionAction"
}

// MARK: - Selection Action Handler

func newSelectionActionHandler(_ session: GeckoSession) -> GeckoSessionHandler {
    GeckoSessionHandler(
        moduleName: "GeckoViewSelectionAction",
        events: SelectionActionEvent.allCases.map(\.rawValue),
        session: session
    ) {  session, delegate, type, message, completion in
        guard let event = SelectionActionEvent(rawValue: type) else {
            completion(.failure(GeckoHandlerError("unknown message \(type)")))
            return
        }

        let delegate = delegate as? SelectionActionDelegate
        switch event {
        case .show:
            guard let request = parseSelectionActionRequest(message) else {
                delegate?.onHideSelectionAction(session: session)
                completion(.success(nil))
                return
            }
            delegate?.onShowSelectionAction(session: session, request: request)

        case .hide:
            delegate?.onHideSelectionAction(session: session)
        }

        completion(.success(nil))
    }
}
