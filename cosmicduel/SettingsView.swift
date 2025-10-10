import SwiftUI
import WebKit

struct SettingsView: View {
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var match: MatchState

    // Local handles
    @State private var showPrivacy = false
    @State private var privacyProgress: Double = 0.0
    @State private var privacyCanGoBack = false
    @State private var privacyCanGoForward = false
    @State private var privacyIsLoading = false

    // Rounds locals (устойчиво к "Publishing changes from within view updates")
    @State private var roundDurationLocal: Int = 0
    @State private var timeAttackDurationLocal: Int = 0

    // Single source of truth for the URL (edit later if needed)
    private let privacyURL = URL(string: "https://example.com/privacy")!

    var body: some View {
        List {
            Section(header: Text("Appearance")) {
                Picker("Theme", selection: Binding(
                    get: { theme.currentTheme },
                    set: { theme.setTheme($0) }
                )) {
                    Text("System").tag(ThemeManager.AppTheme.system)
                    Text("Light").tag(ThemeManager.AppTheme.light)
                    Text("Dark").tag(ThemeManager.AppTheme.dark)
                }
                .onChange(of: theme.currentTheme) { _ in Haptics.shared.selectionChanged() }
            }

            Section(header: Text("Controls & Feedback")) {
                Toggle(isOn: Binding(
                    get: { match.settings.hapticsEnabled },
                    set: { match.settings.setHapticsEnabled($0); Haptics.shared.selectionChanged() }
                )) {
                    Label("Haptics", systemImage: "waveform.path")
                }

                Toggle(isOn: Binding(
                    get: { match.settings.oneHitKOGlobal },
                    set: { match.settings.setOneHitKOGlobal($0); Haptics.shared.selectionChanged() }
                )) {
                    Label("One-hit KO (global)", systemImage: "flame.fill")
                }
                .tint(ColorTokens.accentRed.color)
                .help("For Sudden Death this is always ON regardless of this toggle.")
            }

            // MARK: - FIXED: Rounds (Stepper без прямого биндинга к ObservableObject)
//            Section(header: Text("Rounds")) {
//                // Round duration
//                Stepper(
//                    onIncrement: {
//                        let range = GameSettings.Limits.roundDurationRange
//                        let next = min(roundDurationLocal + 5, range.upperBound)
//                        if next != roundDurationLocal { roundDurationLocal = next }
//                    },
//                    onDecrement: {
//                        let range = GameSettings.Limits.roundDurationRange
//                        let next = max(roundDurationLocal - 5, range.lowerBound)
//                        if next != roundDurationLocal { roundDurationLocal = next }
//                    }
//                ) {
//                    HStack {
//                        Label("Round duration", systemImage: "timer")
//                        Spacer()
//                        Text("\(roundDurationLocal) s")
//                            .foregroundStyle(ColorTokens.textSecondary.color)
//                            .monospacedDigit()
//                    }
//                }
//                .onChange(of: roundDurationLocal) { newVal in
//                    let range = GameSettings.Limits.roundDurationRange
//                    let clamped = min(max(newVal, range.lowerBound), range.upperBound)
//                    // Записываем в settings асинхронно, чтобы выйти из фазы построения вью
//                    if clamped != match.settings.roundDurationSec {
//                        DispatchQueue.main.async {
//                            match.settings.setRoundDurationSec(clamped)
//                            Haptics.shared.selectionChanged()
//                        }
//                    }
//                }
//
//                // Time Attack duration
//                Stepper(
//                    onIncrement: {
//                        let range = GameSettings.Limits.timeAttackRange
//                        let next = min(timeAttackDurationLocal + 5, range.upperBound)
//                        if next != timeAttackDurationLocal { timeAttackDurationLocal = next }
//                    },
//                    onDecrement: {
//                        let range = GameSettings.Limits.timeAttackRange
//                        let next = max(timeAttackDurationLocal - 5, range.lowerBound)
//                        if next != timeAttackDurationLocal { timeAttackDurationLocal = next }
//                    }
//                ) {
//                    HStack {
//                        Label("Time Attack duration", systemImage: "hourglass")
//                        Spacer()
//                        Text("\(timeAttackDurationLocal) s")
//                            .foregroundStyle(ColorTokens.textSecondary.color)
//                            .monospacedDigit()
//                    }
//                }
//                .onChange(of: timeAttackDurationLocal) { newVal in
//                    let range = GameSettings.Limits.timeAttackRange
//                    let clamped = min(max(newVal, range.lowerBound), range.upperBound)
//                    DispatchQueue.main.async {
//                        if clamped != match.settings.timeAttackDurationSec {
//                            match.settings.setTimeAttackDurationSec(clamped)
//                            Haptics.shared.selectionChanged()
//                        }
//                    }
//                }
//            }

            Section {
                Button {
                    Haptics.shared.selectionChanged()
                    showPrivacy = true
                } label: {
                    Label("Privacy Policy", systemImage: "lock.shield.fill")
                }
            }

            Section {
                Button(role: .destructive) {
                    match.settings.resetToDefaults()
                    // синхронизуем локальные значения с дефолтами
                    roundDurationLocal = match.settings.roundDurationSec
                    timeAttackDurationLocal = match.settings.timeAttackDurationSec
                    Haptics.shared.warning()
                } label: {
                    Label("Reset to Defaults", systemImage: "arrow.uturn.backward")
                }
            } footer: {
                Text("Version 1.0")
                    .foregroundStyle(ColorTokens.textSecondary.color)
            }
        }
        .navigationTitle("Settings")
        .preferredColorScheme(theme.currentColorScheme)
        .sheet(isPresented: $showPrivacy) {
            PrivacySheet(
                privacyURL: privacyURL,
                progress: $privacyProgress,
                canGoBack: $privacyCanGoBack,
                canGoForward: $privacyCanGoForward,
                isLoading: $privacyIsLoading
            ) {
                Haptics.shared.selectionChanged()
                showPrivacy = false
            }
        }
        .onAppear {
            // первичная синхронизация локалов с настройками (и кламп в диапазон на всякий случай)
            let r = GameSettings.Limits.roundDurationRange
            roundDurationLocal = min(max(match.settings.roundDurationSec, r.lowerBound), r.upperBound)
            let t = GameSettings.Limits.timeAttackRange
            timeAttackDurationLocal = min(max(match.settings.timeAttackDurationSec, t.lowerBound), t.upperBound)
        }
    }
}

