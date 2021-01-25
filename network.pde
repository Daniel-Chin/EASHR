// parses haptic input to abstract musical objects. 
// For example, parses breath pressure data stream into discreet note events. 

Network network = new Network();

class Network {
  static final int ON_OFF_THRESHOLD = 40;
  static final int OCTAVE_PRESSURE = 100;
  static final int INTERCEPT_PRESSURE = 50;

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

  int pressure;
  void onPressureChange(int x) {
    pressure = x;
    setExpression();
    update_is_note_on();
    // if (is_note_on) {
    //   detectTuTuTu();
    // }
    useMountains();
  }

  void setExpression() {
    midiOut.setExpression(round(min(127, pressure * EXPRESSION_COEF)));
  }

  boolean is_note_on;
  void update_is_note_on() {
    boolean new_is_note_on = pressure > ON_OFF_THRESHOLD;
    if (is_note_on != new_is_note_on) {
      // tututu_last_max = pressure;
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
    float pitch_class_weight = OCTAVE_PRESSURE / 12f;
    float dy = pitch_class * pitch_class_weight;
    float adjusted = pressure - dy - INTERCEPT_PRESSURE;
    octave_residual = adjusted / OCTAVE_PRESSURE;
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

  int tututu_last_max;  // -1 means ready for a TU
  int tututu_last_min;
  static final float TUTUTU_RELEASE_THRESHOLD = 0.8f;
  static final float TUTUTU_THRESHOLD = 1.3f;
  void detectTuTuTu() {
    // if (tututu_last_max != -1) {
    //   // not ready for TU
    //   if (
    //     pressure < tututu_last_max * TUTUTU_RELEASE_THRESHOLD
    //   ) {
    //     tututu_last_max = -1;
    //     tututu_last_min = pressure;
    //   } else {
    //     tututu_last_max = max(pressure, tututu_last_max);
    //   }
    // } else {
    //   // ready for TU
    //   tututu_last_min = min(pressure, tututu_last_min);
    //   if (pressure > tututu_last_min * TUTUTU_THRESHOLD) {
    //     tututu_last_max = pressure;
    //     noteEvent();
    //   }
    // }
  }

  void noteEvent() {
    midiOut.onNoteControlChange();
    print("noteEvent. Octave ");
    print(octave);
    print(", fingers ");
    for (char f : finger_position) {
      print(f);
    }
    println(". ");
  }

  int fingersToPitchClass(char[] fingers) {
    switch (String.valueOf(fingers)) {
      case "______": 
        return 0;
      case "_____^": 
        return 2;
      case "____^^": 
        return 4;
      case "___^^^": 
        return 5;
      case "__^^^^": 
        return 7;
      case "_^^^^^": 
        return 9;
      case "^^^^^^": 
        return 11;
      default:
        return -1;
    }
  }
}
