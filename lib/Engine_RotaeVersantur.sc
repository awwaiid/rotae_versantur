
Engine_RotaeVersantur : CroneEngine {
  var buffer;
  var play_buf_player_synthdef;
  var oscPositionInfo;

  *new { arg context, doneCallback;
    ^super.new(context, doneCallback);
  }

  alloc {

    play_buf_player_synthdef = SynthDef("PlayBufPlayer", {
      arg out=0, bufnum=0, rate=1, start=0, end=1, t_trig=0, loops=1, jumpPos=0;
      var snd, playHead, frames, duration, envelope;

      rate = rate * BufRateScale.kr(bufnum);
      frames = BufFrames.kr(bufnum);
      duration = frames * (end - start) / rate / context.server.sampleRate * loops;

      envelope = EnvGen.ar(
        Env.new(
          levels: [0, 1, 1, 0],
          times: [0, duration - 0.01, 0.01],
          curve: \sine,
        ),
        gate: t_trig,
      );

      playHead = Phasor.ar(
        trig: t_trig,
        rate: rate,
        start: start * frames,
        end: end * frames,
        resetPos: jumpPos,
      );

      SendReply.kr(
        trig: Impulse.kr(15),
        cmdName: '/playPosition',
        values: [ frames, start * frames, end * frames, playHead ]
      );

      snd = BufRd.ar(
        numChannels: 2,
        bufnum: bufnum,
        phase: playHead,
        loop: 0,
        interpolation: 4,
      );

      snd = snd * envelope;

      Out.ar(out, snd)
    }).play;

    oscPositionInfo = OSCFunc({ |msg|
      var frames = msg[3];
      var startFrame = msg[4];
      var endFrame = msg[5];
      var playHead = msg[6];
      // var id=msg[3].asInteger;
      // var progress=msg[4];
      NetAddr("127.0.0.1", 10111).sendMsg(
        "/playPosition", frames, startFrame, endFrame, playHead
      );
    }, '/playPosition');

    this.addCommand("loadFromFile", "s", {
      arg msg;
      var filename = msg[1];
      ("Going to load " ++ filename).postln;
      Buffer.read(context.server, filename, action: {
        arg bufnum;
        ("loaded " ++ filename ++ " frames: " ++ bufnum.numFrames).postln;
        play_buf_player_synthdef.set(\bufnum, bufnum, \t_trig, 1);

        // Communicate back that the sample is loaded
        // scriptAddress.sendBundle(0, ['/engineSamplerLoad', filename, bufnum.numFrames]);

        // Create synth and start it playing
        // Synth("samplePlayerSynth", [
        //   \bufnum, bufnum
        // ], target: context.server);

      })
    });

    this.addCommand("setPosition", "i", {
      arg msg;
      var targetFrame = msg[1];
      ("Going to frame " ++ targetFrame).postln;
      play_buf_player_synthdef.set(\jumpPos, targetFrame, \t_trig, 1);
    });
  }


  free {
    oscPositionInfo.free;
  }
}
