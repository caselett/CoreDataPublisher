//
//  ContentView.swift
//  Example
//
//  Created by caselet on 2/24/25.
//

import SwiftUI
import CoreData

struct ContentView: View {

    @StateObject
    private var viewModel = ContentViewModel(useKeyPath: true)

    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.items) { item in
                    if let timestamp = item.timestamp,
                       let rowTimestamp = item.row?.timestamp {
                        NavigationLink {
                            VStack {
                                Text("Item at \(timestamp, formatter: DateFormatter.itemFormatter)")
                                Text("Row at \(rowTimestamp, formatter: DateFormatter.itemFormatter)")

                                Button { [weak viewModel] in
                                    viewModel?.editRow(for: item)
                                } label: {
                                    Label("Edit Row", systemImage: "pencil")
                                }
                                .padding(.top, 24)
                            }
                        } label: {
                            VStack {
                                Group {
                                    Text("Item at \(timestamp, formatter: DateFormatter.itemFormatter)")
                                    Text("Row at \(rowTimestamp, formatter: DateFormatter.itemFormatter)")
                                }
                                .foregroundColor(timestamp == rowTimestamp ? .green : .red)
                            }
                        }
                    }
                }
                .onDelete { [weak viewModel] offsets in
                    viewModel?.deleteItems(offsets: offsets)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                ToolbarItem {
                    Button { [weak viewModel] in
                        viewModel?.addItem()
                    } label: {
                        Label("Add Item", systemImage: "plus")
                    }
                }
            }
            .navigationTitle(Text("Select an item"))
        }
    }
}

extension DateFormatter {
    static let itemFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter
    }()
}

#Preview {
    ContentView()
}
