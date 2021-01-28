#include <Wire.h>
#include <Adafruit_PWMServoDriver.h>
#include <SoftwareSerial.h>
#include <Adafruit_BMP085.h>

#define N_SERVOS 6
const int SERVO_PINS[N_SERVOS] = {10,11,12,13,14,15};
const int CAPACITIVE_PINS[N_SERVOS] = {7,6,5,4,3,2};
#define PEDAL_PIN 12
#define INIT_MID 95
#define DEFAULT_CAPACITIVE_THRESHOLD 2

#define MINPULSE 150 // This is the 'minimum' pulse length count (out of 4096)
#define MAXPULSE 600 // This is the 'maximum' pulse length count (out of 4096)
#define SERVO_FREQ 50 // Analog servos run at ~50 Hz updates
#define OSC_FREQ 24890000 // Specific to each PCA 9685 board

#define ROUND_ROBIN_PACKET_MAX_SIZE 127 // one-byte length indicator maximum 127 on serial

Adafruit_PWMServoDriver pwm;
Adafruit_BMP085 bmp;
SoftwareSerial blueSerial(10, 11); // RX, TX
bool _abort = false;

// For detach
int detach_slow = 5;
int last_degree[N_SERVOS] = {0};
int detach_target_degree[N_SERVOS] = {0};
int last_detach_millis;
int capacitive_threshold = DEFAULT_CAPACITIVE_THRESHOLD;
#define ATMOS_OFFSET 36000
int atmos_pressure = -1;
int measure_atmos_state = 20;
long measure_atmos_tmp = 0;
int measure_atmos_times = 0;

// For Serial communication
#define BUFF_LEN_S 4
#define BUFF_LEN_D 5
#define BUFF_LEN_C 1
#define BUFF_LEN_R 6
#define LONGEST_COMMAND 6  // max(BUFF_LEN_ S D R)
char command_buffer[LONGEST_COMMAND] = {' '};
char header = NULL;
int n_char_expect;
int n_char_got;
bool hand_shaked = false;

// For capacitive diffing
bool last_capacitive[N_SERVOS] = {false};

// For pedal diffing
bool last_pedal = false;

void setup() {
  // pwm = Adafruit_PWMServoDriver()
  // pwm.begin();
  // pwm.setOscillatorFrequency(OSC_FREQ);
  // pwm.setPWMFreq(SERVO_FREQ);

  // for (int i = 0; i < N_SERVOS; i++) {
  //   setServo(i, INIT_MID);
  //   last_degree[i] = INIT_MID; // in case you relax() before sending any attach command
  // }

  // pinMode(PEDAL_PIN, INPUT);
  blueSerial.begin(9600);
  String expecting = "hi arduino";
  int len = expecting.length();
  for (int i = 0; i < len; i++) {
    if (readOne() != expecting[i]) {
      _abort = true;
      fatalError("Handshake failed! ");
      return;
    }
  }
  blueSerial.print("hi processing");
  hand_shaked = true;
  
  if (! bmp.begin()) {
    fatalError("Could not find a valid BMP085 sensor, check wiring!");
    return;
  }

  last_detach_millis = millis();
}

char readOne() {    // blocking
  int recved = -1;
  while (recved == -1) {
    recved = blueSerial.read();
  }
  return (char) recved;
}

int heart_beat_count = 0;
void heartBeat() { // for debug
    heart_beat_count ++;
    if (heart_beat_count == 10000) {
        roundRobin_println("HEARTBEAT");
    }
    if (heart_beat_count == 30000) {
        heart_beat_count = 0;
        roundRobin_println("  HEARTBEAT");
    }
}

void loop() {
  roundRobin_write('F');
  roundRobin_write('4');
  roundRobin_write('_');
  if (_abort) {
    roundRobin_loop();
    delay(1);
    return;
  }
  roundRobin_loop();
  // heartBeat();
  // handleDetach();
  if (roundRobin_available() > 0) {
    mySerialEvent();
  }
  relayCapacitive();
  // relayPedal();
  relayPressure();
}

void mySerialEvent() {
  if (! hand_shaked) return;
  char recved;
  while (roundRobin_available()) {
    recved = roundRobin_read();
    if (header == NULL) {
      header = recved;
      n_char_got = 0;
      if (header == '\r') {
        n_char_expect = BUFF_LEN_R;
      } else if (header == 'S') {
        n_char_expect = BUFF_LEN_S;
      } else if (header == 'D') {
        n_char_expect = BUFF_LEN_D;
      } else if (header == 'C') {
        n_char_expect = BUFF_LEN_C;
      } else {
        fatalError("Unknown header: chr(" + String(int(header)) + ')');
        return;
      }
    } else {
      command_buffer[n_char_got] = recved;
      n_char_got ++;
      if (n_char_got == n_char_expect) {
        handleCommand();
        header = NULL;
      }
    }
  }
}

