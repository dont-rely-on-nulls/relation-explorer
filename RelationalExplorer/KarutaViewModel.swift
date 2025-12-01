//
//  KarutaViewModel.swift
//  RelationalExplorer
//
//  Created by Marcos Magueta on 25/11/25.
//

import Foundation
import Network
import Combine

class KarutaViewModel: ObservableObject {
    @Published var code: String = ""
    @Published var queryResults: [QueryResult] = []
    @Published var isConnected: Bool = false
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false
    @Published var schema: [RelationSchema] = []

    private var connection: NWConnection?
    private var host: String
    private var port: UInt16
    internal let batchSize = 10

    init(host: String = "127.0.0.1", port: UInt16 = 8080) {
        self.host = host
        self.port = port
    }

    func updateConnection(host: String, port: UInt16) {
        self.host = host
        self.port = port
    }

    func connect() {
        print("🔌 Attempting to connect to \(host):\(port)")
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: NWEndpoint.Port(integerLiteral: port))
        connection = NWConnection(to: endpoint, using: .tcp)

        connection?.stateUpdateHandler = { [weak self] state in
            print("🔄 Connection state changed: \(state)")
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    print("✅ Connection ready!")
                    self?.isConnected = true
                    self?.errorMessage = nil
                    // Fetch schema automatically on connection
                    self?.fetchSchema()
                case .failed(let error):
                    print("❌ Connection failed: \(error)")
                    self?.isConnected = false
                    self?.errorMessage = "Connection failed: \(error.localizedDescription)"
                case .waiting(let error):
                    print("⏳ Waiting to connect: \(error)")
                    self?.isConnected = false
                    self?.errorMessage = "Waiting to connect: \(error.localizedDescription)"
                case .preparing:
                    print("🔧 Preparing connection...")
                case .setup:
                    print("⚙️ Setting up connection...")
                case .cancelled:
                    print("🚫 Connection cancelled")
                    self?.isConnected = false
                @unknown default:
                    print("❓ Unknown connection state: \(state)")
                }
            }
        }

        connection?.start(queue: .global())
        print("🚀 Connection started")
    }

    func fetchSchema() {
        print("📋 Fetching schema...")
        let command = "SCHEMA\n"
        sendCommand(command) { [weak self] xml in
            guard let self = self else {
                print("❌ Self is nil in fetchSchema callback")
                return
            }

            guard let xml = xml else {
                print("❌ No XML response received for SCHEMA")
                return
            }

            print("📦 Received SCHEMA XML response:")
            print(xml)

            let parser = DominoXMLParser()
            if let response = parser.parseSchemaResponse(xml: xml) {
                print("📋 Parsed schema response: status=\(response.status), relations=\(response.relations.count)")
                DispatchQueue.main.async {
                    if response.status == "ok" {
                        self.schema = response.relations
                        print("✅ Schema loaded: \(response.relations.count) relations")
                        for relation in response.relations {
                            print("  - \(relation.name): \(relation.attributes.count) attributes")
                        }
                    } else if let message = response.message {
                        print("❌ Schema error: \(message)")
                    }
                }
            } else {
                print("❌ Failed to parse schema response")
            }
        }
    }

    func disconnect() {
        // Close all active sessions
        for result in queryResults where result.sessionId != nil {
            closeSession(result.sessionId!)
        }
        connection?.cancel()
        connection = nil
        isConnected = false
        queryResults = []
    }

    func executeQuery() {
        executeQueries()
    }

    func clearResults() {
        // Close all active sessions
        for result in queryResults where result.sessionId != nil {
            closeSession(result.sessionId!)
        }
        queryResults = []
        errorMessage = nil
    }

    func formatQuery() {
        // Simple formatter that adds proper indentation
        let lines = code.split(separator: "\n")
        var formatted: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty {
                formatted.append(formatExpression(trimmed))
            }
        }

        code = formatted.joined(separator: "\n")
    }

    private func formatExpression(_ expr: String) -> String {
        var result = ""
        var depth = 0
        var inString = false
        var lastChar: Character?

        for char in expr {
            if char == "\"" && lastChar != "\\" {
                inString.toggle()
            }

            if !inString {
                if char == "{" {
                    if lastChar != nil && lastChar != "{" && lastChar != "," && lastChar != " " {
                        result += " "
                    }
                    result.append(char)
                    depth += 1
                } else if char == "}" {
                    depth -= 1
                    result.append(char)
                } else if char == "," {
                    result.append(char)
                    result += " "
                } else if char == " " {
                    // Skip extra spaces
                    if lastChar != " " && lastChar != "," && lastChar != "{" {
                        result.append(char)
                    }
                } else {
                    result.append(char)
                }
            } else {
                result.append(char)
            }

            lastChar = char
        }

        return result.trimmingCharacters(in: .whitespaces)
    }

    private func closeSession(_ sessionId: String) {
        let command = "CLOSE \(sessionId)\n"
        sendCommand(command) { _ in }
    }

    internal func sendCommand(_ command: String, completion: @escaping (String?) -> Void) {
        guard let connection = connection else {
            print("❌ No connection available")
            completion(nil)
            return
        }

        print("📤 Sending command: \(command.trimmingCharacters(in: .whitespacesAndNewlines))")
        let data = Data(command.utf8)
        connection.send(content: data, completion: .contentProcessed { [weak self] error in
            if let error = error {
                print("❌ Send failed: \(error)")
                DispatchQueue.main.async {
                    self?.errorMessage = "Send failed: \(error.localizedDescription)"
                    self?.isLoading = false
                }
                completion(nil)
                return
            }

            print("✅ Command sent, waiting for response...")
            self?.receiveXMLResponse(completion: completion)
        })
    }

    private func receiveXMLResponse(completion: @escaping (String?) -> Void) {
        var buffer = Data()

        func receiveChunk() {
            print("📥 Receiving data...")
            connection?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, isComplete, error in
                if let error = error {
                    print("❌ Receive error: \(error)")
                    DispatchQueue.main.async {
                        self.errorMessage = "Receive failed: \(error.localizedDescription)"
                        self.isLoading = false
                    }
                    completion(nil)
                    return
                }

                if let data = data {
                    print("📦 Received \(data.count) bytes")
                    buffer.append(data)
                }

                // Check if we have a complete XML response
                if let xmlString = String(data: buffer, encoding: .utf8),
                   xmlString.contains("</response>") {
                    print("✅ Complete XML response received (\(xmlString.count) chars)")
                    completion(xmlString)
                } else if !isComplete {
                    print("⏳ Incomplete, receiving more...")
                    receiveChunk() // Continue receiving
                } else {
                    print("⚠️ Connection complete but no </response> found")
                    completion(nil)
                }
            }
        }

        receiveChunk()
    }
}
