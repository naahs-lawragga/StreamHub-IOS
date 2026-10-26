import SwiftUI
import UIKit

/// A guide to TMDB's own account settings. StreamHub never handles the account password.
struct TMDBTutorialView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step = 0
    @AccessibilityFocusState private var headingFocused: Bool

    private let titles = ["Start with your TMDB account", "Open your API settings", "Tell TMDB about StreamHub", "Copy your read access token", "Connect and start exploring"]
    private let symbols = ["person.crop.circle.badge.checkmark", "key.horizontal.fill", "app.badge.fill", "doc.on.clipboard.fill", "play.rectangle.on.rectangle.fill"]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    illustration.id("top")
                    progress
                    Text(titles[step])
                        .font(.largeTitle.bold())
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityFocused($headingFocused)
                    stepContent
                    help
                }
                .padding(22)
                .frame(maxWidth: 620, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .onChange(of: step) { _, _ in
                proxy.scrollTo("top", anchor: .top)
                headingFocused = true
            }
        }
        .background(Brand.background)
        .navigationTitle("Connect TMDB")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { controls }
    }

    private var illustration: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26)
                .fill(LinearGradient(colors: [Brand.red.opacity(0.28), Brand.surface], startPoint: .topLeading, endPoint: .bottomTrailing))
            HStack(spacing: 18) {
                Image(systemName: symbols[step])
                    .font(.system(size: 42, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 78, height: 78)
                    .background(Brand.red.opacity(0.32), in: RoundedRectangle(cornerRadius: 22))
                VStack(alignment: .leading, spacing: 7) {
                    Text("YOUR STORIES.\nYOUR CONNECTION.")
                        .font(.headline.weight(.heavy))
                    Text("A quick setup guide")
                        .font(.subheadline).foregroundStyle(.white.opacity(0.75))
                }
                Spacer(minLength: 0)
            }.padding(22)
        }
        .frame(minHeight: 142)
        .accessibilityHidden(true)
    }

    private var progress: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("STEP \(step + 1) OF \(titles.count)")
                .font(.caption.bold()).tracking(1.5).foregroundStyle(Brand.red)
            ProgressView(value: Double(step + 1), total: Double(titles.count)).tint(Brand.red)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(step + 1) of \(titles.count)")
    }

    @ViewBuilder private var stepContent: some View {
        switch step {
        case 0: accountStep
        case 1: apiStep
        case 2: applicationStep
        case 3: tokenStep
        default: connectStep
        }
    }

    private var accountStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("TMDB supplies the movie information, TV details, posters, and search results in StreamHub. Create an account on TMDB, or sign in to one you already have.")
            instruction("1", "Open TMDB in Safari and create your account.")
            instruction("2", "Complete any email verification that TMDB requests.")
            instruction("3", "Keep this guide open in StreamHub so you can return after each step.")
            websiteLink("Create a TMDB account", "https://www.themoviedb.org/signup")
            websiteLink("Already have an account? Sign in", "https://www.themoviedb.org/login")
            note("Your password belongs on TMDB’s website. StreamHub only needs the read access token you will obtain later.", symbol: "lock.shield")
        }
    }

    private var apiStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("While signed in, open your account’s API settings. If you already have API access, you can go straight to the token step.")
            instruction("1", "Open the API page in your TMDB account settings.")
            instruction("2", "Choose the option to request API access. For a personal, noncommercial project, choose the Developer option if it is offered.")
            instruction("3", "Read TMDB’s terms and agree only if your intended use meets them. TMDB controls access and may ask for additional information.")
            websiteLink("Open TMDB API settings", "https://www.themoviedb.org/settings/api")
            note("On iPhone, try Safari’s page menu → Request Desktop Website if the registration form is missing or difficult to use. TMDB recommends a desktop computer and browser for API registration.", symbol: "desktopcomputer")
            Button("I already have API access") { move(to: 3) }
                .font(.subheadline.bold())
        }
    }

    private var applicationStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Use these project details when TMDB asks about your application. Copy each value into the matching field, and provide your own accurate contact details wherever required.")
            TMDBCopyField(label: "Application name", value: "StreamHub")
            TMDBCopyField(label: "Application URL", value: "https://github.com/naahs-lawragga/StreamHub-IOS")
            TMDBCopyField(label: "Application summary", value: "StreamHub is a free, open-source iOS application for personal, noncommercial movie and television discovery. It uses TMDB metadata and artwork for search, title details, and a local watchlist, with TMDB attribution. It does not host movies or bypass provider restrictions.")
            note("If the form asks for an application type, choose Mobile Application when available. Field names may change. If your use is commercial, follow TMDB’s commercial licensing process instead.", symbol: "iphone")
            Text("Submit the form on TMDB and follow any instructions it gives you. Continue once your API settings show the credentials.")
                .foregroundStyle(.secondary)
        }
    }

    private var tokenStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("In TMDB’s API settings, find the credential labeled API Read Access Token and copy its complete value.")
            credentialCard("Use this", value: "API Read Access Token", symbol: "checkmark.circle.fill", color: .green)
            credentialCard("A different credential", value: "API Key (v3 auth)", symbol: "minus.circle", color: .secondary)
            Text("StreamHub’s connection field expects the read access token. The shorter API key is a separate credential and will not work in that field.")
            instruction("1", "Copy the entire API Read Access Token from TMDB.")
            instruction("2", "Return to StreamHub without sharing or posting the token.")
            instruction("3", "Paste just the token: do not add quotation marks or the word Bearer.")
            websiteLink("Return to API settings", "https://www.themoviedb.org/settings/api")
            note("Your token is a credential. Keep it out of screenshots, GitHub issues, public repositories, and chat messages.", symbol: "hand.raised.fill")
        }
    }

    private var connectStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("You are ready to connect. Tap Enter My Token below to return to the connection screen.")
            instruction("1", "Paste the complete read access token into the secure TMDB API Read Access Token field.")
            instruction("2", "Tap Save token. StreamHub stores it in this device’s Keychain.")
            instruction("3", "Open Home or Search to load titles. You can replace or remove the token in Settings → TMDB connection.")
            note("The token is sent to TMDB for metadata requests. StreamHub does not read the clipboard automatically or need your TMDB password.", symbol: "checkmark.shield.fill")
            Text("If connection fails")
                .font(.headline).accessibilityAddTraits(.isHeader)
            Text("Check your connection and confirm you copied the API Read Access Token, with no extra text. If TMDB reports it as invalid, copy it again from your API settings and replace the saved value. Follow TMDB’s instructions if the token has been revoked or access is pending.")
                .foregroundStyle(.secondary)
        }
    }

    private var help: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
            Text("Official guidance").font(.caption.bold()).foregroundStyle(.secondary)
            websiteLink("TMDB getting started guide", "https://developer.themoviedb.org/docs/getting-started")
            websiteLink("About API Read Access Tokens", "https://developer.themoviedb.org/docs/authentication-application")
        }.font(.subheadline)
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button("Back") { move(to: step - 1) }
                .buttonStyle(.bordered).tint(.white).disabled(step == 0)
            Button {
                if step == titles.count - 1 { dismiss() }
                else { move(to: step + 1) }
            } label: {
                Text(step == titles.count - 1 ? "Enter My Token" : "Continue")
                    .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent).tint(Brand.red)
        }
        .padding(.horizontal, 22).padding(.vertical, 14)
        .background(.ultraThinMaterial)
    }

    private func move(to value: Int) {
        let next = max(0, min(value, titles.count - 1))
        if reduceMotion { step = next }
        else { withAnimation(.easeInOut(duration: 0.2)) { step = next } }
    }

    private func instruction(_ number: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number).font(.subheadline.bold()).foregroundStyle(Brand.red)
                .frame(width: 26, height: 26).background(Brand.red.opacity(0.12), in: Circle())
            Text(text).fixedSize(horizontal: false, vertical: true)
        }.accessibilityElement(children: .combine)
    }

    private func note(_ text: String, symbol: String) -> some View {
        Label {
            Text(text).font(.subheadline).fixedSize(horizontal: false, vertical: true)
        } icon: { Image(systemName: symbol).foregroundStyle(Brand.red) }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(Brand.surface, in: RoundedRectangle(cornerRadius: 16))
    }

    private func websiteLink(_ title: String, _ address: String) -> some View {
        Link(destination: URL(string: address)!) {
            Label(title, systemImage: "arrow.up.right.square").frame(minHeight: 32, alignment: .leading)
        }
    }

    private func credentialCard(_ heading: String, value: String, symbol: String, color: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol).font(.title2).foregroundStyle(color)
            VStack(alignment: .leading, spacing: 5) {
                Text(heading).font(.caption).foregroundStyle(.secondary)
                Text(value).font(.headline)
            }
            Spacer(minLength: 0)
        }.padding(16).background(Brand.surface, in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct TMDBCopyField: View {
    let label: String
    let value: String
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label).font(.caption.bold()).foregroundStyle(.secondary)
            Text(value).font(.subheadline).textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                // Only user-requested, nonsecret form text is placed on the clipboard.
                UIPasteboard.general.string = value
                copied = true
            } label: {
                Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                    .font(.subheadline.bold())
            }
            .accessibilityLabel(copied ? "Copied \(label)" : "Copy \(label)")
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(Brand.surface, in: RoundedRectangle(cornerRadius: 16))
    }
}
