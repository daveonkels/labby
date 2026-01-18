import SwiftUI

struct AboutView: View {
    @Environment(\.openURL) private var openURL

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    private var copyrightYears: String {
        let currentYear = Calendar.current.component(.year, from: Date())
        if currentYear > 2026 {
            return "2026-\(currentYear)"
        }
        return "2026"
    }

    var body: some View {
        List {
            // Links section (no header)
            Section {
                LinkRow(
                    title: "Website",
                    icon: "globe",
                    url: URL(string: "https://homelabhub.app")!
                )
            }

            // Legal section
            Section {
                LinkRow(
                    title: "Terms of Service",
                    icon: "doc.text",
                    url: URL(string: "https://homelabhub.app/terms")!
                )

                LinkRow(
                    title: "Privacy Policy",
                    icon: "hand.raised",
                    url: URL(string: "https://homelabhub.app/privacy")!
                )

                NavigationLink {
                    LicensesView()
                } label: {
                    Label("Licenses", systemImage: "doc.on.doc")
                }
            }

            // Footer
            Section {
            } footer: {
                VStack(spacing: 4) {
                    Text("Version \(appVersion) (\(buildNumber))")
                    Text("© \(copyrightYears) Dave Onkels. All Rights Reserved.")
                    Image("AboutAppIcon")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 13.5))
                        .padding(.top, 12)
                    Text("Dedicated to Mugzy")
                        .italic()
                        .padding(.top, 8)
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.top, 24)
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct LinkRow: View {
    let title: String
    let icon: String
    let url: URL

    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            openURL(url)
        } label: {
            HStack {
                Label(title, systemImage: icon)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

struct LicensesView: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("SwiftSoup")
                        .font(.headline)

                    Text("MIT License")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("A pure Swift HTML Parser, with best of DOM, CSS, and jQuery. Used for parsing Homepage configuration.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            } header: {
                Text("Open Source Libraries")
            }

            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Dashboard Icons")
                        .font(.headline)

                    Text("MIT License")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("Service icons provided by homarr-labs/dashboard-icons and selfhst/icons.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            } header: {
                Text("Icon Sources")
            }
        }
        .navigationTitle("Licenses")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        AboutView()
    }
}
