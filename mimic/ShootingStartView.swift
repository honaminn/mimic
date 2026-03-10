//
//  ShootingStartView.swift
//  mimic
//
//  Created by honamiNAKASUJI on 2026/03/05.
//

import SwiftUI

struct ShootingStartView: View {
    let selectedTags: Set<String>
    let totalShots: Int
    @State private var navigateToModelPose = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("撮影開始")
                .font(.title2)
                .fontWeight(.bold)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 1.0, green: 0.95, blue: 0.88))
        .navigationTitle("スタート")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .navigationDestination(isPresented: $navigateToModelPose) {
            ModelPoseView(selectedTags: selectedTags, totalShots: totalShots, currentShot: 1)
        }
        .onAppear {
            guard !navigateToModelPose else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                navigateToModelPose = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .mimicPopToRoot)) { _ in
            dismiss()
        }
    }
}

struct ShootingStartView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ShootingStartView(selectedTags: ["cute"], totalShots: 8)
        }
    }
}
