import SwiftUI
import AVFoundation
import Combine
import UIKit
import Photos

struct ShootingMainView: View {
    let selectedTags: Set<String>
    let currentShot: Int
    let totalShots: Int
    let referencePose: PoseGuide

    @StateObject private var camera = CameraSessionModel()
    @State private var shotNumber: Int
    @State private var autoCaptureWorkItem: DispatchWorkItem?
    @State private var didScheduleAutoCapture = false
    @State private var autoCaptureStartDate: Date?
    @State private var isAutoCaptureActive = false
    @State private var countdownValue: Int?
    @State private var navigateToShootingShow = false
    @State private var latestCapturedImageForShow: UIImage?
    @Environment(\.dismiss) private var dismiss
    private let autoCaptureDelay: TimeInterval = 10.0
    private let autoCaptureTicker = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    init(selectedTags: Set<String> = [], currentShot: Int = 1, totalShots: Int = 10, referencePose: PoseGuide = PoseGuideCatalog.fallback) {
        self.selectedTags = selectedTags
        self.currentShot = currentShot
        self.totalShots = totalShots
        self.referencePose = referencePose
        _shotNumber = State(initialValue: currentShot)
    }

    var body: some View {
        ZStack {
            if let message = camera.errorMessage {
                VStack(spacing: 10) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 44))
                    Text(message)
                        .font(.headline)
                    Text("設定アプリ > mimic > カメラ をオンにしてください")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if camera.permissionDenied {
                        Button("設定を開く") {
                            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                            UIApplication.shared.open(url)
                        }
                        .padding(.top, 8)
                    }
                }
                .padding()
            } else {
                CameraPreview(session: camera.session)
                    .ignoresSafeArea()
                    .overlay(alignment: .bottom) {
                        bottomOverlay
                            .padding(.bottom, 24)
                    }

                if let countdownValue {
                    Text("\(countdownValue)")
                        .font(.system(size: 120, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.35), radius: 10, x: 0, y: 4)
                        .transition(.opacity)
                }

                if let capturedImage = camera.capturedImage {
                    VStack {
                        HStack {
                            Image(uiImage: capturedImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 70, height: 70)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(.white.opacity(0.8), lineWidth: 1)
                                )
                                .padding(.leading, 20)
                                .padding(.top, 14)
                            Spacer()
                        }
                        Spacer()
                    }
                }
            }
        }
        .onAppear {
            camera.start()
            scheduleAutoCaptureIfNeeded()
        }
        .onDisappear {
            autoCaptureWorkItem?.cancel()
            isAutoCaptureActive = false
            countdownValue = nil
            camera.stop()
        }
        .onReceive(autoCaptureTicker) { _ in
            guard isAutoCaptureActive, let startDate = autoCaptureStartDate else { return }
            let elapsed = Date().timeIntervalSince(startDate)
            let remaining = max(0, autoCaptureDelay - elapsed)

            if remaining <= 5.0, remaining > 0 {
                countdownValue = Int(ceil(remaining))
            } else {
                countdownValue = nil
            }
        }
        .onReceive(camera.$capturedImage.compactMap { $0 }) { image in
            shotNumber = min(shotNumber + 1, totalShots)
            isAutoCaptureActive = false
            countdownValue = nil
            saveImageToDeviceLibrary(image)
            saveImageToAppStorage(image)
            latestCapturedImageForShow = image
            navigateToShootingShow = true
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .navigationDestination(isPresented: $navigateToShootingShow) {
            if let latestCapturedImageForShow {
                ShootingShowView(
                    selectedTags: selectedTags,
                    totalShots: totalShots,
                    nextShot: currentShot + 1,
                    previousPose: referencePose,
                    capturedImage: latestCapturedImageForShow
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.black)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.9))
                        .frame(width: 56, height: 56)
                    Text("\(shotNumber)/\(totalShots)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)
                }
            }
        }
    }

    private var bottomOverlay: some View {
        HStack(alignment: .bottom, spacing: 20) {
            VStack(spacing: 8) {
                Image(systemName: referencePose.symbol)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 52, height: 52)
                Text("おてほん")
                    .font(.system(size: 22, weight: .bold))
                Text(referencePose.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 132, height: 248)
            .background(Color(red: 0.92, green: 0.72, blue: 0.74))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            ZStack {
                Circle()
                    .trim(from: 0.15, to: 0.95)
                    .stroke(Color(red: 0.96, green: 0.82, blue: 0.39), style: StrokeStyle(lineWidth: 22, lineCap: .round))
                    .frame(width: 168, height: 168)
                    .rotationEffect(.degrees(-90))

                Circle()
                    .trim(from: 0.30, to: 0.82)
                    .stroke(Color(red: 0.88, green: 0.86, blue: 0.82), style: StrokeStyle(lineWidth: 22, lineCap: .round))
                    .frame(width: 168, height: 168)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text("一致度")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.brown)
                    HStack(alignment: .lastTextBaseline, spacing: 2) {
                        Text("55")
                            .font(.system(size: 72, weight: .black, design: .rounded))
                            .foregroundStyle(Color.orange)
                        Text("%")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.brown)
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
    }

    private func scheduleAutoCaptureIfNeeded() {
        guard !didScheduleAutoCapture else { return }
        didScheduleAutoCapture = true
        autoCaptureStartDate = Date()
        isAutoCaptureActive = true

        let workItem = DispatchWorkItem {
            camera.capturePhoto()
        }
        autoCaptureWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + autoCaptureDelay, execute: workItem)
    }

    private func saveImageToDeviceLibrary(_ image: UIImage) {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        switch status {
        case .authorized, .limited:
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }) { success, error in
                if !success {
                    DispatchQueue.main.async {
                        self.camera.errorMessage = error?.localizedDescription ?? "端末フォトへの保存に失敗しました"
                    }
                }
            }
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { newStatus in
                guard newStatus == .authorized || newStatus == .limited else { return }
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                }, completionHandler: nil)
            }
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.camera.errorMessage = "写真ライブラリへのアクセスを許可してください"
            }
        @unknown default:
            break
        }
    }

    private func saveImageToAppStorage(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.95) else {
            camera.errorMessage = "アプリ内保存に失敗しました"
            return
        }
        do {
            let folder = try AppPhotoStore.ensureFolder()
            let filename = "mimic_\(UUID().uuidString).jpg"
            let url = folder.appendingPathComponent(filename)
            try data.write(to: url, options: .atomic)
        } catch {
            camera.errorMessage = "アプリ内保存に失敗しました"
        }
    }
}

