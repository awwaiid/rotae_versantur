
Engine_RotaeVersantur : CroneEngine {
  classvar numReels = 4;
  var buffer;
  var play_buf_player_synthdef;
  var oscPositionInfo;
  var reels;

  *new { arg context, doneCallback;
    ^super.new(context, doneCallback);
  }

  alloc {

    SynthDef(\ReelSynth, {
      arg out=0, bufnum=0, rate=1, start=0, end=1, t_trig=0, loops=1, jumpPos=0, reelNum=0, amp=1;
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
        trig: Impulse.kr(4),
        cmdName: '/playPosition',
        values: [ reelNum, frames, start * frames, end * frames, playHead ]
      );

      snd = BufRd.ar(
        numChannels: 2,
        bufnum: bufnum,
        phase: playHead,
        loop: 0,
        interpolation: 4,
      );

      snd = snd * envelope * amp;

      Out.ar(out, snd)
    }).add;

		reels = Array.fill(numReels, { arg i;
			Synth.new(\ReelSynth, [\reelNum, i]);
		});

    oscPositionInfo = OSCFunc({ |msg|
      var reelNum = msg[3];
      var frames = msg[4];
      var startFrame = msg[5];
      var endFrame = msg[6];
      var playHead = msg[7];
      // var id=msg[3].asInteger;
      // var progress=msg[4];
      NetAddr("127.0.0.1", 10111).sendMsg(
        "/playPosition", reelNum, frames, startFrame, endFrame, playHead
      );
    }, '/playPosition');

    this.addCommand("loadFromFile", "is", {
      arg msg;
      var reelNum = msg[1];
      var filename = msg[2];
      ("Going to load " ++ filename ++ " into reel " ++ reelNum).postln;
      Buffer.read(context.server, filename, action: {
        arg bufnum;
        ("loaded " ++ filename ++ " frames: " ++ bufnum.numFrames).postln;
        reels[reelNum].set(\bufnum, bufnum, \rate, 0, \t_trig, 1);

        // Communicate back that the sample is loaded
        // scriptAddress.sendBundle(0, ['/engineSamplerLoad', filename, bufnum.numFrames]);

      })
    });

    this.addCommand("setPosition", "ii", {
      arg msg;
      var reelNum = msg[1];
      var targetFrame = msg[2];
      ("Reel " ++ reelNum ++ " jumping to frame " ++ targetFrame).postln;
      reels[reelNum].set(\jumpPos, targetFrame, \t_trig, 1);
    });

    this.addCommand("setRate", "if", {
      arg msg;
      var reelNum = msg[1];
      var rate = msg[2];
      ("Reel " ++ reelNum ++ " setting rate to " ++ rate).postln;
      reels[reelNum].set(\rate, rate);
    });

    this.addCommand("setAmp", "if", {
      arg msg;
      var reelNum = msg[1];
      var amp = msg[2];
      ("Reel " ++ reelNum ++ " setting amp to " ++ amp).postln;
      reels[reelNum].set(\amp, amp);
    });
  }

  free {
    reels.do({ arg reel; reel.free; });
    oscPositionInfo.free;
  }
}
