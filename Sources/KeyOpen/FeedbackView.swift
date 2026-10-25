import AppKit
import KeyOpenCore
import SwiftUI

/// "Send Feedback…": a message, optionally tagged with the version, sent as an
/// email draft or a GitHub issue — either way the user presses the final Send.
struct FeedbackView: View {
    let onDone: () -> Void
    @State private var message = ""
    @State private var includeVersion = true

    private var info: DiagnosticInfo? { includeVersion ? AppInfo.diagnostics : nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Send Feedback")
                .font(.system(size: 14, weight: .semibold))
                .frame(maxWidth: .infinity)
            Text("Missed a hotkey? Got a combo wrong? Tell us which app.")
                .font(.system(size: 12))
            MessageField(text: $message, placeholder: "Your message…", height: 96)
            Toggle("Include version info (\(AppInfo.version) · macOS \(AppInfo.osVersion))",
                   isOn: $includeVersion)
                .font(.system(size: 11.5))
            HStack(spacing: 8) {
                Button {
                    NSWorkspace.shared.open(Feedback.issueURL(message: message, info: info))
                    onDone()
                } label: { Text("Open GitHub Issue").frame(maxWidth: .infinity) }
                Button {
                    let diagnostics = AppInfo.diagnostics
                    Mailer.compose(subject: Feedback.subject(.feedback, info: diagnostics),
                                   body: Feedback.body(message: message, info: info))
                    onDone()
                } label: { Text("Send").frame(maxWidth: .infinity) }
                .keyboardShortcut(.defaultAction)
                .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .controlSize(.large)
        }
        .padding(20)
        .frame(width: 380)
    }
}

/// Shown at launch when macOS recorded a KeyOpen crash since the last run.
/// Nothing is sent unless the user sends the Mail draft themselves.
struct CrashReportView: View {
    let report: URL
    let onDone: () -> Void
    @State private var note = ""

    var body: some View {
        VStack(spacing: 0) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 52, height: 52)
            Text("KeyOpen quit unexpectedly last time")
                .font(.system(size: 14, weight: .semibold))
                .padding(.top, 8)
            Text("Send the crash report so it can be fixed? It holds the app and macOS versions and where in the code it crashed. Mail opens with it attached, so you see everything before it's sent.")
                .font(.system(size: 12))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)
            MessageField(text: $note, placeholder: "What were you doing? (optional)", height: 46)
                .padding(.top, 10)
            Button("View report") { NSWorkspace.shared.activateFileViewerSelecting([report]) }
                .buttonStyle(.link)
                .tint(Palette.system)
                .font(.system(size: 11.5))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
            HStack(spacing: 8) {
                Button { onDone() } label: { Text("Don't Send").frame(maxWidth: .infinity) }
                    .keyboardShortcut(.cancelAction)
                Button {
                    send()
                    onDone()
                } label: { Text("Send Report").frame(maxWidth: .infinity) }
                .keyboardShortcut(.defaultAction)
            }
            .controlSize(.large)
        }
        .padding(20)
        .frame(width: 380)
    }

    private func send() {
        let info = AppInfo.diagnostics
        let subject = Feedback.subject(.crash, info: info)
        let body = Feedback.body(message: note, info: info)
        if !Mailer.compose(subject: subject, body: body, attachment: report) {
            // The fallback mail handler can't attach files: point at the
            // report so it can be dragged into the draft.
            NSWorkspace.shared.activateFileViewerSelecting([report])
        }
    }
}

/// A multi-line field with a placeholder, which `TextEditor` lacks on macOS 13.
private struct MessageField: View {
    @SwiftUI.Binding var text: String
    let placeholder: String
    let height: CGFloat

    var body: some View {
        TextEditor(text: $text)
            .font(.system(size: 12))
            .scrollContentBackground(.hidden)
            .padding(4)
            .background(Color(nsColor: .textBackgroundColor))
            .overlay(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .allowsHitTesting(false)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(nsColor: .separatorColor)))
            .frame(height: height)
    }
}

/// Opens an email draft to us. The user reviews it and presses Send.
@MainActor
enum Mailer {
    /// Returns whether the attachment made it into the draft.
    @discardableResult
    static func compose(subject: String, body: String, attachment: URL? = nil) -> Bool {
        if let service = NSSharingService(named: .composeEmail) {
            service.recipients = [Feedback.email]
            service.subject = subject
            var items: [Any] = [body]
            if let attachment { items.append(attachment) }
            if service.canPerform(withItems: items) {
                service.perform(withItems: items)
                return true
            }
        }
        // No Mail.app account: hand off to whatever handles mailto:.
        NSWorkspace.shared.open(Feedback.mailtoURL(subject: subject, body: body))
        return attachment == nil
    }
}
