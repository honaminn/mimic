import Foundation
import SwiftUI

struct SettingView: View {
    // --- 1. 変数（データの置き場所） ---
    @State var sliderValue: Double = 5.0
    @State var people = 1
    @State private var isOn = false
    @State private var showShootingFlow = false
    // ここで複数選択したタグを保存します
    @State private var selectedTags: Set<String> = []

    var body: some View {
        ZStack {
            NavigationStack {
                GeometryReader { geometry in
                    ScrollView {
                        let sectionGap = max(20, geometry.size.height * 0.06)

                        VStack(spacing: 30) {
                            // 枚数設定
                            HStack(alignment: .center, spacing: 20) {
                                VStack {
                                    Image(systemName: "camera.fill")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 80, height: 80)
                                        .foregroundStyle(.tint)
                                    Text("何枚撮る？")
                                }
                                .padding(.horizontal, 25)

                                VStack(spacing: 8) {
                                    Slider(
                                        value: $sliderValue,
                                        in: 3...10,
                                        step: 1,
                                        minimumValueLabel: Text("3"),
                                        maximumValueLabel: Text("10")
                                    ) {
                                        Text("枚数")
                                    }

                                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                                        Text("\(Int(sliderValue))")
                                            .font(.system(size: 34, weight: .bold))
                                        Text("枚")
                                            .font(.subheadline)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                            }

                            Color.clear.frame(height: sectionGap)

                            // 人数設定
                        

                            // ポーズ設定
                            HStack(alignment: .top, spacing: 15) {
                                VStack {
                                    Image(systemName: "person.crop.rectangle.fill")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 80, height: 80)
                                        .foregroundStyle(.tint)
                                    Text("ポーズは？")
                                }

                                Spacer()

                                VStack(alignment: .leading, spacing: 10) {
                                  

                                    Text("カテゴリ")
                                        .font(.body)

                                    VStack {
                                        HStack {
                                            // ここで下の関数を呼び出しています
                                            poseChip(title: "cute")
                                            poseChip(title: "cool")
                                        }
                                        HStack {
                                            poseChip(title: "funny")
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 25)

                        }
                        .frame(minHeight: geometry.size.height, alignment: .top)
                        .padding(.top, 20)
                        .padding(20)
                    }
                }
                .navigationTitle("設定")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("スタート") {
                            var transaction = Transaction()
                            transaction.animation = nil
                            withTransaction(transaction) {
                                showShootingFlow = true
                            }
                        }
                        .fontWeight(.semibold)
                    }
                }
                .background(Color(red: 1.0, green: 0.95, blue: 0.88))
            }
            .allowsHitTesting(!showShootingFlow)

            if showShootingFlow {
                NavigationStack {
                    ShootingStartView(selectedTags: selectedTags, totalShots: Int(sliderValue))
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .mimicPopToRoot)) { _ in
            var transaction = Transaction()
            transaction.animation = nil
            withTransaction(transaction) {
                showShootingFlow = false
            }
        }
    } // body の終わり

    // --- 2. チップスを作る関数（SettingView のカッコの内側に書くのがポイント！） ---
    func poseChip(title: String) -> some View {
        let isSelected = selectedTags.contains(title)
        
        return Button(action: {
            if isSelected {
                selectedTags.remove(title)
            } else {
                selectedTags.insert(title)
            }
        }) {
            HStack(spacing: 4) {
                if isSelected {
                    Image(systemName: "checkmark")
                }
                Text(title)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue : Color.gray.opacity(0.2))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
    }
} // ★ SettingView 本体の閉じカッコ

struct SettingView_Previews: PreviewProvider {
    static var previews: some View {
        SettingView()
    }
}
