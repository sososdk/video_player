import 'package:flutter/material.dart';

import 'package:video_player/src/video_player.dart';

class SimplePlayerWidget extends StatefulWidget {
  final VideoPlayerController controller;
  final double aspectRatio;
  final Widget controls;

  const SimplePlayerWidget({
    Key key,
    this.controller,
    this.aspectRatio,
    this.controls,
  })  : assert(controller != null),
        assert(controls != null),
        super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _SimplePlayerWidgetState();
  }
}

class _SimplePlayerWidgetState extends State<SimplePlayerWidget> {
  bool initialized = false;
  bool isKeepUp = false;
  bool hasError = false;
  VoidCallback listener;

  VideoPlayerController get controller => widget.controller;

  double get aspectRatio => widget.aspectRatio;

  Widget get controls => widget.controls;

  @override
  void initState() {
    super.initState();
    listener = () {
      if (initialized != controller.value.initialized ||
          isKeepUp != controller.value.isKeepUp ||
          hasError != controller.value.hasError) {
        initialized = controller.value.initialized;
        isKeepUp = controller.value.isKeepUp;
        hasError = controller.value.hasError;
        setState(() {});
      }
    };
    initialized = controller.value.initialized;
    isKeepUp = controller.value.isKeepUp;
    hasError = controller.value.hasError;
    controller.addListener(listener);
  }

  @override
  void didUpdateWidget(SimplePlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != controller) {
      initialized = controller.value.initialized;
      isKeepUp = controller.value.isKeepUp;
      hasError = controller.value.hasError;
      controller.addListener(listener);
    }
  }

  @override
  void dispose() {
    controller.removeListener(listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Hero(
          tag: controller,
          child: Stack(children: [
            Center(
              child: AspectRatio(
                aspectRatio: _getAspectRatio(aspectRatio, controller),
                child: VideoPlayer(controller),
              ),
            ),
            Visibility(
              visible: !isKeepUp,
              child: IgnorePointer(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: hasError
                        ? Text(
                            controller.value.errorDescription,
                            style: TextStyle(
                              fontSize: 12.0,
                              color: Colors.white30,
                            ),
                          )
                        : SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2.0),
                          ),
                  ),
                ),
              ),
            ),
          ]),
        ),
        controls,
      ],
    );
  }

  double _getAspectRatio(double aspectRatio, VideoPlayerController controller) {
    return aspectRatio ?? controller.value.aspectRatio;
  }
}
