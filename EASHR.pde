// this file is in charge of setup, connect, and void draw. 

import java.util.Arrays;
import processing.serial.*;

final static boolean DEBUGGING_NO_ARDUINO = true;
final static int COM = 0;
final static float FLUTE_BEND_MAX = .4;
final static int CAPACITIVE_THRESHOLD = 3;
final static int LOW_PASS = 75;
final static boolean MIDI_advanced_expression = false;
final static int MAX_PRESSURE = 400;
final static float CURSOR_SIZE = 1f;
final static float EXPRESSION_COEF = .4;
final static int TRANSPOSE_OCTAVES = 3;

final static String TITLE = "The EASHR";
final static int ROUND_ROBIN_PACKET_MAX_SIZE = 127;  // one-byte length indicator maximum 127 on serial
final static int TRANSPOSE = TRANSPOSE_OCTAVES * 12;

Port port;
boolean abort = false;
String abort_msg = "ABORT";

void setup() {
  // size(1366, 768);
  fullScreen();
  fill(255);
  textAlign(CENTER);
  textSize(36);
  noStroke();
  gui = new GUI();
}

class Port {
  // logs communications
  // fake a dummy interface when DEBUGGING_NO_ARDUINO is false
  // Do the Round Robin for bluetooth
  Serial serial;
  PrintWriter sendLogger;
  PrintWriter recvLogger;
  String outQueue = "";
  String inQueue = "";
  boolean round_robin_my_turn = true;
  int round_robin_recv_state = -1;

  void initLoggers() {
    sendLogger = createWriter("Serial_proc_ardu.log");
    recvLogger = createWriter("Serial_ardu_proc.log");
  }
  public Port(Serial serial) {
    this.serial = serial;
    initLoggers();
  }
  public Port(String s) {
    assert s.equals("fake");
    initLoggers();
  }
  void loop() {
    if (DEBUGGING_NO_ARDUINO) return;
    if (round_robin_my_turn) {
      int packet_size = min(outQueue.length(), ROUND_ROBIN_PACKET_MAX_SIZE);
      serial.write(packet_size);
      if (packet_size > 0) {
        serial.write(outQueue.substring(0, packet_size));
        outQueue = outQueue.substring(packet_size);
      }
      round_robin_my_turn = false;
      round_robin_recv_state = -1;
    } else {
      while (serial.available() > 0) {
        if (round_robin_recv_state == -1) {
          round_robin_recv_state = serial.read();
        } else {
          // rr_state > 0
          inQueue += serial.readChar();
          round_robin_recv_state -= 1;
        }
        if (round_robin_recv_state == 0) {
          round_robin_my_turn = true;
          break;
        }
      }
    }
  }
  void write(String s, boolean log_line_break) {
    if (! DEBUGGING_NO_ARDUINO) {
      outQueue += s;
    }
    sendLogger.print(s);
    if (log_line_break) {
      sendLogger.println();
    }
  }
  void write(String s) {
    this.write(s, false);
  }
  char read() {
    if (! DEBUGGING_NO_ARDUINO) {
      char recved = inQueue.charAt(0);
      inQueue = inQueue.substring(1);
      recvLogger.print(recved);
      return recved;
    } else return '_';
  }
  int available() {
    if (! DEBUGGING_NO_ARDUINO) {
      return inQueue.length();
    } else return 0;
  }
  char serial_readOne() {  // blocks until got one char
    while (serial.available() == 0) {
      delay(1);
    }
    return (char) serial.read();
  }
  String readAll() {
    String tmp = inQueue;
    inQueue = "";
    recvLogger.print(tmp);
    return tmp;
  }
  void close() {
    sendLogger.flush();
    sendLogger.close();
    recvLogger.flush();
    recvLogger.close();
  }
}

void draw() {
  if (abort) {
    background(0);
    fill(255);
    textSize(72);
    textAlign(CENTER, CENTER);
    text(abort_msg, 0, 0, width, height);
    return;
  }
  if (arduino != null) {
    if (port != null) {
      port.loop();
    }
    arduino.loop();
  }
  network.loop();
  gui.loop();
}

PApplet getThis() {
  return this;
}

void keyPressed() {
  if (key == ESC) {
    stop();
  }
}

void stop() {
  println("Application terminates.");
  midiOut.clear();
  if (port != null) {
    port.sendLogger.flush();
    port.sendLogger.close();
    port.recvLogger.flush();
    port.recvLogger.close();
  }
  super.stop();
}
