import PhotosUI
import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var viewModel = MomentComposerViewModel()
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isShowingCamera = false
    @State private var isShowingPhotoLibrary = false
    @State private var isShowingCameraUnavailableAlert = false
    @State private var saveResultMessage: String?
    @State private var sharePayload: SharePayload?

    private let photoLibrarySaver = PhotoLibrarySaver()

    var body: some View {
        ZStack {
            backgroundView

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    heroSection
                    controlsSection
                    previewSection
                    insightSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $isShowingCamera) {
            CameraPicker { image in
                if let image {
                    viewModel.composeMoment(from: image)
                }
            }
            .ignoresSafeArea()
        }
        .sheet(item: $sharePayload) { payload in
            ShareSheet(items: [payload.image])
        }
        .photosPicker(
            isPresented: $isShowingPhotoLibrary,
            selection: $selectedPhotoItem,
            matching: .images,
            preferredItemEncoding: .current
        )
        .alert("Camera Unavailable", isPresented: $isShowingCameraUnavailableAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Simulator ではカメラ入力を無効化しています。Library から写真を選ぶか、実機で Camera を使ってください。")
        }
        .alert("保存結果", isPresented: saveResultAlertBinding) {
            Button("OK", role: .cancel) {
                saveResultMessage = nil
            }
        } message: {
            Text(saveResultMessage ?? "")
        }
        .task {
            await viewModel.prepare()
        }
        .onChange(of: selectedPhotoItem) { _, newValue in
            guard let newValue else { return }
            Task {
                await viewModel.loadPhoto(from: newValue)
                selectedPhotoItem = nil
            }
        }
    }

    private var backgroundView: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.07, blue: 0.11),
                    Color(red: 0.14, green: 0.11, blue: 0.18),
                    Color(red: 0.42, green: 0.29, blue: 0.19)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color(red: 0.96, green: 0.67, blue: 0.41).opacity(0.22))
                .frame(width: 280, height: 280)
                .blur(radius: 14)
                .offset(x: 120, y: -220)

            RoundedRectangle(cornerRadius: 48, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .frame(width: 320, height: 320)
                .rotationEffect(.degrees(22))
                .blur(radius: 4)
                .offset(x: -130, y: 210)
        }
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Moments AI Cam")
                .font(.system(size: 42, weight: .black, design: .serif))
                .foregroundStyle(.white)

            Text("「エモい」のその先へ。写真の明るさ、音、写っている関係性を読み取り、その瞬間の感情を短い詩として刻む。")
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                StatusPill(title: "Model", value: viewModel.modelSummary)
                StatusPill(title: "Ambience", value: viewModel.ambientLevelLabel)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.82))
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }

    private var controlsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Capture")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.74))
                .textCase(.uppercase)

            HStack(spacing: 12) {
                Button {
                    if isCameraCaptureAvailable {
                        isShowingCamera = true
                    } else {
                        isShowingCameraUnavailableAlert = true
                    }
                } label: {
                    Label("Camera", systemImage: "camera.fill")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryActionButtonStyle())

                Button {
                    isShowingPhotoLibrary = true
                } label: {
                    Label("Library", systemImage: "photo.stack.fill")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryActionButtonStyle())
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(red: 1.0, green: 0.82, blue: 0.76))
            }
        }
    }

    @ViewBuilder
    private var previewSection: some View {
        if let image = viewModel.sourceImage {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Stamped Moment")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.74))
                        .textCase(.uppercase)

                    Spacer()

                    if let moment = viewModel.generatedMoment {
                        Button("保存") {
                            Task {
                                await saveMomentImage(image: image, moment: moment)
                            }
                        }
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Capsule())

                        Button("SNSにシェア") {
                            sharePayload = renderSharePayload(image: image, moment: moment)
                        }
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color(red: 0.99, green: 0.8, blue: 0.47))
                        .clipShape(Capsule())
                    }
                }

                ZStack {
                    if let moment = viewModel.generatedMoment {
                        MomentCardView(image: image, moment: moment, compact: false)
                    } else {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .overlay(
                                LinearGradient(
                                    colors: [.clear, Color.black.opacity(0.78)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .overlay(alignment: .bottomLeading) {
                                if viewModel.isGenerating {
                                    ProgressBlock(text: "その場の空気を言葉にしています…")
                                        .padding(18)
                                }
                            }
                    }
                }
                .frame(height: 520)
                .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 36, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
            }
        } else {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .frame(height: 340)
                .overlay {
                    VStack(spacing: 16) {
                        Image(systemName: "sparkles.rectangle.stack")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.85))
                        Text("写真を撮ると、その瞬間の感情を\nAI が短い詩として刻みます。")
                            .font(.system(size: 20, weight: .bold, design: .serif))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Color.white.opacity(0.9))
                        Text("Apple Intelligence と端末上の解析だけで完結。")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.68))
                    }
                }
        }
    }

    @ViewBuilder
    private var insightSection: some View {
        if let moment = viewModel.generatedMoment {
            VStack(alignment: .leading, spacing: 16) {
                Text("Atmosphere Read")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.74))
                    .textCase(.uppercase)

                VStack(spacing: 12) {
                    InsightRow(title: "Emotion", value: moment.poem.emotion)
                    InsightRow(title: "Brightness", value: moment.analysis.brightnessDescriptor)
                    InsightRow(title: "Temperature", value: moment.analysis.warmthDescriptor)
                    InsightRow(title: "Relation", value: moment.analysis.relationshipDescription)
                    InsightRow(title: "Scene", value: moment.analysis.sceneLine)
                    InsightRow(title: "Audio", value: moment.analysis.soundDescriptor)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(moment.analysis.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            .padding(22)
            .background(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(.ultraThinMaterial.opacity(0.82))
            )
        }
    }

    @MainActor
    private func renderSharePayload(image: UIImage, moment: GeneratedMoment) -> SharePayload? {
        let content = ShareCanvasView(image: image, moment: moment)
            .frame(width: 1080, height: 1350)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 1

        guard let rendered = renderer.uiImage else {
            viewModel.errorMessage = "共有画像の生成に失敗しました。"
            return nil
        }

        return SharePayload(image: rendered)
    }

    private var isCameraCaptureAvailable: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        return UIImagePickerController.isSourceTypeAvailable(.camera)
        #endif
    }

    private var saveResultAlertBinding: Binding<Bool> {
        Binding(
            get: { saveResultMessage != nil },
            set: { isPresented in
                if !isPresented {
                    saveResultMessage = nil
                }
            }
        )
    }

    @MainActor
    private func saveMomentImage(image: UIImage, moment: GeneratedMoment) async {
        guard let rendered = renderSharePayload(image: image, moment: moment)?.image else {
            return
        }

        do {
            try await photoLibrarySaver.save(image: rendered)
            saveResultMessage = "写真アプリに保存しました。"
        } catch {
            saveResultMessage = error.localizedDescription
        }
    }
}

