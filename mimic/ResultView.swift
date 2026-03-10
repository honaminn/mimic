import SwiftUI
import UIKit

struct ResultView: View {
    let totalShots: Int
    @State private var sharePayload: SharePayload?
    @State private var shareErrorMessage: String?
    @State private var currentIndex = 0
    @AppStorage("mimic.popToRoot") private var popToRoot = false
    @Environment(\.dismiss) private var dismiss

    init(totalShots: Int = 0) {
        self.totalShots = totalShots
    }

    var body: some View {
        ZStack {
            Color(red: 1.0, green: 0.95, blue: 0.88)
                .ignoresSafeArea()

            VStack(spacing: 22) {
                HStack {
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.95))
                            .frame(width: 44, height: 44)
                            .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 6)
                        Button {
                            popToRoot = true
                            dismiss()
                        } label: {
                            Image(systemName: "checkmark")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(.black)
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 26)

                let photoSize = CGSize(width: 320, height: 480)
                if photoURLs.isEmpty {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.black.opacity(0.12))
                        .frame(width: photoSize.width, height: photoSize.height)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(.white.opacity(0.6), lineWidth: 8)
                        )
                } else {
                    TabView(selection: $currentIndex) {
                        ForEach(Array(photoURLs.enumerated()), id: \.offset) { index, url in
                            ZStack {
                                if let image = UIImage(contentsOfFile: url.path) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                } else {
                                    Color.black.opacity(0.12)
                                }
                            }
                            .frame(width: photoSize.width, height: photoSize.height)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(.white.opacity(0.6), lineWidth: 8)
                            )
                            .tag(index)
                        }
                    }
                    .frame(width: photoSize.width, height: photoSize.height)
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }

                HStack(spacing: 10) {
                    let count = max(photoURLs.count, 1)
                    ForEach(0..<count, id: \.self) { index in
                        Circle()
                            .fill(index == currentIndex ? .black.opacity(0.85) : .black.opacity(0.2))
                            .frame(width: 6, height: 6)
                    }
                }

                Spacer()

                HStack {
                    Spacer()
                    Button {
                        if let item = shareItemForCurrentIndex() {
                            sharePayload = SharePayload(items: [item])
                        } else {
                            shareErrorMessage = "共有できる写真が見つかりませんでした"
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.black)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 26)
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .sheet(item: $sharePayload) { payload in
            ActivityView(activityItems: payload.items)
        }
        .alert("共有エラー", isPresented: .constant(shareErrorMessage != nil)) {
            Button("OK") {
                shareErrorMessage = nil
            }
        } message: {
            Text(shareErrorMessage ?? "")
        }
    }

    private var photoURLs: [URL] {
        SessionPhotoStore.loadPhotos()
    }

    private func shareItemForCurrentIndex() -> Any? {
        guard !photoURLs.isEmpty else { return nil }
        let index = min(max(currentIndex, 0), photoURLs.count - 1)
        let url = photoURLs[index]
        if let image = UIImage(contentsOfFile: url.path) {
            return image
        }
        return url
    }

}

struct SharePayload: Identifiable {
    let id = UUID()
    let items: [Any]
}

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct ResultView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ResultView(totalShots: 10)
        }
    }
}
