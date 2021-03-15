// parses haptic input to abstract musical objects. 
// For example, parses breath velocity data stream into discreet note events. 

Network network = new Network();

class Network {
  // static final int ON_OFF_THRESHOLD = 20;
  // static final int OCTAVE_VELOCITY = 130;
  // static final int INTERCEPT_VELOCITY = 50;
  static final int ON_OFF_THRESHOLD = 30;
  static final int OCTAVE_VELOCITY = 200;
  static final int INTERCEPT_VELOCITY = 90;

  char[] finger_position = new char[6];

  Network() {
    Arrays.fill(finger_position, '^');
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
    useMountains();
    updatePitch();
  }

  int velocity;
  void onVelocityChange(int x) {
    velocity = x;
    setExpression();
    update_is_note_on();
    // if (is_note_on) {
    //   detectTuTuTu();
    // }
    useMountains();
  }
  void onPressureChange(int x) {
    onVelocityChange(p2v(x));
  }

  void setExpression() {
    midiOut.setExpression(mapExpression(velocity));
  }

  boolean is_note_on;
  void update_is_note_on() {
    boolean new_is_note_on = velocity > ON_OFF_THRESHOLD;
    if (is_note_on != new_is_note_on) {
      // tututu_last_max = velocity;
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
  float octave_residual;
  void useMountains() {
    float pitch_class_weight = OCTAVE_VELOCITY / 12f;
    float dy = pitch_class * pitch_class_weight;
    float adjusted = velocity - dy - INTERCEPT_VELOCITY;
    octave_residual = adjusted / OCTAVE_VELOCITY;
    octave = max(0, round(octave_residual));
    octave_residual = max(-.5, octave_residual - octave);
    pitchBend();
    updatePitch();
  }

  float sigmoid(float x){
    return 1 / (1f + exp(-x));
  }

  static final float MIDI_BEND_MAX = 2; // semitones
  // FLUTE_BEND_MAX should not be close to 1 otherwise MIDI data byte potentially overflow
  static final float BEND_COEFFICIENT = FLUTE_BEND_MAX / MIDI_BEND_MAX;
  static final int PITCH_BEND_ORIGIN = 8192;
  void pitchBend() {
    //linear mapping
    int pitch_bend = round(map(octave_residual, 0f, .5, PITCH_BEND_ORIGIN, PITCH_BEND_ORIGIN * (1f + BEND_COEFFICIENT)));

    //logistic mapping
    // int pitch_bend = round(map(sigmoid(octave_residual * 20), 0f, .5, PITCH_BEND_ORIGIN, PITCH_BEND_ORIGIN * (1f + BEND_COEFFICIENT)));

    midiOut.setPitchBend(pitch_bend);
  }

  int pitch;
  void updatePitch() {
    int new_pitch = fingersToPitchClass(finger_position) + 12 * octave + TRANSPOSE;
    boolean diff = false;
    if (pitch != new_pitch) {
      diff = true;
    }
    pitch = new_pitch;
    if (diff && is_note_on) {
      midiOut.pitch_from_network = pitch;
      noteEvent();
    }
  }

  // int tututu_last_max;  // -1 means ready for a TU
  // int tututu_last_min;
  // static final float TUTUTU_RELEASE_THRESHOLD = 0.8f;
  // static final float TUTUTU_THRESHOLD = 1.3f;
  void detectTuTuTu() {
    // if (tututu_last_max != -1) {
    //   // not ready for TU
    //   if (
    //     velocity < tututu_last_max * TUTUTU_RELEASE_THRESHOLD
    //   ) {
    //     tututu_last_max = -1;
    //     tututu_last_min = velocity;
    //   } else {
    //     tututu_last_max = max(velocity, tututu_last_max);
    //   }
    // } else {
    //   // ready for TU
    //   tututu_last_min = min(velocity, tututu_last_min);
    //   if (velocity > tututu_last_min * TUTUTU_THRESHOLD) {
    //     tututu_last_max = velocity;
    //     noteEvent();
    //   }
    // }
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

  int p2v(int x) {
    println("p2v", x);
    return round(pow(x * .01, 3.5) * 200);
  }
  int mapExpression(int velocity) {
    return round(min(127, max(20, velocity * .4)));
  }
}
