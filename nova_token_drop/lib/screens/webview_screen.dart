import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../core/theme.dart';
import '../widgets/neon.dart';

class WebViewScreen extends StatefulWidget {
  final String title;
  final String url;
  final bool whiteBackground;
  const WebViewScreen({
    super.key,
    required this.title,
    required this.url,
    this.whiteBackground = false,
  });

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(widget.whiteBackground ? Colors.white : NovaColors.deepSpace)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() => _loading = true);
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
        onWebResourceError: (_) {
          if (mounted) {
            setState(() {
              _loading = false;
              _error = true;
            });
          }
        },
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.whiteBackground ? Colors.white : NovaColors.deepSpace,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              decoration: const BoxDecoration(
                color: NovaColors.panelDark,
                boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 8)],
              ),
              child: Row(children: [
                NeonIconButton(
                  icon: Icons.arrow_back_rounded,
                  gradient: const [NovaColors.violet, NovaColors.blue],
                  onTap: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(widget.title.toUpperCase(),
                      style: NovaText.title(18), overflow: TextOverflow.ellipsis),
                ),
                NeonIconButton(
                  icon: Icons.refresh_rounded,
                  gradient: const [NovaColors.blue, NovaColors.cyan],
                  onTap: () {
                    setState(() => _error = false);
                    _controller.reload();
                  },
                ),
              ]),
            ),
            Expanded(
              child: Stack(
                children: [
                  if (!_error) WebViewWidget(controller: _controller),
                  if (_error) _errorView(),
                  if (_loading && !_error)
                    Container(
                      color: widget.whiteBackground ? Colors.white : NovaColors.deepSpace,
                      child: const Center(
                        child: CircularProgressIndicator(color: NovaColors.cyan),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorView() {
    return Container(
      color: widget.whiteBackground ? Colors.white : NovaColors.deepSpace,
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded,
                size: 56, color: widget.whiteBackground ? Colors.black38 : NovaColors.textLo),
            const SizedBox(height: 16),
            Text(
              'Could not load the page.\nCheck your internet connection.',
              textAlign: TextAlign.center,
              style: NovaText.label(15,
                  color: widget.whiteBackground ? Colors.black54 : NovaColors.textLo),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 180,
              child: NeonButton(
                label: 'Retry',
                icon: Icons.refresh_rounded,
                onTap: () {
                  setState(() {
                    _error = false;
                    _loading = true;
                  });
                  _controller.reload();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
