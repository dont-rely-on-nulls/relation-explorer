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

struct QueryResult: Identifiable {
    let id = UUID()
    let query: String
    var sessionId: String?
    var tableData: RelationTable?
    var hasMoreRows: Bool = false
    var isLoading: Bool = false
    var errorMessage: String?
    var executionTime: TimeInterval?
    var startTime: Date?
}

struct DominoQueryResponse {
    let status: String
    let sessionId: String?
    let message: String?
}

struct DominoTuplesResponse {
    let status: String
    let tuples: [[String: String]]
    let message: String?
}

struct RelationSchema: Identifiable {
    let id = UUID()
    let name: String
    let cardinality: String
    let attributes: [RelationAttribute]
    let constraints: [RelationConstraint]
    let provenance: String?
}

struct RelationConstraint: Identifiable {
    let id = UUID()
    let attribute: String
    let constraint: String
}

struct RelationAttribute: Identifiable {
    let id = UUID()
    let name: String
    let type: String
}

struct DominoSchemaResponse {
    let status: String
    let relations: [RelationSchema]
    let message: String?
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

// MARK: - Domino XML Server Parser

class DominoXMLParser: NSObject, XMLParserDelegate {
    private var currentElement = ""
    private var currentValue = ""
    private var currentAttributes: [String: String] = [:]

    // For query response
    private var status = ""
    private var sessionId: String?
    private var message: String?

    // For tuples response
    private var tuples: [[String: String]] = []
    private var currentTuple: [String: String] = [:]
    private var currentAttributeName: String?

    // For schema response
    private var relations: [RelationSchema] = []
    private var currentRelation: (name: String, cardinality: String, attributes: [RelationAttribute])?
    private var currentRelationAttributes: [RelationAttribute] = []
    private var currentRelationConstraints: [RelationConstraint] = []
    private var currentRelationProvenance: String?
    private var currentConstraintAttribute: String?
    private var inConstraints: Bool = false
    private var inProvenance: Bool = false

    func parseQueryResponse(xml: String) -> DominoQueryResponse? {
        status = ""
        sessionId = nil
        message = nil

        let parser = XMLParser(data: Data(xml.utf8))
        parser.delegate = self
        guard parser.parse() else { return nil }

        return DominoQueryResponse(status: status, sessionId: sessionId, message: message)
    }

    func parseTuplesResponse(xml: String) -> DominoTuplesResponse? {
        status = ""
        message = nil
        tuples = []
        currentTuple = [:]

        let parser = XMLParser(data: Data(xml.utf8))
        parser.delegate = self
        guard parser.parse() else { return nil }

        return DominoTuplesResponse(status: status, tuples: tuples, message: message)
    }

    func parseSchemaResponse(xml: String) -> DominoSchemaResponse? {
        status = ""
        message = nil
        relations = []
        currentRelation = nil
        currentRelationAttributes = []
        currentRelationConstraints = []
        currentRelationProvenance = nil
        currentConstraintAttribute = nil
        inConstraints = false
        inProvenance = false

        let parser = XMLParser(data: Data(xml.utf8))
        parser.delegate = self
        guard parser.parse() else { return nil }

        return DominoSchemaResponse(status: status, relations: relations, message: message)
    }

    // MARK: - XMLParserDelegate

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        currentValue = ""
        currentAttributes = attributeDict

        if elementName == "tuple" {
            currentTuple = [:]
        } else if elementName == "attribute" {
            currentAttributeName = attributeDict["name"]
            // For schema parsing - check if we're in a relation context and not in constraints
            if let name = attributeDict["name"], let type = attributeDict["type"], currentRelation != nil, !inConstraints {
                currentRelationAttributes.append(RelationAttribute(name: name, type: type))
            }
        } else if elementName == "relation" {
            let name = attributeDict["name"] ?? ""
            let cardinality = attributeDict["cardinality"] ?? ""
            currentRelation = (name, cardinality, [])
            currentRelationAttributes = []
            currentRelationConstraints = []
            currentRelationProvenance = nil
        } else if elementName == "constraints" {
            inConstraints = true
        } else if elementName == "constraint" {
            currentConstraintAttribute = attributeDict["attribute"]
        } else if elementName == "provenance" {
            inProvenance = true
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentValue += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let trimmedValue = currentValue.trimmingCharacters(in: .whitespacesAndNewlines)

        switch elementName {
        case "status":
            status = trimmedValue
        case "session":
            sessionId = trimmedValue
        case "message":
            message = trimmedValue
        case "attribute":
            if let name = currentAttributeName {
                currentTuple[name] = trimmedValue
            }
            currentAttributeName = nil
        case "tuple":
            if !currentTuple.isEmpty {
                tuples.append(currentTuple)
            }
            currentTuple = [:]
        case "constraint":
            if let attr = currentConstraintAttribute, !trimmedValue.isEmpty {
                currentRelationConstraints.append(RelationConstraint(attribute: attr, constraint: trimmedValue))
            }
            currentConstraintAttribute = nil
        case "constraints":
            inConstraints = false
        case "provenance":
            if inProvenance {
                currentRelationProvenance = trimmedValue
                inProvenance = false
            }
        case "relation":
            if let rel = currentRelation {
                let schema = RelationSchema(
                    name: rel.name,
                    cardinality: rel.cardinality,
                    attributes: currentRelationAttributes,
                    constraints: currentRelationConstraints,
                    provenance: currentRelationProvenance
                )
                relations.append(schema)
            }
            currentRelation = nil
            currentRelationAttributes = []
            currentRelationConstraints = []
            currentRelationProvenance = nil
        default:
            break
        }

        currentValue = ""
    }
}
