import SwiftUI
import SwiftData
import PhotosUI
import ImagePlayground

struct BackgroundSettingsView: View {
    @Environment(\.modelContext) private var modelContext
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
                Text("Preview")
            }

            // Current Selection
            Section {
                HStack {
                    Label(backgroundTypeLabel, systemImage: backgroundTypeIcon)
                    Spacer()
                    if settings.backgroundType != .gradient {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
            } header: {
                Text("Current Background")
            }

            // Options Section
            Section {
                // Photo Library Option
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label("Choose from Photos", systemImage: "photo.on.rectangle")
                }
                .disabled(isProcessingImage)

                // AI Generation Option
                Button {
                    showingImagePlayground = true
                } label: {
                    Label("Generate with AI", systemImage: "wand.and.stars")
                }
                .disabled(isProcessingImage)

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
                Text("Options")
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
        .imagePlaygroundSheet(isPresented: $showingImagePlayground) { url in
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
            return "Default Gradient"
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
    let settings: AppSettings

    var body: some View {
        ZStack {
            if let imageData = settings.backgroundImage,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipped()

                // Overlay for readability preview
                Color.black.opacity(0.1)
            } else {
                // Default gradient preview
                GradientBackgroundPreview()
            }

            // Sample content overlay
            VStack {
                Text("Dashboard")
                    .font(.largeTitle.bold())
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
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)

            GeometryReader { geo in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.green.opacity(0.15), Color.clear],
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
                            colors: [Color.blue.opacity(0.1), Color.clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: geo.size.width * 0.3
                        )
                    )
                    .frame(width: geo.size.width * 0.5)
                    .position(x: geo.size.width * 0.15, y: geo.size.height * 0.8)
                    .blur(radius: 25)
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

#Preview {
    NavigationStack {
        BackgroundSettingsView()
    }
    .modelContainer(for: [AppSettings.self], inMemory: true)
}
