import YoutubeIframe, { YoutubeIframeRef } from "react-native-youtube-iframe";
import React, { useRef, useImperativeHandle, forwardRef, useCallback, useState } from "react";
import { View } from "react-native";
import type WebView from "react-native-webview";

// ── Public ref API ─────────────────────────────────────────────────

export interface VideoPlayerHandle {
  /** Inject a YouTube IFrame API call into the player. */
  inject: (js: string) => void;
  /** Returns the current playback position in seconds. */
  getCurrentTime: () => Promise<number>;
  /** Returns the total video duration in seconds. */
  getDuration: () => Promise<number>;
  /** Request the player to enter fullscreen (handled by parent via orientation + layout on native). */
  requestFullscreen: () => Promise<void>;
  /** Exit fullscreen if currently active. */
  exitFullscreen: () => Promise<void>;
  /** Start or resume playback. */
  play: () => Promise<void>;
  /** Pause playback. */
  pause: () => Promise<void>;
  /** Seek to a specific time in seconds. */
  seekTo: (seconds: number) => Promise<void>;
  /** Set playback volume (0–100). No-op on native; controlled via device buttons. */
  setVolume: (volume: number) => Promise<void>;
  /** Mute audio. No-op on native. */
  mute: () => Promise<void>;
  /** Unmute audio. No-op on native. */
  unMute: () => Promise<void>;
}

/**
 * Injected JavaScript that adds a supplementary message-event listener
 * so the library's setPlaybackRate / setVolume / mute / unmute are forwarded
 * to the YouTube IFrame API player.
 *
 * Two-pronged approach:
 * 1. Direct handler — listens for message events and calls player.* immediately.
 * 2. Fallback poll — if the direct handler can't reach window.player (timing),
 *    a pending-volume variable is polled every 200ms and applied when the
 *    player becomes available.
 *
 * Also injects a <style> tag to remove default body margins / iframe size
 * constraints that would cause letterboxing on the wrong axis.
 */
const INJECTED_JS = `
(function(){
  var pendingVolume = undefined;
  var pendingMuted = undefined; // true = mute, false = unmute

  function applyToPlayer(fn) {
    if (window.player && typeof window.player.setVolume === 'function') {
      try { fn(window.player); } catch(_) {}
      return true;
    }
    return false;
  }

  function handleMessageEvent(e) {
    try {
      // e.data may be a pre-parsed object on some WebView implementations
      var d = typeof e.data === 'string' ? JSON.parse(e.data) : e.data;
      if (!d || !d.eventName) return;
      switch (d.eventName) {
        case 'setPlaybackRate':
          applyToPlayer(function(p) { p.setPlaybackRate(d.meta.playbackRate); });
          break;
        case 'setVolume':
          pendingVolume = d.meta.volume;
          if (!applyToPlayer(function(p) { p.setVolume(d.meta.volume); })) {
            // Player not ready yet — polling will pick it up
          }
          break;
        case 'muteVideo':
          pendingMuted = true;
          applyToPlayer(function(p) { p.mute(); });
          break;
        case 'unMuteVideo':
          pendingMuted = false;
          applyToPlayer(function(p) { p.unMute(); });
          break;
      }
    } catch(_) {}
  }

  // Listen on both window (iOS) and document (Android) because React Native
  // WebView dispatches postMessage events on different targets per platform.
  window.addEventListener('message', handleMessageEvent);
  document.addEventListener('message', handleMessageEvent);

  // Fallback poll: apply any pending volume/mute change when the player
  // becomes available (covers the gap between message arrival and onReady).
  setInterval(function() {
    if (!window.player || typeof window.player.setVolume !== 'function') return;
    if (pendingVolume !== undefined) {
      try { window.player.setVolume(pendingVolume); } catch(_) {}
      pendingVolume = undefined;
    }
    if (pendingMuted === true) {
      try { window.player.mute(); } catch(_) {}
      pendingMuted = undefined;
    } else if (pendingMuted === false) {
      try { window.player.unMute(); } catch(_) {}
      pendingMuted = undefined;
    }
  }, 200);

  (function enforceFill(){
    var s=document.createElement('style');
    s.textContent='html,body{margin:0!important;padding:0!important;background:#000!important;overflow:hidden!important;width:100%!important;height:100%!important}'+
      ' iframe{display:block!important;width:100%!important;height:100%!important;max-width:100%!important;left:0!important}'+
      ' .ytp-chrome-top,.ytp-chrome-bottom{display:none!important}';
    document.head.appendChild(s);
  })();
  true;
})();
`;

