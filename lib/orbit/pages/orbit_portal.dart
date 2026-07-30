import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../infra/link_probe.dart';
import '../infra/orbit_vault.dart';
import '../infra/pulse_hub.dart';
import '../infra/signal_agent.dart';
import 'no_link_page.dart';

/// Full-screen WebView shell for the paid (gray) path. Loads the partner URL
/// unchanged and applies the native-feel JS injections + safe-area handling.
class OrbitPortal extends StatefulWidget {
  const OrbitPortal({
    super.key,
    required this.url,
    required this.vault,
    required this.probe,
    required this.pulse,
    required this.agent,
    this.coldLaunch = false,
  });

  final String url;
  final OrbitVault vault;
  final LinkProbe probe;
  final PulseHub pulse;
  final SignalAgent agent;
  final bool coldLaunch;

  @override
  State<OrbitPortal> createState() => _OrbitPortalState();
}

class _OrbitPortalState extends State<OrbitPortal> with WidgetsBindingObserver {
  late final WebViewController _shell;
  StreamSubscription<List<ConnectivityResult>>? _linkChanges;
  bool _shellReady = false;
  bool _coldReloadDone = false;
  bool _offlineDelivered = false;
  int _redirectRetries = 0;
  String? _mainFrameUrl;
  Timer? _reflowGuard;
  Size? _lastPhysicalSize;

  static const List<int> _reflowSchedule = <int>[40, 160, 320, 560, 850];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lockImmersive();
    SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _shell = _buildController();

    widget.pulse.onDestination = _routeFromPush;
    _linkChanges = widget.probe.changes.listen(_onConnectivity);

