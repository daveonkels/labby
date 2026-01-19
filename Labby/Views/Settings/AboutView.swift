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
                    url: URL(string: "https://labby.casa")!
                )
            }

            // Powered By section
            Section {
                LinkRow(
                    title: "Homepage",
                    icon: "square.grid.2x2",
                    url: URL(string: "https://gethomepage.dev")!
                )

                LinkRow(
                    title: "Homepage on GitHub",
                    icon: "chevron.left.forwardslash.chevron.right",
                    url: URL(string: "https://github.com/gethomepage/homepage")!
                )
            } header: {
                RetroSectionHeader("Powered By", icon: "bolt.fill")
            } footer: {
                Text("Labby syncs with Homepage, an open-source dashboard for self-hosted services.")
            }

            // Legal section
            Section {
                LinkRow(
                    title: "Terms of Service",
                    icon: "doc.text",
                    url: URL(string: "https://labby.casa/terms.html")!
                )

                LinkRow(
                    title: "Privacy Policy",
                    icon: "hand.raised",
                    url: URL(string: "https://labby.casa/privacy.html")!
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
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                    Text("© \(copyrightYears) Dave Onkels. All Rights Reserved.")
                        .font(.footnote)
                    Image("AboutAppIcon")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 13.5))
                        .padding(.top, 12)
                    Text("Dedicated to Mugzy")
                        .italic()
                        .font(.footnote)
                        .padding(.top, 8)
                }
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
                        .retroStyle(.headline, weight: .semibold)

                    Text("MIT License")
                        .retroStyle(.subheadline, weight: .medium)
                        .foregroundStyle(.secondary)

                    Text("A pure Swift HTML Parser, with best of DOM, CSS, and jQuery. Used for parsing Homepage configuration.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            } header: {
                RetroSectionHeader("Open Source Libraries", icon: "chevron.left.forwardslash.chevron.right")
            }

            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Dashboard Icons")
                        .retroStyle(.headline, weight: .semibold)

                    Text("MIT License")
                        .retroStyle(.subheadline, weight: .medium)
                        .foregroundStyle(.secondary)

                    Text("Service icons provided by homarr-labs/dashboard-icons and selfhst/icons.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            } header: {
                RetroSectionHeader("Icon Sources", icon: "photo.stack")
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
