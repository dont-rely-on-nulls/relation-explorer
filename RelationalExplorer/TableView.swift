//
//  TableView.swift
//  RelationalExplorer
//
//  Created by Marcos Magueta on 25/11/25.
//

import SwiftUI

struct TableView: View {
    let table: RelationTable

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 1) {
                ForEach(table.columns, id: \.self) { column in
                    Text(column)
                        .font(.system(.callout, design: .monospaced))
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.15))
                }
            }
            .background(Color.blue.opacity(0.1))

            Divider()

            // Rows
            ScrollView {
                VStack(spacing: 1) {
                    ForEach(Array(table.rows.enumerated()), id: \.offset) { index, row in
                        HStack(spacing: 1) {
                            ForEach(Array(row.enumerated()), id: \.offset) { cellIndex, cell in
                                Text(cell)
                                    .font(.system(.body, design: .monospaced))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(index % 2 == 0 ? Color.clear : Color.gray.opacity(0.05))
                            }
                        }
                    }
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

struct EmptyTableView: View {
    var body: some View {
        VStack {
            Image(systemName: "table")
                .font(.system(size: 48))
                .foregroundColor(.gray)
                .padding()
            Text("No results yet")
                .font(.headline)
                .foregroundColor(.gray)
            Text("Execute a query to see results here")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
