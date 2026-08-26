import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:se_controle_ai/core/config/globals.dart';

mixin MessageMixin<T extends StatelessWidget> {
  void toastErro(String erro) {
    Flushbar flush = Flushbar();

    flush = Flushbar(
      boxShadows: const [
        BoxShadow(
          spreadRadius: 0,
          blurRadius: 40,
          offset: Offset(0, 4),
          // color: LibCores.s1,
        ),
      ],
      backgroundColor: Colors.white,
      borderRadius: .circular(12),
      margin: const .all(15),
      messageText: Row(
        children: [
          const Icon(Icons.cancel, size: 28.0, color: Colors.red),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              erro,
              style: const TextStyle(
                fontSize: 14.5,
                // color: LibCores.c2
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      duration: const Duration(seconds: 3),
    );

    if (Globals.navigatorKey.currentContext != null) {
      flush.show(Globals.navigatorKey.currentContext!);
    }
  }

  void toastSucesso(
    String msg, {
    FlushbarPosition? position,
    Duration? duration,
  }) {
    Flushbar flush = Flushbar();

    flush = Flushbar(
      boxShadows: const [
        BoxShadow(
          spreadRadius: 0,
          blurRadius: 40,
          offset: Offset(0, 4),
          // color: LibCores.s1,
        ),
      ],
      flushbarPosition: position ?? FlushbarPosition.BOTTOM,
      backgroundColor: Colors.white,
      borderRadius: BorderRadius.circular(12),
      margin: const EdgeInsets.all(15),
      messageText: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, size: 28.0, color: Colors.blue),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              msg,
              style: const TextStyle(fontSize: 14.5, color: Colors.black),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),

      duration: duration ?? const Duration(seconds: 3),
    );

    if (Globals.navigatorKey.currentContext != null) {
      flush.show(Globals.navigatorKey.currentContext!);
    }
  }
}