void handleCommand() {
  if (header == '\r') {
    String str_command = String(command_buffer).substring(0, 6);  // Stupid \x00 problem
    if (str_command.equals("ABORT_")) {
      _abort = true;
      return;
    } else {
      fatalError("Unknown command starting with \\r: ");
      roundRobin_println(str_command);
      return;
    }
  } else if (header == 'S' || header == 'D') {
    int servo_ID = int(command_buffer[1]) - int('2');
    if (command_buffer[0] == 'R') {
      servo_ID += 3;
    }
    if (servo_ID >= N_SERVOS || servo_ID < 0) {
      fatalError("Invalid servo ID: ");
      roundRobin_write(command_buffer[0]);
      roundRobin_write(command_buffer[1]);
      return;
    }
    int degree = decodeDegree(command_buffer[2], command_buffer[3]);
    if (isDegreeIllegal(degree)) {
      return;
    }
    if (header == 'S') {
      attach(servo_ID, degree);
    } else if (header == 'D') {
      detach_slow = decodeDigit(command_buffer[4]);
      detach(servo_ID, degree);
    }
  } else if (header == 'C') {
    capacitive_threshold = (int) command_buffer[0];
  }
}

bool isDegreeIllegal(int degree) {
  if (degree > 180 || degree < 0) {
    fatalError("Invalid degree: ");
    roundRobin_println(String(degree));
    return true;
  }
  return false;
}

void fatalError(String msg) {
  delay(100); // avoid two-way serial collision
  roundRobin_println("ERRArduino fatal Error: " + msg);
  _abort = true;
}

int decodeDigit(char x) {
  return (int) x - (int) '0';
}

int decodeDegree(char a, char b) {
  return 127 * (int(a) - 1) + int(b) - 1;
}

void detach(int servo_ID, int degree) {
  detach_target_degree[servo_ID] = degree;
}

void attach(int servo_ID, int degree) {
  setServo(servo_ID, degree);
  last_degree[servo_ID] = degree;
  detach_target_degree[servo_ID] = NULL;
}

void handleDetach() {
  while ((millis() + 1000 - last_detach_millis) % 1000 >= detach_slow) {
    last_detach_millis += detach_slow;
    last_detach_millis %= 1000;
    for (int i = 0; i < N_SERVOS; i++) {
      if (detach_target_degree[i] != NULL) {
        if (detach_target_degree[i] > last_degree[i]) {
          last_degree[i] ++;
        } else {
          last_degree[i] --;
        }
        setServo(i, last_degree[i]);
        if (last_degree[i] == detach_target_degree[i]) {
          detach_target_degree[i] = NULL;
        }
      }
    }
  }
}

uint8_t readCapacitivePin(int pinToMeasure) {
  volatile uint8_t* port;
  volatile uint8_t* ddr;
  volatile uint8_t* pin;
  byte bitmask;
  port = portOutputRegister(digitalPinToPort(pinToMeasure));
  ddr = portModeRegister(digitalPinToPort(pinToMeasure));
  bitmask = digitalPinToBitMask(pinToMeasure);
  pin = portInputRegister(digitalPinToPort(pinToMeasure));
  *port &= ~(bitmask);
  *ddr  |= bitmask;
  delay(1);
  uint8_t SREG_old = SREG; //back up the AVR Status Register
  noInterrupts();
  *ddr &= ~(bitmask);
  *port |= bitmask;
  uint8_t cycles = 17;
  if (*pin & bitmask) {
    cycles =  0;
  } else if (*pin & bitmask) {
    cycles =  1;
  } else if (*pin & bitmask) {
    cycles =  2;
  } else if (*pin & bitmask) {
    cycles =  3;
  } else if (*pin & bitmask) {
    cycles =  4;
  } else if (*pin & bitmask) {
    cycles =  5;
  } else if (*pin & bitmask) {
    cycles =  6;
  } else if (*pin & bitmask) {
    cycles =  7;
  } else if (*pin & bitmask) {
    cycles =  8;
  } else if (*pin & bitmask) {
    cycles =  9;
  } else if (*pin & bitmask) {
    cycles = 10;
  } else if (*pin & bitmask) {
    cycles = 11;
  } else if (*pin & bitmask) {
    cycles = 12;
  } else if (*pin & bitmask) {
    cycles = 13;
  } else if (*pin & bitmask) {
    cycles = 14;
  } else if (*pin & bitmask) {
    cycles = 15;
  } else if (*pin & bitmask) {
    cycles = 16;
  }
  SREG = SREG_old;
  *port &= ~(bitmask);
  *ddr  |= bitmask;
  return cycles;
}