enum AppPhotoStore {
    static func ensureFolder() throws -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let folder = docs.appendingPathComponent("CapturedPhotos", isDirectory: true)
        if !FileManager.default.fileExists(atPath: folder.path) {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        return folder
    }
}

final class CameraSessionModel: ObservableObject {
    let session = AVCaptureSession()

    @Published var permissionDenied = false
    @Published var errorMessage: String?
    @Published var capturedImage: UIImage?

    private let queue = DispatchQueue(label: "camera.session.queue")
    private var isConfigured = false
    private let photoOutput = AVCapturePhotoOutput()
    private lazy var photoCaptureDelegate = PhotoCaptureDelegate { [weak self] image in
        DispatchQueue.main.async {
            self?.capturedImage = image
            if image == nil {
                self?.errorMessage = "撮影に失敗しました"
            }
        }
    }

    func start() {
        checkPermissionAndStart()
    }

    func stop() {
        queue.async {
            guard self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    func capturePhoto() {
        queue.async {
            guard self.isConfigured, self.session.isRunning else { return }
            let settings = AVCapturePhotoSettings()
            settings.flashMode = .off
            self.photoOutput.capturePhoto(with: settings, delegate: self.photoCaptureDelegate)
        }
    }

    private func checkPermissionAndStart() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            DispatchQueue.main.async {
                self.permissionDenied = false
                self.errorMessage = nil
            }
            configureAndRunIfNeeded()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    self.permissionDenied = !granted
                    self.errorMessage = granted ? nil : "カメラのアクセスを許可してください"
                }
                if granted {
                    self.configureAndRunIfNeeded()
                }
            }
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.permissionDenied = true
                self.errorMessage = "カメラのアクセスを許可してください"
            }
        @unknown default:
            DispatchQueue.main.async {
                self.permissionDenied = true
                self.errorMessage = "カメラを利用できません"
            }
        }
    }

    private func configureAndRunIfNeeded() {
        queue.async {
            if !self.isConfigured {
                self.configureSession()
                self.isConfigured = true
            }

            guard !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .photo

        defer {
            session.commitConfiguration()
        }

        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [
                .builtInTripleCamera,
                .builtInDualWideCamera,
                .builtInDualCamera,
                .builtInWideAngleCamera,
                .builtInUltraWideCamera,
                .builtInTelephotoCamera
            ],
            mediaType: .video,
            position: .back
        )

        guard let device = discovery.devices.first ?? AVCaptureDevice.default(for: .video) else {
            DispatchQueue.main.async {
                self.errorMessage = "カメラが見つかりません（シミュレータでは利用できません）"
            }
            return
        }

        guard let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) else {
            DispatchQueue.main.async {
                self.errorMessage = "カメラの初期化に失敗しました"
            }
            return
        }

        if session.inputs.isEmpty {
            session.addInput(input)
        }

        guard session.canAddOutput(photoOutput) else {
            DispatchQueue.main.async {
                self.errorMessage = "カメラ出力の初期化に失敗しました"
            }
            return
        }
        session.addOutput(photoOutput)
    }
}

final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    nonisolated(unsafe) private let completion: (UIImage?) -> Void

    init(completion: @escaping (UIImage?) -> Void) {
        self.completion = completion
    }

    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil, let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else {
            completion(nil)
            return
        }
        completion(image)
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.videoGravity = .resizeAspectFill
        view.previewLayer.session = session
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.previewLayer.session = session
    }
}

final class PreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}

struct ShootingMainView_Previews: PreviewProvider {
    static var previews: some View {
        ShootingMainView(
            selectedTags: ["cool"],
            currentShot: 5,
            totalShots: 10,
            referencePose: PoseGuide(name: "ダブルピース", symbol: "hand.victory.fill")
        )
    }
}
