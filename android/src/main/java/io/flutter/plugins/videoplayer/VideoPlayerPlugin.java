// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package io.flutter.plugins.videoplayer;

import android.content.Context;
import android.net.Uri;
import android.os.Build;
import android.util.Log;
import android.util.LongSparseArray;
import android.view.Surface;
import com.google.android.exoplayer2.C;
import com.google.android.exoplayer2.ExoPlaybackException;
import com.google.android.exoplayer2.ExoPlayerFactory;
import com.google.android.exoplayer2.Format;
import com.google.android.exoplayer2.PlaybackParameters;
import com.google.android.exoplayer2.Player;
import com.google.android.exoplayer2.SimpleExoPlayer;
import com.google.android.exoplayer2.Timeline;
import com.google.android.exoplayer2.audio.AudioAttributes;
import com.google.android.exoplayer2.extractor.DefaultExtractorsFactory;
import com.google.android.exoplayer2.source.ExtractorMediaSource;
import com.google.android.exoplayer2.source.MediaSource;
import com.google.android.exoplayer2.source.TrackGroupArray;
import com.google.android.exoplayer2.source.dash.DashMediaSource;
import com.google.android.exoplayer2.source.dash.DefaultDashChunkSource;
import com.google.android.exoplayer2.source.hls.HlsMediaSource;
import com.google.android.exoplayer2.source.smoothstreaming.DefaultSsChunkSource;
import com.google.android.exoplayer2.source.smoothstreaming.SsMediaSource;
import com.google.android.exoplayer2.trackselection.DefaultTrackSelector;
import com.google.android.exoplayer2.trackselection.TrackSelectionArray;
import com.google.android.exoplayer2.trackselection.TrackSelector;
import com.google.android.exoplayer2.upstream.DataSource;
import com.google.android.exoplayer2.upstream.DefaultDataSourceFactory;
import com.google.android.exoplayer2.upstream.DefaultHttpDataSource;
import com.google.android.exoplayer2.upstream.DefaultHttpDataSourceFactory;
import com.google.android.exoplayer2.util.Util;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.Registrar;
import io.flutter.view.TextureRegistry;
import java.util.Arrays;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import static com.google.android.exoplayer2.Player.REPEAT_MODE_ALL;
import static com.google.android.exoplayer2.Player.REPEAT_MODE_OFF;

public class VideoPlayerPlugin implements MethodCallHandler {

  private static final String TAG = "VideoPlayerPlugin";

  private static class VideoPlayer {

    private SimpleExoPlayer exoPlayer;

    private Surface surface;

    private final TextureRegistry.SurfaceTextureEntry textureEntry;

    private QueuingEventSink eventSink = new QueuingEventSink();

    private final EventChannel eventChannel;

    private boolean isInitialized = false;

    VideoPlayer(
        Context context,
        EventChannel eventChannel,
        TextureRegistry.SurfaceTextureEntry textureEntry,
        String dataSource,
        Result result) {
      this.eventChannel = eventChannel;
      this.textureEntry = textureEntry;

      TrackSelector trackSelector = new DefaultTrackSelector();
      exoPlayer = ExoPlayerFactory.newSimpleInstance(context, trackSelector);

      Uri uri = Uri.parse(dataSource);

      DataSource.Factory dataSourceFactory;
      if ("asset".equals(uri.getScheme()) || "file".equals(uri.getScheme())) {
        dataSourceFactory = new DefaultDataSourceFactory(context, "ExoPlayer");
      } else {
        dataSourceFactory =
            new DefaultHttpDataSourceFactory(
                "ExoPlayer",
                null,
                DefaultHttpDataSource.DEFAULT_CONNECT_TIMEOUT_MILLIS,
                DefaultHttpDataSource.DEFAULT_READ_TIMEOUT_MILLIS,
                true);
      }

      MediaSource mediaSource = buildMediaSource(uri, dataSourceFactory, context);
      exoPlayer.prepare(mediaSource);

      setupVideoPlayer(eventChannel, textureEntry, result);
    }

    private MediaSource buildMediaSource(
        Uri uri, DataSource.Factory mediaDataSourceFactory, Context context) {
      int type = Util.inferContentType(uri.getLastPathSegment());
      switch (type) {
        case C.TYPE_SS:
          return new SsMediaSource.Factory(
              new DefaultSsChunkSource.Factory(mediaDataSourceFactory),
              new DefaultDataSourceFactory(context, null, mediaDataSourceFactory))
              .createMediaSource(uri);
        case C.TYPE_DASH:
          return new DashMediaSource.Factory(
              new DefaultDashChunkSource.Factory(mediaDataSourceFactory),
              new DefaultDataSourceFactory(context, null, mediaDataSourceFactory))
              .createMediaSource(uri);
        case C.TYPE_HLS:
          return new HlsMediaSource.Factory(mediaDataSourceFactory).createMediaSource(uri);
        case C.TYPE_OTHER:
          return new ExtractorMediaSource.Factory(mediaDataSourceFactory)
              .setExtractorsFactory(new DefaultExtractorsFactory())
              .createMediaSource(uri);
        default: {
          throw new IllegalStateException("Unsupported type: " + type);
        }
      }
    }

