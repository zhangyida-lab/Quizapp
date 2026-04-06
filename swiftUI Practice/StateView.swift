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


struct StateView: View {
    @State var value:Int = 0
    var body: some View {
        VStack {
            
            Text("\(value)")
            Text(verbatim: "zhangsan de ceshi nizhidao ma ")
            HStack{
                Button("+"){
                    value += 1
                }
                Button("-"){
                    value -= 1
                }
                .padding()
            }
            .padding()
            
          
        }
        .padding()
    }
}

#Preview {
    StateView()
}
