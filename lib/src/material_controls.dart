import 'dart:async';

import 'package:chewie/src/animated_play_pause.dart';
import 'package:chewie/src/center_play_button.dart';
import 'package:chewie/src/chewie_player.dart';
import 'package:chewie/src/chewie_progress_colors.dart';
import 'package:chewie/src/material_progress_bar.dart';
import 'package:chewie/src/utils.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class MaterialControls extends StatefulWidget {
  const MaterialControls({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _MaterialControlsState();
  }
}

class _MaterialControlsState extends State<MaterialControls>
    with SingleTickerProviderStateMixin {
  late VideoPlayerValue _latestValue;
  double? _latestVolume;
  bool _hideStuff = true;
  Timer? _hideTimer;
  Timer? _initTimer;
  Timer? _showAfterExpandCollapseTimer;
  bool _dragging = false;
  bool _displayTapped = false;

  final barHeight = 48.0;
  final marginSize = 5.0;

  late VideoPlayerController controller;
  ChewieController? _chewieController;

  // We know that _chewieController is set in didChangeDependencies
  ChewieController get chewieController => _chewieController!;

  @override
  Widget build(BuildContext context) {
    if (_latestValue.hasError) {
      return chewieController.errorBuilder?.call(
            context,
            chewieController.videoPlayerController.value.errorDescription!,
          ) ??
          const Center(
            child: Icon(
              Icons.error,
              color: Colors.white,
              size: 42,
            ),
          );
    }

    return MouseRegion(
      onHover: (_) {
        _showStuff_cancelAndRestartTimer();
      },
      child: GestureDetector(
        onTap: () => _showStuff_cancelAndRestartTimer(),
        child: Stack(
          children: <Widget>[
            if (_latestValue.isBuffering)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else
              _buildHitArea(),
            Positioned(
              top: 30,
              left: 30,
              child: GestureDetector(
                onTap: _onExpandCollapse,
                child: Visibility(
                  visible: chewieController.isFullScreen,
                  child: Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 50,
                  ),
                ),
              ),
            ),
            if (chewieController.allowFullScreen)
              Positioned(
                top: 10,
                right: 10,
                child: GestureDetector(
                  onTap: _onExpandCollapse,
                  child: Visibility(
                    visible: !chewieController.isFullScreen,
                    child: _buildExpandButton(),
                  ),
                ),
              ),
            Align(
                alignment: Alignment.bottomCenter,
                child: _buildBottomBar(context)),
          ],
        ),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    final _oldController = _chewieController;
    _chewieController = ChewieController.of(context);
    controller = chewieController.videoPlayerController;

    if (_oldController != chewieController) {
      _dispose();
      _initialize();
    }

    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _dispose();
    super.dispose();
  }

  void _dispose() {
    controller.removeListener(_updateState);
    _hideTimer?.cancel();
    _initTimer?.cancel();
    _showAfterExpandCollapseTimer?.cancel();
  }

  Future<void> _initialize() async {
    controller.addListener(_updateState);

    _updateState();

    if (controller.value.isPlaying || chewieController.autoPlay) {
      _startHideTimer();
    }

    if (chewieController.showControlsOnInitialize) {
      _initTimer = Timer(const Duration(milliseconds: 200), () {
        setState(() {
          _hideStuff = false;
        });
      });
    }
  }

  void _updateState() {
    setState(() {
      _latestValue = controller.value;
    });
  }

  GestureDetector _buildExpandButton() {
    return GestureDetector(
      onTap: _onExpandCollapse,
      child: AnimatedOpacity(
        opacity: _hideStuff ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 300),
        child: Image.asset(
          'assets/images/fullscreen.png',
          fit: BoxFit.fitWidth,
          height: 40,
          width: 40,
        ),
      ),
    );
  }

  Container _buildHitArea() {
    final bool isFinished = _latestValue.position >= _latestValue.duration;
    if(isFinished) {
      _showStuff_cancelAndRestartTimer();
    }

    return Container(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _hideStuff = !_hideStuff;
          });
        },
        child: Visibility(
          visible: !_hideStuff,
          child: Container(
            width: double.infinity,
            color: Colors.black.withOpacity(0.5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Visibility(
                  visible: !isFinished,
                  child: Opacity(
                    opacity: controller.value.position >= Duration(seconds: 10)
                        ? 1
                        : 0,
                    child: GestureDetector(
                      onTap: () {
                        controller.seekTo(
                            controller.value.position - Duration(seconds: 10));
                      },
                      child: Icon(
                        Icons.replay_10_sharp,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  ),
                ),
                CenterPlayButton(
                  iconColor: Colors.white,
                  backgroundColor: Colors.transparent,
                  isFinished: isFinished,
                  isPlaying: controller.value.isPlaying,
                  show: true,
                  onPressed: _playPause,
                ),
                Visibility(
                  visible: !isFinished,
                  child: Opacity(
                    opacity: (controller.value.duration -
                                controller.value.position) >=
                            Duration(seconds: 10)
                        ? 1
                        : 0,
                    child: GestureDetector(
                      onTap: () {
                        controller.seekTo(
                            controller.value.position + Duration(seconds: 10));
                      },
                      child: Icon(
                        Icons.forward_10_sharp,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPosition(Color? iconColor) {
    final position = _latestValue.position;
    final duration = _latestValue.duration;

    return Container(
      alignment: Alignment.centerLeft,
      padding: EdgeInsets.fromLTRB(30, 0, 0, 0),
      child: Text(
        '${formatDuration(position)} / ${formatDuration(duration)}',
        style: TextStyle(
          fontSize: 20.0,
          color: iconColor,
        ),
      ),
    );
  }

  Container _buildBottomBar(
    BuildContext context,
  ) {
    final iconColor = Theme.of(context).textTheme.button!.color;

    return Container(
      height: _hideStuff ? 10 : 60,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Column(
          children: <Widget>[
            Container(height: 10, child: _buildProgressBar()),

            AnimatedOpacity(
              opacity: _hideStuff ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 300),
              child: Visibility(
                visible: !_hideStuff,
                child: Container(
                  height: 50,
                  child: _buildPosition(Colors.white),
                ),
              ),
            ),
            //_buildPlayPause(controller),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return MaterialVideoProgressBar(
      controller,
      onDragStart: () {
        setState(() {
          _dragging = true;
        });

        _hideTimer?.cancel();
      },
      onDragEnd: () {
        setState(() {
          _dragging = false;
        });

        _showStuff_cancelAndRestartTimer();
      },
      barHeight: _hideStuff ? 11 : 7,
      colors: chewieController.materialProgressColors ??
          ChewieProgressColors(
              playedColor: Color(0xFFBB141A),
              handleColor: Theme.of(context).accentColor,
              bufferedColor: Color(0xFFA4A4A4),
              backgroundColor: Theme.of(context).disabledColor),
    );
  }

  //Functions
  void _playPause() {
    final isFinished = _latestValue.position >= _latestValue.duration;

    setState(() {
      if (controller.value.isPlaying) {
        _showStuff_cancelAndRestartTimer();
        controller.pause();
      } else {
        _showStuff_cancelAndRestartTimer();

        if (!controller.value.isInitialized) {
          controller.initialize().then((_) {
            controller.play();
          });
        } else {
          if (isFinished) {
            controller.seekTo(const Duration());
          }
          controller.play();
        }
      }
    });
  }

  void _onExpandCollapse() {
    setState(() {
      _hideStuff = true;

      chewieController.toggleFullScreen();
      _showAfterExpandCollapseTimer =
          Timer(const Duration(milliseconds: 300), () {
        setState(() {
          _showStuff_cancelAndRestartTimer();
        });
      });
    });
  }

  void _showStuff_cancelAndRestartTimer() {

    //Show Stuff
    setState(() {
      _hideStuff = false;
    });

    //Cancel Timer
    _hideTimer?.cancel();

    //Restart Timer
    _startHideTimer();
  }

  void _startHideTimer() {
    //Hide stuff after 3 seconds
    _hideTimer = Timer(const Duration(seconds: 3), ()
    {

      //check if video is finished
      final bool isFinished = _latestValue.position >= _latestValue.duration;

      //Dont hide stuff if video is finished
      if(!isFinished)
      {
        setState(() {
          _hideStuff = true;
        });
      }
    });
  }
}