    private void setupVideoPlayer(
        EventChannel eventChannel,
        TextureRegistry.SurfaceTextureEntry textureEntry,
        Result result) {

      eventChannel.setStreamHandler(
          new EventChannel.StreamHandler() {
            @Override
            public void onListen(Object o, EventChannel.EventSink sink) {
              eventSink.setDelegate(sink);
            }

            @Override
            public void onCancel(Object o) {
              eventSink.setDelegate(null);
            }
          });

      surface = new Surface(textureEntry.surfaceTexture());
      exoPlayer.setVideoSurface(surface);
      setAudioAttributes(exoPlayer);

      exoPlayer.addListener(
          new Player.EventListener() {

            @Override public void onPlayerStateChanged(final boolean playWhenReady, final int playbackState) {
              if (playbackState == Player.STATE_BUFFERING) {
                Map<String, Object> event = new HashMap<>();
                event.put("event", "bufferingUpdate");
                List<Integer> range = Arrays.asList(0, exoPlayer.getBufferedPercentage());
                // iOS supports a list of buffered ranges, so here is a list with a single range.
                event.put("values", Collections.singletonList(range));
                eventSink.success(event);
              } else if (playbackState == Player.STATE_READY && !isInitialized) {
                isInitialized = true;
                sendInitialized();
              }
            }

            @Override public void onPlayerError(final ExoPlaybackException error) {
              if (eventSink != null) {
                eventSink.error("VideoError", "Video player had error " + error, null);
              }
            }

            @Override public void onTimelineChanged(Timeline timeline, Object manifest, int reason) {
              Log.e(TAG, "timeline: " + timeline);
            }

            @Override public void onTracksChanged(TrackGroupArray trackGroups, TrackSelectionArray trackSelections) {
              Log.e(TAG, "onTracksChanged: " + trackGroups);
            }

            @Override public void onLoadingChanged(boolean isLoading) {
              Log.e(TAG, "isLoading: " + isLoading);
            }

            @Override public void onRepeatModeChanged(int repeatMode) {
              Log.e(TAG, "repeatMode: " + repeatMode);
            }

            @Override public void onShuffleModeEnabledChanged(boolean shuffleModeEnabled) {
              Log.e(TAG, "shuffleModeEnabled: " + shuffleModeEnabled);
            }

            @Override public void onPositionDiscontinuity(int reason) {
              Log.e(TAG, "onPositionDiscontinuity: " + reason);
            }

            @Override public void onPlaybackParametersChanged(PlaybackParameters playbackParameters) {
              Log.e(TAG, "onPlaybackParametersChanged: " + playbackParameters);
            }

            @Override public void onSeekProcessed() {
              Log.e(TAG, "onSeekProcessed");
            }
          });

      Map<String, Object> reply = new HashMap<>();
      reply.put("textureId", textureEntry.id());
      result.success(reply);
    }

    @SuppressWarnings("deprecation")
    private static void setAudioAttributes(SimpleExoPlayer exoPlayer) {
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
        exoPlayer.setAudioAttributes(
            new AudioAttributes.Builder().setContentType(C.CONTENT_TYPE_MOVIE).build());
      } else {
        exoPlayer.setAudioStreamType(C.STREAM_TYPE_MUSIC);
      }
    }

    void play() {
      exoPlayer.setPlayWhenReady(true);
    }

    void pause() {
      exoPlayer.setPlayWhenReady(false);
    }

    void setLooping(boolean value) {
      exoPlayer.setRepeatMode(value ? REPEAT_MODE_ALL : REPEAT_MODE_OFF);
    }

    void setVolume(double value) {
      float bracketedValue = (float) Math.max(0.0, Math.min(1.0, value));
      exoPlayer.setVolume(bracketedValue);
    }

    void seekTo(int location) {
      exoPlayer.seekTo(location);
    }

    long getPosition() {
      return exoPlayer.getCurrentPosition();
    }

