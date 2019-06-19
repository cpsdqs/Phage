//
//  ContentView.swift
//  Phage
//
//  Created by cpsdqs on 2019-06-17.
//  Copyright © 2019 cpsdqs. All rights reserved.
//

import SwiftUI
import PhageCore

struct ContentView : View {
    @ObjectBinding var data = PhageData()

    private func sortedBundles() -> [PhageDataBundle] {
        return data.bundles.sorted(by: { (arg0, arg1) -> Bool in
            let (lhs, _) = arg0
            let (rhs, _) = arg1
            return lhs.lexicographicallyPrecedes(rhs)
        }).map({ (arg0) -> PhageDataBundle in
            let (_, value) = arg0
            return value
        })
    }

    var body: some View {
        List {
            HStack(alignment: .firstTextBaseline) {
                Text("Bundles").font(.title).bold()
                Spacer()
                Button(action: {
                    NSWorkspace.shared.open(self.data.containerURL)
                }) {
                    Text("Show in Finder")
                }
            }
            ForEach(sortedBundles()) { bundle in
                Toggle(isOn: .constant(true)) {
                    VStack(alignment: .leading) {
                        Text(bundle.url.lastPathComponent)
                        Text("Files: \(bundle.files.count)").color(.gray)
                    }
                }
            }
            if data.bundles.count == 0 {
                HStack {
                    Spacer()
                    Text("No bundles").color(.gray)
                    Spacer()
                }
            }
        }
    }
}


#if DEBUG
struct ContentView_Previews : PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif
