//
//  ContentView.swift
//  RelationalExplorer
//
//  Created by Marcos Magueta on 25/11/25.
//

import SwiftUI

struct ContentView: View {
    @State private var host: String = "127.0.0.1"
    @State private var port: String = "8080"
    @State private var showExamples: Bool = false
    @StateObject private var viewModel = KarutaViewModel()

    var body: some View {
        TabView {
            // Query Tab
            queryTab
                .tabItem {
                    Label("Query", systemImage: "terminal")
                }

            // Schema Tab
            schemaTab
                .tabItem {
                    Label("Schema", systemImage: "list.bullet.rectangle")
                }
        }
        .frame(minWidth: 800, minHeight: 600)
        .onReceive(NotificationCenter.default.publisher(for: .executeQuery)) { _ in
            if viewModel.isConnected && !viewModel.isLoading {
                viewModel.executeQuery()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .formatQuery)) { _ in
            if !viewModel.code.isEmpty {
                viewModel.formatQuery()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .clearResults)) { _ in
            if !viewModel.queryResults.isEmpty {
                viewModel.clearResults()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .insertExample)) { notification in
            if let example = notification.object as? String {
                viewModel.code = example
            }
        }
    }

    var queryTab: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: 16) {
                // App title with icon
                HStack(spacing: 8) {
                    Image(systemName: "cylinder.split.1x2")
                        .font(.title2)
                        .foregroundStyle(.blue.gradient)
                    Text("Domino Explorer")
                        .font(.title2)
                        .fontWeight(.bold)
                }

                Spacer()

                // Connection controls
                HStack(spacing: 8) {
                    TextField("Host", text: $host)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 150)
                        .disabled(viewModel.isConnected)

                    TextField("Port", text: $port)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .disabled(viewModel.isConnected)

                    if viewModel.isConnected {
                        Button("Disconnect") {
                            viewModel.disconnect()
                        }
                        .buttonStyle(.bordered)

                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                            Text("Connected")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Button("Connect") {
                            if let portNum = UInt16(port) {
                                viewModel.updateConnection(host: host, port: portNum)
                                viewModel.connect()
                            }
                        }
                        .buttonStyle(.borderedProminent)

                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                            Text("Disconnected")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding()
            .background(LinearGradient(
                colors: [Color(NSColor.windowBackgroundColor), Color(NSColor.controlBackgroundColor)],
                startPoint: .top,
                endPoint: .bottom
            ))

            Divider()

            // Main content area
            HSplitView {
                // Left side: Code editor
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Query Editor")
                            .font(.headline)

                        Spacer()

                        // Toolbar buttons
                        Menu {
                            Button("Scan employees") {
                                viewModel.code = "{scan, employees}"
                            }
                            Button("Scan departments") {
                                viewModel.code = "{scan, departments}"
                            }
                            Button("Take 25 naturals") {
                                viewModel.code = "{take, {scan, naturals}, 25}"
                            }
                            Divider()
                            Button("Join example") {
                                viewModel.code = "{join, {scan, employees}, {scan, departments}, dept_id}"
                            }
                            Button("Multi-query example") {
                                viewModel.code = "{scan, employees}\n{scan, departments}\n{take, {scan, naturals}, 10}"
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "list.bullet.rectangle")
                                Text("Examples")
                            }
                        }
                        .menuStyle(.borderlessButton)
                        .disabled(!viewModel.isConnected)

                        Button(action: {
                            viewModel.formatQuery()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "wand.and.stars")
                                Text("Format")
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.code.isEmpty)

                        Button(action: {
                            viewModel.clearResults()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "trash")
                                Text("Clear")
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.queryResults.isEmpty)

                        Button(action: {
                            viewModel.executeQuery()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "play.fill")
                                Text("Execute")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!viewModel.isConnected || viewModel.isLoading)
                        .keyboardShortcut(.return, modifiers: .command)
                    }
                    .padding(.horizontal)
                    .padding(.top)

                    TextEditor(text: $viewModel.code)
                        .font(.system(.body, design: .monospaced))
                        .padding(8)
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(viewModel.isConnected ? Color.blue.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 2)
                        )
                        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                        .padding(.horizontal)

                    if let error = viewModel.errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                    }

                    Spacer()
                }
                .frame(minWidth: 300)
                .padding(.bottom)

                // Right side: Query results
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Results")
                            .font(.headline)
                        Spacer()
                        if viewModel.isLoading {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top)

                    if viewModel.queryResults.isEmpty {
                        EmptyTableView()
                    } else {
                        ScrollView {
                            VStack(spacing: 16) {
                                ForEach(viewModel.queryResults) { result in
                                    QueryResultView(result: result, viewModel: viewModel)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    Spacer()
                }
                .frame(minWidth: 300)
                .padding(.bottom)
            }
        }
    }

    var schemaTab: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: 16) {
                // App title with icon
                HStack(spacing: 8) {
                    Image(systemName: "cylinder.split.1x2")
                        .font(.title2)
                        .foregroundStyle(.blue.gradient)
                    Text("Database Schema")
                        .font(.title2)
                        .fontWeight(.bold)
                }

                Spacer()

                // Connection controls
                HStack(spacing: 8) {
                    TextField("Host", text: $host)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 150)
                        .disabled(viewModel.isConnected)

                    TextField("Port", text: $port)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .disabled(viewModel.isConnected)

                    if viewModel.isConnected {
                        Button("Disconnect") {
                            viewModel.disconnect()
                        }
                        .buttonStyle(.bordered)

                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                            Text("Connected")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Button("Connect") {
                            if let portNum = UInt16(port) {
                                viewModel.updateConnection(host: host, port: portNum)
                                viewModel.connect()
                            }
                        }
                        .buttonStyle(.borderedProminent)

                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                            Text("Disconnected")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding()
            .background(LinearGradient(
                colors: [Color(NSColor.windowBackgroundColor), Color(NSColor.controlBackgroundColor)],
                startPoint: .top,
                endPoint: .bottom
            ))

            Divider()

            // Schema content
            SchemaView(viewModel: viewModel)
        }
    }
}