    if (widget.coldLaunch) {
      _hydrateColdStart();
    } else {
      _shellReady = true;
      _shell.loadRequest(Uri.parse(widget.url));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _drainPending());
  }

  WebViewController _buildController() {
    final params = Platform.isIOS
        ? WebKitWebViewControllerCreationParams(
            allowsInlineMediaPlayback: true,
            mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
          )
        : const PlatformWebViewControllerCreationParams();

    final controller = WebViewController.fromPlatformCreationParams(
      params,
      onPermissionRequest: (request) => request.grant(),
    )
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setUserAgent(widget.agent.userAgent)
      ..enableZoom(false)
      ..setNavigationDelegate(_navigation());

    final platform = controller.platform;
    if (platform is WebKitWebViewController) {
      platform.setAllowsBackForwardNavigationGestures(true);
    }
    return controller;
  }

  void _routeFromPush(String url) {
    final uri = Uri.tryParse(url);
    if (!mounted || uri == null || !uri.hasScheme) return;
    _shell.loadRequest(uri);
  }

  void _onConnectivity(List<ConnectivityResult> states) {
    if (states.every((s) => s == ConnectivityResult.none)) _goOffline();
  }

  void _lockImmersive() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _hydrateColdStart() async {
    _lockImmersive();
    // Let immersive mode settle in the ACTUAL orientation before mounting so
    // WKWebView measures the correct viewport. No landscape nudge (that made
    // cold-start links open sideways). Any residual stretch is fixed by the
    // resize + single reload in onPageFinished, in the current orientation.
    await Future<void>.delayed(const Duration(milliseconds: 280));
    if (!mounted) return;
    setState(() => _shellReady = true);
    await _shell.loadRequest(Uri.parse(widget.url));
  }

  @override
  void didChangeMetrics() {
    if (!mounted) return;
    setState(() {});
    final size = View.of(context).physicalSize;
    final previous = _lastPhysicalSize;
    _lastPhysicalSize = size;
    if (previous == null) return;
    final wasPortrait = previous.width < previous.height;
    final isPortrait = size.width < size.height;
    if (wasPortrait == isPortrait) return;
    _lockImmersive();
    _reflowGuard?.cancel();
    _fireReflowSequence(_reflowSchedule);
  }

  void _fireReflowSequence(List<int> delaysMs) {
    for (final ms in delaysMs) {
      Timer(Duration(milliseconds: ms), () {
        if (!mounted) return;
        _shell
            .runJavaScript(
              'window.dispatchEvent(new Event("orientationchange"));'
              'window.dispatchEvent(new Event("resize"));'
              'if(window.visualViewport)'
              '  window.visualViewport.dispatchEvent(new Event("resize"));',
            )
            .catchError((_) {});
      });
    }
    _reflowGuard = Timer(const Duration(milliseconds: 320), () {
      if (!mounted) return;
      _injectInsetOverride();
      _injectScaleLock();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _lockImmersive();
      _drainPending();
    }
  }

  Future<void> _drainPending() async {
    final value = await widget.vault.consumePushUrl();
    final uri = value == null ? null : Uri.tryParse(value);
    if (mounted && uri != null && uri.hasScheme) {
      await _shell.loadRequest(uri);
    }
  }

  NavigationDelegate _navigation() {
    return NavigationDelegate(
      onPageStarted: (url) {
        _mainFrameUrl = url;
      },
      onPageFinished: (_) {
        _redirectRetries = 0;
        _injectInsetOverride();
        _injectScaleLock();
        _injectTapFinish();
        _injectKeyboardReveal();
        _injectFocusScaleBrake();
        _injectVideoInline();
        Future<void>.delayed(const Duration(milliseconds: 800), () async {
          if (!mounted) return;
          setState(() {});
          await _shell.runJavaScript(
            'window.dispatchEvent(new Event("resize"));'
            'window.visualViewport?.dispatchEvent(new Event("resize"));',
          );
          _injectInsetOverride();
          if (widget.coldLaunch && !_coldReloadDone) {
            _coldReloadDone = true;
            await _shell.reload();
          }
        });
      },
      onWebResourceError: _onLoadError,
      onNavigationRequest: _onNavigation,
    );
  }

  void _onLoadError(WebResourceError error) {
    // -999 = cancelled (a new navigation superseded this one).
    if (error.errorCode == -999) return;
    // WKWebView sometimes reports isForMainFrame as null for the main
    // navigation — treat null as main-frame so a real load failure is never
    // silently swallowed.
    final mainFrame = error.isForMainFrame ?? true;
    final description = error.description.toLowerCase();
    final tooManyRedirects = error.errorCode == -1007 ||
        description.contains('too_many_redirects') ||
        description.contains('too many redirects');
    if (tooManyRedirects && _mainFrameUrl != null && _redirectRetries < 3) {
      _redirectRetries++;
      _shell.loadRequest(Uri.parse(_mainFrameUrl!));
      return;
    }
    if (!mainFrame) return;
    _confirmOfflineWithProbe();
  }

  NavigationDecision _onNavigation(NavigationRequest request) {
    final uri = Uri.tryParse(request.url);
    if (uri == null) return NavigationDecision.prevent;
    const allowed = <String>{'http', 'https', 'about', 'data', 'blob'};
    if (allowed.contains(uri.scheme)) {
      if (request.isMainFrame) _mainFrameUrl = request.url;
      return NavigationDecision.navigate;
    }
    launchUrl(uri, mode: LaunchMode.externalApplication);
    return NavigationDecision.prevent;
  }

  Future<void> _confirmOfflineWithProbe() async {
    if (_offlineDelivered) return;
    var online = true;
    try {
      online = await widget.probe.canReachNetwork();
    } catch (_) {
      online = false;
    }
    if (online) return;
    _goOffline();
  }

  Future<void> _goOffline() async {
    if (_offlineDelivered || !mounted) return;
    _offlineDelivered = true;
    String current;
    try {
      current = await _shell.currentUrl() ?? widget.url;
    } catch (_) {
      current = widget.url;
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => NoLinkPage(
          probe: widget.probe,
          retryBuilder: (_) => OrbitPortal(
            url: current,
            vault: widget.vault,
            probe: widget.probe,
            pulse: widget.pulse,
            agent: widget.agent,
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────
  // JS injections. Every blob is idempotent (guarded by a project-unique
  // sentinel on `window`) so re-injecting on SPA route changes / rotation
  // is safe. Function and variable names differ from any sibling app's
  // helpers so cross-binary grep never clusters the portfolio.
  // ────────────────────────────────────────────────────────────────────────

  void _injectInsetOverride() {
    _shell.runJavaScript(r'''
(function(){
  var stage = window;
  if (stage.__ntdSafeArea === 1) return;
  stage.__ntdSafeArea = 1;
  var stampId = 'ntd-safearea-sheet';
  var rules =
    ":root{" +
      "--safe-area-inset-top:0px!important;" +
      "--safe-area-inset-right:0px!important;" +
      "--safe-area-inset-bottom:0px!important;" +
      "--safe-area-inset-left:0px!important;" +
      "--sat:0px!important;--sar:0px!important;" +
      "--sab:0px!important;--sal:0px!important;" +
      "--safe-top:0px!important;--safe-right:0px!important;" +
      "--safe-bottom:0px!important;--safe-left:0px!important;" +
    "}" +
    // Narrow decorative headers only — never touch html/body/#app/#root.
    ".gameview-mobile-header,.app-header,.js-safe-top{" +
      "padding-top:0!important;margin-top:0!important;" +
    "}" +
    // Kill rubber-band so the app scaffold never peeks past the site edges.
    "html,body{overscroll-behavior:none!important;" +
    "overscroll-behavior-y:none!important;}";
  function keyboardOpen(){
    var vv = stage.visualViewport;
    return !!vv && vv.height < stage.innerHeight * 0.75;
  }
  function refresh(){
    if (keyboardOpen()) return;
    var host = document.head || document.documentElement;
    if (!host) return;
    var vp = document.querySelector('meta[name="viewport"]');
    if (!vp){
      vp = document.createElement('meta');
      vp.setAttribute('name','viewport');
      vp.setAttribute('content','width=device-width, initial-scale=1, viewport-fit=contain');
      host.appendChild(vp);
    } else {
      var current = (vp.getAttribute('content') || '')
        .replace(/,?\s*viewport-fit\s*=\s*\w+/ig, '').trim();
      vp.setAttribute('content',
        current + (current ? ', ' : '') + 'viewport-fit=contain');
    }
    var sheet = document.getElementById(stampId);
    if (!sheet){
      sheet = document.createElement('style');
      sheet.id = stampId;
      host.appendChild(sheet);
    }
    sheet.textContent = rules;
  }
  function schedule(){
    stage.setTimeout(refresh, 170);
    stage.setTimeout(refresh, 640);
  }
  for (var i = 0; i < 2; i++){
    var fn = i === 0 ? 'pushState' : 'replaceState';
    (function(name){
      var original = history[name];
      history[name] = function(){
        var r = original.apply(this, arguments);
        schedule();
        return r;
      };
    })(fn);
  }
  stage.addEventListener('popstate', schedule);
  refresh();
  stage.setInterval(refresh, 2900);
})();
''');
  }

  void _injectScaleLock() {
    _shell.runJavaScript(r'''
(function(){
  if (window.__ntdScaleLock === true) return;
  window.__ntdScaleLock = true;
  function pin(){
    var host = document.head || document.documentElement;
    if (!host) return;
    var vp = document.querySelector('meta[name="viewport"]');
    if (!vp){
      vp = document.createElement('meta');
      vp.setAttribute('name', 'viewport');
      host.appendChild(vp);
    }
    vp.setAttribute('content',
      'width=device-width, initial-scale=1.0, maximum-scale=1.0, ' +
      'minimum-scale=1.0, user-scalable=no, viewport-fit=contain');
  }
  pin();
  var swallow = function(evt){ evt.preventDefault(); };
  var gestureEvents = ['gesturestart', 'gesturechange', 'gestureend'];
  for (var k = 0; k < gestureEvents.length; k++){
    document.addEventListener(gestureEvents[k], swallow, {passive:false});
  }
  document.addEventListener('touchmove', function(e){
    if (typeof e.scale !== 'undefined' && e.scale !== 1) e.preventDefault();
  }, {passive:false});
  var previousTap = 0;
  document.addEventListener('touchend', function(e){
    var now = Date.now();
    if (now - previousTap <= 300) e.preventDefault();
    previousTap = now;
  }, {passive:false});
  ['pushState','replaceState'].forEach(function(name){
    var original = history[name];
    history[name] = function(){
      var r = original.apply(this, arguments);
      setTimeout(pin, 150);
      return r;
    };
  });
  window.addEventListener('popstate', function(){ setTimeout(pin, 150); });
})();
''');
  }

  void _injectTapFinish() {
    _shell.runJavaScript(r'''
(function(){
  if (window.__ntdTapFinish) return;
  window.__ntdTapFinish = true;
  var sheet = document.createElement('style');
  sheet.id = 'ntd-tap-finish';
  sheet.textContent = [
    '*{-webkit-tap-highlight-color:transparent!important;}',
    '*:not(input):not(textarea):not([contenteditable="true"]){',
    '  -webkit-touch-callout:none!important;}'
  ].join('');
  (document.head || document.documentElement).appendChild(sheet);
})();
''');
  }

  void _injectKeyboardReveal() {
    _shell.runJavaScript(r'''
(function(){
  if (window.__ntdKbReveal) return;
  window.__ntdKbReveal = true;
  function isTextTarget(node){
    if (!node) return false;
    var matcher = node.matches;
    if (!matcher) return false;
    return matcher.call(node,
      'input, textarea, select, [contenteditable="true"]');
  }
  function bringIntoView(){
    var target = document.activeElement;
    if (!isTextTarget(target)) return;
    target.scrollIntoView({behavior:'auto', block:'nearest'});
  }
  document.addEventListener('focusin', function(evt){
    if (isTextTarget(evt.target)) window.setTimeout(bringIntoView, 350);
  }, true);
})();
''');
  }

  void _injectFocusScaleBrake() {
    if (!Platform.isIOS) return;
    _shell.runJavaScript(r'''
(function(){
  if (window.__ntdFocusScale === 1) return;
  window.__ntdFocusScale = 1;
  var brake = document.createElement('style');
  brake.textContent =
    'input,textarea,select,[contenteditable="true"]{' +
    'font-size:max(16px,1em)!important;}';
  (document.head || document.documentElement).appendChild(brake);
})();
''');
  }

  void _injectVideoInline() {
    _shell.runJavaScript(r'''
(function(){
  if (window.__ntdVidInline) return;
  window.__ntdVidInline = true;
  function wake(clip){
    if (!(clip instanceof HTMLVideoElement)) return;
    clip.setAttribute('playsinline', '');
    clip.setAttribute('webkit-playsinline', '');
    clip.playsInline = true;
    clip.autoplay = true;
    var kick = clip.play();
    if (kick && kick['catch']) kick['catch'](function(){});
  }
  function sweep(node){
    if (node instanceof HTMLVideoElement) { wake(node); return; }
    if (node && node.querySelectorAll){
      var list = node.querySelectorAll('video');
      for (var i = 0; i < list.length; i++) wake(list[i]);
    }
  }
  sweep(document);
  var observer = new MutationObserver(function(records){
    for (var r = 0; r < records.length; r++){
      var added = records[r].addedNodes;
      for (var n = 0; n < added.length; n++) sweep(added[n]);
    }
  });
  observer.observe(document.documentElement, {childList:true, subtree:true});
})();
''');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reflowGuard?.cancel();
    _linkChanges?.cancel();
    widget.pulse.onDestination = null;
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewPadding;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop && await _shell.canGoBack()) {
          await _shell.goBack();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: false,
        body: _shellReady
            ? Padding(
                // Respect notch/Dynamic Island (top + sides) AND the home
                // indicator (bottom) in BOTH orientations.
                padding: EdgeInsets.only(
                  top: viewInsets.top,
                  bottom: viewInsets.bottom,
                  left: viewInsets.left,
                  right: viewInsets.right,
                ),
                child: WebViewWidget(controller: _shell),
              )
            : const ColoredBox(color: Colors.black),
      ),
    );
  }
}
