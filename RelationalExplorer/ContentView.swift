//
//  ContentView.swift
//  RelationalExplorer
//
//  Created by Marcos Magueta on 25/11/25.
//

import SwiftUI

struct ContentView: View {
    @State private var host: String = "localhost"
    @State private var port: String = "5555"
    @State private var viewModel: KarutaViewModel?

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("Karuta Explorer")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                // Connection controls
                TextField("Host", text: $host)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 150)
                    .disabled(viewModel?.isConnected ?? false)

                TextField("Port", text: $port)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .disabled(viewModel?.isConnected ?? false)

                if viewModel?.isConnected ?? false {
                    Button("Disconnect") {
                        viewModel?.disconnect()
                    }
                    .buttonStyle(.bordered)

                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                } else {
                    Button("Connect") {
                        if let portNum = UInt16(port) {
                            let vm = KarutaViewModel(host: host, port: portNum)
                            viewModel = vm
                            vm.connect()
                        }
                    }
                    .buttonStyle(.borderedProminent)

                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                }
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Main content area
            HSplitView {
                // Left side: Code editor
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Query")
                            .font(.headline)
                        Spacer()
                        Button(action: {
                            viewModel?.executeQuery()
                        }) {
                            HStack {
                                Image(systemName: "play.fill")
                                Text("Execute")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!(viewModel?.isConnected ?? false) || (viewModel?.isLoading ?? false))
                    }
                    .padding(.horizontal)
                    .padding(.top)

                    TextEditor(text: Binding(
                        get: { viewModel?.code ?? "" },
                        set: { viewModel?.code = $0 }
                    ))
                        .font(.system(.body, design: .monospaced))
                        .padding(4)
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        .padding(.horizontal)

                    if let error = viewModel?.errorMessage {
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

                // Right side: Table view
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Results")
                            .font(.headline)
                        Spacer()
                        if let table = viewModel?.tableData {
                            Text("\(table.rowCount) rows")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        if viewModel?.isLoading ?? false {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top)

                    if let table = viewModel?.tableData {
                        TableView(table: table)
                            .padding(.horizontal)
                    } else {
                        EmptyTableView()
                    }

                    Spacer()
                }
                .frame(minWidth: 300)
                .padding(.bottom)
            }
        }
        .frame(minWidth: 800, minHeight: 600)
    }
}

#Preview {
    ContentView()
}
