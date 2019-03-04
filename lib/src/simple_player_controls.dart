import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/src/video_player.dart';

bool hasHours(Duration duration) {
  return duration == null
      ? false
      : (duration.inMilliseconds ~/ 1000 ~/ 3600 > 0);
}

String formatDuration(bool hasHours, Duration position) {
  final ms = position.inMilliseconds;
  int seconds = ms ~/ 1000;
  final int hours = seconds ~/ 3600;
  seconds = seconds % 3600;
  var minutes = seconds ~/ 60;
  seconds = seconds % 60;

  final hoursString = hours >= 10 ? '$hours' : hours == 0 ? '00' : '0$hours';

  final minutesString =
      minutes >= 10 ? '$minutes' : minutes == 0 ? '00' : '0$minutes';

  final secondsString =
      seconds >= 10 ? '$seconds' : seconds == 0 ? '00' : '0$seconds';

  final formattedTime =
      '${hasHours ? '$hoursString:' : ''}$minutesString:$secondsString';

  return formattedTime;
}

Size checkTextFits(TextSpan text, {Locale locale, double scale, int maxLines}) {
  var tp = TextPainter(
    text: text,
    textAlign: TextAlign.left,
    textDirection: TextDirection.ltr,
    textScaleFactor: scale ?? 1,
    maxLines: maxLines,
    locale: locale,
  );
  tp.layout();
  return tp.size;
}

class SimplePlayerControls extends StatefulWidget {
  final VideoPlayerController controller;
  final ValueChanged<bool> onExpandCollapse;
  final bool isLive;
  final bool isFullscreen;
  final Color backgroundColor;
  final Color iconColor;

  const SimplePlayerControls({
    Key key,
    @required this.controller,
    @required this.onExpandCollapse,
    this.isLive = false,
    this.isFullscreen = false,
    this.backgroundColor: const Color.fromRGBO(41, 41, 41, 0.7),
    this.iconColor: const Color.fromARGB(255, 200, 200, 200),
  })  : assert(onExpandCollapse != null),
        super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _SimplePlayerControlsState();
  }
}

class _SimplePlayerControlsState extends State<SimplePlayerControls> {
  final marginSize = 5.0;
  bool _hideStuff = true;
  Timer _hideTimer;
  Timer _expandCollapseTimer;
  Timer _initTimer;

  VideoPlayerController get controller => widget.controller;

  bool get isLive => widget.isLive;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = widget.backgroundColor;
    final iconColor = widget.iconColor;
    final orientation = MediaQuery.of(context).orientation;
    final barHeight = orientation == Orientation.portrait ? 30.0 : 30.0;

    return Stack(
      fit: StackFit.passthrough,
      children: [
        _buildHitArea(),
        _buildBottomBar(backgroundColor, iconColor, barHeight),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _dispose();
    super.dispose();
  }

  void _dispose() {
    controller.removeListener(_updateState);
    _hideTimer?.cancel();
    _expandCollapseTimer?.cancel();
    _initTimer?.cancel();
  }

  @override
  void didUpdateWidget(SimplePlayerControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != controller) {
      _dispose();
      _initialize();
    }
  }

  void _initialize() {
    controller.addListener(_updateState);
    _updateState();
    if (controller.value.isPlaying) {
      _startHideTimer();
    }
    _initTimer = Timer(Duration(milliseconds: 200), () {
      setState(() => _hideStuff = false);
    });
  }

