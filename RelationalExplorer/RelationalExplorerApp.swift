//
//  RelationalExplorerApp.swift
//  RelationalExplorer
//
//  Created by Marcos Magueta on 25/11/25.
//

import SwiftUI

@main
struct RelationalExplorerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            // Replace default About
            CommandGroup(replacing: .appInfo) {
                Button("About Domino Explorer") {
                    NSApplication.shared.orderFrontStandardAboutPanel(
                        options: [
                            NSApplication.AboutPanelOptionKey.credits: NSAttributedString(
                                string: "A relational database explorer for Domino\n\nBuilt with SwiftUI and Erlang",
                                attributes: [
                                    .font: NSFont.systemFont(ofSize: 11),
                                    .foregroundColor: NSColor.secondaryLabelColor
                                ]
                            ),
                            NSApplication.AboutPanelOptionKey.applicationName: "Domino Explorer",
                            NSApplication.AboutPanelOptionKey.applicationVersion: "1.0.0",
                            NSApplication.AboutPanelOptionKey(rawValue: "Copyright"): "© 2025 DrN Team"
                        ]
                    )
                }
            }

            // File menu additions
            CommandGroup(after: .newItem) {
                Divider()
            }

            // Query menu
            CommandMenu("Query") {
                Button("Execute Query") {
                    NotificationCenter.default.post(name: .executeQuery, object: nil)
                }
                .keyboardShortcut(.return, modifiers: .command)

                Button("Format Query") {
                    NotificationCenter.default.post(name: .formatQuery, object: nil)
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])

                Button("Clear Results") {
                    NotificationCenter.default.post(name: .clearResults, object: nil)
                }
                .keyboardShortcut("k", modifiers: .command)

                Divider()

                Menu("Insert Example") {
                    Button("Scan Employees") {
                        NotificationCenter.default.post(name: .insertExample, object: "{scan, employees}")
                    }
                    Button("Scan Departments") {
                        NotificationCenter.default.post(name: .insertExample, object: "{scan, departments}")
                    }
                    Button("Take 25 Naturals") {
                        NotificationCenter.default.post(name: .insertExample, object: "{take, {scan, naturals}, 25}")
                    }
                    Divider()
                    Button("Join Example") {
                        NotificationCenter.default.post(name: .insertExample, object: "{join, {scan, employees}, {scan, departments}, dept_id}")
                    }
                }
            }

            // Help menu additions
            CommandGroup(replacing: .help) {
                Button("Domino Explorer Help") {
                    if let url = URL(string: "https://github.com/anthropics/domino") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .keyboardShortcut("?", modifiers: .command)
            }
        }
    }
}

// Notification names for menu commands
extension Notification.Name {
    static let executeQuery = Notification.Name("executeQuery")
    static let formatQuery = Notification.Name("formatQuery")
    static let clearResults = Notification.Name("clearResults")
    static let insertExample = Notification.Name("insertExample")
}
