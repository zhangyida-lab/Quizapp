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
@Observable
class ViewModel {
    var counter = 0
    var text = "hello yida"
}

struct ObserableView: View {
    @State var viewModel = ViewModel()
    var body: some View {
        VStack {
            Text(viewModel.text)
                .font(.title)
            Text("\(viewModel.counter)")
            Button("clickMe"){
                viewModel.counter += 1
                viewModel.text = "zhangsan"
            }
          
        }
        .padding()
    }
}

#Preview {
    ObserableView()
}
