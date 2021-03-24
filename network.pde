// parses haptic input to abstract musical objects. 
// For example, parses breath velocity data stream into discreet note events. 

Network network = new Network();

class Network {
  static final float ON_OFF_THRESHOLD = 4.1;
  static final float PARA_EXPONENT = 3.5;
  // "PB" for pitch bend
  static final float PARA_PB_SLOPE = -0.38858001759969996;
  static final float PARA_PB_INTERCEPT = 15.084561444938931;
  // "OT" for octave threshold
  static final float PARA_OT_SLOPE = -11.514012809196554;
  static final float PARA_OT_INTERCEPT = 0.4223719905882273;
  static final float PARA_OT_HYSTERESIS = 0.6959966494737573;

  static float ONE_OVER_PARA_OT_SLOPE;

  char[] finger_position = new char[6];

  Network() {
    Arrays.fill(finger_position, '^');
    ONE_OVER_PARA_OT_SLOPE = 1f / PARA_OT_SLOPE;
  }

  void loop() {
    fingerChangeBaggingLoop();
  }

  int atom_end = -1;  // an atom is a short period of time where the player moves multiple fingers. These movements are viewed as one holistic intention. 
  void fingerChangeBaggingLoop() {
    if (atom_end != -1 && millis() >= atom_end) {
      atom_end = -1;
      updatePitchClass();
    }
  }

  void onFingerChange(int finger_id, char state) {
    finger_position[finger_id] = state;
    if (atom_end == -1) {
      atom_end = millis() + LOW_PASS;
    }

    int fast_pitch_class = fingersToPitchClass(finger_position);
    int fast_pitch = fingersToPitchClass(finger_position) + 12 * octave + TRANSPOSE;
    midiOut.pitch_from_network = fast_pitch;
  }

  int pitch_class;
  void updatePitchClass() {
    pitch_class = fingersToPitchClass(finger_position);
    updateOctave();
    updatePitch();
  }

  void onPressureChange(int x) {
    updateVelocity(pow(x, PARA_EXPONENT));
  }

  float velocity;
  void updateVelocity(float x) {
    velocity = x;
    setExpression();
    update_is_note_on();
    updateOctave();
    updatePitchBend();
  }

  void setExpression() {
    midiOut.setExpression(round(
      min(127, velocity * .0000025)
    ));
  }

  boolean is_note_on;
  void update_is_note_on() {
    boolean new_is_note_on = velocity > ON_OFF_THRESHOLD;
    if (is_note_on != new_is_note_on) {
      if (new_is_note_on) {
        midiOut.pitch_from_network = pitch;
      } else {
        midiOut.pitch_from_network = -1;
      }
      noteEvent();
    }
    is_note_on = new_is_note_on;
  }

  int octave;
  void updateOctave() {
    float y_red = log(velocity) - PARA_OT_INTERCEPT;
    float y_blue = y_red - PARA_OT_HYSTERESIS;
    int red_octave = floor((
      y_red * ONE_OVER_PARA_OT_SLOPE - pitch_class
    ) / 12);
    int blue_octave = floor((
      y_blue * ONE_OVER_PARA_OT_SLOPE - pitch_class
    ) / 12);
    if (octave != blue_octave && octave != red_octave) {
      octave = blue_octave;
      // a little bit un-defined whether it should be red or blue
    }
    updatePitch();
  }

  int pitch;
  void updatePitch() {
    int new_pitch = fingersToPitchClass(finger_position) + 12 * octave + TRANSPOSE;
    boolean diff = false; // make sure `pitch` is already updated when calling downstream functions
    if (pitch != new_pitch) {
      diff = true;
    }
    pitch = new_pitch;
    if (diff && is_note_on) {
      midiOut.pitch_from_network = pitch;
      updatePitchBend();
      noteEvent();
    }
  }

  void updatePitchBend() {
    float slope = exp(pitch * PARA_PB_SLOPE + PARA_PB_INTERCEPT);
    float freq_bend = log(slope * velocity) * 10; // this 10 is not a parameter
    float freq = exp((pitch + 36.37631656229591) * 0.0577622650466621);
    float bent_pitch = log(freq + freq_bend) * 17.312340490667562 - 36.37631656229591;
    float pitch_bend = bent_pitch - pitch;
    midiOut.setPitchBend(pitch_bend * PITCH_BEND_MULTIPLIER);
  }

  void noteEvent() {
    midiOut.onNoteControlChange();
    // print("noteEvent. Octave ");
    // print(octave);
    // print(", fingers ");
    // for (char f : finger_position) {
    //   print(f);
    // }
    // println(". ");
  }

  int fingersToPitchClass(char[] fingers) {
    int i;
    for (i = 0; i < 6; i ++) {
      if (fingers[i] == '^') {
        break;
      }
    }
    i = 6 - i;
    if (i < 3) {
      return i * 2;
    } else {
      return i * 2 - 1;
    }
    // switch (String.valueOf(fingers)) {
    //   case "______": 
    //     return 0;
    //   case "_____^": 
    //     return 2;
    //   case "____^^": 
    //     return 4;
    //   case "___^^^": 
    //     return 5;
    //   case "__^^^^": 
    //     return 7;
    //   case "_^^^^^": 
    //     return 9;
    //   case "^^^^^^": 
    //     return 11;
    //   default:
    //     return -1;
    // }
  }
}
