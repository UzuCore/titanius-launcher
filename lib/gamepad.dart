import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:go_router/go_router.dart';

enum GamepadButton {
  up,
  down,
  upDown,
  left,
  right,
  leftRight,
  a,
  b,
  x,
  y,
  c,
  z,
  l1,
  l2,
  r1,
  r2,
  start,
  select,
}

void useGamepad(WidgetRef ref, void Function(String location, GamepadButton key) listener) {
  return use(_GamepadHook(GoRouter.of(ref.context).location, listener));
}

class _GamepadHook extends Hook<void> {
  final String location;
  final void Function(String location, GamepadButton key) listener;
  const _GamepadHook(this.location, this.listener);

  @override
  _GamepadHookState createState() => _GamepadHookState();
}

class _GamepadHookState extends HookState<void, _GamepadHook> {
  @override
  void initHook() {
    super.initHook();
    HardwareKeyboard.instance.addHandler(listener);
  }

  @override
  void build(BuildContext context) {}

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(listener);
    super.dispose();
  }

  bool listener(KeyEvent e) {
    if (e is KeyDownEvent) {
      debugPrint("Gamepad down ${e.logicalKey}");
      if (e.logicalKey == LogicalKeyboardKey.arrowUp) {
        hook.listener(hook.location, GamepadButton.up);
      } else if (e.logicalKey == LogicalKeyboardKey.arrowDown) {
        hook.listener(hook.location, GamepadButton.down);
      } else if (e.logicalKey == LogicalKeyboardKey.arrowLeft) {
        hook.listener(hook.location, GamepadButton.left);
      } else if (e.logicalKey == LogicalKeyboardKey.arrowRight) {
        hook.listener(hook.location, GamepadButton.right);
      } else if (e.logicalKey == LogicalKeyboardKey.gameButtonA || e.logicalKey == LogicalKeyboardKey.numpad2) {
        hook.listener(hook.location, GamepadButton.a);
      } else if (e.logicalKey == LogicalKeyboardKey.gameButtonB ||
          e.logicalKey == LogicalKeyboardKey.backspace ||
          e.logicalKey == LogicalKeyboardKey.numpad6) {
        hook.listener(hook.location, GamepadButton.b);
      } else if (e.logicalKey == LogicalKeyboardKey.gameButtonX ||
          e.logicalKey == LogicalKeyboardKey.numpad4 ||
          e.logicalKey == LogicalKeyboardKey.keyX) {
        hook.listener(hook.location, GamepadButton.x);
      } else if (e.logicalKey == LogicalKeyboardKey.gameButtonY ||
          e.logicalKey == LogicalKeyboardKey.numpad8 ||
          e.logicalKey == LogicalKeyboardKey.keyY) {
        hook.listener(hook.location, GamepadButton.y);
      } else if (e.logicalKey == LogicalKeyboardKey.gameButtonC) {
        hook.listener(hook.location, GamepadButton.c);
      } else if (e.logicalKey == LogicalKeyboardKey.gameButtonZ) {
        hook.listener(hook.location, GamepadButton.z);
      } else if (e.logicalKey == LogicalKeyboardKey.gameButtonLeft1) {
        hook.listener(hook.location, GamepadButton.l1);
      } else if (e.logicalKey == LogicalKeyboardKey.gameButtonRight1) {
        hook.listener(hook.location, GamepadButton.r1);
      } else if (e.logicalKey == LogicalKeyboardKey.gameButtonLeft2) {
        hook.listener(hook.location, GamepadButton.l2);
      } else if (e.logicalKey == LogicalKeyboardKey.gameButtonRight2) {
        hook.listener(hook.location, GamepadButton.r2);
      } else if (e.logicalKey == LogicalKeyboardKey.gameButtonStart || e.logicalKey == LogicalKeyboardKey.enter) {
        hook.listener(hook.location, GamepadButton.start);
      } else if (e.logicalKey == LogicalKeyboardKey.gameButtonSelect || e.logicalKey == LogicalKeyboardKey.insert) {
        hook.listener(hook.location, GamepadButton.select);
      } else if (e.logicalKey == LogicalKeyboardKey.audioVolumeUp) {
        FlutterVolumeController.raiseVolume(null).then((value) => debugPrint("Volume raised"));
      } else if (e.logicalKey == LogicalKeyboardKey.audioVolumeDown) {
        FlutterVolumeController.lowerVolume(null).then((value) => debugPrint("Volume lowered"));
      } else if (e.logicalKey == LogicalKeyboardKey.audioVolumeMute) {
        FlutterVolumeController.toggleMute().then((value) => debugPrint("Volume muted"));
      }
    } else if (e is KeyRepeatEvent) {
      debugPrint("Gamepad repeat ${e.logicalKey}");
      if (e.logicalKey == LogicalKeyboardKey.arrowLeft) {
        hook.listener(hook.location, GamepadButton.left);
      } else if (e.logicalKey == LogicalKeyboardKey.arrowRight) {
        hook.listener(hook.location, GamepadButton.right);
      } else if (e.logicalKey == LogicalKeyboardKey.gameButtonLeft1) {
        hook.listener(hook.location, GamepadButton.l1);
      } else if (e.logicalKey == LogicalKeyboardKey.gameButtonRight1) {
        hook.listener(hook.location, GamepadButton.r1);
      } else if (e.logicalKey == LogicalKeyboardKey.gameButtonLeft2) {
        hook.listener(hook.location, GamepadButton.l2);
      } else if (e.logicalKey == LogicalKeyboardKey.gameButtonRight2) {
        hook.listener(hook.location, GamepadButton.r2);
      }
    }
    return true;
  }
}
