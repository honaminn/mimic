//
//  AlbumView.swift
//  mimic
//
//  Created by honamiNAKASUJI on 2026/03/05.
//

import SwiftUI
import UIKit

struct AlbumView: View {
    @State private var groupedSessions: [PhotoSection] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                if groupedSessions.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 44))
                            .foregroundStyle(.secondary)
                        Text("まだ写真がありません")
                            .font(.headline)
                        Text("撮影するとここに表示されます")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 320)
                    .padding(.top, 40)
                } else {
                    let groupedByDay = groupSectionsByDay(groupedSessions)
                    LazyVStack(alignment: .leading, spacing: 22) {
                        ForEach(groupedByDay) { dayGroup in
                            Text(dayGroup.title)
                                .font(.headline)
                                .padding(.horizontal, 16)

                            VStack(spacing: 14) {
                                ForEach(dayGroup.sections) { section in
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        LazyHStack(spacing: 10) {
                                            ForEach(section.items) { item in
                                                NavigationLink(value: item) {
                                                    PhotoThumbnail(url: item.url)
                                                }
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Album")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(red: 1.0, green: 0.95, blue: 0.88))
            .onAppear {
                groupedSessions = loadGroupedSessions()
            }
            .navigationDestination(for: PhotoItem.self) { item in
                PhotoDetailView(item: item) { deletedUrl in
                    groupedSessions = removePhoto(url: deletedUrl, from: groupedSessions)
                }
            }
        }
    }
}

private struct PhotoItem: Identifiable, Hashable {
    let url: URL
    let date: Date
    let sessionId: String
    var id: String { url.path }
}

private struct PhotoSection: Identifiable {
    let date: Date
    let sessionId: String
    let items: [PhotoItem]
    let latestDate: Date

    var id: String { "\(sessionId)-\(date.timeIntervalSince1970)" }
    var title: String { DateFormatter.albumSection.string(from: date) }
}

private struct DayGroup: Identifiable {
    let date: Date
    let sections: [PhotoSection]

    var id: Date { date }
    var title: String { DateFormatter.albumSection.string(from: date) }
}

private struct PhotoThumbnail: View {
    let url: URL
    @ScaledMetric private var thumbnailSize: CGFloat = 96

    var body: some View {
        Group {
            if let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.black.opacity(0.1)
            }
        }
        .frame(width: thumbnailSize, height: thumbnailSize)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(.white.opacity(0.6), lineWidth: 2)
        )
    }
}

private struct PhotoDetailView: View {
    let item: PhotoItem
    let onDelete: (URL) -> Void
    @State private var sharePayload: AlbumSharePayload?
    @State private var showDeleteAlert = false
    @State private var zoomScale: CGFloat = 1.0
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.opacity(0.92).ignoresSafeArea()
            if let image = UIImage(contentsOfFile: item.url.path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(zoomScale)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                zoomScale = min(max(value, 1.0), 4.0)
                            }
                    )
                    .padding(16)
            } else {
                Text("画像を読み込めませんでした")
                    .foregroundStyle(.white)
            }
        }
        .navigationTitle(DateFormatter.albumDetail.string(from: item.date))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if let image = UIImage(contentsOfFile: item.url.path) {
                        sharePayload = AlbumSharePayload(items: [image])
                    } else {
                        sharePayload = AlbumSharePayload(items: [item.url])
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    showDeleteAlert = true
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
        .alert("写真を削除しますか？", isPresented: $showDeleteAlert) {
            Button("キャンセル", role: .cancel) {}
            Button("削除", role: .destructive) {
                try? FileManager.default.removeItem(at: item.url)
                onDelete(item.url)
                dismiss()
            }
        }
        .sheet(item: $sharePayload) { payload in
            AlbumActivityView(activityItems: payload.items)
        }
    }
}

private var gridColumns: [GridItem] {
    [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]
}

