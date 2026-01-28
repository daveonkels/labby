import SwiftUI
import SwiftData

struct ConnectionSetupView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// Connection to edit, or nil for creating a new connection
    var connection: HomepageConnection?

    @State private var name = "My Homepage"
    @State private var urlString = ""
    @State private var trustSelfSignedCerts = true
    @State private var username = ""
    @State private var password = ""
    @State private var showAuthFields = false
    @State private var isValidating = false
    @State private var validationError: String?
    @State private var isValid = false
    @State private var showingHomepageInfo = false

    private var isEditing: Bool { connection != nil }
    private var hasCredentials: Bool { !username.isEmpty && !password.isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                // What is Homepage? - expandable info section
                Section {
                    DisclosureGroup(isExpanded: $showingHomepageInfo) {
                        HomepageInfoView()
                            .padding(.vertical, 8)
                    } label: {
                        Label("What is Homepage?", systemImage: "questionmark.circle")
                    }
                }

                Section {
                    TextField("Name", text: $name)
                        .textContentType(.name)

                    TextField("URL", text: $urlString)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: urlString) {
                            // Only reset validation if URL actually changed from original
                            if urlString != connection?.baseURLString {
                                isValid = false
                                validationError = nil
                            }
                        }
                } header: {
                    RetroSectionHeader("Connection Details", icon: "link")
                } footer: {
                    Text("Enter the URL of your Homepage instance (e.g., http://192.168.1.100:3000)")
                }

                Section {
                    Toggle("Trust Self-Signed Certificates", isOn: $trustSelfSignedCerts)
                } header: {
                    RetroSectionHeader("Security", icon: "lock.shield")
                } footer: {
                    Text("Enable this if your server uses a self-signed SSL certificate. Only affects connections to this server.")
                }

                Section {
                    Toggle("Requires Authentication", isOn: $showAuthFields)

                    if showAuthFields {
                        TextField("Username", text: $username)
                            .textContentType(.username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                        SecureField("Password", text: $password)
                            .textContentType(.password)
                    }
                } header: {
                    RetroSectionHeader("Authentication", icon: "person.badge.key")
                } footer: {
                    if showAuthFields {
                        Text("For auth proxies like TinyAuth, Authelia, or Authentik. Credentials are stored securely in your device's Keychain.")
                    } else {
                        Text("Enable if your Homepage is behind an authentication proxy.")
                    }
                }

                Section {
                    Button {
                        Task {
                            await validateConnection()
                        }
                    } label: {
                        HStack {
                            Text("Test Connection")

                            Spacer()

                            if isValidating {
                                ProgressView()
                            } else if isValid {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(LabbyColors.primary(for: colorScheme))
                            } else if validationError != nil {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                    .disabled(urlString.isEmpty || isValidating)

                    if let error = validationError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(isEditing ? "Edit Connection" : "Connect Homepage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveConnection()
                    }
                    .disabled(!isValid && !isEditing)
                }
            }
            .onAppear {
                if let connection {
                    name = connection.name
                    urlString = connection.baseURLString
                    trustSelfSignedCerts = connection.trustSelfSignedCertificates
                    isValid = true // Assume existing connection is valid

                    // Load authentication settings
                    if let existingUsername = connection.username, !existingUsername.isEmpty {
                        username = existingUsername
                        showAuthFields = true
                        // Load password from Keychain
                        if let existingPassword = KeychainManager.getPassword(for: connection.id) {
                            password = existingPassword
                        }
                    }
                }
            }
        }
    }

    private func validateConnection() async {
        isValidating = true
        validationError = nil
        isValid = false

        // Normalize URL
        var normalizedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalizedURL.hasPrefix("http://") && !normalizedURL.hasPrefix("https://") {
            normalizedURL = "http://" + normalizedURL
        }

        guard let url = URL(string: normalizedURL),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme) else {
            validationError = "Only HTTP and HTTPS URLs are supported"
            isValidating = false
            return
        }

        // Update the text field with normalized URL
        urlString = normalizedURL

        // Temporarily trust this host during validation if toggle is on
        if trustSelfSignedCerts, let host = url.host {
            TrustedDomainManager.shared.trustHost(host)
        }

        // Build request with optional authentication
        var request = URLRequest(url: url)
        if showAuthFields && hasCredentials {
            let authValue = KeychainManager.basicAuthHeaderValue(username: username, password: password)
            request.setValue(authValue, forHTTPHeaderField: "Authorization")
        }

        // Try to connect
        do {
            let (_, response) = try await LabbyURLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                if (200...299).contains(httpResponse.statusCode) {
                    isValid = true
                } else if httpResponse.statusCode == 401 {
                    if showAuthFields && hasCredentials {
                        validationError = "Authentication failed. Check your username and password."
                    } else {
                        validationError = "Server requires authentication. Enable authentication and enter credentials."
                    }
                } else if httpResponse.statusCode == 403 {
                    validationError = "Access forbidden. Check your credentials have permission to access this resource."
                } else {
                    validationError = "Server returned status \(httpResponse.statusCode)"
                }
            }
        } catch {
            validationError = "Could not connect: \(error.localizedDescription)"
        }

        isValidating = false
    }

    private func saveConnection() {
        if let existing = connection {
            // Update existing connection
            existing.name = name
            existing.baseURLString = urlString
            existing.trustSelfSignedCertificates = trustSelfSignedCerts

            // Update authentication
            if showAuthFields && hasCredentials {
                existing.username = username
                KeychainManager.savePassword(password, for: existing.id)
            } else {
                existing.username = nil
                KeychainManager.deletePassword(for: existing.id)
            }

            // Update trusted domains based on setting
            if let host = existing.baseURL?.host {
                if trustSelfSignedCerts {
                    TrustedDomainManager.shared.trustHost(host)
                } else {
                    TrustedDomainManager.shared.untrustHost(host)
                }
            }

            // Trigger sync after updating
            Task {
                await SyncManager.shared.syncConnection(existing, modelContext: modelContext)
            }
        } else {
            // Create new connection
            let newConnection = HomepageConnection(
                baseURLString: urlString,
                name: name,
                trustSelfSignedCertificates: trustSelfSignedCerts,
                username: showAuthFields && hasCredentials ? username : nil
            )

            // Save password to Keychain if authentication is enabled
            if showAuthFields && hasCredentials {
                KeychainManager.savePassword(password, for: newConnection.id)
            }

            // Register trusted domain if enabled
            if trustSelfSignedCerts, let host = newConnection.baseURL?.host {
                TrustedDomainManager.shared.trustHost(host)
            }

            modelContext.insert(newConnection)

            // Trigger sync after saving
            Task {
                await SyncManager.shared.syncConnection(newConnection, modelContext: modelContext)
            }
        }

        dismiss()
    }
}

