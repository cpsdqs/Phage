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
    @ObservedObject var data = PhageData()

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
                    NavigationLink(
                        destination:
                            BundleView(dependencies: self.data.dependencies, bundle: bundle)
                                .frame(minWidth: 300)
                    ) {
                        HStack {
                            Toggle(isOn: .constant(true)) {
                                EmptyView()
                            }.frame(width: 24)
                            VStack(alignment: .leading) {
                                Text(bundle.url.lastPathComponent)
                                Text("Files: \(bundle.files.count)").foregroundColor(.secondary)
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
            }.frame(width: 300)
        }
    }
}

struct BundleView : View {
    private struct MaybeNone : View {
        var count: Int
        var text: String
        var body: some View {
            if count == 0 {
                return AnyView(Text(text).frame(maxWidth: .infinity).padding(.bottom))
            } else {
                return AnyView(EmptyView())
            }
        }
    }

    var dependencies: PhageDependencies
    var bundle: PhageDataBundle

    var body: some View {
        List {
            Text(bundle.url.lastPathComponent).font(.title).bold().padding(.top)
            Spacer()

            Text("Files").font(.headline).bold()
            MaybeNone(count: bundle.files.count, text: "No files")
            ForEach(Array(bundle.files.values)) { item in
                BundleFileView(file: item)
            }
            Spacer()

            Text("Dependencies").font(.headline).bold()
            MaybeNone(count: bundle.dependencies().count, text: "No dependencies")
            ForEach(bundle.dependencies().map { IdURL($0) }) { item in
                DependencyView(dependencies: self.dependencies, url: item.url)
            }
        }
    }
}

struct BundleFileView : View {
    var file: PhageDataFile

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(file.url.lastPathComponent).bold()
                Spacer()
                Button(action: {
                    NSWorkspace.shared.openFile(self.file.url.path)
                }) {
                    Text("Edit")
                }
            }
            FileContents(contents: file.contents())
        }.padding()
            .background(Color(NSColor.controlBackgroundColor).cornerRadius(8))
    }
}

private struct ForEachIdTag<T> {
    var id: Int
    var data: T
}

struct FileContents : View {
    var contents: PhageDataFile.Contents?
    var body: some View {
        switch contents {
        case .none:
            return AnyView(Text("could not read file contents").foregroundColor(.secondary))
        case .some(.javascript(let section)):
            return AnyView(SectionView(section: section))
        case .some(.stylesheets(let sections)):
            if sections.isEmpty {
                return AnyView(Text("no stylesheet sections").foregroundColor(.secondary))
            }
            return AnyView(VStack(alignment: .leading) {
                ForEach(sections.enumerated().map({ (i, s) in ForEachIdTag(id: i, data: s) }), id: \.id) { item in
                    SectionView(stylesheetNumber: item.id + 1, section: item.data)
                }
            })
        }
    }
}

struct SectionView : View {
    private struct Title: View {
        var number: Int?
        var body: some View {
            if let number = number {
                return Text("Stylesheet Section #\(number)")
            } else {
                return Text("Script")
            }
        }
    }

    var stylesheetNumber: Int?
    var section: PhageCore.Section

    var body: some View {
        VStack(alignment: .leading) {
            Title(number: stylesheetNumber)
            VStack(alignment: .leading) {
                ForEach(section.rules.enumerated().map({ (i, s) in ForEachIdTag(id: i, data: s) }), id: \.id) { rule in
                    SectionMatchRule(rule: rule.data)
                }
            }.padding(.leading).padding(.top, 4)
        }
    }
}

struct SectionMatchRule : View {
    private struct Tag : View {
        var text: String
        var body: some View {
            Text(text)
                .font(.system(size: 10))
                .padding(2)
                .cornerRadius(4)
                .background(Color(NSColor.windowBackgroundColor).cornerRadius(4))
        }
    }
    private struct Value : View {
        var value: String
        var body: some View {
            Text(value)
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .padding(2)
        }
    }

    var rule: PhageCore.MatchRule

    var body: some View {
        switch rule {
        case .domain(let domain):
            return HStack { Tag(text: "Domain"); Value(value: domain) }
        case .exact(let exact):
            return HStack { Tag(text: "Exact"); Value(value: exact) }
        case .glob(let glob):
            return HStack { Tag(text: "Glob"); Value(value: glob) }
        case .prefix(let prefix):
            return HStack { Tag(text: "Prefix"); Value(value: prefix) }
        case .regexp(let regexp):
            return HStack { Tag(text: "RegExp"); Value(value: regexp) }
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
                Text("Loading")
            } else if loaded {
                Text("Loaded")
            }
        }.onTapGesture {
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
