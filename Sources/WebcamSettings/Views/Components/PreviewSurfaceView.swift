import AVFoundation
import AppKit
import SwiftUI

struct PreviewSurfaceView: NSViewRepresentable {
    let session: AVCaptureSession?

    func makeNSView(context _: Context) -> PreviewContainerView {
        let view = PreviewContainerView()
        view.layer?.cornerRadius = 14
        view.layer?.masksToBounds = true
        return view
    }

    func updateNSView(_ nsView: PreviewContainerView, context _: Context) {
        nsView.previewLayer.session = session
    }
}

final class PreviewContainerView: NSView {
    let previewLayer = AVCaptureVideoPreviewLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        layer = CALayer()
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.85).cgColor

        previewLayer.videoGravity = .resizeAspect
        previewLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        layer?.addSublayer(previewLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        previewLayer.frame = bounds
    }
}