struct AddServiceView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.selectedTab) private var selectedTab

    /// Service to edit, or nil for creating a new service
    var service: Service?

    /// Whether to show the Homepage sync hint (when opened from dashboard)
    var showHomepageHint: Bool = false

    @State private var name = ""
    @State private var urlString = ""
    @State private var category = ""
    @State private var iconSymbol = "app.fill"
    @State private var validationError: String?

    private var isEditing: Bool { service != nil }

    private let commonSymbols = [
        "app.fill", "play.tv", "film", "tv", "movieclapper",
        "house", "server.rack", "network", "cloud", "doc",
        "folder", "photo", "music.note", "gamecontroller",
        "chart.bar", "gear", "hammer", "wrench", "externaldrive.fill"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)

                    TextField("URL", text: $urlString)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: urlString) {
                            validationError = nil
                        }

                    if let error = validationError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    TextField("Category (optional)", text: $category)
                } header: {
                    RetroSectionHeader("Service Details", icon: "app.fill")
                }

                Section {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 12) {
                        ForEach(commonSymbols, id: \.self) { symbol in
                            Button {
                                iconSymbol = symbol
                            } label: {
                                Image(systemName: symbol)
                                    .font(.title2)
                                    .frame(width: 44, height: 44)
                                    .background(iconSymbol == symbol ? LabbyColors.primary(for: colorScheme).opacity(0.2) : Color.clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    RetroSectionHeader("Icon", icon: "star.fill")
                }

                // Homepage sync hint (only shown when adding from dashboard)
                if showHomepageHint && !isEditing {
                    Section {
                        Button {
                            dismiss()
                            selectedTab.wrappedValue = .settings
                        } label: {
                            HStack {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .foregroundStyle(LabbyColors.primary(for: colorScheme))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Sync with Homepage")
                                        .font(.subheadline.weight(.medium))
                                    Text("Automatically import services from your Homepage dashboard")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                    } header: {
                        RetroSectionHeader("Already have a dashboard?", icon: "link")
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(isEditing ? "Edit Service" : "Add Service")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveService()
                    }
                    .disabled(name.isEmpty || urlString.isEmpty)
                }
            }
            .onAppear {
                if let service {
                    name = service.name
                    urlString = service.urlString
                    category = service.category ?? ""
                    iconSymbol = service.iconSFSymbol ?? "app.fill"
                }
            }
        }
    }

    private func saveService() {
        // Normalize URL
        var normalizedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalizedURL.hasPrefix("http://") && !normalizedURL.hasPrefix("https://") {
            normalizedURL = "http://" + normalizedURL
        }

        // Validate URL scheme
        guard let url = URL(string: normalizedURL),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme) else {
            validationError = "Only HTTP and HTTPS URLs are supported"
            return
        }

        if let existing = service {
            // Update existing service
            let urlChanged = existing.urlString != normalizedURL
            existing.name = name
            existing.urlString = normalizedURL
            existing.iconSFSymbol = iconSymbol
            existing.category = category.isEmpty ? nil : category

            // Reset health check if URL changed
            if urlChanged {
                existing.isHealthy = nil
                existing.lastHealthCheck = nil
            }
        } else {
            // Create new service
            let newService = Service(
                name: name,
                urlString: normalizedURL,
                iconSFSymbol: iconSymbol,
                category: category.isEmpty ? nil : category,
                isManuallyAdded: true
            )
            modelContext.insert(newService)
        }

        dismiss()
    }
}

#Preview("Connection Setup") {
    ConnectionSetupView()
}

#Preview("Add Service") {
    AddServiceView()
        .modelContainer(for: Service.self, inMemory: true)
}
