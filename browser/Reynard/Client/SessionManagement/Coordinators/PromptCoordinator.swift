//
//  PromptCoordinator.swift
//  Reynard
//
//  Created by Minh Ton on 16/6/26.
//

import GeckoView

@MainActor
protocol PromptPresenting {
    func present(_ request: PromptRequest, for session: GeckoSession, completion: @escaping (PromptResponse?) -> Void)
    func update(_ request: PromptRequest)
    func dismiss(promptID: String)
}

@MainActor
final class PromptCoordinator: PromptDelegate {
    private let presenter: PromptPresenting

    init(presenter: PromptPresenting) {
        self.presenter = presenter
    }

    func onPrompt(session: GeckoSession, request: PromptRequest, completion: @escaping (PromptResponse?) -> Void) {
        presenter.present(request, for: session, completion: completion)
    }
    
    func onPromptUpdate(session: GeckoSession, request: PromptRequest) {
        presenter.update(request)
    }
    
    func onPromptDismiss(session: GeckoSession, promptId: String) {
        presenter.dismiss(promptID: promptId)
    }
}
