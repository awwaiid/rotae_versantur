
Engine_RotaeVersantur : CroneEngine {
  classvar numWheels = 4;
  var oscPositionInfo;
  var wheels;
  var buffers;
  var recorders;
  // var recBuf;
  // var recorder;
  // var recBus;

  *new { arg context, doneCallback;
    ^super.new(context, doneCallback);
  }

  alloc {

    ~recBus = Bus.audio(context.server, 2);

    SynthDef(\WheelSynth, {
      arg out=0, recordBus, bouncing=0, bufnum=0, rate=1, startFrame=0, endFrame=1, t_trig=0, jumpPos=0, wheelNum=0, amp=1, reverbMix=0, pan=0;
      var snd, playHead, duration, envelope, frames;

      rate = rate * BufRateScale.kr(bufnum);
      frames = BufFrames.kr(bufnum);
      duration = (endFrame - startFrame) / (rate.max(0.001)) / context.server.sampleRate;

      envelope = EnvGen.ar(
        Env.new(
          levels: [0, 1, 1, 0],
          times: [0, (duration - 0.01).max(0), 0.01],
          curve: \sine,
        ),
        gate: t_trig,
      );

      playHead = Phasor.ar(
        trig: t_trig,
        rate: rate,
        start: startFrame,
        end: endFrame,
        resetPos: jumpPos,
      );

      SendReply.kr(
        trig: Impulse.kr(4),
        cmdName: '/playPosition',
        values: [ wheelNum, frames, startFrame, endFrame, playHead ]
      );

      snd = BufRd.ar(
        numChannels: 2,
        bufnum: bufnum,
        phase: playHead,
        loop: 0,
        interpolation: 4,
      );

      snd = Balance2.ar(snd[0], snd[1], pan);
      snd = FreeVerb2.ar(snd[0], snd[1], reverbMix);
      snd = snd * envelope * amp;

      Out.ar(out, snd);
      Out.ar(recordBus, snd * bouncing);
    }).add;

    oscPositionInfo = OSCFunc({ |msg|
      var wheelNum = msg[3];
      var frames = msg[4];
      var startFrame = msg[5];
      var endFrame = msg[6];
      var playHead = msg[7];
      NetAddr("127.0.0.1", 10111).sendMsg(
        "/playPosition", wheelNum, frames, startFrame, endFrame, playHead
      );
    }, '/playPosition');

    // inputBus = Bus.audio(context.server, 1);

    buffers = Array.fill(numWheels, {
      arg i;
      var bufferLengthSeconds = 1; // 30 seconds each 60 * 5; // 5 minutes each

      Buffer.alloc(
        context.server,
        context.server.sampleRate * bufferLengthSeconds,
        2
      );
    });

    context.server.sync;

		wheels = Array.fill(numWheels, { arg i;
			Synth.new(\WheelSynth, [\wheelNum, i, \bufnum, buffers[i].bufnum, \recordBus, ~recBus]);
		});

    context.server.sync;

    this.addCommand("loadFromFile", "is", {
      arg msg;
      var wheelNum = msg[1];
      var filename = msg[2];

      ("Going to load " ++ filename ++ " into wheel " ++ wheelNum).postln;

      // Buffer.read(context.server, filename, action: {
      // buffers[wheelNum].read(filename, action: {
      Buffer.read(context.server, filename, action: {
        arg buffer;
        ("loaded " ++ filename ++ " frames: " ++ buffer.numFrames).postln;
        // wheels[wheelNum].set(\bufnum, bufnum, \rate, 0, \t_trig, 1);
        buffers[wheelNum].free; // Free the old one
        buffers[wheelNum] = buffer;
        wheels[wheelNum].set(\bufnum, buffer.bufnum, \endFrame, buffer.numFrames, \rate, 0, \t_trig, 1);

        // Communicate back that the sample is loaded
        // scriptAddress.sendBundle(0, ['/fileLoaded', filename, fileFrames]);
        NetAddr("127.0.0.1", 10111).sendMsg(
          "/fileLoaded", wheelNum, buffer.numFrames
        );

      })
    });

    SynthDef(\recordToFile, {
      arg bufnum = 0, recordBus, out = 0, monitorAmp = 1;
      var mic = SoundIn.ar([0, 1]);
      var wheels = In.ar(recordBus, 2);
      var mix = mic + wheels;

      // mic.poll(4);
      // wheels.poll(4);
      // mix.poll(4);

      DiskOut.ar(bufnum, mix);
      // DiskOut.ar(bufnum, mic);
      Out.ar(out, mic * monitorAmp);
    }).add;

    // SynthDef(\recordToFile, {
    //   arg bufnum = 0, out = 0, monitorAmp = 1;
    //   var in = SoundIn.ar([0, 1]);
    //   DiskOut.ar(bufnum, in);
    //   Out.ar(out, in * monitorAmp);
    // }).add;


    this.addCommand("recordStart", "i", {
      arg msg;
      var wheelNum = msg[1];
      ("Recording starting for wheel " ++ wheelNum).postln;
      ~recBuf = Buffer.alloc(context.server, 65536, 2);
      ~recBuf.write("/home/we/dust/audio/rotae_versantur/recording_buffer_" ++ wheelNum ++ ".wav", "wav", "int24", 0, 0, true);
      ~recorder = Synth(\recordToFile, [\bufnum, ~recBuf, \recordBus, ~recBus], addAction: \addToTail);
    });

    this.addCommand("recordStop", "i", {
      arg msg;
      var wheelNum = msg[1];
      ("Recording stopping for wheel " ++ wheelNum).postln;
      ~recorder.free;
      ~recBuf.close({
        ("Recording file closed for wheel " ++ wheelNum).postln;
        ~recBuf.free;
        Buffer.read(context.server, "/home/we/dust/audio/rotae_versantur/recording_buffer_" ++ wheelNum ++ ".wav", action: {
          arg buffer;
          ("recording loaded frames: " ++ buffer.numFrames).postln;
          buffers[wheelNum].free; // Free the old one
          buffers[wheelNum] = buffer;
          // wheels[wheelNum].set(\bufnum, buffer.bufnum, \rate, 0, \t_trig, 1);
          wheels[wheelNum].set(\bufnum, buffer.bufnum, \endFrame, buffer.numFrames);
          NetAddr("127.0.0.1", 10111).sendMsg(
            "/fileLoaded", wheelNum, buffer.numFrames
          );
        });
      });
    });

    this.addCommand("bounceStart", "i", {
      arg msg;
      var wheelNum = msg[1];
      wheels[wheelNum].set(\bouncing, 1);
      ("Bounce on: " ++ wheelNum).postln;
    });

    this.addCommand("bounceStop", "i", {
      arg msg;
      var wheelNum = msg[1];
      wheels[wheelNum].set(\bouncing, 0);
      ("Bounce off: " ++ wheelNum).postln;
    });


    this.addCommand("setPosition", "ii", {
      arg msg;
      var wheelNum = msg[1];
      var targetFrame = msg[2];
      ("Wheel " ++ wheelNum ++ " jumping to frame " ++ targetFrame).postln;
      wheels[wheelNum].set(\jumpPos, targetFrame, \t_trig, 1);
    });

    this.addCommand("setRate", "if", {
      arg msg;
      var wheelNum = msg[1];
      var rate = msg[2];
      ("Wheel " ++ wheelNum ++ " setting rate to " ++ rate).postln;
      wheels[wheelNum].set(\rate, rate);
    });

    this.addCommand("setAmp", "if", {
      arg msg;
      var wheelNum = msg[1];
      var amp = msg[2];
      ("Wheel " ++ wheelNum ++ " setting amp to " ++ amp).postln;
      wheels[wheelNum].set(\amp, amp);
    });

    this.addCommand("setPan", "if", {
      arg msg;
      var wheelNum = msg[1];
      var pan = msg[2];
      ("Wheel " ++ wheelNum ++ " setting pan to " ++ pan).postln;
      wheels[wheelNum].set(\pan, pan);
    });

    this.addCommand("setReverbMix", "if", {
      arg msg;
      var wheelNum = msg[1];
      var reverbMix = msg[2];
      ("Wheel " ++ wheelNum ++ " setting reverbMix to " ++ reverbMix).postln;
      wheels[wheelNum].set(\reverbMix, reverbMix);
    });

    this.addCommand("setLength", "if", {
      arg msg;
      var wheelNum = msg[1];
      var length = msg[2];
      ("Wheel " ++ wheelNum ++ " setting endFrame to " ++ length).postln;
      wheels[wheelNum].set(\endFrame, length);
    });
  }

  free {
    if(~recorder.notNil, { ~recorder.free; });
    if(~recBuf.notNil, { ~recBuf.free; });
    wheels.do({ arg wheel; wheel.free; });
    buffers.do({ arg buffer; buffer.free; });
    oscPositionInfo.free;
    ~recBus.free;
  }
}
