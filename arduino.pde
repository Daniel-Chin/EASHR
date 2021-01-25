// This file is a wrapper class of the Arduino board. 

Arduino arduino = null;

class Arduino {
  static final boolean HAS_PEDAL = false;  // if no pedal, there is atmosphere noise
  String buffer = "";

  Arduino() {
    setCapacitiveThreshold(CAPACITIVE_THRESHOLD);
  }

  char encodeDigit(int digit) {
    // look! when digit <= 9, it behaves like str()! 
    int result = digit + (int) '0';
    if (result >= 127) {
      fatalError("encodeDigit() input too large");
      return '!';
    }
    return (char) result;
  }

  int decodeDigit(char c) {
    return (int) c - (int) '0';
  }

  String encodeDegree(int degree) {
    String result = "" + (char)(degree / 127 + 1);
    return result + (char)(degree % 127 + 1);
  }

  int decodePrintable(char a, char b) {
    return 95 * ((int) a - 32) + (int) b - 32;
  }

  void abort() {
    port.write("\rABORT_", true);
  }

  void setCapacitiveThreshold(int x) {
    port.write("C" + (char)(x), true);
  }

  // receiving
  void loop() {
    buffer += port.readAll();
    int i;
    for (i = 0; i + 3 <= buffer.length(); i += 3) {
      switch (buffer.charAt(i)) {
      case 'F':
        network.onFingerChange(
          decodeDigit(buffer.charAt(i + 1)), 
          buffer.charAt(i + 2)
        );
        break;
      case 'P':
        if (HAS_PEDAL) {
          onPedalSignal(buffer.charAt(i + 1));
        }
        break;
      case 'B':
        network.onPressureChange(
          decodePrintable(
            buffer.charAt(i + 1), buffer.charAt(i + 2)
          )
        );
        break;
      case 'E':
        delay(100);   // wait for the entire error msg to send
        buffer += port.readAll();
        fatalError("Arduino E message: " + buffer.substring(i + 1));
        return;
      case 'D':
        print("Debug message from Arduino: ");
        print(buffer.charAt(i+1));
        println(buffer.charAt(i+2));
        break;
      default:
        fatalError("Unknown ardu -> proc header: 0x" + str(int(buffer.charAt(i))));
        print("buffer: ");
        println(buffer);
        return;
      }
    }
    buffer = buffer.substring(i, buffer.length());
  }

  void onPedalSignal(char state) {
  }
}

final String KEYS = " vfrji9";
int keyboard_ardu_velocity = 100;
void keyReleased() {
  if (arduino == null) return;
  int key_i = KEYS.indexOf(key);
  boolean is_key = true;
  if (key_i == -1) {
    key_i = KEYS.indexOf(key + 32); // toLowerCase
    if (key_i == -1) {
      is_key = false;
    }
  }
  if (is_key) {
    char state;
    for (int i = 0; i < 6; i ++) {
      if (i < key_i) {
        state = '_';
      } else {
        state = '^';
      }
      network.onFingerChange(i, state);
    }
    return;
  }
  if (key == 'q') {
    network.onPressureChange(
      49
    );
  }
  if (key == 'a') {
    network.onPressureChange(
      0
    );
  }
}