  Widget _buildBottomBar(
    Color backgroundColor,
    Color iconColor,
    double barHeight,
  ) {
    return IgnorePointer(
      ignoring: _hideStuff,
      child: AnimatedOpacity(
        opacity: _hideStuff ? 0.0 : 1.0,
        duration: Duration(milliseconds: 300),
        child: Container(
          alignment: Alignment.bottomCenter,
          margin: EdgeInsets.all(marginSize),
          child: ClipRRect(
            borderRadius: BorderRadius.all(
              Radius.circular(10.0),
            ),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(
                sigmaX: 10.0,
                sigmaY: 10.0,
              ),
              child: Container(
                height: barHeight,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.all(
                    Radius.circular(10.0),
                  ),
                ),
                child: isLive
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildPlayPause(controller, iconColor, barHeight),
                          _buildLive(iconColor),
                        ],
                      )
                    : Row(
                        children: [
                          _buildSkipBack(iconColor, barHeight),
                          _buildPlayPause(controller, iconColor, barHeight),
                          _buildSkipForward(iconColor, barHeight),
                          _buildPosition(iconColor),
                          _buildProgressBar(),
                          _buildRemaining(iconColor),
                          _buildExpandButton(iconColor, barHeight),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLive(Color iconColor) {
    return Padding(
      padding: EdgeInsets.only(right: 12.0),
      child: Text(
        'LIVE',
        style: TextStyle(color: iconColor, fontSize: 12.0),
      ),
    );
  }

  Widget _buildHitArea() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: controller.value.isPlaying
          ? _toggleControls
          : () {
              _hideTimer?.cancel();
              setState(() {
                _hideStuff = false;
              });
            },
    );
  }

  Widget _buildPlayPause(
    VideoPlayerController controller,
    Color iconColor,
    double barHeight,
  ) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _playPause,
      child: Container(
        height: barHeight,
        padding: EdgeInsets.only(
          left: 6.0,
          right: 6.0,
        ),
        child: Icon(
          controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
          color: iconColor,
          size: 16.0,
        ),
      ),
    );
  }

  Widget _buildPosition(Color iconColor) {
    var value = controller.value;
    final duration = value.duration;
    final position = value.isPreview ? value.previewPosition : value.position;
    final bool hours = hasHours(duration);
    final textStyle = TextStyle(color: iconColor, fontSize: 10.0);
    double minWidth = checkTextFits(TextSpan(
      text: hours ? '44:44:44' : '44:44',
      style: textStyle,
    )).width;
    return Padding(
      padding: EdgeInsets.only(right: 12.0),
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: minWidth),
        child: Container(
          alignment: Alignment.centerRight,
          child: Text(
            formatDuration(hours, position),
            style: textStyle,
          ),
        ),
      ),
    );
  }

  Widget _buildRemaining(Color iconColor) {
    final duration = controller.value.duration;
    final position = controller.value.duration != null
        ? controller.value.duration - controller.value.position
        : Duration(seconds: 0);
    final bool hours = hasHours(duration);
    final textStyle = TextStyle(color: iconColor, fontSize: 10.0);
    double minWidth = checkTextFits(TextSpan(
      text: hours ? '-44:44:44' : '-44:44',
      style: textStyle,
    )).width;
    return Padding(
      padding: EdgeInsets.only(right: 6.0),
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: minWidth),
        child: Container(
          alignment: Alignment.centerLeft,
          child: Text(
            '-${formatDuration(hours, position)}',
            style: textStyle,
          ),
        ),
      ),
    );
  }

  Widget _buildSkipBack(Color iconColor, double barHeight) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _skipBack,
      child: Container(
        height: barHeight,
        margin: EdgeInsets.only(left: 10.0),
        padding: EdgeInsets.only(
          left: 6.0,
          right: 6.0,
        ),
        child: Icon(
          Icons.replay,
          color: iconColor,
          size: 13.0,
        ),
      ),
    );
  }

  Widget _buildSkipForward(Color iconColor, double barHeight) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _skipForward,
      child: Container(
        height: barHeight,
        padding: EdgeInsets.only(left: 6.0, right: 8.0),
        margin: EdgeInsets.only(
          right: 8.0,
        ),
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.skewY(0.0)
            ..rotateX(math.pi)
            ..rotateZ(math.pi),
          child: Icon(
            Icons.replay,
            color: iconColor,
            size: 13.0,
          ),
        ),
      ),
    );
  }

  Widget _buildExpandButton(Color iconColor, double barHeight) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => widget.onExpandCollapse(widget.isFullscreen),
      child: Container(
        height: barHeight,
        padding: EdgeInsets.only(left: 6.0, right: 8.0),
        margin: EdgeInsets.only(
          right: 8.0,
        ),
        child: Icon(
          widget.isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
          color: iconColor,
          size: 16.0,
        ),
      ),
    );
  }

  void _cancelAndRestartTimer() {
    _hideTimer?.cancel();
    setState(() {
      _hideStuff = false;
      _startHideTimer();
    });
  }

  void _hideControls() {
    _hideTimer?.cancel();
    setState(() => _hideStuff = true);
  }

  void _showControls() {
    _hideTimer?.cancel();
    setState(() {
      _hideStuff = false;
      _startHideTimer();
    });
  }

  void _toggleControls() {
    if (_hideStuff) {
      _showControls();
    } else {
      _hideControls();
    }
  }

  Widget _buildProgressBar() {
    return Expanded(
      child: Padding(
        padding: EdgeInsets.only(right: 12.0),
        child: VideoProgressBar(
          controller,
          onDragStart: () {
            _hideTimer?.cancel();
          },
          onDragEnd: () {
            _startHideTimer();
          },
          colors: ProgressColors(
            playedColor: Color.fromARGB(120, 255, 255, 255),
            handleColor: Color.fromARGB(255, 255, 255, 255),
            bufferedColor: Color.fromARGB(60, 255, 255, 255),
            backgroundColor: Color.fromARGB(20, 255, 255, 255),
          ),
        ),
      ),
    );
  }

  void _playPause() {
    setState(() {
      if (controller.value.isPlaying) {
        _hideStuff = false;
        _hideTimer?.cancel();
        controller.pause();
      } else {
        _cancelAndRestartTimer();

        if (controller.value.initialized) {
          controller.play();
        } else {
          controller.initialize();
          controller.play();
        }
      }
    });
  }

  void _skipBack() {
    _cancelAndRestartTimer();
    final beginning = Duration(seconds: 0).inMilliseconds;
    final skip =
        (controller.value.position - Duration(seconds: 15)).inMilliseconds;
    controller.seekTo(Duration(milliseconds: math.max(skip, beginning)));
  }

  void _skipForward() {
    _cancelAndRestartTimer();
    final end = controller.value.duration?.inMilliseconds ?? 0;
    final skip =
        (controller.value.position + Duration(seconds: 15)).inMilliseconds;
    controller.seekTo(Duration(milliseconds: math.min(skip, end)));
  }

  void _startHideTimer() {
    _hideTimer = Timer(const Duration(seconds: 10), () {
      setState(() => _hideStuff = true);
    });
  }

  void _updateState() {
    setState(() {});
  }
}

