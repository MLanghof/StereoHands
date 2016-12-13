import java.nio.*;

import gab.opencv.*;

import org.opencv.core.*;
                    
HandProcessor processor;

float zoom = 0.9f;
float panX = 0;
float panY = 0;


final int SIZE = 2048;
  

void setup() {
  size(2048, 1400, P2D);
  noLoop();
  
  processor =  new HandProcessor();
  
  // Crisp pixels pls
  hint(DISABLE_TEXTURE_MIPMAPS);
  ((PGraphicsOpenGL)g).textureSampling(2);
} 

void draw() {
  if (frameCount == 1) surface.setLocation(180, -10);
  background(0);
  if (processor.getCurrentImage() != null)
  {
    pushMatrix();
    translate(panX, panY);
    scale(zoom);
    
    processor.drawImage();
    
    popMatrix();
  }
  
  strokeWeight(1);
  processor.drawUI();
}

void mouseClicked()
{
  processor.handleClick(mouseX, mouseY);
}


void mouseWheel(MouseEvent event)
{
  zoom(event.getCount());
  redraw();
}

void zoom(float distance)
{
  float newZoom = zoom * pow(0.9, distance);
  PVector centre = new PVector(mouseX, mouseY);
  PVector pan = new PVector(panX, panY);
  PVector diff = PVector.sub(pan, centre).mult(newZoom/zoom);
  PVector newPan = PVector.add(centre, diff);
  panX = newPan.x;
  panY = newPan.y;
  zoom = newZoom;
}


void mouseDragged()
{
  panX -= pmouseX - mouseX;
  panY -= pmouseY - mouseY;
  redraw();
}

void keyPressed()
{
  if (key == ' ') {
    saveOutput();
  }
}

void saveOutput()
{
  
}