// MARK: - Privacy Sheet (modal in-app browser)
private struct PrivacySheet: View {
    let privacyURL: URL

    @Binding var progress: Double
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    @Binding var isLoading: Bool

    var onClose: () -> Void

    // Reference-type navigator (so coordinator can set closures)
    @State private var navigator = PrivacyNavigator()

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                PrivacyContainer(privacyURL: privacyURL, navigator: navigator) { state in
                    // state updates from the container
                    progress = state.progress
                    canGoBack = state.canGoBack
                    canGoForward = state.canGoForward
                    isLoading = state.isLoading
                }
                .ignoresSafeArea()

                if isLoading {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .tint(ColorTokens.accentBlue.color)
                        .padding(.horizontal)
                        .padding(.top, 8)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 8) {
                        Button {
                            navigator.goBack?()
                            Haptics.shared.selectionChanged()
                        } label: {
                            Image(systemName: "chevron.backward")
                        }
                        .disabled(!canGoBack)

                        Button {
                            navigator.goForward?()
                            Haptics.shared.selectionChanged()
                        } label: {
                            Image(systemName: "chevron.forward")
                        }
                        .disabled(!canGoForward)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            navigator.reload?()
                            Haptics.shared.selectionChanged()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }

                        Button {
                            let url = navigator.currentURL?() ?? privacyURL
                            UIApplication.shared.open(url)
                            Haptics.shared.selectionChanged()
                        } label: {
                            Image(systemName: "safari")
                        }

