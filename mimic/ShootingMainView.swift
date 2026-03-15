import SwiftUI
import AVFoundation
import Combine
import UIKit
import Photos
import Vision

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
    @State private var showExitAlert = false
    @State private var poseScore: Double?
    @State private var poseStatus: String?
    @State private var lastPoseScore: Double?
    @State private var lastPoseUpdate: Date?
    @State private var smoothedPoseScore: Double?
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
                CameraPreview(camera: camera)
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
            if currentShot == 1 {
                SessionPhotoStore.startNewSession()
            }
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
            let finalImage = camera.finalizeCapturedImage(image)
            shotNumber = min(shotNumber + 1, totalShots)
            isAutoCaptureActive = false
            countdownValue = nil
            saveImageToDeviceLibrary(finalImage)
            saveImageToAppStorage(finalImage)
            latestCapturedImageForShow = finalImage
            navigateToShootingShow = true
        }
        .onReceive(camera.$currentPoseAngles) { angles in
            let now = Date()
            guard let angles else {
                if let lastPoseUpdate, now.timeIntervalSince(lastPoseUpdate) < 2.0 {
                    poseScore = lastPoseScore
                    poseStatus = nil
                } else {
                    poseScore = 0
                    poseStatus = "No Pose"
                }
                return
            }
            if let reference = PoseReferenceStore.angles(for: referencePose.name) {
                let score = PoseAngleScorer.score(current: angles, reference: reference)
                let alpha = 0.2
                if let current = smoothedPoseScore {
                    smoothedPoseScore = current * (1 - alpha) + score * alpha
                } else {
                    smoothedPoseScore = score
                }
                poseScore = smoothedPoseScore
                lastPoseScore = score
                lastPoseUpdate = now
                poseStatus = nil
            } else {
                poseScore = 0
                poseStatus = "No Ref"
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .mimicPopToRoot)) { _ in
            dismiss()
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
                    showExitAlert = true
                } label: {
                    topPill {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.black)
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                topPill {
                    Text("\(shotNumber)/\(totalShots)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)
                }
            }
        }
        .alert("撮影をやめる？", isPresented: $showExitAlert) {
            Button("やめる", role: .destructive) {
                NotificationCenter.default.post(name: .mimicPopToRoot, object: nil)
            }
            Button("キャンセル", role: .cancel) {}
        }
    }

    private var bottomOverlay: some View {
        HStack(alignment: .bottom, spacing: 20) {
            VStack(spacing: 8) {
                poseImage(for: referencePose)
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
                let start: CGFloat = 0.15
                let span: CGFloat = 0.80
                let progress = CGFloat(min(max((poseScore ?? 0) / 100.0, 0), 1))
                let end = start + span * progress

                Circle()
                    .trim(from: start, to: start + span)
                    .stroke(Color(red: 0.88, green: 0.86, blue: 0.82), style: StrokeStyle(lineWidth: 22, lineCap: .round))
                    .frame(width: 168, height: 168)
                    .rotationEffect(.degrees(-90))

                Circle()
                    .trim(from: start, to: end)
                    .stroke(Color(red: 0.96, green: 0.82, blue: 0.39), style: StrokeStyle(lineWidth: 22, lineCap: .round))
                    .frame(width: 168, height: 168)
                    .rotationEffect(.degrees(-90))
                    .opacity(poseScore == nil ? 0.2 : 1.0)
                    .animation(.easeOut(duration: 0.2), value: poseScore)

                VStack(spacing: 2) {
                    Text("一致度")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.brown)
                    HStack(alignment: .lastTextBaseline, spacing: 2) {
                        if let poseScore {
                            Text("\(Int(poseScore.rounded()))")
                                .font(.system(size: 72, weight: .black, design: .rounded))
                                .foregroundStyle(Color.orange)
                            Text("%")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(.brown)
                        } else {
                            Text("--")
                                .font(.system(size: 64, weight: .black, design: .rounded))
                                .foregroundStyle(Color.orange)
                        }
                    }
                    if let poseStatus {
                        Text(poseStatus)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
    }

    private func topPill<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            Capsule()
                .fill(Color.white.opacity(0.9))
                .frame(width: 72, height: 44)
                .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 6)
            content()
        }
    }

    private func poseImage(for pose: PoseGuide) -> some View {
        Group {
            if let imageName = pose.imageName {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: pose.symbol)
                    .resizable()
                    .scaledToFit()
            }
        }
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
            let sessionId = SessionPhotoStore.currentSessionId()
            let timestamp = Int(Date().timeIntervalSince1970)
            let filename = "mimic_\(sessionId)_\(timestamp)_\(UUID().uuidString).jpg"
            let url = folder.appendingPathComponent(filename)
            try data.write(to: url, options: .atomic)
            SessionPhotoStore.appendPhoto(url)
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

