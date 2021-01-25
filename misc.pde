static final color DISABLED_GRAY = #999999;
static final int IMG_ALLERGY = 10000;

void fatalError(String msg) {
  println("Processing fatal Error: " + msg);
  abort_msg = "Fatal Error: " + msg;
  abort = true;
  port.close();
}

static float twelveExponen(int times) {
  return pow(1.0594630943592953, times);
}

void delaySafe(int time_in_ms) {
  long end_time = millis() + time_in_ms;
  while (millis() < end_time) {
    port.loop();
    delay(1);
  }
}

int pitchToDiatone(int pitch) {
  int base_pitch = pitch % 12;
  int octave = (pitch - base_pitch) / 12 - 5;
  int base_level;
  if (base_pitch <= 4) {
    // C D E
    if (base_pitch % 2 != 0) {
      fatalError("non-Diatonic pitch not supported yet");
    }
    base_level = base_pitch / 2;
  } else {
    // F G A B
    if (base_pitch % 2 == 0) {
      fatalError("non-Diatonic pitch not supported yet");
    }
    base_level = (base_pitch + 1) / 2;
  }
  return 3 + base_level + 8 * octave;
}
