// Note: only work over https or localhost
//
// thanks:
// - https://medium.com/@mk.pyts/how-to-access-webcam-video-stream-in-flutter-for-web-1bdc74f2e9c7
// - https://kevinwilliams.dev/blog/taking-photos-with-flutter-web
// - https://github.com/cozmo/jsQR
import 'dart:async';
import 'package:universal_html/html.dart' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

///
///call global function jsQR
/// import https://github.com/cozmo/jsQR/blob/master/dist/jsQR.js on your index.html at web folder
///
dynamic _jsQR(d, w, h, o) {
  return js.context.callMethod('jsQR', [d, w, h, o]);
}

class QrCodeCameraWebImpl extends StatefulWidget {
  final void Function(String qrValue) qrCodeCallback;
  final Widget? child;
  final BoxFit fit;
  final Widget Function(BuildContext context, Object error)? onError;

  QrCodeCameraWebImpl({
    Key? key,
    required this.qrCodeCallback,
    this.child,
    this.fit = BoxFit.cover,
    this.onError,
  }) : super(key: key);

  @override
  _QrCodeCameraWebImplState createState() => _QrCodeCameraWebImplState();
}

class _QrCodeCameraWebImplState extends State<QrCodeCameraWebImpl> {
//  final double _width = 1000;
//  final double _height = _width / 4 * 3;
  final String _uniqueKey = UniqueKey().toString();

  //see https://developer.mozilla.org/en-US/docs/Web/API/HTMLMediaElement/readyState
  static const _HAVE_ENOUGH_DATA = 4;

  // Webcam widget to insert into the tree
  late Widget _videoWidget;

  // VideoElement
  late html.VideoElement _video;
  late html.CanvasElement _canvasElement;
  html.CanvasRenderingContext2D? _canvas;
  html.MediaStream? _stream;

  @override
  void initState() {
    super.initState();

    // Create a video element which will be provided with stream source
    _video = html.VideoElement();
    // Register an webcam
    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(
        'webcamVideoElement$_uniqueKey', (int viewId) => _video);
    // Create video widget
    _videoWidget = HtmlElementView(
        key: UniqueKey(), viewType: 'webcamVideoElement$_uniqueKey');

    // Access the webcam stream
    try {
      html.window.navigator.mediaDevices?.getUserMedia({
        'video': {'facingMode': 'user'}
      }).then((html.MediaStream stream) {
        _stream = stream;
        _video.srcObject = stream;
        _video.setAttribute('playsinline',
            'true'); // required to tell iOS safari we don't want fullscreen
        _video.play();
      });
    } catch (err) {
      print(err);
      //Fallback
      try {
        html.window.navigator
            .getUserMedia(video: {'facingMode': 'user'}).then(
                (html.MediaStream stream) {
          _stream = stream;
          _video.srcObject = stream;
          _video.setAttribute('playsinline',
              'true'); // required to tell iOS safari we don't want fullscreen
          _video.play();
        });
      } catch (e) {
        print(e);
      }
    }

//        .mediaDevices   //don't work rear camera
//        .getUserMedia({
//      'video': {
//        'facingMode': 'environment',
//      }
//    })

    _canvasElement = html.CanvasElement();
    _canvas = _canvasElement.getContext("2d") as html.CanvasRenderingContext2D?;
    Future.delayed(Duration(milliseconds: 20), () {
      tick();
    });
  }

  bool _disposed = false;
  tick() {
    if (_disposed) {
      return;
    }

    if (_video.readyState == _HAVE_ENOUGH_DATA) {
      _canvasElement.width = _video.videoWidth;
      _canvasElement.height = _video.videoHeight;
      _canvas?.drawImage(_video, 0, 0);
      var imageData = _canvas?.getImageData(
        0,
        0,
        _canvasElement.width ?? 0,
        _canvasElement.height ?? 0,
      );
      if (imageData is html.ImageData) {
        js.JsObject? code = _jsQR(
          imageData.data,
          imageData.width,
          imageData.height,
          {
            'inversionAttempts': 'dontInvert',
          },
        );
        if (code != null) {
          String value = code['data'];
          this.widget.qrCodeCallback(value);
        }
      }
    }
    Future.delayed(Duration(milliseconds: 10), () => tick());
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: double.infinity,
      width: double.infinity,
      child: FittedBox(
        fit: widget.fit,
        child: SizedBox(
          width: 400,
          height: 300,
          child: _videoWidget,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _video.pause();
    Future.delayed(Duration(milliseconds: 1), () {
      try {
        _stream?.getTracks().forEach((mt) {
          mt.stop();
        });
      } catch (e) {
        print('error on dispose qrcode: $e');
      }
    });
    super.dispose();
  }
}
