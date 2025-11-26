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
    @Published var tableData: RelationTable?
    @Published var isConnected: Bool = false
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false

    private var connection: NWConnection?
    private let host: String
    private let port: UInt16

    init(host: String = "localhost", port: UInt16 = 5555) {
        self.host = host
        self.port = port
    }

    func connect() {
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: NWEndpoint.Port(integerLiteral: port))
        connection = NWConnection(to: endpoint, using: .tcp)

        connection?.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    self?.isConnected = true
                    self?.errorMessage = nil
                case .failed(let error):
                    self?.isConnected = false
                    self?.errorMessage = "Connection failed: \(error.localizedDescription)"
                case .waiting(let error):
                    self?.isConnected = false
                    self?.errorMessage = "Waiting to connect: \(error.localizedDescription)"
                default:
                    break
                }
            }
        }

        connection?.start(queue: .global())
    }

    func disconnect() {
        connection?.cancel()
        connection = nil
        isConnected = false
    }

    func executeQuery() {
        guard isConnected, let connection = connection else {
            errorMessage = "Not connected to server"
            return
        }

        guard !code.isEmpty else {
            errorMessage = "Query is empty"
            return
        }

        isLoading = true
        errorMessage = nil

        let data = Data(code.utf8)
        connection.send(content: data, completion: .contentProcessed { [weak self] error in
            if let error = error {
                DispatchQueue.main.async {
                    self?.errorMessage = "Send failed: \(error.localizedDescription)"
                    self?.isLoading = false
                }
                return
            }

            self?.receiveResponse()
        })
    }

    private func receiveResponse() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            DispatchQueue.main.async {
                self?.isLoading = false

                if let error = error {
                    self?.errorMessage = "Receive failed: \(error.localizedDescription)"
                    return
                }

                guard let data = data, !data.isEmpty else {
                    if isComplete {
                        self?.errorMessage = "No data received"
                    }
                    return
                }

                // Parse XML response
                if let xmlString = String(data: data, encoding: .utf8) {
                    self?.parseXMLResponse(xmlString)
                } else {
                    self?.errorMessage = "Failed to decode response"
                }
            }
        }
    }

    private func parseXMLResponse(_ xml: String) {
        let parser = RelationTableParser()
        if let table = parser.parse(xml: xml) {
            self.tableData = table
            self.errorMessage = nil
        } else {
            self.errorMessage = "Failed to parse XML response"
        }
    }
}
