//
//  MainView.swift
//  mimic
//
//  Created by honamiNAKASUJI on 2026/03/05.
//

import Foundation
import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 1
    var body: some View {
        TabView(selection: $selectedTab) {
            
            Tab("Shoot", systemImage: "camera", value:1){
                SettingView()
            }
            Tab("Album", systemImage: "photo",value:2){
                AlbumView()
            }
            
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