struct QueryResultView: View {
    let result: QueryResult
    @ObservedObject var viewModel: KarutaViewModel
    @State private var showCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Query header
            HStack(spacing: 8) {
                // Query badge
                HStack(spacing: 6) {
                    Image(systemName: "function")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text(result.query)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.blue.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                        )
                )

                Spacer()

                // Stats
                if let table = result.tableData {
                    HStack(spacing: 12) {
                        Label("\(table.rowCount)", systemImage: "tablecells")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if let execTime = result.executionTime {
                            Label(String(format: "%.2fs", execTime), systemImage: "clock")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        // Copy button
                        Button(action: {
                            copyTableToClipboard(table)
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                                Text(showCopied ? "Copied!" : "Copy")
                            }
                            .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }

                if result.isLoading {
                    ProgressView()
                        .scaleEffect(0.6)
                }
            }

            // Error message
            if let error = result.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Table
            if let table = result.tableData {
                TableView(table: table)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(6)
                    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)

                // Load More button
                if result.hasMoreRows {
                    HStack {
                        Spacer()
                        Button(action: {
                            viewModel.loadMoreRows(for: result.id)
                        }) {
                            HStack(spacing: 6) {
                                if result.isLoading {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                } else {
                                    Image(systemName: "arrow.down.circle.fill")
                                }
                                Text("Load More (10 rows)")
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                        .disabled(result.isLoading)
                        Spacer()
                    }
                    .padding(.top, 8)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
        )
    }

    private func copyTableToClipboard(_ table: RelationTable) {
        var csv = table.columns.joined(separator: "\t") + "\n"
        for row in table.rows {
            csv += row.joined(separator: "\t") + "\n"
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(csv, forType: .string)

        showCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showCopied = false
        }
    }
}

struct SchemaView: View {
    @ObservedObject var viewModel: KarutaViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if viewModel.schema.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "cylinder.split.1x2")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("No schema loaded")
                        .font(.headline)
                        .foregroundColor(.gray)
                    Text("Connect to the database to see available relations")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(viewModel.schema) { relation in
                            VStack(alignment: .leading, spacing: 8) {
                                // Relation header
                                HStack {
                                    Image(systemName: "tablecells")
                                        .foregroundColor(.blue)
                                    Text(relation.name)
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                    Spacer()
                                    Text(relation.cardinality)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(4)
                                }

                                // Attributes list
                                if !relation.attributes.isEmpty {
                                    VStack(alignment: .leading, spacing: 4) {
                                        ForEach(relation.attributes) { attr in
                                            HStack {
                                                Image(systemName: "smallcircle.filled.circle")
                                                    .font(.system(size: 8))
                                                    .foregroundColor(.secondary)
                                                Text(attr.name)
                                                    .font(.body)
                                                Spacer()
                                                Text(attr.type)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            .padding(.leading, 24)
                                        }
                                    }
                                } else {
                                    Text("No attributes")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .italic()
                                        .padding(.leading, 24)
                                }

                                // Constraints list
                                if !relation.constraints.isEmpty {
                                    Divider()
                                        .padding(.vertical, 8)

                                    HStack {
                                        Image(systemName: "exclamationmark.shield")
                                            .foregroundColor(.orange)
                                        Text("Constraints")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                    }
                                    .padding(.leading, 24)

                                    VStack(alignment: .leading, spacing: 4) {
                                        ForEach(relation.constraints) { constraint in
                                            HStack {
                                                Text(constraint.attribute)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                Text(constraint.constraint)
                                                    .font(.caption)
                                                    .fontWeight(.medium)
                                            }
                                            .padding(.leading, 36)
                                        }
                                    }
                                }

                                // Provenance
                                if let provenance = relation.provenance, !provenance.isEmpty {
                                    Divider()
                                        .padding(.vertical, 8)

                                    HStack(alignment: .top) {
                                        Image(systemName: "arrow.triangle.branch")
                                            .foregroundColor(.purple)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Provenance")
                                                .font(.caption)
                                                .fontWeight(.semibold)
                                            Text(provenance)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .padding(.leading, 24)
                                }

                                // Quick insert button
                                Button(action: {
                                    viewModel.code = "{scan, \(relation.name)}"
                                }) {
                                    HStack {
                                        Image(systemName: "arrow.right.circle.fill")
                                        Text("Insert scan query")
                                    }
                                    .font(.caption)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .padding(.leading, 24)
                                .padding(.top, 4)
                            }
                            .padding()
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                        }
                    }
                    .padding()
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
