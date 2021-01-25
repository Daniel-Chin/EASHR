import java.awt.Robot;
import java.awt.AWTException;

static final int[][] C = {
  {235, 100, 55}, 
  {227, 199, 14}, 
  {0,   138, 97}, 
  {119, 193, 254}, 
  {0,   98,  191}, 
  {119, 79,  194}, 
  {159, 29,  63}, 
};

GUI gui;

class GUI {
  boolean has_robby;
  Robot robby;

  int cursorX = 500;
  int cursorY = 500;
  boolean cursor_visible = true;

  GUI() {
    try {
      robby = new Robot();
      has_robby = true;
      last_mouse_X = mouseX;
      last_mouse_Y = mouseY;
      noCursor();
      cursor_visible = false;
    } catch (AWTException e) {
      println("Robot class not supported by your system!");
      has_robby = false;
    }
  }

  void loop() {
    if (DEBUGGING_NO_ARDUINO) {
      if (has_robby) {
        handleCursor();
      } else {
        cursorX = mouseX;
        cursorY = mouseY;
      }
      int diatone = cursorX * 7 / width;
      int pitch_class = diatone * 2;
      if (pitch_class >= 6) {
        pitch_class --;
      }
      int breath_pressure = round((1 - cursorY / (float)(height)) * MAX_PRESSURE);
      for (int i = 0; i < 6; i ++) {
        if (i < 6 - diatone) {
          network.onFingerChange(i, '_');
        } else {
          network.onFingerChange(i, '^');
        }
      }
      network.onPressureChange(breath_pressure);
    }
    draw();
  }

  // static final int CURSOR_MSPF = 1000;
  // int handleCursor_last_millis = 0;
  int last_mouse_X;
  int last_mouse_Y;
  int mouse_v_x;
  int mouse_v_y;
  boolean teleported = false;
  void handleCursor() {
    if (focused) {
      // if (millis() - handleCursor_last_millis >= CURSOR_MSPF) {
        // handleCursor_last_millis = millis();
        if (teleported) {
          teleported = false;
          last_mouse_X = mouseX - mouse_v_x;
          last_mouse_Y = mouseY - mouse_v_y;
        }
        mouse_v_x = mouseX - last_mouse_X;
        mouse_v_y = mouseY - last_mouse_Y;
        cursorX += mouse_v_x;
        cursorY += mouse_v_y;
        last_mouse_X = mouseX;
        last_mouse_Y = mouseY;
        if (cursorX < 0) {
          cursorX += width;
        }
        if (cursorX > width) {
          cursorX -= width;
        }
        if (cursorY < 0) {
          cursorY = 0;
        }
        if (cursorY > height) {
          cursorY = height;
        }
        if (
          mouseX < width * .2 ||
          mouseX > width * .8 ||
          mouseY < height * .2 ||
          mouseY > height * .8
        ) {
          robby.mouseMove(width / 2, height / 2);
          teleported = true;
        }
      // }
    }
  }

  int diatone;
  void draw() {
    background(0);
    if (! focused && DEBUGGING_NO_ARDUINO && has_robby) {
      fill(255);
      text("Click to continue", width / 2, height / 2);
      if (! cursor_visible) {
        cursor(HAND);
        cursor_visible = true;
        midiOut.clear();
      }
      return;
    }
    if (focused && DEBUGGING_NO_ARDUINO && has_robby) {
      if (cursor_visible) {
        noCursor();
        cursor_visible = false;
      }
    }
    pushMatrix();
    translate(0, height);
    scale(1, -1);
    float slope = network.OCTAVE_PRESSURE / 12f;
    for (int i = 0; i < 7; i ++) {
      int pitch_class = i * 2;
      if (pitch_class >= 6) {
        pitch_class --;
      }
      float dy = pitch_class * slope;
      float intercept = dy + network.INTERCEPT_PRESSURE;
      int j = 0;
      for (
        float y = intercept - network.OCTAVE_PRESSURE * .5; 
        y < MAX_PRESSURE; 
        y += network.OCTAVE_PRESSURE
      ) {
        fill(C[i][0], C[i][1], C[i][2], min(255, (y / height + .25) * 256));
        int y0 = round(y * height / MAX_PRESSURE);
        int _h = network.OCTAVE_PRESSURE * height / MAX_PRESSURE;
        if (j == 0) {
          _h += y0;
          y0 = 0;
        }
        rect(
          width * i / 7, y0, 
          width / 7, _h
        );
        j ++;
      }
    }
    fill(0);
    rect(0, 0, width, network.ON_OFF_THRESHOLD * height / MAX_PRESSURE);
    if (network.is_note_on) {
      diatone = floor((network.pitch_class + 1) / 2f);
      float dy = network.pitch_class * slope;
      float y = dy + network.INTERCEPT_PRESSURE + network.octave * network.OCTAVE_PRESSURE;
      int to_diatone = diatone;
      if (network.octave_residual > 0) {
        to_diatone ++;
      } else {
        to_diatone --;
      }
      to_diatone = (to_diatone + 7) % 7;
      fill(C[to_diatone][0], C[to_diatone][1], C[to_diatone][2], 60);
      rect(
        diatone * width / 7, 
        y * height / MAX_PRESSURE, 
        width / 7, 
        height - cursorY - y * height / MAX_PRESSURE
      );
    }
    popMatrix();
    if (has_robby || ! DEBUGGING_NO_ARDUINO) {
      drawCursor();
    }
  }

  static final int CURSOT_R = 60;
  static final String SYMBOLS = "CDEFGAB";
  void drawCursor() {
    pushMatrix();    
    translate(cursorX, cursorY);
    scale(CURSOR_SIZE);
    fill(255);
    rect(-CURSOT_R, -CURSOT_R, CURSOT_R*2, CURSOT_R*2);
    stroke(0);
    line(-CURSOT_R, 0, CURSOT_R, 0);
    noStroke();
    fill(0);
    if (network.is_note_on) {
      text(SYMBOLS.charAt(diatone) + String.valueOf(network.octave + TRANSPOSE_OCTAVES), 0, -18);
      String modi;
      if (network.octave_residual > 0) {
        modi = "+";
      } else {
        modi = "-";
      }
      int perc = abs(round(network.octave_residual * 2 * FLUTE_BEND_MAX * 100));
      if (perc < 10) {
        modi += '0';
      }
      modi += String.valueOf(perc) + '%';
      text(modi, 0, CURSOT_R - 18);
    }
    // fill(255);
    // stroke(0);
    // beginShape();
    // vertex(0, 0);
    // vertex(0, 60);
    // vertex(20, 45);
    // vertex(45, 45);
    // endShape(CLOSE);
    popMatrix();
  }
}
