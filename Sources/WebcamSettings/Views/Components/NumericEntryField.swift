import AppKit
import SwiftUI

struct NumericEntryField: NSViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    let focusRequestID: Int
    let isEnabled: Bool
    let onCommit: () -> Void
    let onIncrement: () -> Void
    let onDecrement: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NumericTextField {
        let textField = NumericTextField()
        textField.delegate = context.coordinator
        textField.isBordered = true
        textField.isBezeled = true
        textField.focusRingType = .default
        textField.alignment = .right
        textField.target = context.coordinator
        textField.action = #selector(Coordinator.commit)
        textField.onIncrement = {
            context.coordinator.parent.onIncrement()
        }
        textField.onDecrement = {
            context.coordinator.parent.onDecrement()
        }
        return textField
    }

    func updateNSView(_ nsView: NumericTextField, context: Context) {
        context.coordinator.parent = self
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        nsView.isEnabled = isEnabled
        nsView.onIncrement = {
            context.coordinator.parent.onIncrement()
        }
        nsView.onDecrement = {
            context.coordinator.parent.onDecrement()
        }
        if focusRequestID != context.coordinator.lastAppliedFocusRequestID {
            context.coordinator.lastAppliedFocusRequestID = focusRequestID
            context.coordinator.requestFocus(for: nsView)
        } else if isFocused, nsView.window?.firstResponder !== nsView.currentEditor() {
            context.coordinator.requestFocus(for: nsView)
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: NumericEntryField
        var lastAppliedFocusRequestID: Int

        init(parent: NumericEntryField) {
            self.parent = parent
            self.lastAppliedFocusRequestID = parent.focusRequestID
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let textField = notification.object as? NSTextField else { return }
            parent.text = textField.stringValue
        }

        func controlTextDidBeginEditing(_ notification: Notification) {
            parent.isFocused = true
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            parent.isFocused = false
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            switch commandSelector {
            case #selector(NSResponder.moveUp(_:)):
                parent.isFocused = true
                parent.onIncrement()
                return true
            case #selector(NSResponder.moveDown(_:)):
                parent.isFocused = true
                parent.onDecrement()
                return true
            default:
                return false
            }
        }

        @MainActor
        @objc func commit() {
            parent.onCommit()
        }

        func requestFocus(for textField: NumericTextField, attemptsRemaining: Int = 4) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
                guard textField.isEnabled else { return }
                guard let window = textField.window else {
                    if attemptsRemaining > 0 {
                        self.requestFocus(for: textField, attemptsRemaining: attemptsRemaining - 1)
                    }
                    return
                }

                window.makeFirstResponder(nil)
                if window.makeFirstResponder(textField) {
                    textField.selectText(nil)
                } else if attemptsRemaining > 0 {
                    self.requestFocus(for: textField, attemptsRemaining: attemptsRemaining - 1)
                }
            }
        }
    }
}

final class NumericTextField: NSTextField {
    var onIncrement: (() -> Void)?
    var onDecrement: (() -> Void)?
}
