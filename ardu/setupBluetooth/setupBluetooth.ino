#include <SoftwareSerial.h>

#define MODE 1

SoftwareSerial blueSerial(10, 11); // RX, TX

void setup() {
  blueSerial.begin(38400);
  Serial.begin(9600);
  Serial.println("Start. ");
  if (MODE == 1) {
    setupBlue();
  }
}

void interactive() {
  int s;
  if (Serial.available()) {
    Serial.print("Sending: '");
    while (Serial.available()) {
      s = Serial.read();
      if (s != 10 && s != 13) {
        Serial.print((char)(s));
      } else {
        Serial.print(" ");
      }
      blueSerial.write(s);
      delay(20);
    }
    Serial.println("'. ");
  }
  delay(100);
  if (blueSerial.available()) {
    Serial.print("Got: '");
    while (blueSerial.available()) {
      s = blueSerial.read();
      if (s != 10 && s != 13) {
        Serial.print((char)(s));
      } else {
        Serial.print(" ");
      }
      delay(20);
    }
    Serial.println("'. ");
  }
}

void loop() {
  if (MODE == 0) {
    interactive();
  } else {
    delay(1000);
  }
}

void setupBlue() {
  delay(1000);
  command("AT", 1);
  // command("AT+ORGL");
  command("AT+NAME=Flute", 1);
  command("AT+NAME", 2);
  command("AT+UART", 2);
  Serial.println("The above should be '9600'. ");
  command("AT+ROLE", 2);
  Serial.println("The above should be '0'. ");
  command("AT+PSWD=\"1293\"", 1);
  command("AT+PSWD", 2);
  command("AT+RESET", 1);
  Serial.println("Arduino script exits. ");
}

void command(String c, int n_lines) {
  blueSerial.println(c);
  Serial.print(">> ");
  Serial.println(c);
  for (int _ = 0; _ < n_lines; _ ++) {
    Serial.print(readline());
  }
  delay(20);
}

String readline() {
  String buffer = "";
  int got = -1;
  while (got != 10) {
    got = blueSerial.read();
    if (got != -1) {
      buffer += (char) got;
    }
  }
  return buffer;
}
