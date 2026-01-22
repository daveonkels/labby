import SwiftUI
import SwiftData
import PhotosUI
import ImagePlayground

struct BackgroundSettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.supportsImagePlayground) private var supportsImagePlayground
    @Query private var allSettings: [AppSettings]

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showingImagePlayground = false
    @State private var isProcessingImage = false

    private var settings: AppSettings {
        if let existing = allSettings.first {
            return existing
        }
        // Create default settings if none exist
        let newSettings = AppSettings()
        modelContext.insert(newSettings)
        try? modelContext.save()
        return newSettings
    }

    var body: some View {
        List {
            // Preview Section
            Section {
                BackgroundPreview(settings: settings)
                    .frame(height: 200)
                    .listRowInsets(EdgeInsets())
            } header: {
                RetroSectionHeader("Preview", icon: "eye")
            }

            // Current Selection
            Section {
                HStack {
                    Label(backgroundTypeLabel, systemImage: backgroundTypeIcon)
                    Spacer()
                    if settings.backgroundType != .gradient || settings.gradientPreset != .default {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(LabbyColors.primary(for: colorScheme))
                    }
                }
            } header: {
                RetroSectionHeader("Current Background", icon: "checkmark.circle")
            }

            // Gradient Presets Section
            Section {
                GradientPresetGrid(
                    selectedPreset: settings.backgroundType == .gradient ? settings.gradientPreset : nil,
                    onSelect: { preset in
                        withAnimation {
                            settings.setGradientPreset(preset)
                            try? modelContext.save()
                        }
                    }
                )
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
            } header: {
                RetroSectionHeader("Gradients", icon: "circle.lefthalf.filled")
            }

            // Intensity Section
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Background Intensity")
                        Spacer()
                        Text("\(Int(settings.backgroundIntensity * 100))%")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

                    Slider(
                        value: Binding(
                            get: { settings.backgroundIntensity },
                            set: { newValue in
                                settings.backgroundIntensity = newValue
                                try? modelContext.save()
                            }
                        ),
                        in: 0...1,
                        step: 0.05
                    )

                    HStack {
                        Text("Subtle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("Vibrant")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            } header: {
                RetroSectionHeader("Intensity", icon: "slider.horizontal.3")
            } footer: {
                Text("Adjusts how visible the background appears behind the dashboard content.")
            }

            // Options Section
            Section {
                // Photo Library Option
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label("Choose from Photos", systemImage: "photo.on.rectangle")
                }
                .disabled(isProcessingImage)

                // AI Generation Option (only available on devices with Apple Intelligence)
                if supportsImagePlayground {
                    Button {
                        showingImagePlayground = true
                    } label: {
                        Label("Generate with AI", systemImage: "wand.and.stars")
                    }
                    .disabled(isProcessingImage)
                }

                // Reset Option
                if settings.backgroundType != .gradient {
                    Button(role: .destructive) {
                        withAnimation {
                            settings.resetToDefault()
                            try? modelContext.save()
                        }
                    } label: {
                        Label("Reset to Default", systemImage: "arrow.counterclockwise")
                    }
                }
            } header: {
                RetroSectionHeader("Options", icon: "ellipsis.circle")
            } footer: {
                Text("Custom backgrounds will be displayed behind your dashboard with a subtle overlay for readability.")
            }
        }
        .navigationTitle("Dashboard Background")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedPhoto) { _, newValue in
            if let newValue {
                Task {
                    await loadPhoto(from: newValue)
                }
            }
        }
        .imagePlaygroundSheet(
            isPresented: supportsImagePlayground ? $showingImagePlayground : .constant(false)
        ) { url in
            Task {
                await loadGeneratedImage(from: url)
            }
        }
        .overlay {
            if isProcessingImage {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .overlay {
                        ProgressView("Processing...")
                            .padding()
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
            }
        }
    }

    private var backgroundTypeLabel: String {
        switch settings.backgroundType {
        case .gradient:
            return "\(settings.gradientPreset.displayName) Gradient"
        case .customImage:
            return "Custom Photo"
        case .aiGenerated:
            return "AI Generated"
        }
    }

    private var backgroundTypeIcon: String {
        switch settings.backgroundType {
        case .gradient:
            return "circle.lefthalf.filled"
        case .customImage:
            return "photo"
        case .aiGenerated:
            return "sparkles"
        }
    }

    @MainActor
    private func loadPhoto(from item: PhotosPickerItem) async {
        isProcessingImage = true
        defer {
            isProcessingImage = false
            selectedPhoto = nil
        }

        guard let data = try? await item.loadTransferable(type: Data.self) else {
            return
        }

        // Resize image to reasonable size for background
        if let resizedData = resizeImageData(data, maxDimension: 1920) {
            settings.setCustomImage(resizedData, type: .customImage)
            try? modelContext.save()
        }
    }

    @MainActor
    private func loadGeneratedImage(from url: URL) async {
        isProcessingImage = true
        defer { isProcessingImage = false }

        guard let data = try? Data(contentsOf: url) else {
            return
        }

        settings.setCustomImage(data, type: .aiGenerated)
        try? modelContext.save()
    }

    private func resizeImageData(_ data: Data, maxDimension: CGFloat) -> Data? {
        guard let uiImage = UIImage(data: data) else { return data }

        let size = uiImage.size
        let maxSide = max(size.width, size.height)

        guard maxSide > maxDimension else { return data }

        let scale = maxDimension / maxSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resizedImage = renderer.image { _ in
            uiImage.draw(in: CGRect(origin: .zero, size: newSize))
        }

        return resizedImage.jpegData(compressionQuality: 0.8)
    }
}

