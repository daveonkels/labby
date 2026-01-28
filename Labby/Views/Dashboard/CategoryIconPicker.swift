import SwiftUI

struct CategoryIconPicker: View {
    let categoryName: String
    let currentIcon: String?
    let onSelect: (String?) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedTab: IconPickerTab = .symbols

    enum IconPickerTab: String, CaseIterable {
        case symbols = "Symbols"
        case emoji = "Emoji"
    }

    /// Special value indicating "no icon"
    static let noIconValue = ""

    /// Check if current icon is an emoji
    private var currentIconIsEmoji: Bool {
        currentIcon?.hasPrefix("emoji:") ?? false
    }

    /// Extract emoji name from current icon if it's an emoji
    private var currentEmojiName: String? {
        guard let icon = currentIcon, icon.hasPrefix("emoji:") else { return nil }
        return String(icon.dropFirst(6))
    }

    /// Current SF Symbol name (nil if current icon is emoji or no icon)
    private var currentSymbolName: String? {
        guard let icon = currentIcon, !icon.hasPrefix("emoji:") else { return nil }
        return icon
    }

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

    private var filteredEmojis: [(name: String, emojis: [(character: String, name: String)])] {
        Self.filteredEmojiCategories(query: searchText)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    // Tab picker
                    Picker("Icon Type", selection: $selectedTab) {
                        ForEach(IconPickerTab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)

                    // No Icon option at the top
                    if searchText.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Options")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 20)

                            HStack(spacing: 12) {
                                // No Icon button
                                Button {
                                    onSelect(nil)
                                    dismiss()
                                } label: {
                                    VStack(spacing: 8) {
                                        Image(systemName: "eye.slash")
                                            .font(.title2)
                                            .frame(width: 56, height: 56)
                                            .foregroundStyle(currentIcon == nil ? (colorScheme == .dark ? .black : .white) : .secondary)
                                            .background {
                                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                    .fill(currentIcon == nil ? LabbyColors.primary(for: colorScheme) : Color.secondary.opacity(0.15))
                                            }
                                        Text("No Icon")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .buttonStyle(.plain)

                                Spacer()
                            }
                            .padding(.horizontal, 16)
                        }
                    }

                    // Content based on selected tab
                    if selectedTab == .symbols {
                        symbolsContent
                    } else {
                        emojisContent
                    }
                }
                .padding(.vertical, 16)
            }
            .searchable(text: $searchText, prompt: selectedTab == .symbols ? "Search symbols" : "Search emoji")
            .navigationTitle("Icon for \(categoryName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                // Auto-select emoji tab if current icon is emoji
                if currentIconIsEmoji {
                    selectedTab = .emoji
                }
            }
        }
    }

    // MARK: - Symbols Content

    @ViewBuilder
    private var symbolsContent: some View {
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
                            isSelected: symbol == currentSymbolName,
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

    // MARK: - Emojis Content

    @ViewBuilder
    private var emojisContent: some View {
        ForEach(filteredEmojis, id: \.name) { category in
            VStack(alignment: .leading, spacing: 12) {
                Text(category.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 56))], spacing: 12) {
                    ForEach(category.emojis, id: \.name) { emoji in
                        EmojiButton(
                            character: emoji.character,
                            name: emoji.name,
                            isSelected: emoji.name == currentEmojiName,
                            action: {
                                onSelect("emoji:\(emoji.name)")
                                dismiss()
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Emoji Categories

    static let emojiCategories: [(name: String, emojis: [(character: String, name: String)])] = [
        ("Smileys", [
            ("😀", "grinning"), ("😊", "smile"), ("😎", "cool"), ("🤓", "nerd"),
            ("🤖", "robot"), ("👻", "ghost"), ("💀", "skull"), ("👽", "alien"),
            ("🎃", "pumpkin"), ("😈", "devil")
        ]),
        ("Gestures", [
            ("👍", "thumbsup"), ("👎", "thumbsdown"), ("👋", "wave"), ("🤝", "handshake"),
            ("👏", "clap"), ("🙌", "celebrate"), ("💪", "muscle"), ("🤞", "fingers_crossed"),
            ("✌️", "peace"), ("🤙", "call_me")
        ]),
        ("Animals", [
            ("🐶", "dog"), ("🐱", "cat"), ("🐭", "mouse"), ("🐰", "rabbit"),
            ("🦊", "fox"), ("🐻", "bear"), ("🐼", "panda"), ("🦁", "lion"),
            ("🐸", "frog"), ("🦄", "unicorn"), ("🐝", "bee"), ("🦋", "butterfly")
        ]),
        ("Nature", [
            ("🌸", "cherry_blossom"), ("🌻", "sunflower"), ("🌲", "evergreen"), ("🌴", "palm_tree"),
            ("🍀", "four_leaf_clover"), ("🌈", "rainbow"), ("⭐", "star"), ("🌙", "moon"),
            ("☀️", "sun"), ("🔥", "fire"), ("💧", "droplet"), ("❄️", "snowflake")
        ]),
        ("Food & Drink", [
            ("🍎", "apple"), ("🍕", "pizza"), ("🍔", "burger"), ("🍟", "fries"),
            ("🌮", "taco"), ("🍩", "donut"), ("🍪", "cookie"), ("🎂", "cake"),
            ("☕", "coffee"), ("🍺", "beer"), ("🍷", "wine"), ("🧃", "juice_box")
        ]),
        ("Activities", [
            ("⚽", "soccer"), ("🏀", "basketball"), ("🎮", "video_game"), ("🎯", "target"),
            ("🎨", "art"), ("🎬", "movie"), ("🎤", "microphone"), ("🎧", "headphones"),
            ("🎸", "guitar"), ("🎹", "piano"), ("🏆", "trophy"), ("🎪", "circus")
        ]),
        ("Travel", [
            ("🚀", "rocket"), ("✈️", "airplane"), ("🚗", "car"), ("🚕", "taxi"),
            ("🚌", "bus"), ("🚂", "train"), ("🛸", "ufo"), ("⛵", "sailboat"),
            ("🏠", "house"), ("🏢", "office"), ("🏥", "hospital"), ("🏫", "school")
        ]),
        ("Objects", [
            ("💻", "laptop"), ("🖥️", "desktop"), ("📱", "phone"), ("⌚", "watch"),
            ("📷", "camera"), ("💡", "lightbulb"), ("🔋", "battery"), ("🔌", "plug"),
            ("📦", "package"), ("🗄️", "file_cabinet"), ("📚", "books"), ("✏️", "pencil")
        ]),
        ("Tools", [
            ("🔧", "wrench"), ("🔨", "hammer"), ("⚙️", "gear"), ("🔩", "nut_and_bolt"),
            ("🛠️", "tools"), ("⛏️", "pick"), ("🔑", "key"), ("🔒", "lock"),
            ("🔓", "unlock"), ("🧲", "magnet"), ("🧪", "test_tube"), ("🔬", "microscope")
        ]),
        ("Symbols", [
            ("❤️", "heart"), ("💜", "purple_heart"), ("💙", "blue_heart"), ("💚", "green_heart"),
            ("⚡", "lightning"), ("💥", "boom"), ("✨", "sparkles"), ("🎵", "music"),
            ("💬", "speech"), ("💭", "thought"), ("✅", "check"), ("❌", "cross"),
            ("⚠️", "warning"), ("🚫", "prohibited"), ("♻️", "recycle"), ("🔄", "refresh")
        ])
    ]

    /// Look up emoji character by name
    static func emoji(for name: String) -> String? {
        for category in emojiCategories {
            if let emoji = category.emojis.first(where: { $0.name == name }) {
                return emoji.character
            }
        }
        return nil
    }

    /// Filter emoji categories by search query
    static func filteredEmojiCategories(query: String) -> [(name: String, emojis: [(character: String, name: String)])] {
        if query.isEmpty {
            return emojiCategories
        }
        let lowercased = query.lowercased()
        return emojiCategories.compactMap { category in
            let filtered = category.emojis.filter { $0.name.lowercased().contains(lowercased) }
            return filtered.isEmpty ? nil : (category.name, filtered)
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

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title2)
                .frame(width: 56, height: 56)
                .foregroundStyle(isSelected ? (colorScheme == .dark ? .black : .white) : .primary)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isSelected ? LabbyColors.primary(for: colorScheme) : Color.secondary.opacity(0.15))
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(symbol.replacingOccurrences(of: ".", with: " "))
    }
}

struct EmojiButton: View {
    let character: String
    let name: String
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            Text(character)
                .font(.system(size: 28))
                .frame(width: 56, height: 56)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isSelected ? LabbyColors.primary(for: colorScheme) : Color.secondary.opacity(0.15))
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name.replacingOccurrences(of: "_", with: " "))
    }
}

#Preview {
    CategoryIconPicker(
        categoryName: "Media",
        currentIcon: "play.tv.fill",
        onSelect: { _ in }
    )
}
