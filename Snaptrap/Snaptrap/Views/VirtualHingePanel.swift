import SwiftUI

/// Controls for the virtual hinge, shown only on devices without a real one.
struct VirtualHingePanel: View {
    @Bindable var hinge: VirtualHinge

    var body: some View {
        VStack(spacing: 10) {
            Label("No hinge here, so here's a virtual one", systemImage: "book.closed")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                Image(systemName: "book.closed")
                Slider(value: $hinge.degrees, in: 0...180)
                    .frame(width: 180)
                Text("\(Int(hinge.degrees))°")
                    .monospacedDigit()
                    .frame(width: 44, alignment: .trailing)
                Image(systemName: "book")
            }
            HStack(spacing: 12) {
                Button("Snap!", systemImage: "bolt.fill") { hinge.snap() }
                    .buttonStyle(.borderedProminent)
                Button("Close", systemImage: "iphone") { hinge.close() }
                    .buttonStyle(.bordered)
            }
            .tint(Theme.leaf)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 22))
    }
}
