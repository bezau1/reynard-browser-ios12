//
//  PromptPresenter.swift
//  Reynard
//
//  Created by Minh Ton on 16/6/26.
//

import GeckoView
import UIKit

@MainActor
final class PromptPresenter: PromptPresenting {
    private var selectPickers: [String: SelectPicker] = [:]
    private var colorPickers: [String: ColorPicker] = [:]
    private var dateTimePickers: [String: DateTimePicker] = [:]
    private var filePickers: [String: FilePicker] = [:]
    
    // MARK: - Lifecycle
    
    init() {}
    
    func present(_ request: PromptRequest, for session: GeckoSession, completion: @escaping (PromptResponse?) -> Void) {
        switch request {
        case .alert(let request):
            presentAlert(request: request) { completion(nil) }

        case .button(let request):
            presentButton(request: request, completion: completion)

        case .text(let request):
            presentText(request: request, completion: completion)

        case .folderUpload(let request):
            presentFolderUpload(request: request, completion: completion)

        case .color(let request):
            presentColorPicker(session: session, request: request, completion: completion)

        case .dateTime(let request):
            presentDateTimePicker(session: session, request: request, completion: completion)

        case .file(let request):
            presentFilePicker(session: session, request: request, completion: completion)

        case .choice(let request):
            presentSelectPicker(session: session, request: request, completion: completion)
        }
    }
    
    func update(_ request: PromptRequest) {
        guard case .choice(let request) = request,
              let picker = selectPickers[request.id] else {
            return
        }
        
        picker.updateChoices(request.choices, mode: request.mode)
    }
    
    func dismiss(promptID: String) {
        if dateTimePickers[promptID] != nil {
            // Gecko fires dismiss when native date UI steals focus; the picker owns completion.
            return
        }
        selectPickers.removeValue(forKey: promptID)?.cancelAndDismiss()
        colorPickers.removeValue(forKey: promptID)?.cancelAndDismiss()
        dateTimePickers.removeValue(forKey: promptID)?.cancelAndDismiss()
        filePickers.removeValue(forKey: promptID)?.cancelAndDismiss()
    }
    
    // MARK: - Basic Prompts
    
