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


struct BindingView: View {
    @State var title: String = "zhangsan"
    var body: some View {
        VStack {
            Text(title)
            BindingChildView(title: $title)
        }
        .padding()
    }
}

struct BindingChildView: View {
    @Binding var title:String
    var body: some View {
        Button("click me"){
            title = "how are you"
        }
    }
}

#Preview {
    BindingView()
}
