import SwiftUI
import AVFoundation
import Combine
import UIKit

struct ShootingMainView: View {
    @StateObject private var camera = CameraSessionModel()

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
            }
        }
        .onAppear {
            camera.start()
        }
        .onDisappear {
            camera.stop()
        }
    }
}

final class CameraSessionModel: ObservableObject {
    let session = AVCaptureSession()

    @Published var permissionDenied = false
    @Published var errorMessage: String?

    private let queue = DispatchQueue(label: "camera.session.queue")
    private var isConfigured = false

    func start() {
        checkPermissionAndStart()
    }

    func stop() {
        queue.async {
            guard self.session.isRunning else { return }
            self.session.stopRunning()
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
        ShootingMainView()
    }
}