final class CameraSessionModel: NSObject, ObservableObject {
    let session = AVCaptureSession()

    @Published var permissionDenied = false
    @Published var errorMessage: String?
    @Published var capturedImage: UIImage?
    @Published @MainActor var currentPoseAngles: PoseAngles?
    weak var previewLayer: AVCaptureVideoPreviewLayer?

    private let queue = DispatchQueue(label: "camera.session.queue")
    private let visionQueue = DispatchQueue(label: "camera.vision.queue")
    private var isConfigured = false
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let poseStateQueue = DispatchQueue(label: "camera.pose.state.queue")
    nonisolated(unsafe) private var lastPoseTimestamp: CFTimeInterval = 0
    nonisolated(unsafe) private let poseRequest = VNDetectHumanBodyPoseRequest()
    private lazy var photoCaptureDelegate = PhotoCaptureDelegate { [weak self] image in
        DispatchQueue.main.async {
            guard let self else { return }
            if let image {
                let normalized = image.normalizedOrientation()
                self.capturedImage = cropToAspect(normalized) ?? normalized
            } else {
                self.capturedImage = nil
                self.errorMessage = "撮影に失敗しました"
            }
        }
    }

    func updatePreviewLayer(_ layer: AVCaptureVideoPreviewLayer) {
        previewLayer = layer
        layer.videoGravity = .resizeAspectFill
    }

    func finalizeCapturedImage(_ image: UIImage) -> UIImage {
        let normalized = image.normalizedOrientation()
        return cropToAspect(normalized) ?? normalized
    }

    private func cropToAspect(_ image: UIImage) -> UIImage? {
        let ratio = CGFloat(9.0 / 16.0)
        return image.croppedToAspectRatio(ratio)
    }

    override init() {
        super.init()
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
            if let connection = self.photoOutput.connection(with: .video) {
                if connection.isVideoRotationAngleSupported(90) {
                    connection.videoRotationAngle = 90
                }
                connection.isVideoMirrored = true
            }
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
            position: .front
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

        if session.canAddOutput(videoOutput) {
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            videoOutput.setSampleBufferDelegate(self, queue: visionQueue)
            session.addOutput(videoOutput)
        }
    }
}

extension CameraSessionModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
        let shouldProcess = poseStateQueue.sync { () -> Bool in
            if timestamp - lastPoseTimestamp < 0.1 {
                return false
            }
            lastPoseTimestamp = timestamp
            return true
        }
        guard shouldProcess else { return }

        let handler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: .rightMirrored, options: [:])
        do {
            try handler.perform([poseRequest])
            guard let observation = poseRequest.results?.first else {
                Task { @MainActor in
                    self.currentPoseAngles = nil
                }
                return
            }
            let angles = PoseAngleScorer.angles(from: observation)
            Task { @MainActor in
                self.currentPoseAngles = angles
            }
        } catch {
            Task { @MainActor in
                self.currentPoseAngles = nil
            }
        }
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
        Task { @MainActor in
            completion(image.normalizedOrientation())
        }
    }
}

private extension UIImage {
    @MainActor
    func normalizedOrientation() -> UIImage {
        if imageOrientation == .up {
            return self
        }
        let targetSize: CGSize
        switch imageOrientation {
        case .left, .right, .leftMirrored, .rightMirrored:
            targetSize = CGSize(width: size.height, height: size.width)
        default:
            targetSize = size
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let normalized = renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return normalized
    }

    func croppedToAspectRatio(_ targetRatio: CGFloat) -> UIImage {
        let imageSize = size
        guard imageSize.width > 0, imageSize.height > 0 else { return self }

        let currentRatio = imageSize.height / imageSize.width
        var cropRect = CGRect(origin: .zero, size: imageSize)

        if currentRatio > targetRatio {
            let newHeight = imageSize.width * targetRatio
            let y = (imageSize.height - newHeight) / 2
            cropRect = CGRect(x: 0, y: y, width: imageSize.width, height: newHeight)
        } else if currentRatio < targetRatio {
            let newWidth = imageSize.height / targetRatio
            let x = (imageSize.width - newWidth) / 2
            cropRect = CGRect(x: x, y: 0, width: newWidth, height: imageSize.height)
        }

        guard let cgImage = cgImage?.cropping(to: cropRect) else { return self }
        return UIImage(cgImage: cgImage, scale: scale, orientation: imageOrientation)
    }
}

struct CameraPreview: UIViewRepresentable {
    let camera: CameraSessionModel

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.videoGravity = .resizeAspectFill
        view.previewLayer.session = camera.session
        camera.updatePreviewLayer(view.previewLayer)
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.previewLayer.session = camera.session
        camera.updatePreviewLayer(uiView.previewLayer)
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
