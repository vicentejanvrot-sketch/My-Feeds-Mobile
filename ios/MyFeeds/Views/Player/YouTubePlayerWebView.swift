import SwiftUI
import WebKit

/// Commands sent from Swift to the embedded YouTube IFrame player.
@Observable
final class YouTubePlayerController {
    fileprivate weak var webView: WKWebView?

    var isReady = false
    var isPlaying = false
    var currentTime: Double = 0
    var duration: Double = 0
    var didEnd = false
    var loadFailed = false

    var onReady: (() -> Void)?
    var onEnded: (() -> Void)?
    var onFirstPlay: (() -> Void)?
    fileprivate var firedFirstPlay = false

    private func evaluate(_ js: String) {
        webView?.evaluateJavaScript(js, completionHandler: nil)
    }

    func play() { evaluate("player.playVideo();") }
    func pause() { evaluate("player.pauseVideo();") }
    func togglePlayback() {
        // Query the IFrame directly instead of relying on the asynchronously
        // mirrored Swift state, which can lag behind the actual player.
        evaluate("""
        (function() {
          if (!player || !player.getPlayerState) return;
          if (player.getPlayerState() === 1) player.pauseVideo();
          else player.playVideo();
        })();
        """)
    }
    func seek(to seconds: Double) { evaluate("player.seekTo(\(seconds), true);") }
    func skip(_ delta: Double) {
        let target = max(0, min(currentTime + delta, duration > 0 ? duration : .greatestFiniteMagnitude))
        seek(to: target)
    }
    func setRate(_ rate: Double) { evaluate("player.setPlaybackRate(\(rate));") }
    func setQuality(_ quality: String) { evaluate("player.setPlaybackQuality('\(quality)');") }
    func mute() { evaluate("player.mute();") }
    func unmute() { evaluate("player.unMute();") }
    func setVolume(_ volume: Int) { evaluate("player.setVolume(\(max(0, min(volume, 100))));") }
}

/// WKWebView hosting the YouTube IFrame API with a JS→Swift bridge.
struct YouTubePlayerWebView: UIViewRepresentable {
    let videoId: String
    let controller: YouTubePlayerController

    func makeCoordinator() -> Coordinator {
        Coordinator(controller: controller)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.userContentController.add(context.coordinator, name: "bridge")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false

        controller.webView = webView
        webView.loadHTMLString(html, baseURL: URL(string: "https://www.youtube.com"))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "bridge")
    }

    private var html: String {
        """
        <!DOCTYPE html><html><head>
        <meta name="viewport" content="initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
        <style>html,body{margin:0;padding:0;background:#000;height:100%;overflow:hidden}
        #player{position:absolute;top:0;left:0;width:100%;height:100%}</style>
        </head><body>
        <div id="player"></div>
        <script src="https://www.youtube.com/iframe_api"></script>
        <script>
        var player;
        function post(msg){window.webkit.messageHandlers.bridge.postMessage(msg);}
        function onYouTubeIframeAPIReady(){
          player = new YT.Player('player', {
            videoId: '\(videoId)',
            playerVars: {controls:0, playsinline:1, rel:0, modestbranding:1, fs:0, disablekb:1, cc_load_policy:0, iv_load_policy:3},
            events: {
              onReady: function(){
                disableCaptions();
                setTimeout(disableCaptions, 500);
                post({event:'ready', duration: player.getDuration()});
              },
              onStateChange: function(e){
                disableCaptions();
                post({event:'state', state: e.data});
              },
              onError: function(e){ post({event:'error', code: e.data}); }
            }
          });
        }
        function disableCaptions(){
          if(!player) return;
          try { player.unloadModule('captions'); } catch(e) {}
        }
        setInterval(function(){
          if(player && player.getCurrentTime){
            post({event:'time', time: player.getCurrentTime(), duration: player.getDuration()});
          }
        }, 500);
        </script>
        </body></html>
        """
    }

    final class Coordinator: NSObject, WKScriptMessageHandler {
        let controller: YouTubePlayerController

        init(controller: YouTubePlayerController) {
            self.controller = controller
        }

        nonisolated func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard let body = message.body as? [String: Any],
                  let event = body["event"] as? String else { return }
            let time = body["time"] as? Double
            let duration = body["duration"] as? Double
            let state = body["state"] as? Int

            Task { @MainActor [controller] in
                switch event {
                case "ready":
                    controller.isReady = true
                    if let duration { controller.duration = duration }
                    controller.onReady?()
                case "time":
                    if let time { controller.currentTime = time }
                    if let duration, duration > 0 { controller.duration = duration }
                case "state":
                    guard let state else { return }
                    switch state {
                    case 1:
                        controller.isPlaying = true
                        if !controller.firedFirstPlay {
                            controller.firedFirstPlay = true
                            controller.onFirstPlay?()
                        }
                    case 2, 5, -1:
                        controller.isPlaying = false
                    case 0:
                        controller.isPlaying = false
                        if !controller.didEnd {
                            controller.didEnd = true
                            controller.onEnded?()
                        }
                    default:
                        break
                    }
                case "error":
                    controller.loadFailed = true
                default:
                    break
                }
            }
        }
    }
}
