class SceneHandshake {
  static final int MAX_RETRY = 5;
  boolean did_draw = false;
  int retry = 0;
  String port_name;
  
  SceneHandshake() {
    onEnter();
  }
  
  void onEnter() {
    if (DEBUGGING_NO_ARDUINO) {
      port = new Port("fake");
      finish();
    } else {
      String[] ports = Serial.list();
      {
        int i = 0;
        for (String name : ports) {
          println(i, ":", name);
          i ++;
        }
      }
      port_name = ports[COM];
    }
  }
  
  void finish() {
    arduino = new Arduino();
  }
  
  void draw() {
    if (DEBUGGING_NO_ARDUINO) return;
    if (! did_draw) {
      background(0);
      fill(255);
      textAlign(CENTER, CENTER);
      textSize(36);
      text("Please wait...", 0, 0, width, height);
      textSize(24);
      String message;
      if (retry == 0) {
        message = "Connecting to Arduino... If no response, check console log.";
      } else {
        message = "Failed. Auto retry " + str(retry) + " / " + str(MAX_RETRY);
      }
      text(message, 0, 0, width, height * 1.2);
      did_draw = true;
    } else {
      if (handshake(port_name)) {
        finish();
      } else {
        retry ++;
        did_draw = false;
      }
    }
    if (retry > MAX_RETRY) {
      fatalError("Handshake failed"); return;
    }
  }
}

boolean handshake(String port_name) {
  port = new Port(new Serial(getThis(), port_name, 9600));
  port.serial.clear();
  println("Connected to " + port_name);
  println("Handshaking... ");

  port.serial.write("hi arduino");
  println("Sent: 'hi arduino'.");
  
  String expecting = "hi processing";
  int len = expecting.length();
  print("Receiving: \"");
  int tolerance = 1;
  int i = 0;
  while (i < len) {
    char recved = port.serial_readOne();
    print("" + recved);
    if (recved != expecting.charAt(i)) {
      if (tolerance > 0) {
        tolerance --;
        while (port.serial_readOne() != expecting.charAt(0)) {
          print("_");
        }
        i = 1;
        continue;
      }
      String residu = port.readAll();
      print(residu.substring(0, min(30, residu.length())));
      println("\", which is incorrect.");
      port.serial.clear();
      port.serial.stop();
      return false;
    }
    i ++;
  }
  println("\", which is good.");
  return true;
}
