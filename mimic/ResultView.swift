import SwiftUI

struct ResultView: View {
    let totalShots: Int

    init(totalShots: Int = 0) {
        self.totalShots = totalShots
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("撮影完了")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("\(totalShots)枚の撮影が完了しました")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 1.0, green: 0.95, blue: 0.88))
        .navigationTitle("結果")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
}

struct ResultView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ResultView(totalShots: 10)
        }
    }
}
