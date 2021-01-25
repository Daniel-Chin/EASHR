import java.awt.Robot;
import java.awt.AWTException;

GUI gui;

class GUI {
  boolean has_robby;
  Robot robby;

  int cursorX = 500;
  int cursorY = 500;

  GUI() {
    try {
      robby = new Robot();
      has_robby = true;
      last_mouse_X = mouseX;
      last_mouse_Y = mouseY;
      noCursor();
    } catch (AWTException e) {
      println("Robot class not supported by your system!");
      has_robby = false;
    }
  }

  void loop() {
    if (has_robby) {
      handleCursor();
    } else {
      cursorX = mouseX;
      cursorY = mouseY;
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

  void draw() {
    background(0);
    if (has_robby) {
      drawCursor();
    }
  }

  void drawCursor() {
    pushMatrix();    
    translate(cursorX, cursorY);
    scale(CURSOR_SIZE);
    fill(255);
    stroke(0);
    beginShape();
    vertex(0, 0);
    vertex(0, 60);
    vertex(20, 45);
    vertex(45, 45);
    endShape(CLOSE);
    popMatrix();
  }
}
