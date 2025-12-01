//
//  KarutaViewModel_MultiQuery.swift
//  RelationalExplorer
//
//  Multi-query support for Domino XML Server
//

import Foundation
import Network
import Combine

extension KarutaViewModel {
    func executeQueries() {
        guard isConnected else {
            errorMessage = "Not connected to server"
            return
        }

        // Parse queries - split by newlines first, then split multi-expression lines
        let lines = code.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var queries: [String] = []
        for line in lines {
            // Split line into individual expressions (top-level tuples)
            queries.append(contentsOf: splitExpressions(String(line)))
        }

        guard !queries.isEmpty else {
            errorMessage = "No queries to execute"
            return
        }

        // Clear previous results
        queryResults = []
        errorMessage = nil
        isLoading = true

        // Execute each query
        for query in queries {
            let result = QueryResult(query: String(query))
            queryResults.append(result)
            executeQuery(for: result.id, query: String(query))
        }
    }

    private func executeQuery(for resultId: UUID, query: String) {
        guard let resultIndex = queryResults.firstIndex(where: { $0.id == resultId }) else { return }

        queryResults[resultIndex].isLoading = true
        queryResults[resultIndex].startTime = Date()

        let command = "QUERY \(query)\n"
        sendCommand(command) { [weak self] response in
            self?.handleQueryResponse(for: resultId, xml: response)
        }
    }

    func loadMoreRows(for resultId: UUID) {
        guard let resultIndex = queryResults.firstIndex(where: { $0.id == resultId }),
              let sessionId = queryResults[resultIndex].sessionId,
              !queryResults[resultIndex].isLoading else { return }

        queryResults[resultIndex].isLoading = true

        let command = "NEXT \(sessionId) \(batchSize)\n"
        sendCommand(command) { [weak self] response in
            self?.handleNextResponse(for: resultId, xml: response)
        }
    }

    private func handleQueryResponse(for resultId: UUID, xml: String?) {
        DispatchQueue.main.async {
            guard let resultIndex = self.queryResults.firstIndex(where: { $0.id == resultId }) else { return }

            guard let xml = xml else {
                self.queryResults[resultIndex].errorMessage = "No response received"
                self.queryResults[resultIndex].isLoading = false
                return
            }

            print("📨 Query Response for \(resultId): \(xml)")

            let parser = DominoXMLParser()
            if let response = parser.parseQueryResponse(xml: xml) {
                if response.status == "ok", let sessionId = response.sessionId {
                    self.queryResults[resultIndex].sessionId = sessionId
                    self.queryResults[resultIndex].isLoading = false
                    // Automatically load first batch
                    self.loadMoreRows(for: resultId)
                } else if let message = response.message {
                    self.queryResults[resultIndex].errorMessage = message
                    self.queryResults[resultIndex].isLoading = false
                }
            } else {
                self.queryResults[resultIndex].errorMessage = "Failed to parse response"
                self.queryResults[resultIndex].isLoading = false
            }
        }
    }

    private func handleNextResponse(for resultId: UUID, xml: String?) {
        DispatchQueue.main.async {
            guard let resultIndex = self.queryResults.firstIndex(where: { $0.id == resultId }) else { return }

            self.queryResults[resultIndex].isLoading = false

            guard let xml = xml else {
                self.queryResults[resultIndex].errorMessage = "No tuples response"
                return
            }

            let parser = DominoXMLParser()
            if let response = parser.parseTuplesResponse(xml: xml) {
                if response.status == "ok" {
                    let newTuples = response.tuples

                    if let existingTable = self.queryResults[resultIndex].tableData {
                        // Append rows
                        let updatedRows = existingTable.rows + newTuples.map { tuple in
                            existingTable.columns.map { column in tuple[column] ?? "" }
                        }
                        self.queryResults[resultIndex].tableData = RelationTable(
                            columns: existingTable.columns,
                            rows: updatedRows
                        )
                    } else {
                        // Create new table (first batch)
                        if !newTuples.isEmpty {
                            let columns = Array(newTuples[0].keys.filter { $0 != "meta" }).sorted()
                            let rows = newTuples.map { tuple in
                                columns.map { column in tuple[column] ?? "" }
                            }
                            self.queryResults[resultIndex].tableData = RelationTable(
                                columns: columns,
                                rows: rows
                            )

                            // Calculate execution time for first batch
                            if let startTime = self.queryResults[resultIndex].startTime {
                                self.queryResults[resultIndex].executionTime = Date().timeIntervalSince(startTime)
                            }
                        }
                    }

                    self.queryResults[resultIndex].hasMoreRows = newTuples.count >= self.batchSize
                } else if let message = response.message {
                    self.queryResults[resultIndex].errorMessage = message
                }
            }

            // Check if all queries are done
            let allDone = self.queryResults.allSatisfy { !$0.isLoading }
            if allDone {
                self.isLoading = false
            }
        }
    }

    /// Split a line that may contain multiple top-level expressions
    /// e.g., "{scan, employees}{take, {scan, naturals}, 25}" -> ["{scan, employees}", "{take, {scan, naturals}, 25}"]
    private func splitExpressions(_ line: String) -> [String] {
        var expressions: [String] = []
        var currentExpr = ""
        var braceDepth = 0
        var inString = false
        var escapeNext = false

        for char in line {
            if escapeNext {
                currentExpr.append(char)
                escapeNext = false
                continue
            }

            if char == "\\" {
                escapeNext = true
                currentExpr.append(char)
                continue
            }

            if char == "\"" {
                inString.toggle()
                currentExpr.append(char)
                continue
            }

            if inString {
                currentExpr.append(char)
                continue
            }

            // Track brace depth
            if char == "{" {
                braceDepth += 1
                currentExpr.append(char)
            } else if char == "}" {
                braceDepth -= 1
                currentExpr.append(char)

                // If we're back to depth 0, we've completed an expression
                if braceDepth == 0 && !currentExpr.trimmingCharacters(in: .whitespaces).isEmpty {
                    expressions.append(currentExpr.trimmingCharacters(in: .whitespaces))
                    currentExpr = ""
                }
            } else {
                currentExpr.append(char)
            }
        }

        // Add any remaining expression (in case the line doesn't end with })
        if !currentExpr.trimmingCharacters(in: .whitespaces).isEmpty {
            expressions.append(currentExpr.trimmingCharacters(in: .whitespaces))
        }

        return expressions.isEmpty ? [line] : expressions
    }
}
