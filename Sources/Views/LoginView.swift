import CoreImage.CIFilterBuiltins
import SwiftUI

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

    var body: some View {
        HStack(spacing: 100) {
            VStack(alignment: .leading, spacing: 28) {
                Text("سی‌نما").font(.vazir(80, .heavy)).foregroundStyle(.red)
                Text("ورود به حساب").font(.appTitle)
                VStack(alignment: .leading, spacing: 14) {
                    Text("۱. با گوشی یا کامپیوتری که در سی‌نما وارد حساب‌تان شده‌اید، کد QR را اسکن کنید.")
                    Text("۲. در صفحه‌ای که باز می‌شود، ورود این تلویزیون را تأیید کنید.")
                }
                .font(.appBody)
                switch state {
                case .code(let url, _): Text(url).font(.appCaption).foregroundStyle(.secondary)
                case .error(let m): Text(m).foregroundStyle(.red)
                case .loading: EmptyView()
                }
                HStack(spacing: 24) {
                    Button("کد جدید") { attempt += 1 }
                    Button("تغییر کلید API") { app.phase = .needsKey }
                }
            }
            .frame(maxWidth: 800, alignment: .leading)

            ZStack {
                switch state {
                case .code(_, let image):
                    if let image {
                        Image(uiImage: image).interpolation(.none).resizable().scaledToFit()
                            .padding(24).background(Color.white).clipShape(RoundedRectangle(cornerRadius: 20))
                    }
                default:
                    ProgressView()
                }
            }
            .frame(width: 520, height: 520)
        }
        .padding(80)
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
            Text("کلید API").font(.appLargeTitle)
            Text("درخواست‌ها به یک c-api-key نیاز دارند؛ همان کلیدی که کلاینت وب رسمی تلویزیون سی‌نما (tv.30app.store) می‌فرستد. آن را از درخواست‌های شبکهٔ مرورگر بخوانید و اینجا وارد کنید. پیشنهاد می‌شود به‌جای تایپ روی تلویزیون، آن را هنگام ساخت برنامه در Config/Secrets.xcconfig بگذارید.")
                .font(.appBody)
            TextField("c-api-key", text: $key)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("ذخیره") { app.saveKey(key) }.disabled(key.trimmed.isEmpty)
        }
        .frame(maxWidth: 1100)
        .padding(80)
    }
}
