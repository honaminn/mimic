//
//  ModelPoseView.swift
//  mimic
//
//  Created by honamiNAKASUJI on 2026/03/05.
//

import SwiftUI
import Combine

struct ModelPoseView: View {
    let selectedTags: Set<String>
    let totalShots: Int
    let currentShot: Int
    let previousPose: PoseGuide?

    @State private var selectedPose: PoseGuide = PoseGuideCatalog.fallback
    @State private var progress: Double = 1.0
    @State private var navigateToShootingMain = false
    @State private var countdownStartDate: Date?
    @State private var isCountingDown = false
    @Environment(\.dismiss) private var dismiss

    private let totalDuration: TimeInterval = 3.0
    private let countdownTimer = Timer.publish(every: 0.03, on: .main, in: .common).autoconnect()

    init(selectedTags: Set<String>, totalShots: Int, currentShot: Int = 1, previousPose: PoseGuide? = nil) {
        self.selectedTags = selectedTags
        self.totalShots = totalShots
        self.currentShot = currentShot
        self.previousPose = previousPose
    }

    var body: some View {
        VStack(spacing: 24) {
            poseImage(for: selectedPose)
                .frame(width: 180, height: 180)
                .padding(24)
                .background(Color.white.opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 20))

            Text(selectedPose.name)
                .font(.title2)
                .fontWeight(.bold)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.gray.opacity(0.25))
                    .frame(height: 10)

                GeometryReader { geometry in
                    Capsule()
                        .fill(Color.blue)
                        .frame(width: geometry.size.width * progress, height: 10)
                }
            }
            .frame(height: 10)
            .frame(maxWidth: 280)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 1.0, green: 0.95, blue: 0.88))
        .navigationTitle("モデルポーズ")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .navigationDestination(isPresented: $navigateToShootingMain) {
            ShootingMainView(
                selectedTags: selectedTags,
                currentShot: currentShot,
                totalShots: totalShots,
                referencePose: selectedPose
            )
        }
        .onAppear {
            selectedPose = PoseGuideCatalog.pick(from: selectedTags, excluding: previousPose)
            progress = 1.0
            countdownStartDate = Date()
            isCountingDown = true
        }
        .onReceive(countdownTimer) { _ in
            guard isCountingDown, let startDate = countdownStartDate else { return }
            let elapsed = Date().timeIntervalSince(startDate)
            let remaining = max(0, totalDuration - elapsed)
            progress = remaining / totalDuration

            if remaining <= 0 {
                isCountingDown = false
                navigateToShootingMain = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .mimicPopToRoot)) { _ in
            dismiss()
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
}

struct ModelPoseView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ModelPoseView(selectedTags: ["cute", "cool"], totalShots: 10, currentShot: 5)
        }
    }
}
