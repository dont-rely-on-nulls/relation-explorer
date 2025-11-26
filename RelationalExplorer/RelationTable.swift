//
//  RelationTable.swift
//  RelationalExplorer
//
//  Created by Marcos Magueta on 25/11/25.
//

import Foundation

struct RelationTable: Identifiable {
    let id = UUID()
    let columns: [String]
    let rows: [[String]]

    var rowCount: Int {
        rows.count
    }

    var columnCount: Int {
        columns.count
    }
}

class RelationTableParser: NSObject, XMLParserDelegate {
    private var currentElement = ""
    private var columns: [String] = []
    private var rows: [[String]] = []
    private var currentRow: [String] = []
    private var currentValue = ""

    func parse(xml: String) -> RelationTable? {
        columns = []
        rows = []
        currentRow = []
        currentValue = ""

        let parser = XMLParser(data: Data(xml.utf8))
        parser.delegate = self

        guard parser.parse() else {
            return nil
        }

        guard !columns.isEmpty else {
            return nil
        }

        return RelationTable(columns: columns, rows: rows)
    }

    // MARK: - XMLParserDelegate

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        currentValue = ""

        if elementName == "row" {
            currentRow = []
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentValue += string.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "column" {
            if !currentValue.isEmpty {
                columns.append(currentValue)
            }
        } else if elementName == "cell" {
            currentRow.append(currentValue)
        } else if elementName == "row" {
            if !currentRow.isEmpty {
                rows.append(currentRow)
            }
            currentRow = []
        }

        currentValue = ""
    }
}