    private void sendInitialized() {
      if (isInitialized) {
        Map<String, Object> event = new HashMap<>();
        event.put("event", "initialized");
        event.put("duration", exoPlayer.getDuration());

        if (exoPlayer.getVideoFormat() != null) {
          Format videoFormat = exoPlayer.getVideoFormat();
          int width = videoFormat.width;
          int height = videoFormat.height;
          int rotationDegrees = videoFormat.rotationDegrees;
          // Switch the width/height if video was taken in portrait mode
          if (rotationDegrees == 90 || rotationDegrees == 270) {
            width = exoPlayer.getVideoFormat().height;
            height = exoPlayer.getVideoFormat().width;
          }
          event.put("width", width);
          event.put("height", height);
        }
        eventSink.success(event);
      }
    }

    void dispose() {
      if (isInitialized) {
        exoPlayer.stop();
      }
      textureEntry.release();
      eventChannel.setStreamHandler(null);
      if (surface != null) {
        surface.release();
      }
      if (exoPlayer != null) {
        exoPlayer.release();
      }
    }
  }

  public static void registerWith(Registrar registrar) {
    final VideoPlayerPlugin plugin = new VideoPlayerPlugin(registrar);
    final MethodChannel channel =
        new MethodChannel(registrar.messenger(), "flutter.io/videoPlayer");
    channel.setMethodCallHandler(plugin);
    registrar.addViewDestroyListener(
        view -> {
          plugin.onDestroy();
          return false; // We are not interested in assuming ownership of the NativeView.
        });
  }

  private VideoPlayerPlugin(Registrar registrar) {
    this.registrar = registrar;
    this.videoPlayers = new LongSparseArray<>();
  }

  private final LongSparseArray<VideoPlayer> videoPlayers;

  private final Registrar registrar;

  void onDestroy() {
    // The whole FlutterView is being destroyed. Here we release resources acquired for all instances
    // of VideoPlayer. Once https://github.com/flutter/flutter/issues/19358 is resolved this may
    // be replaced with just asserting that videoPlayers.isEmpty().
    // https://github.com/flutter/flutter/issues/20989 tracks this.
    for (int i = 0; i < videoPlayers.size(); i++) {
      videoPlayers.valueAt(i).dispose();
    }
    videoPlayers.clear();
  }

  @Override
  public void onMethodCall(MethodCall call, Result result) {
    TextureRegistry textures = registrar.textures();
    if (textures == null) {
      result.error("no_activity", "video_player plugin requires a foreground activity", null);
      return;
    }
    switch (call.method) {
      case "init":
        for (int i = 0; i < videoPlayers.size(); i++) {
          videoPlayers.valueAt(i).dispose();
        }
        videoPlayers.clear();
        break;
      case "create": {
        TextureRegistry.SurfaceTextureEntry handle = textures.createSurfaceTexture();
        EventChannel eventChannel =
            new EventChannel(
                registrar.messenger(), "flutter.io/videoPlayer/videoEvents" + handle.id());

        VideoPlayer player;
        if (call.argument("asset") != null) {
          String assetLookupKey;
          if (call.argument("package") != null) {
            assetLookupKey =
                registrar.lookupKeyForAsset(
                    call.argument("asset"), call.argument("package"));
          } else {
            assetLookupKey = registrar.lookupKeyForAsset(call.argument("asset"));
          }
          player =
              new VideoPlayer(
                  registrar.context(),
                  eventChannel,
                  handle,
                  "asset:///" + assetLookupKey,
                  result);
          videoPlayers.put(handle.id(), player);
        } else {
          player =
              new VideoPlayer(
                  registrar.context(),
                  eventChannel,
                  handle,
                  call.argument("uri"),
                  result);
          videoPlayers.put(handle.id(), player);
        }
        break;
      }
      default: {
        long textureId = ((Number) call.argument("textureId")).longValue();
        VideoPlayer player = videoPlayers.get(textureId);
        if (player == null) {
          result.error(
              "Unknown textureId",
              "No video player associated with texture id " + textureId,
              null);
          return;
        }
        onMethodCall(call, result, textureId, player);
        break;
      }
    }
  }

  private void onMethodCall(MethodCall call, Result result, long textureId, VideoPlayer player) {
    switch (call.method) {
      case "setLooping":
        player.setLooping(call.argument("looping"));
        result.success(null);
        break;
      case "setVolume":
        player.setVolume(call.argument("volume"));
        result.success(null);
        break;
      case "play":
        player.play();
        result.success(null);
        break;
      case "pause":
        player.pause();
        result.success(null);
        break;
      case "seekTo":
        int location = ((Number) call.argument("location")).intValue();
        player.seekTo(location);
        result.success(null);
        break;
      case "position":
        result.success(player.getPosition());
        break;
      case "dispose":
        player.dispose();
        videoPlayers.remove(textureId);
        result.success(null);
        break;
      default:
        result.notImplemented();
        break;
    }
  }
}
