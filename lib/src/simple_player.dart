import 'package:flutter/material.dart';

import 'package:video_player/src/simple_player_controls.dart';
import 'package:video_player/src/simple_player_widget.dart';
import 'package:video_player/src/video_player.dart';

typedef Widget VideoChildBuilder(
    BuildContext context, VideoPlayerController controller);

class SimplePlayer extends StatefulWidget {
  final VideoPlayerController controller;
  final ValueChanged<bool> onExpandCollapse;
  final double videoAspectRatio;
  final VideoChildBuilder childBuilder;
  final Color backgroundColor;
  final Color iconColor;
  final bool isLive;
  final bool isFullscreen;

  SimplePlayer({
    Key key,
    @required this.controller,
    @required this.onExpandCollapse,
    this.videoAspectRatio,
    this.childBuilder,
    this.backgroundColor: const Color.fromRGBO(41, 41, 41, 0.7),
    this.iconColor: const Color.fromARGB(255, 200, 200, 200),
    this.isLive = false,
    this.isFullscreen = false,
  })  : assert(controller != null),
        super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _SimplePlayerState();
  }
}

class _SimplePlayerState extends State<SimplePlayer> {
  VoidCallback listener;
  bool initialized;
  bool isBuffering;
  bool isStopForBuffering;

  VideoPlayerController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    listener = () {
      if (!mounted) return;
      if (initialized != controller.value.initialized ||
          isBuffering != controller.value.isBuffering) {
        initialized = controller.value.initialized;
        isBuffering = controller.value.isBuffering;
        setState(() {});
      }
    };
    initialized = controller.value.initialized ?? false;
    isBuffering = controller.value.isBuffering ?? false;
    controller.addListener(listener);
    controller.initialize();
    controller.play();
  }

  @override
  void didUpdateWidget(SimplePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      initialized = controller.value.initialized ?? false;
      isBuffering = controller.value.isBuffering ?? false;
      controller.addListener(listener);
      controller.initialize();
      controller.play();
    }
  }

  @override
  void dispose() {
    controller.removeListener(listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      SimplePlayerWidget(
        controller: controller,
        aspectRatio: widget.videoAspectRatio,
        controls: SimplePlayerControls(
          controller: controller,
          onExpandCollapse: widget.onExpandCollapse,
          backgroundColor: widget.backgroundColor,
          iconColor: widget.iconColor,
          isLive: widget.isLive,
          isFullscreen: widget.isFullscreen,
        ),
      ),
    ];
    if (widget.childBuilder != null) {
      children.add(widget.childBuilder(context, controller));
    }

    return Stack(
      fit: StackFit.passthrough,
      children: children,
    );
  }
}

class SimpleController extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return _SimpleControllerState();
  }
}

class _SimpleControllerState extends State<SimpleController> {
  @override
  Widget build(BuildContext context) {
    return null;
  }
}
