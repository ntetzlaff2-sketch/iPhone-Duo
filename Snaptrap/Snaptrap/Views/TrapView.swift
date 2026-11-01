import SwiftUI

/// The open device: two leaves on either side of the fold, bugs, and the HUD.
struct TrapView: View {
    let game: GameModel
    let reading: HingeReading
    let isArmed: Bool
    var virtualHinge: VirtualHinge?

    var body: some View {
        GeometryReader { proxy in
            // 👇 The fold itself. Include it while inactive so the leaves are ready before the device bends.
            let fold = proxy.reservedRegions(kind: .division, options: [.includeInactive]).first?.frame
            let layout = TrapLayout(screenSize: proxy.size, fold: fold)

            ZStack {
                Canvas { context, _ in
                    TrapRenderer(game: game, layout: layout, closure: reading.closure)
                        .draw(in: &context)
                }
                .offset(shake(for: layout))
                .accessibilityLabel("Flytrap leaves")

                TrapHUD(game: game, layout: layout, reading: reading, isArmed: isArmed)
            }
            .onChange(of: layout, initial: true) { _, newLayout in
                game.layout = newLayout
            }
        }
        .ignoresSafeArea()
        .overlay(alignment: .bottom) {
            if let virtualHinge {
                VirtualHingePanel(hinge: virtualHinge)
                    .padding(.bottom, 12)
            }
        }
    }

    /// The whole swamp jolts across the fold when the jaws slam.
    private func shake(for layout: TrapLayout) -> CGSize {
        guard let t = game.snapFlash else { return .zero }
        let amount = 12 * (1 - t) * sin(t * 60)
        return layout.isRotated ? CGSize(width: 0, height: amount) : CGSize(width: amount, height: 0)
    }
}
