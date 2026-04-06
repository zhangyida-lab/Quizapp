//
//  ContentView 2.swift
//  swiftUI Practice
//
//  Created by tony on 4/5/26.
//


//
//  ContentView.swift
//  swiftUI Practice
//
//  Created by tony on 4/4/26.
//

import SwiftUI
var name = "zhangsan"

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
            Text(verbatim: "zhangsan de ceshi nizhidao ma \(name) ")
          
        }
        .padding()
    }
}

struct ChildView: View {
    var body: some View {
        VStack {
            Text("zhangsan")
            
        }
    }
}

#Preview {
    ChildView()
}