class VideoProgressBar extends StatefulWidget {
  VideoProgressBar(
    this.controller, {
    ProgressColors colors,
    this.onDragEnd,
    this.onDragStart,
    this.onDragUpdate,
  }) : colors = colors ?? ProgressColors();

  final VideoPlayerController controller;
  final ProgressColors colors;
  final Function() onDragStart;
  final Function() onDragEnd;
  final Function() onDragUpdate;

  @override
  _VideoProgressBarState createState() {
    return _VideoProgressBarState();
  }
}

class _VideoProgressBarState extends State<VideoProgressBar> {
  VoidCallback listener;

  VideoPlayerController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    listener = () => setState(() {});
    controller.addListener(listener);
  }

  @override
  void didUpdateWidget(VideoProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
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
    void seekToRelativePosition(Offset globalPosition,
        [bool isPreview = false]) {
      final RenderBox box = context.findRenderObject();
      final Offset tapPos = box.globalToLocal(globalPosition);
      final double relative = tapPos.dx / box.size.width;
      final Duration position = controller.value.duration * relative;
      controller.seekToPreview(isPreview: true, moment: position);
    }

    return GestureDetector(
      child: Center(
        child: Container(
          height: MediaQuery.of(context).size.height,
          width: MediaQuery.of(context).size.width,
          child: CustomPaint(
            painter: _ProgressBarPainter(
              controller.value,
              widget.colors,
            ),
          ),
        ),
      ),
      onHorizontalDragStart: (DragStartDetails details) {
        if (!controller.value.initialized) {
          return;
        }
        if (widget.onDragStart != null) {
          widget.onDragStart();
        }
      },
      onHorizontalDragUpdate: (DragUpdateDetails details) {
        if (!controller.value.initialized) {
          return;
        }
        if (widget.onDragUpdate != null) {
          widget.onDragUpdate();
        }
        seekToRelativePosition(details.globalPosition, true);
      },
      onHorizontalDragEnd: (DragEndDetails details) {
        if (!controller.value.initialized) {
          return;
        }
        if (widget.onDragEnd != null) {
          widget.onDragEnd();
        }
        controller.seekToPreview();
      },
      onTapDown: (TapDownDetails details) {
        if (!controller.value.initialized) {
          return;
        }
        seekToRelativePosition(details.globalPosition, true);
      },
      onTapUp: (TapUpDetails details) {
        if (!controller.value.initialized) {
          return;
        }
        controller.seekToPreview();
      },
    );
  }
}

