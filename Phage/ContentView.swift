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
        NavigationView {
            List {
                HStack(alignment: .firstTextBaseline) {
                    Text("Bundles").font(.title).bold()
                    Spacer()
                    Button(action: {
                        NSWorkspace.shared.open(bundlesURL)
                    }) {
                        Text("Show in Finder")
                    }
                }
                ForEach(sortedBundles()) { bundle in
                    NavigationLink(destination: ExtractedView(dependencies: self.data.dependencies, bundle: bundle)) {
                        HStack {
                            Toggle(isOn: .constant(true)) {
                                EmptyView()
                            }.frame(width: 24)
                            VStack(alignment: .leading) {
                                Text(bundle.url.lastPathComponent)
                                Text("Files: \(bundle.files.count)").foregroundColor(.gray)
                            }
                        }
                    }
                }
                if data.bundles.count == 0 {
                    HStack {
                        Spacer()
                        Text("No bundles").foregroundColor(.gray)
                        Spacer()
                    }
                }
            }
        }
    }
}

struct ExtractedView : View {
    var dependencies: PhageDependencies
    var bundle: PhageDataBundle

    var body: some View {
        List {
            Text(bundle.url.lastPathComponent).font(.title).bold()
            Spacer()

            Text("Files").font(.headline).bold()
            ForEach(Array(bundle.files.values)) { item in
                Text(item.url.lastPathComponent)
            }
            Spacer()

            Text("Dependencies").font(.headline).bold()
            ForEach(bundle.dependencies().map { IdURL($0) }) { item in
                DependencyView(dependencies: self.dependencies, url: item.url)
            }
        }
    }
}

struct DependencyView : View {
    var dependencies: PhageDependencies
    var url: URL

    @State var loading = false
    @State var loaded = false

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(url.lastPathComponent)
                Text(url.absoluteString).font(Font.system(size: 10))
            }
            Spacer()
            if loading {
                Text("(Loading)")
            } else if loaded {
                Text("(Loaded)")
            }
        }.tapAction {
            debugPrint("Loading dependency \(self.url)")
            self.loading = true
            self.dependencies.loadDependency(at: self.url) { data in
                if data != nil {
                    debugPrint("Loaded")
                    self.loaded = true
                    self.loading = false
                } else {
                    debugPrint("Failed to load")
                    self.loading = false
                }
            }
        }.onAppear {
            self.loaded = self.dependencies.getDependencyContents(of: self.url) != nil
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

class IdURL : Identifiable {
    var url: URL

    var id: String {
        return url.absoluteString
    }

    init(_ url: URL) {
        self.url = url
    }
}