interface VideoPlayerContentProps {
  videoId: string;
  width?: number;
  height?: number;
  playbackRate?: number;
  onReady?: () => void;
  onError?: () => void;
  /** Fires when the YouTube player state changes (playing, paused, ended, etc.). */
  onChangeState?: (event: string) => void;
  /** Fires periodically with the latest currentTime (seconds) and duration (seconds). */
  onProgress?: (currentTime: number, duration: number) => void;
  /** Ignored on native — only meaningful on web to block iframe tap interception. */
  blockIframeTouches?: boolean;
}

/**
 * Renders a YouTube embed inside a native WebView on iOS/Android.
 *
 * Accepts `playbackRate` to control speed and uses `webViewProps`
 * to capture a WebView ref so the parent can inject quality-change
 * JavaScript (`player.setPlaybackQuality('hd1080')` etc.).
 *
 * YouTube's native chrome is hidden (`controls: false`) so the parent
 * can render its own custom transport overlay and progress bar.
 */
const VideoPlayerContent = forwardRef<VideoPlayerHandle, VideoPlayerContentProps>(
  function VideoPlayerContent(
    { videoId, width, height: _height, playbackRate = 1, onReady, onError, onChangeState, onProgress: _onProgress, blockIframeTouches: _blockIframeTouches },
    ref,
  ) {
    const youtubeRef = useRef<YoutubeIframeRef | null>(null);
    /** Direct ref to the underlying WebView so we can inject JavaScript
     *  that calls the YouTube IFrame API player directly. This bypasses
     *  the library's internal postMessage pipe, which is broken in v2.4.x
     *  (see github.com/LonelyCpp/react-native-youtube-iframe/issues/376). */
    const webViewRef = useRef<WebView | null>(null);
    const [shouldPlay, setShouldPlay] = useState(false);
    const [nativeVolume, setNativeVolume] = useState(100);
    const [nativeMuted, setNativeMuted] = useState(false);
    /** Last play/pause state requested by our own transport control. */
    const requestedPlayingRef = useRef(false);

    /** Inject JavaScript that calls a method on the YouTube IFrame API player.
     *  This is the direct fallback that bypasses the library's broken v2.4.x
     *  postMessage pipeline. The `player` variable is set by YouTube's IFrame
     *  API as a global on the iframe's window once the player is ready. */
    const injectPlayerJS = useCallback((code: string) => {
      if (webViewRef.current) {
        webViewRef.current.injectJavaScript(code);
      }
    }, []);

    // Force the player into an exact 16:9 box derived from width only.
    // The incoming height prop is accepted for backward compat but NOT
    // used to size the player — this prevents the WebView from becoming
    // wider than 16:9 and causing YouTube's own pillarboxing (black side bars).
    const boxWidth = width ?? 0;
    const boxHeight = Math.round(boxWidth * 9 / 16);

    // Direct injectJavaScript calls that bypass the library's broken
    // postMessage pipe in v2.4.x. The YouTube IFrame API player is stored
    // as a global `player` variable by the library's iframe.html.
    const play = useCallback(async () => {
      requestedPlayingRef.current = true;
      setShouldPlay(true);
      injectPlayerJS('try{if(window.player&&player.playVideo){player.playVideo();}}catch(e){} true;');
    }, [injectPlayerJS]);

    const pause = useCallback(async () => {
      requestedPlayingRef.current = false;
      setShouldPlay(false);
      injectPlayerJS('try{if(window.player&&player.pauseVideo){player.pauseVideo();}}catch(e){} true;');
    }, [injectPlayerJS]);

    const togglePlayback = useCallback(async () => {
      // Flip the requested state on every press. Player-state callbacks can be
      // delayed or omitted by WKWebView, so they must not decide the command.
      const next = !requestedPlayingRef.current;
      requestedPlayingRef.current = next;
      setShouldPlay(next);
      injectPlayerJS(next
        ? 'try{if(window.player&&player.playVideo){player.playVideo();}}catch(e){} true;'
        : 'try{if(window.player&&player.pauseVideo){player.pauseVideo();}}catch(e){} true;');
    }, [injectPlayerJS]);

    const seekTo = useCallback(async (seconds: number) => {
      youtubeRef.current?.seekTo(seconds, true);
    }, []);

    useImperativeHandle(ref, () => ({
      inject: (_js: string) => {
        // On native the library overrides webViewProps.ref, so we
        // cannot inject JS directly.  Instead the injected JavaScript
        // handler (INJECTED_JS) catches the library's own
        // sendPostMessage calls for setPlaybackRate / setVolume and
        // forwards them to window.player.  This method is a no-op on
        // native; the web platform file uses eval() for injection.
      },
      getCurrentTime: () =>
        youtubeRef.current?.getCurrentTime() ?? Promise.resolve(0),
      getDuration: () =>
        youtubeRef.current?.getDuration() ?? Promise.resolve(0),
      requestFullscreen: () => Promise.resolve(),
      exitFullscreen: () => Promise.resolve(),
      play,
      pause,
      seekTo,
      setVolume: async (volume: number) => {
        setNativeVolume(volume);
        injectPlayerJS(`try{if(window.player&&player.setVolume){player.setVolume(${volume});}}catch(e){} true;`);
      },
      mute: async () => {
        setNativeMuted(true);
        injectPlayerJS('try{if(window.player&&player.mute){player.mute();}}catch(e){} true;');
      },
      unMute: async () => {
        setNativeMuted(false);
        injectPlayerJS('try{if(window.player&&player.unMute){player.unMute();}}catch(e){} true;');
      },
      togglePlayback,
    }), [play, pause, seekTo, togglePlayback, injectPlayerJS]);

    /** Intercept onChangeState to keep shouldPlay in sync with the real
     *  YouTube player. Without this, shouldPlay can drift (e.g. autoplay
     *  starts the video but shouldPlay stays false), causing togglePlayback
     *  to send a no-op command. Syncing here guarantees togglePlayback
     *  always toggles from the correct baseline. */
    const handleStateChange = useCallback(
      (event: string) => {
        if (event === "playing") {
          requestedPlayingRef.current = true;
          setShouldPlay(true);
        } else if (event === "paused" || event === "ended" || event === "unstarted") {
          requestedPlayingRef.current = false;
          setShouldPlay(false);
        }
        onChangeState?.(event);
      },
      [onChangeState],
    );

    return (
      <View
        style={{
          width: boxWidth,
          height: boxHeight,
          alignSelf: "center",
          overflow: "hidden",
          backgroundColor: "#000",
        }}
      >
        <YoutubeIframe
          ref={youtubeRef}
          width={boxWidth}
          height={boxHeight}
          videoId={videoId}
          // Avoid the library's third-party GitHub Pages controller URL. Its
          // referrer does not match our declared player origin and current
          // YouTube WebView validation rejects that combination with 152-4.
          useLocalHTML
          baseUrlOverride="https://rork.com/"
          play={shouldPlay}
          volume={nativeVolume}
          mute={nativeMuted}
          playbackRate={playbackRate}
          onReady={onReady}
          onError={onError}
          onChangeState={handleStateChange}
          webViewProps={{
            allowsInlineMediaPlayback: true,
            mediaPlaybackRequiresUserAction: false,
            injectedJavaScript: INJECTED_JS,
            style: { width: boxWidth, height: boxHeight, backgroundColor: "transparent" },
            allowsFullscreenVideo: true,
            domStorageEnabled: true,
            thirdPartyCookiesEnabled: true,
            // Always allow the WebView to be interactive so YouTube's IFrame API
            // receives user-gesture signals and accepts programmatic play / pause
            // commands (mobile autoplay policy). Transport controls are rendered
            // below the player wrapper now, so the WebView cannot capture their taps.
            pointerEvents: "auto" as const,
            // Capture the underlying WebView ref so we can call injectJavaScript
            // directly. The library's postMessage pipe is broken in v2.4.x.
            ref: (ref: WebView | null) => {
              webViewRef.current = ref;
            },
          }}
          initialPlayerParams={{
            controls: false,
            showClosedCaptions: false,
            modestbranding: 1,
            rel: 0,
            playsinline: 1,
            preventFullScreen: true,
            // Must match the base URL assigned to the locally generated page
            // so YouTube receives consistent origin and referrer identities.
            origin: "https://rork.com",
          }}
        />
      </View>
    );
  },
);

export default VideoPlayerContent;