void relayCapacitive() {
  for (int i = 0; i < N_SERVOS; i ++) {
    uint8_t reading = readCapacitivePin(CAPACITIVE_PINS[i]);
    bool is_finger_down = reading >= capacitive_threshold;
    if (is_finger_down != last_capacitive[i]) {
      last_capacitive[i] = is_finger_down;
      roundRobin_write('F');
      roundRobin_write((char) ((int)'0' + i));
      if (is_finger_down) {
        roundRobin_write('_');
      } else {
        roundRobin_write('^');
      }
    }
  }
}

void relayPedal() {
  bool now_pedal = digitalRead(PEDAL_PIN);
  if (now_pedal != last_pedal) {
    last_pedal = now_pedal;
    roundRobin_write('P');
    if (now_pedal) {
      roundRobin_write('_');
    } else {
      roundRobin_write('^');
    }
    roundRobin_write(';');
  }
}

void setServo(int id, int angle) {
  pwm.setPWM(SERVO_PINS[id], 0, map(angle, 0, 180, MINPULSE, MAXPULSE));
}

void sendDebugMsg(String msg) {
  roundRobin_write('D');
  roundRobin_print(msg.substring(0, 2));
}

// Round Robin
String round_robin_in_queue = "";
String round_robin_out_queue = "";
int round_robin_my_turn = false;
int round_robin_recv_state = -1;

void roundRobin_loop() {
  if (round_robin_my_turn) {
    int packet_size = min(round_robin_out_queue.length(), ROUND_ROBIN_PACKET_MAX_SIZE);
    blueSerial.write((char) packet_size);
    if (packet_size > 0) {
      blueSerial.print(round_robin_out_queue.substring(0, packet_size));
      round_robin_out_queue = round_robin_out_queue.substring(packet_size);
    }
    round_robin_my_turn = false;
    round_robin_recv_state = -1;
  } else if (! _abort) {
    while (blueSerial.available() > 0) {
      if (round_robin_recv_state == -1) {
        round_robin_recv_state = blueSerial.read();
      } else {
        // rr_state > 0
        round_robin_in_queue += (char) blueSerial.read();
        // This leads to memory fragmentation quickly. 
        // Too bad.
        round_robin_recv_state -= 1;
      }
      if (round_robin_recv_state == 0) {
        round_robin_my_turn = true;
        break;
      }
    }
  }  
}

int roundRobin_available() {
  return round_robin_in_queue.length();
}

char roundRobin_read() {
  char tmp = round_robin_in_queue.charAt(0);
  round_robin_in_queue = round_robin_in_queue.substring(1);
  return tmp;
}

void roundRobin_write(char x) {
  round_robin_out_queue += x;
}

void roundRobin_print(String x) {
  round_robin_out_queue += x;
}

void roundRobin_println(String x) {
  roundRobin_print(x);
  roundRobin_write('\n');
}

void relayPressure() {
  int p = bmp.readPressure() - ATMOS_OFFSET;
  if (measure_atmos_state >= 0) {
    measure_atmos_tmp += p;
    measure_atmos_times ++;
    if (measure_atmos_state == 0) {
      atmos_pressure = measure_atmos_tmp / measure_atmos_times;
      // roundRobin_print("E");
      // roundRobin_print(String(atmos_pressure));
    }
    measure_atmos_state --;
  } else {
    p -= atmos_pressure;
    p = max(0, p);
    roundRobin_write('B');
    roundRobin_print(encodePrintable(p));
  }
}

String encodePrintable(int x) {
  int residual = x % 95;
  int high = (x - residual) / 95;
  high = min(94, high);
  char buffer[2] = {' '};
  buffer[0] = (char)(high + 32);
  buffer[1] = (char)(residual + 32);
  String result = buffer;
  if (result.length() == 2) { 
    // for unknown reason, 
    // with this `if`, it always goes into the first branch, 
    // but if you remove this `if`, `result` contains a trialing \n. 
    return result;
  } else {
    return "  ";
  }
}