private func loadGroupedSessions() -> [PhotoSection] {
    guard let folder = try? AppPhotoStore.ensureFolder() else { return [] }
    guard let items = try? FileManager.default.contentsOfDirectory(
        at: folder,
        includingPropertiesForKeys: [.creationDateKey],
        options: [.skipsHiddenFiles]
    ) else { return [] }

    let photos: [PhotoItem] = items.compactMap { url in
        let date = (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date()
        let sessionId = extractSessionId(from: url) ?? ""
        return PhotoItem(url: url, date: date, sessionId: sessionId)
    }

    let sorted = photos.sorted { $0.date < $1.date }
    let sections = buildSections(from: sorted)
    return sections.sorted { $0.latestDate > $1.latestDate }
}

private func extractSessionId(from url: URL) -> String? {
    let name = url.deletingPathExtension().lastPathComponent
    let parts = name.split(separator: "_")
    guard parts.count >= 3, parts.first == "mimic" else { return nil }
    return String(parts[1])
}

private func buildSections(from photos: [PhotoItem]) -> [PhotoSection] {
    var sections: [PhotoSection] = []
    var currentItems: [PhotoItem] = []
    var currentSessionId: String?
    var currentLatest: Date?

    let gapThreshold: TimeInterval = 30 * 60

    func flush() {
        guard let first = currentItems.first else { return }
        let day = Calendar.current.startOfDay(for: first.date)
        let latest = currentLatest ?? first.date
        let sessionId = currentSessionId ?? "legacy-\(Int(day.timeIntervalSince1970))-\(Int(latest.timeIntervalSince1970))"
        let sortedItems = currentItems.sorted { $0.date < $1.date }
        sections.append(PhotoSection(date: day, sessionId: sessionId, items: sortedItems, latestDate: latest))
        currentItems = []
        currentSessionId = nil
        currentLatest = nil
    }

    for item in photos {
        if currentItems.isEmpty {
            currentItems = [item]
            currentSessionId = item.sessionId.isEmpty ? nil : item.sessionId
            currentLatest = item.date
            continue
        }

        let prev = currentItems.last!
        let sameSessionId = !item.sessionId.isEmpty && item.sessionId == currentSessionId
        let hasSessionId = !item.sessionId.isEmpty

        if hasSessionId {
            if sameSessionId {
                currentItems.append(item)
                currentLatest = item.date
            } else {
                flush()
                currentItems = [item]
                currentSessionId = item.sessionId
                currentLatest = item.date
            }
        } else {
            let gap = item.date.timeIntervalSince(prev.date)
            if gap <= gapThreshold && (currentSessionId == nil) {
                currentItems.append(item)
                currentLatest = item.date
            } else {
                flush()
                currentItems = [item]
                currentSessionId = nil
                currentLatest = item.date
            }
        }
    }
    flush()
    return sections
}

private func groupSectionsByDay(_ sections: [PhotoSection]) -> [DayGroup] {
    let grouped = Dictionary(grouping: sections) { Calendar.current.startOfDay(for: $0.date) }
    let dayGroups = grouped.map { (day, value) in
        DayGroup(date: day, sections: value.sorted { $0.latestDate > $1.latestDate })
    }
    return dayGroups.sorted { $0.date > $1.date }
}

private func removePhoto(url: URL, from sections: [PhotoSection]) -> [PhotoSection] {
    let updated = sections.compactMap { section -> PhotoSection? in
        let items = section.items.filter { $0.url != url }
        if items.isEmpty { return nil }
        let latest = items.map(\.date).max() ?? section.latestDate
        return PhotoSection(date: section.date, sessionId: section.sessionId, items: items, latestDate: latest)
    }
    return updated
}

private struct AlbumSharePayload: Identifiable {
    let id = UUID()
    let items: [Any]
}

private struct AlbumActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private extension DateFormatter {
    static let albumSection: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter
    }()

    static let albumDetail: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter
    }()
}