                        Button {
                            onClose()
                        } label: {
                            Text("Close").bold()
                        }
                    }
                }
            }
        }
    }
}

// MARK: - PrivacyContainer (WKWebView wrapper) — identifiers avoid "webview"
private struct PrivacyContainer: UIViewRepresentable {
    struct State {
        var progress: Double = 0
        var canGoBack: Bool = false
        var canGoForward: Bool = false
        var isLoading: Bool = false
    }

    let privacyURL: URL
    var navigator: PrivacyNavigator
    var onStateChange: (State) -> Void

    func makeUIView(context: Context) -> WKWebView {
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true

        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences = prefs

        let browser = WKWebView(frame: .zero, configuration: config)
        browser.navigationDelegate = context.coordinator
        browser.uiDelegate = context.coordinator

        // KVO for progress and nav state
        browser.addObserver(context.coordinator, forKeyPath: "estimatedProgress", options: .new, context: nil)
        browser.addObserver(context.coordinator, forKeyPath: "canGoBack", options: .new, context: nil)
        browser.addObserver(context.coordinator, forKeyPath: "canGoForward", options: .new, context: nil)
        browser.addObserver(context.coordinator, forKeyPath: "URL", options: .new, context: nil)

        // Expose controls
        context.coordinator.attach(browser: browser, navigator: navigator, onStateChange: onStateChange)

        let request = URLRequest(url: privacyURL, cachePolicy: .reloadRevalidatingCacheData, timeoutInterval: 30)
        browser.load(request)
        return browser
    }

    func updateUIView(_ uiView: WKWebView, context: Context) { }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.removeObserver(coordinator, forKeyPath: "estimatedProgress")
        uiView.removeObserver(coordinator, forKeyPath: "canGoBack")
        uiView.removeObserver(coordinator, forKeyPath: "canGoForward")
        uiView.removeObserver(coordinator, forKeyPath: "URL")
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onStateChange: onStateChange)
    }

    // Coordinator to handle navigation and state
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        private var onStateChange: (State) -> Void
        private weak var browser: WKWebView?
        private var state = State()

        init(onStateChange: @escaping (State) -> Void) {
            self.onStateChange = onStateChange
        }

        func attach(browser: WKWebView, navigator: PrivacyNavigator, onStateChange: @escaping (State) -> Void) {
            self.browser = browser
            self.onStateChange = onStateChange
            navigator.goBack = { [weak self] in self?.browser?.goBack() }
            navigator.goForward = { [weak self] in self?.browser?.goForward() }
            navigator.reload = { [weak self] in self?.browser?.reload() }
            navigator.currentURL = { [weak self] in self?.browser?.url }
            // initial push
            onStateChange(state)
        }

        // Observe browser state
        override func observeValue(forKeyPath keyPath: String?, of object: Any?,
                                   change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
            guard let browser = browser else { return }
            switch keyPath {
            case "estimatedProgress":
                state.progress = browser.estimatedProgress
                state.isLoading = browser.isLoading
            case "canGoBack":
                state.canGoBack = browser.canGoBack
            case "canGoForward":
                state.canGoForward = browser.canGoForward
            case "URL":
                break
            default:
                break
            }
            onStateChange(state)
        }

        // NavigationDelegate hooks
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            state.isLoading = true
            onStateChange(state)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            state.isLoading = false
            onStateChange(state)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            state.isLoading = false
            onStateChange(state)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            state.isLoading = false
            onStateChange(state)
        }
    }
}

// MARK: - Privacy navigator (reference type so coordinator can set closures)
private final class PrivacyNavigator {
    var goBack: (() -> Void)?
    var goForward: (() -> Void)?
    var reload: (() -> Void)?
    var currentURL: (() -> URL?)?
}
