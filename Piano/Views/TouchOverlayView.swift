import SwiftUI
import UIKit

struct TouchOverlayView: UIViewRepresentable {
    var padCenters: [CGPoint]
    var padRadius: CGFloat

    var onBegan: (_ padIndex: Int, _ touchId: Int, _ point: CGPoint, _ majorRadius: CGFloat) -> Void
    var onMoved: (_ padIndex: Int, _ touchId: Int, _ current: CGPoint, _ origin: CGPoint) -> Void
    var onEnded: (_ padIndex: Int, _ touchId: Int) -> Void

    func makeUIView(context: Context) -> PianoTouchUIView {
        let view = PianoTouchUIView()
        view.isMultipleTouchEnabled = true
        view.backgroundColor = .clear
        view.delegate = context.coordinator
        return view
    }

    func updateUIView(_ uiView: PianoTouchUIView, context: Context) {
        uiView.padCenters = padCenters
        uiView.padRadius = padRadius
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: PianoTouchDelegate {
        let parent: TouchOverlayView
        init(_ parent: TouchOverlayView) { self.parent = parent }

        func touchBegan(padIndex: Int, touchId: Int, point: CGPoint, majorRadius: CGFloat) {
            parent.onBegan(padIndex, touchId, point, majorRadius)
        }
        func touchMoved(padIndex: Int, touchId: Int, current: CGPoint, origin: CGPoint) {
            parent.onMoved(padIndex, touchId, current, origin)
        }
        func touchEnded(padIndex: Int, touchId: Int) {
            parent.onEnded(padIndex, touchId)
        }
    }
}

// MARK: - UIView

protocol PianoTouchDelegate: AnyObject {
    func touchBegan(padIndex: Int, touchId: Int, point: CGPoint, majorRadius: CGFloat)
    func touchMoved(padIndex: Int, touchId: Int, current: CGPoint, origin: CGPoint)
    func touchEnded(padIndex: Int, touchId: Int)
}

final class PianoTouchUIView: UIView {
    var padCenters: [CGPoint] = []
    var padRadius: CGFloat = 44
    weak var delegate: PianoTouchDelegate?

    // touch → (padIndex, initialPoint)
    private var activeTouches: [UITouch: (index: Int, origin: CGPoint)] = [:]

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let pt = touch.location(in: self)
            guard let index = closestPad(to: pt) else { continue }
            activeTouches[touch] = (index, pt)
            delegate?.touchBegan(padIndex: index,
                                  touchId: touch.hash,
                                  point: pt,
                                  majorRadius: touch.majorRadius)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            guard let info = activeTouches[touch] else { continue }
            let pt = touch.location(in: self)
            delegate?.touchMoved(padIndex: info.index,
                                  touchId: touch.hash,
                                  current: pt,
                                  origin: info.origin)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        endTouches(touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        endTouches(touches)
    }

    private func endTouches(_ touches: Set<UITouch>) {
        for touch in touches {
            guard let info = activeTouches.removeValue(forKey: touch) else { continue }
            delegate?.touchEnded(padIndex: info.index, touchId: touch.hash)
        }
    }

    private func closestPad(to point: CGPoint) -> Int? {
        var best: (index: Int, dist: CGFloat)?
        for (i, center) in padCenters.enumerated() {
            let dist = hypot(point.x - center.x, point.y - center.y)
            if dist <= padRadius, best == nil || dist < best!.dist {
                best = (i, dist)
            }
        }
        return best?.index
    }
}
