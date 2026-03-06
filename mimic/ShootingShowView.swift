//
//  ShootingShowView.swift
//  mimic
//
//  Created by honamiNAKASUJI on 2026/03/05.
//

import SwiftUI
import UIKit

struct ShootingShowView: View {
    let selectedTags: Set<String>
    let totalShots: Int
    let nextShot: Int
    let previousPose: PoseGuide
    let capturedImage: UIImage

    @State private var navigateToNextPose = false
    @State private var navigateToResult = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.92)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                Image(uiImage: capturedImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 20)

                Text("撮影完了")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                Text("次のポーズに移動します")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.bottom, 20)
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .navigationBarBackButtonHidden(true)
        .navigationDestination(isPresented: $navigateToNextPose) {
            if nextShot <= totalShots {
                ModelPoseView(
                    selectedTags: selectedTags,
                    totalShots: totalShots,
                    currentShot: nextShot,
                    previousPose: previousPose
                )
            }
        }
        .navigationDestination(isPresented: $navigateToResult) {
            ResultView(totalShots: totalShots)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                if nextShot <= totalShots {
                    navigateToNextPose = true
                } else {
                    navigateToResult = true
                }
            }
        }
    }
}

struct ShootingShowView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ShootingShowView(
                selectedTags: ["cute", "cool"],
                totalShots: 10,
                nextShot: 6,
                previousPose: PoseGuide(name: "ダブルピース", symbol: "hand.victory.fill"),
                capturedImage: UIImage(systemName: "photo") ?? UIImage()
            )
        }
    }
}
