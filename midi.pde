// Haptic to Audio

import themidibus.MidiBus;

MidiOut midiOut = new MidiOut();

class MidiOut {
  // final static String USING = "ms";
  // final static String USING = "cool";
  final static String USING = "android";
  // final static String USING = "2017";
  // final static String USING = "Gervill";
  MidiBus myBus;
  int last_pitch = -1;
  boolean ignore = false;
  int pitch_from_network = -1;

  MidiOut() {
    MidiBus.list();
    switch (USING) {
      case "ms":
        myBus = new MidiBus(this, -1, "Microsoft GS Wavetable Synth");
        myBus.sendMessage("\u00c0\u0049".getBytes());
        break;
      case "2017":
        myBus = new MidiBus(this, -1, "SimpleSynth virtual input");
        break;
      case "cool":
        myBus = new MidiBus(this, -1, "VirtualMIDISynth #1");
        break;
      case "android":
        myBus = new MidiBus(this, -1, "MIDI function");  // Android
        break;
      case "Gervill":
        myBus = new MidiBus(this, -1, "Gervill");
        break;
      default:
        assert false;
      break;
    }
  }

  void play(int pitch) {
    clear();
    myBus.sendNoteOn(0, pitch, 127);
    last_pitch = pitch;
  }

  void clear() {
    if (last_pitch != -1) {
      myBus.sendNoteOff(0, last_pitch, 127);
      last_pitch = -1;
    }
  }

  void onNoteControlChange() {
    // println("pfn", pitch_from_network);
    if (ignore) {
      return;
    }
    if (pitch_from_network == -1) {
      clear();
    } else {
      play(pitch_from_network);
    }
  }

  void pulse() {
    int pitch = last_pitch;
    clear();
    play(pitch);
  }

  void setExpression(int value) {
    int number;
    if (MIDI_advanced_expression) {
      number = 11;
    } else {
      number = 7;
    }
    myBus.sendControllerChange(0, number, value);
  }

  static final float MIDI_BEND_MAX = 2; // semitones
  static final int PITCH_BEND_ORIGIN = 8192;
  void setPitchBend(float x) {
    float k = x / MIDI_BEND_MAX;
    if (k > 1) {
      k = 1;
      warnPitchBend(x);
    }
    if (k < -1) {
      k = -1;
      warnPitchBend(x);
    }
    int value = round(k * (PITCH_BEND_ORIGIN-1) + PITCH_BEND_ORIGIN);
    myBus.sendMessage(224, value % 128, value / 128);
  }

  void warnPitchBend(float x) {
    if (network.is_note_on) {
      print("Warning: MIDI pitch bend out-of-bound. Value clipped. Intended: ");
      println(x);
    }
  }
}