// MARK: - Background Preview

struct BackgroundPreview: View {
    @Environment(\.colorScheme) private var colorScheme
    let settings: AppSettings

    private var imageOverlayOpacity: Double {
        let baseOpacity = colorScheme == .dark ? 0.85 : 0.9
        return baseOpacity - (settings.backgroundIntensity * 0.5)
    }

    var body: some View {
        ZStack {
            if let imageData = settings.backgroundImage,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipped()

                // Overlay for readability preview
                Color(.systemGroupedBackground)
                    .opacity(imageOverlayOpacity)
            } else {
                // Gradient preview based on selected preset
                GradientBackgroundPreview(preset: settings.gradientPreset, intensity: settings.backgroundIntensity)
            }

            // Sample content overlay
            VStack {
                Text("Dashboard")
                    .retroStyle(.largeTitle, weight: .black)
                    .foregroundStyle(.primary)

                HStack(spacing: 12) {
                    PreviewCard()
                    PreviewCard()
                }
            }
            .padding()
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct GradientBackgroundPreview: View {
    var preset: GradientPreset = .default
    var intensity: Double = 0.5

    @Environment(\.colorScheme) private var colorScheme

    private var primaryColor: Color {
        LabbyColors.primary(for: colorScheme)
    }

    private var opacityScale: Double {
        0.4 + (intensity * 1.2)
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)

            if preset == .default {
                GeometryReader { geo in
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [primaryColor.opacity(0.15 * opacityScale), Color.clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: geo.size.width * 0.4
                            )
                        )
                        .frame(width: geo.size.width * 0.6)
                        .position(x: geo.size.width * 0.85, y: geo.size.height * 0.2)
                        .blur(radius: 30)

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [primaryColor.opacity(0.1 * opacityScale), Color.clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: geo.size.width * 0.3
                            )
                        )
                        .frame(width: geo.size.width * 0.5)
                        .position(x: geo.size.width * 0.15, y: geo.size.height * 0.8)
                        .blur(radius: 25)
                }
                .drawingGroup() // Rasterize to prevent expensive blur recalculation
            } else if preset.isRadial {
                RadialGradient(
                    colors: preset.colors.map { $0.opacity(0.3 * opacityScale) } + [Color.clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: 300
                )
            } else {
                LinearGradient(
                    colors: preset.colors.map { $0.opacity(0.4 * opacityScale) },
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }
}

struct PreviewCard: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(.ultraThinMaterial)
            .frame(width: 80, height: 80)
            .overlay {
                VStack(spacing: 4) {
                    Circle()
                        .fill(.secondary.opacity(0.3))
                        .frame(width: 30, height: 30)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.secondary.opacity(0.3))
                        .frame(width: 50, height: 8)
                }
            }
    }
}

// MARK: - Gradient Preset Grid

struct GradientPresetGrid: View {
    let selectedPreset: GradientPreset?
    let onSelect: (GradientPreset) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(GradientPreset.allCases, id: \.self) { preset in
                GradientPresetButton(
                    preset: preset,
                    isSelected: selectedPreset == preset,
                    action: { onSelect(preset) }
                )
            }
        }
    }
}

struct GradientPresetButton: View {
    let preset: GradientPreset
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            ZStack {
                GradientPresetThumbnail(preset: preset)
                    .frame(height: 70)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(isSelected ? LabbyColors.primary(for: colorScheme) : Color.clear, lineWidth: 3)
                    }

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                }
            }
            .overlay(alignment: .bottom) {
                Text(preset.displayName)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                    .frame(maxWidth: .infinity)
                    .offset(y: 20)
            }
            .padding(.bottom, 16)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(preset.displayName) gradient")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct GradientPresetThumbnail: View {
    let preset: GradientPreset

    @Environment(\.colorScheme) private var colorScheme

    private var primaryColor: Color {
        LabbyColors.primary(for: colorScheme)
    }

    var body: some View {
        if preset == .default {
            // Special handling for default orb style
            ZStack {
                Color(.systemGroupedBackground)

                GeometryReader { geo in
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [primaryColor.opacity(0.3), Color.clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: geo.size.width * 0.4
                            )
                        )
                        .frame(width: geo.size.width * 0.6)
                        .position(x: geo.size.width * 0.75, y: geo.size.height * 0.3)
                        .blur(radius: 8)

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [primaryColor.opacity(0.25), Color.clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: geo.size.width * 0.35
                            )
                        )
                        .frame(width: geo.size.width * 0.5)
                        .position(x: geo.size.width * 0.25, y: geo.size.height * 0.7)
                        .blur(radius: 6)
                }
            }
        } else if preset.isRadial {
            RadialGradient(
                colors: preset.colors.map { $0.opacity(0.8) },
                center: .center,
                startRadius: 0,
                endRadius: 100
            )
        } else {
            LinearGradient(
                colors: preset.colors.map { $0.opacity(0.9) },
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

#Preview {
    NavigationStack {
        BackgroundSettingsView()
    }
    .modelContainer(for: [AppSettings.self], inMemory: true)
}