    private func presentAlert(request: AlertPromptRequest, completion: @escaping () -> Void) {
        guard let presenter = UIApplication.shared.topViewController() else {
            completion()
            return
        }

        let alert = UIAlertController(
            title: request.title.isEmpty ? nil : request.title,
            message: request.message.isEmpty ? nil : request.message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            completion()
        })
        presenter.present(alert, animated: true)
    }

    private func presentButton(request: ButtonPromptRequest, completion: @escaping (PromptResponse?) -> Void) {
        guard let presenter = UIApplication.shared.topViewController() else {
            completion(nil)
            return
        }

        let alert = UIAlertController(
            title: request.title.isEmpty ? nil : request.title,
            message: request.message.isEmpty ? nil : request.message,
            preferredStyle: .alert
        )

        for index in 0..<3 {
            let title = buttonTitle(at: index, request: request)
            guard !title.isEmpty else { continue }

            let isCancel = index == 2 &&
            request.buttonTitles.indices.contains(index) &&
            request.buttonTitles[index] == "cancel"
            alert.addAction(UIAlertAction(
                title: title,
                style: isCancel ? .cancel : .default
            ) { _ in
                completion(.button(index))
            })
        }

        if alert.actions.isEmpty {
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                completion(.button(0))
            })
        }

        presenter.present(alert, animated: true)
    }

    private func presentText(request: TextPromptRequest, completion: @escaping (PromptResponse?) -> Void) {
        guard let presenter = UIApplication.shared.topViewController() else {
            completion(nil)
            return
        }

        let alert = UIAlertController(
            title: request.title.isEmpty ? nil : request.title,
            message: request.message.isEmpty ? nil : request.message,
            preferredStyle: .alert
        )
        alert.addTextField { textField in
            textField.text = request.value
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            completion(nil)
        })
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            completion(.text(alert.textFields?.first?.text ?? ""))
        })
        presenter.present(alert, animated: true)
    }

    private func presentFolderUpload(request: FolderUploadPromptRequest, completion: @escaping (PromptResponse?) -> Void) {
        guard let presenter = UIApplication.shared.topViewController() else {
            completion(nil)
            return
        }

        let message = request.directoryName.isEmpty
        ? "Are you sure you want to upload all files? Only do this if you trust the site."
        : "Are you sure you want to upload all files from \"\(request.directoryName)\"? Only do this if you trust the site."

        let alert = UIAlertController(
            title: "Confirm Upload",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            completion(.folderUpload(allowed: false))
        })
        alert.addAction(UIAlertAction(title: "Upload", style: .default) { _ in
            completion(.folderUpload(allowed: true))
        })
        presenter.present(alert, animated: true)
    }
    
    // MARK: - Picker Prompts
    
    private func presentColorPicker(
        session: GeckoSession,
        request: ColorPromptRequest,
        completion: @escaping (PromptResponse?) -> Void
    ) {
        guard let anchor = promptAnchor(for: request.anchor, session: session) else {
            completion(nil)
            return
        }

        let picker = ColorPicker(
            anchorRect: anchor.rect,
            geckoView: anchor.view
        )
        colorPickers[request.id] = picker

        picker.present(initialColor: UIColor(hexString: request.value) ?? .black) { [weak self] result in
            self?.colorPickers.removeValue(forKey: request.id)
            completion(result.map(PromptResponse.color))
        }
    }

    private func presentDateTimePicker(
        session: GeckoSession,
        request: DateTimePromptRequest,
        completion: @escaping (PromptResponse?) -> Void
    ) {
        guard let anchor = promptAnchor(for: request.anchor, session: session) else {
            completion(nil)
            return
        }

        let picker = DateTimePicker(
            inputMode: request.mode,
            anchorRect: anchor.rect,
            geckoView: anchor.view
        )
        dateTimePickers[request.id] = picker

        picker.present(
            value: request.value,
            min: request.min,
            max: request.max,
            step: request.step
        ) { [weak self] result in
            self?.dateTimePickers.removeValue(forKey: request.id)
            completion(result.map(PromptResponse.dateTime))
        }
    }

    private func presentFilePicker(
        session: GeckoSession,
        request: FilePickerPromptRequest,
        completion: @escaping (PromptResponse?) -> Void
    ) {
        guard let anchor = promptAnchor(for: request.anchor, session: session) else {
            completion(nil)
            return
        }

        let picker = FilePicker(
            promptId: request.id,
            mode: request.mode,
            mimeTypes: request.mimeTypes,
            capture: request.capture,
            anchorRect: anchor.rect,
            geckoView: anchor.view
        )
        filePickers[request.id] = picker

        picker.present { [weak self] result in
            self?.filePickers.removeValue(forKey: request.id)
            completion(result.map(PromptResponse.files))
        }
    }

    private func presentSelectPicker(
        session: GeckoSession,
        request: SelectPromptRequest,
        completion: @escaping (PromptResponse?) -> Void
    ) {
        guard let anchor = promptAnchor(for: request.anchor, session: session) else {
            completion(nil)
            return
        }

        let picker = SelectPicker(
            mode: request.mode,
            choices: request.choices,
            sourceRect: anchor.rect,
            geckoView: anchor.view
        )
        selectPickers[request.id] = picker

        picker.present { [weak self] result in
            self?.selectPickers.removeValue(forKey: request.id)
            completion(result.map(PromptResponse.choices))
        }
    }
    
    private func promptAnchor(
        for anchor: PromptAnchor,
        session: GeckoSession
    ) -> (view: UIView, rect: CGRect)? {
        guard let rect = anchor.rect,
              let geckoView = session.engineView,
              let window = geckoView.window else {
            return nil
        }
        
        var localRect = rect
        let windowPoint = window.convert(rect.origin, from: nil)
        localRect.origin = geckoView.convert(windowPoint, from: nil)
        return (geckoView, localRect)
    }
    
    // MARK: - Helpers
    
    private func buttonTitle(at index: Int, request: ButtonPromptRequest) -> String {
        let label = request.buttonTitles.indices.contains(index) ? request.buttonTitles[index] : ""
        let customLabel = request.customButtonTitles.indices.contains(index) ? request.customButtonTitles[index] : ""
        
        switch label {
        case "ok":
            return "OK"
        case "cancel":
            return "Cancel"
        case "yes":
            return "Yes"
        case "no":
            return "No"
        case "custom":
            return customLabel.isEmpty ? "OK" : customLabel
        default:
            return ""
        }
    }
}
