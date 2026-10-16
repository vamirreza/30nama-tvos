import CoreImage.CIFilterBuiltins
import SwiftUI
#if os(iOS)
import SafariServices
#endif

private func qrImage(_ string: String) -> UIImage? {
    let filter = CIFilter.qrCodeGenerator()
    filter.message = Data(string.utf8)
    filter.correctionLevel = "M"
    guard let output = filter.outputImage else { return nil }
    let scaled = output.transformed(by: CGAffineTransform(scaleX: 12, y: 12))
    guard let cg = CIContext().createCGImage(scaled, from: scaled.extent) else { return nil }
    return UIImage(cgImage: cg)
}

/// Sign in by scanning a QR code with a phone that is logged in to 30nama.
struct LoginView: View {
    @EnvironmentObject private var app: AppState
    private enum Phase { case loading, code(url: String, image: UIImage?), error(String) }
    @State private var state = Phase.loading
    @State private var attempt = 0

    private func step(_ number: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 20) {
            Text(number)
                .font(.appHeadline)
                .frame(width: Metrics.stepBadge, height: Metrics.stepBadge)
                .background(Theme.red, in: Circle())
            Text(text).font(.appBody).foregroundStyle(Color.white.opacity(0.88))
        }
    }

    @ViewBuilder
    private var statusLine: some View {
        switch state {
        case .code(let url, _): Text(url).font(.appCaption).foregroundStyle(Theme.textDim)
        case .error(let m): Text(m).foregroundStyle(Theme.red)
        case .loading: EmptyView()
        }
    }

    #if os(tvOS)
    private var tvBody: some View {
        HStack(spacing: 110) {
            VStack(alignment: .leading, spacing: 34) {
                Logo(height: 120)
                Text(tr("ورود به حساب")).font(.appTitle)
                VStack(alignment: .leading, spacing: 22) {
                    step(tr("۱"), tr("با گوشی یا کامپیوتری که در سی‌نما وارد حساب‌تان شده‌اید، کد QR را اسکن کنید."))
                    step(tr("۲"), tr("در صفحه‌ای که باز می‌شود، ورود این تلویزیون را تأیید کنید."))
                }
                statusLine
                HStack(spacing: 24) {
                    Button(tr("کد جدید")) { attempt += 1 }.buttonStyle(.pillProminent)
                    Button(tr("تغییر کلید API")) { app.phase = .needsKey }.buttonStyle(.pill)
                    LanguageButton()
                }
            }
            .frame(maxWidth: 820, alignment: .leading)

            ZStack {
                switch state {
                case .code(_, let image):
                    if let image {
                        Image(uiImage: image).interpolation(.none).resizable().scaledToFit()
                            .padding(28).background(Color.white).clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                            .shadow(color: Theme.red.opacity(0.45), radius: 60)
                    }
                default:
                    ProgressView().tint(.white)
                }
            }
            .frame(width: 520, height: 520)
        }
        .padding(Metrics.pagePad)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appBackground()
    }
    #endif

    #if os(iOS)
    @State private var safari: SafariTarget?

    private var phoneBody: some View {
        VStack(spacing: Metrics.sectionGap) {
            Spacer()
            Logo(height: 64)
            Card {
                VStack(spacing: 16) {
                    Text(tr("ورود به حساب")).font(.appTitle2)
                    Text(tr("صفحهٔ سی‌نما را باز کنید، وارد حساب‌تان شوید و ورود این دستگاه را تأیید کنید."))
                        .font(.appBody)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Theme.textDim)
                    switch state {
                    case .code(let url, _):
                        if let target = URL(string: url) {
                            Button {
                                #if targetEnvironment(macCatalyst)
                                // The in-app Safari sheet does not work on the Mac: use the default browser.
                                UIApplication.shared.open(target)
                                #else
                                safari = SafariTarget(url: target)
                                #endif
                            } label: {
                                Label(tr("ورود با سی‌نما"), systemImage: "person.badge.key").frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.pillProminent)
                        }
                    case .error(let m):
                        Text(m).foregroundStyle(Theme.red).multilineTextAlignment(.center)
                    case .loading:
                        ProgressView().tint(.white)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            Spacer()
            HStack(spacing: 24) {
                Button(tr("کد جدید")) { attempt += 1 }
                Button(tr("تغییر کلید API")) { app.phase = .needsKey }
                LanguageButton()
            }
            .buttonStyle(.plain)
            .font(.appCallout)
            .foregroundStyle(Theme.textDim)
        }
        .padding(Metrics.pagePad)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appBackground()
        .sheet(item: $safari) { SafariView(url: $0.url).ignoresSafeArea() }
    }
    #endif

    var body: some View {
        Group {
            #if os(tvOS)
            tvBody
            #else
            phoneBody
            #endif
        }
        .task(id: attempt) { await run() }
    }

    private func run() async {
        state = .loading
        do {
            let qr = try await API.qrCode()
            state = .code(url: qr.url, image: qrImage(qr.url))
            let deadline = Date().addingTimeInterval(Config.qrTTLSeconds)
            while !Task.isCancelled && Date() < deadline {
                try? await Task.sleep(nanoseconds: Config.qrPollSeconds * 1_000_000_000)
                if Task.isCancelled { return }
                do {
                    let token = try await API.qrLogin(qr.code)
                    NSLog("[qr] poll \(qr.code): token=\(token != nil)")
                    if let token {
                        app.loggedIn(token: token)
                        return
                    }
                } catch {
                    NSLog("[qr] poll \(qr.code) failed: \(error)")
                }
            }
            // Codes are short-lived; issue a fresh one instead of polling a dead code.
            if !Task.isCancelled { attempt += 1 }
        } catch {
            if let m = describe(error) { state = .error(m) }
        }
    }
}

/// Needed when the build carries no client key. The key is the one the official TV web client sends.
struct APIKeyView: View {
    @EnvironmentObject private var app: AppState
    @State private var key = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            Logo(height: Metrics.launchLogo)
            Card {
                VStack(alignment: .leading, spacing: 24) {
                    Text(tr("کلید API")).font(.appTitle2)
                    Text(tr("درخواست‌ها به یک c-api-key نیاز دارند؛ همان کلیدی که کلاینت وب رسمی تلویزیون سی‌نما (tv.30app.store) می‌فرستد. آن را از درخواست‌های شبکهٔ مرورگر بخوانید و اینجا وارد کنید. پیشنهاد می‌شود به‌جای تایپ روی دستگاه، آن را هنگام ساخت برنامه در Config/Secrets.xcconfig بگذارید."))
                        .font(.appBody)
                        .foregroundStyle(Theme.textDim)
                    TextField("c-api-key", text: $key)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button(tr("ذخیره")) { app.saveKey(key) }
                        .buttonStyle(.pillProminent)
                        .disabled(key.trimmed.isEmpty)
                }
            }
        }
        .frame(maxWidth: 1100)
        .padding(Metrics.pagePad)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appBackground()
    }
}

#if os(iOS)
struct SafariTarget: Identifiable {
    let url: URL
    var id: URL { url }
}

/// The 30nama approval page, shown in-app so the viewer returns to the app on their own.
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController { SFSafariViewController(url: url) }
    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
#endif

/// Switches between Persian and English before signing in.
struct LanguageButton: View {
    @EnvironmentObject private var settings: SettingsStore

    var body: some View {
        Button {
            settings.language = settings.language == .fa ? .en : .fa
        } label: {
            Label(settings.language == .fa ? "English" : "فارسی", systemImage: "globe")
        }
    }
}
