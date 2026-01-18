import SwiftUI

struct CategoryIconPicker: View {
    let categoryName: String
    let currentIcon: String
    let onSelect: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filteredSymbols: [(String, [String])] {
        if searchText.isEmpty {
            return Self.symbolCategories
        }
        let query = searchText.lowercased()
        return Self.symbolCategories.compactMap { category, symbols in
            let filtered = symbols.filter { $0.lowercased().contains(query) }
            return filtered.isEmpty ? nil : (category, filtered)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    ForEach(filteredSymbols, id: \.0) { category, symbols in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(category)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 20)

                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 56))], spacing: 12) {
                                ForEach(symbols, id: \.self) { symbol in
                                    SymbolButton(
                                        symbol: symbol,
                                        isSelected: symbol == currentIcon,
                                        action: {
                                            onSelect(symbol)
                                            dismiss()
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                }
                .padding(.vertical, 16)
            }
            .searchable(text: $searchText, prompt: "Search symbols")
            .navigationTitle("Icon for \(categoryName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Symbol Categories

    static let symbolCategories: [(String, [String])] = [
        ("Media & Entertainment", [
            "play.tv.fill",
            "tv.fill",
            "film.fill",
            "music.note",
            "music.note.list",
            "headphones",
            "hifispeaker.fill",
            "radio.fill",
            "gamecontroller.fill",
            "photo.fill",
            "camera.fill",
            "video.fill",
            "play.circle.fill",
            "play.rectangle.fill",
            "airplayvideo",
            "airplayaudio"
        ]),
        ("Network & Infrastructure", [
            "network",
            "wifi",
            "globe",
            "server.rack",
            "cpu.fill",
            "memorychip.fill",
            "externaldrive.fill",
            "internaldrive.fill",
            "opticaldiscdrive.fill",
            "antenna.radiowaves.left.and.right",
            "bolt.horizontal.fill",
            "cable.connector",
            "fibrechannel",
            "point.3.connected.trianglepath.dotted"
        ]),
        ("Downloads & Storage", [
            "arrow.down.circle.fill",
            "arrow.down.doc.fill",
            "square.and.arrow.down.fill",
            "icloud.and.arrow.down.fill",
            "folder.fill",
            "folder.badge.gearshape",
            "archivebox.fill",
            "tray.full.fill",
            "externaldrive.badge.plus",
            "doc.zipper"
        ]),
        ("Monitoring & Analytics", [
            "chart.bar.fill",
            "chart.line.uptrend.xyaxis",
            "chart.pie.fill",
            "gauge.with.dots.needle.bottom.50percent",
            "speedometer",
            "waveform.path.ecg",
            "heart.text.square.fill",
            "eye.fill",
            "binoculars.fill",
            "scope"
        ]),
        ("Automation & Tools", [
            "gearshape.fill",
            "gearshape.2.fill",
            "wrench.and.screwdriver.fill",
            "hammer.fill",
            "screwdriver.fill",
            "wrench.adjustable.fill",
            "theatermasks.fill",
            "wand.and.stars",
            "cpu",
            "terminal.fill"
        ]),
        ("Security & Privacy", [
            "lock.fill",
            "lock.shield.fill",
            "key.fill",
            "shield.fill",
            "shield.checkered",
            "checkmark.shield.fill",
            "hand.raised.fill",
            "eye.slash.fill",
            "faceid",
            "touchid"
        ]),
        ("Productivity & Documents", [
            "doc.text.fill",
            "doc.richtext.fill",
            "doc.on.doc.fill",
            "list.bullet.rectangle.fill",
            "checklist",
            "calendar",
            "clock.fill",
            "bookmark.fill",
            "paperclip",
            "link"
        ]),
        ("Communication", [
            "bubble.left.and.bubble.right.fill",
            "message.fill",
            "envelope.fill",
            "phone.fill",
            "video.badge.waveform.fill",
            "person.2.fill",
            "bell.fill",
            "megaphone.fill"
        ]),
        ("Home & IoT", [
            "house.fill",
            "homekit",
            "lightbulb.fill",
            "fan.fill",
            "air.conditioner.horizontal.fill",
            "thermometer.medium",
            "drop.fill",
            "bolt.fill",
            "powerplug.fill",
            "ev.charger.fill"
        ]),
        ("Finance & Commerce", [
            "creditcard.fill",
            "banknote.fill",
            "dollarsign.circle.fill",
            "chart.line.uptrend.xyaxis.circle.fill",
            "bag.fill",
            "cart.fill",
            "storefront.fill",
            "building.columns.fill"
        ]),
        ("Development", [
            "chevron.left.forwardslash.chevron.right",
            "curlybraces",
            "terminal.fill",
            "apple.terminal.fill",
            "ladybug.fill",
            "ant.fill",
            "testtube.2",
            "flask.fill",
            "hammer.fill",
            "wrench.and.screwdriver"
        ]),
        ("General", [
            "square.grid.2x2.fill",
            "rectangle.grid.2x2.fill",
            "circle.grid.3x3.fill",
            "star.fill",
            "heart.fill",
            "flag.fill",
            "tag.fill",
            "pin.fill",
            "mappin.and.ellipse",
            "location.fill"
        ])
    ]
}

struct SymbolButton: View {
    let symbol: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title2)
                .frame(width: 56, height: 56)
                .foregroundStyle(isSelected ? .white : .primary)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.15))
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(symbol.replacingOccurrences(of: ".", with: " "))
    }
}

#Preview {
    CategoryIconPicker(
        categoryName: "Media",
        currentIcon: "play.tv.fill",
        onSelect: { _ in }
    )
}