class _ProgressBarPainter extends CustomPainter {
  _ProgressBarPainter(this.value, this.colors);

  VideoPlayerValue value;
  ProgressColors colors;

  @override
  bool shouldRepaint(CustomPainter painter) {
    return true;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final barHeight = 5.0;
    final handleHeight = 6.0;
    final baseOffset = size.height / 2 - barHeight / 2.0;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromPoints(
          Offset(0.0, baseOffset),
          Offset(size.width, baseOffset + barHeight),
        ),
        Radius.circular(4.0),
      ),
      colors.backgroundPaint,
    );
    if (!value.initialized) {
      return;
    }

    int maxBuffered = 0;
    for (DurationRange range in value.buffered) {
      final int end = range.end.inMilliseconds;
      if (end > maxBuffered) {
        maxBuffered = end;
      }
    }
    final double bufferedPartPercent =
        maxBuffered / value.duration.inMilliseconds;
    final double bufferedPart =
        bufferedPartPercent > 1 ? size.width : bufferedPartPercent * size.width;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromPoints(
          Offset(0.0, baseOffset),
          Offset(bufferedPart, baseOffset + barHeight),
        ),
        Radius.circular(4.0),
      ),
      colors.bufferedPaint,
    );

    final double playedPartPercent =
        (value.isPreview ? value.previewPosition : value.position)
                .inMilliseconds /
            value.duration.inMilliseconds;
    final double playedPart =
        playedPartPercent > 1 ? size.width : playedPartPercent * size.width;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromPoints(
          Offset(0.0, baseOffset),
          Offset(playedPart, baseOffset + barHeight),
        ),
        Radius.circular(4.0),
      ),
      colors.playedPaint,
    );

    final shadowPath = Path()
      ..addOval(Rect.fromCircle(
          center: Offset(playedPart, baseOffset + barHeight / 2),
          radius: handleHeight));

    canvas.drawShadow(shadowPath, Colors.black, 0.2, false);
    canvas.drawCircle(
      Offset(playedPart, baseOffset + barHeight / 2),
      handleHeight,
      colors.handlePaint,
    );
  }
}

class ProgressColors {
  ProgressColors({
    Color playedColor: const Color.fromRGBO(255, 0, 0, 0.7),
    Color bufferedColor: const Color.fromRGBO(30, 30, 200, 0.2),
    Color handleColor: const Color.fromRGBO(200, 200, 200, 1.0),
    Color backgroundColor: const Color.fromRGBO(200, 200, 200, 0.5),
  })  : playedPaint = Paint()..color = playedColor,
        bufferedPaint = Paint()..color = bufferedColor,
        handlePaint = Paint()..color = handleColor,
        backgroundPaint = Paint()..color = backgroundColor;

  final Paint playedPaint;
  final Paint bufferedPaint;
  final Paint handlePaint;
  final Paint backgroundPaint;
}