private struct SharePayload: Identifiable {
    let id = UUID()
    let image: UIImage
}

private struct StatusPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.55))
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct InsightRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.52))
                .frame(width: 90, alignment: .leading)

            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .serif))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct ProgressBlock: View {
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(.white)
            Text(text)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.42))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct PrimaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.black)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color(red: 0.99, green: 0.8, blue: 0.47))
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

private struct SecondaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.12 : 0.09))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

private struct MomentCardView: View {
    let image: UIImage
    let moment: GeneratedMoment
    let compact: Bool

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()

            LinearGradient(
                colors: [
                    .clear,
                    Color.black.opacity(0.15),
                    Color.black.opacity(0.84)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            overlayContent
                .padding(compact ? 30 : 26)
        }
        .background(Color.black)
    }

    private var overlayContent: some View {
        VStack(alignment: .leading, spacing: compact ? 14 : 16) {
            Text(moment.poem.title.uppercased())
                .font(.system(size: compact ? 26 : 16, weight: .heavy, design: .rounded))
                .tracking(compact ? 3 : 2.4)
                .foregroundStyle(Color.white.opacity(0.56))

            Text(moment.poem.poem)
                .font(poemFont)
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
                .lineSpacing(compact ? 6 : 3)
                .shadow(color: .black.opacity(0.35), radius: 10, x: 0, y: 3)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(moment.poem.emotion)
                        .font(.system(size: compact ? 20 : 15, weight: .bold, design: .rounded))
                    Text(moment.analysis.metadataLine)
                        .font(.system(size: compact ? 14 : 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.74))
                }

                Spacer()

                Text(moment.poem.accentWord)
                    .font(.system(size: compact ? 40 : 24, weight: .black, design: .serif))
                    .italic()
                    .foregroundStyle(accentGradient)
            }
            .foregroundStyle(.white)
        }
    }

    private var poemFont: Font {
        switch moment.poem.typography {
        case .halo:
            return .system(size: compact ? 58 : 34, weight: .bold, design: .serif)
        case .pulse:
            return .system(size: compact ? 50 : 30, weight: .black, design: .rounded)
        case .drift:
            return .system(size: compact ? 52 : 31, weight: .medium, design: .serif).italic()
        case .ember:
            return .system(size: compact ? 54 : 32, weight: .heavy, design: .serif)
        }
    }

    private var accentGradient: LinearGradient {
        switch moment.poem.typography {
        case .halo:
            return LinearGradient(colors: [.white, Color(red: 0.86, green: 0.93, blue: 1)], startPoint: .top, endPoint: .bottom)
        case .pulse:
            return LinearGradient(colors: [Color(red: 1, green: 0.92, blue: 0.82), Color(red: 1, green: 0.55, blue: 0.4)], startPoint: .top, endPoint: .bottom)
        case .drift:
            return LinearGradient(colors: [Color(red: 0.82, green: 0.92, blue: 1), Color(red: 0.66, green: 0.82, blue: 1)], startPoint: .top, endPoint: .bottom)
        case .ember:
            return LinearGradient(colors: [Color(red: 1, green: 0.87, blue: 0.48), Color(red: 1, green: 0.46, blue: 0.33)], startPoint: .top, endPoint: .bottom)
        }
    }
}

private struct ShareCanvasView: View {
    let image: UIImage
    let moment: GeneratedMoment

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.06, blue: 0.09),
                    Color(red: 0.16, green: 0.12, blue: 0.19)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 28) {
                MomentCardView(image: image, moment: moment, compact: true)
                    .frame(height: 1050)
                    .clipShape(RoundedRectangle(cornerRadius: 44, style: .continuous))

                HStack {
                    Text("Moments AI Cam")
                        .font(.system(size: 30, weight: .black, design: .serif))
                        .foregroundStyle(.white)
                    Spacer()
                    Text(moment.analysis.metadataLine)
                        .font(.system(size: 22, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.7))
                }
            }
            .padding(48)
        }
    }
}

#Preview {
    ContentView()
}
