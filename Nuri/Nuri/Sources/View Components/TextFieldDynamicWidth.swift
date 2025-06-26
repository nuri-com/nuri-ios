import SwiftUI

struct TextFieldDynamicWidth<T: CustomStringConvertible>: View {
    let title: String
    @Binding var text: T
    let formatter: Formatter

    @State private var textRect = CGRect()

    var body: some View {
        ZStack {
            Text(text.description == "" ? title : text.description)
                .background(GlobalGeometryGetter(rect: $textRect))
                .layoutPriority(1)
                .opacity(0)
            TextField(title, value: $text, formatter: formatter)
                .frame(width: textRect.width)
        }
    }
}

struct GlobalGeometryGetter: View {
    @Binding var rect: CGRect

    var body: some View {
        return GeometryReader { geometry in
            self.makeView(geometry: geometry)
        }
    }

    func makeView(geometry: GeometryProxy) -> some View {
        DispatchQueue.main.async {
            self.rect = geometry.frame(in: .global)
        }
        return Rectangle().fill(Color.clear)
    }
}
