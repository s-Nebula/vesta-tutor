import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import 'package:vesta_app/l10n/tr.dart';
/// Top strip warning that there is no connection. The data shown is the
/// last cached copy and refreshes by itself on reconnection.
class OfflineBanner extends StatefulWidget {
  final Widget child;

  const OfflineBanner({super.key, required this.child});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    Connectivity().checkConnectivity().then(_update, onError: (_) {});
    _subscription = Connectivity().onConnectivityChanged.listen(_update);
  }

  void _update(List<ConnectivityResult> results) {
    final offline = results.isEmpty ||
        results.every((result) => result == ConnectivityResult.none);
    if (mounted && offline != _offline) setState(() => _offline = offline);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          child: _offline
              ? Material(
                  color: const Color(0xFF8A5A00),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.cloud_off_rounded,
                              size: 16, color: Colors.white),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              tr('Sin conexión: mostrando los últimos datos guardados'),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        Expanded(
          child: _offline
              // The strip already takes up the system's top inset.
              ? MediaQuery.removePadding(
                  context: context,
                  removeTop: true,
                  child: widget.child,
                )
              : widget.child,
        ),
      ],
    );
  }
}
