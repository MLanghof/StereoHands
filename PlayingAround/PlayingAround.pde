import java.nio.*;

import gab.opencv.*;
import org.opencv.core.*;

////////////////////////////////////////////////////////////////////////

// Input selection
final boolean reducedSampleSize = true;
final boolean ignoreNIR = true;
// Disabling these substantially improves load times
final boolean loadAlbedo = false;
final boolean loadNormals = false;

// Preprocessing constants
final float armCutPos = 0.75; // as fraction of image width
final boolean cutArm = true;
final boolean debugArmStart = true;

final float gapExclusionHeight = 0.1; // as fraction of image height
final int minArmThickness = 200; // in pixels
final int minFingerThickness = 50; // in pixels

final float albedoThreshold = 0.2;

// Paths
final String baseFolder = "D:/PSHands/";

final String resultImageFolder = "Results/";
final String featurePath = "D:/Features/features.ser";
final String featuresFolder = "D:/Features/";

////////////////////////////////////////////////////////////////////////
                    
HandProcessor processor;

float zoom = 0.9f;
float panX = 0;
float panY = 0;


void setup() {
  size(2020, 1400, P2D);
  noLoop();
  
  processor =  new HandProcessor();
  
  // Crisp pixels pls
  hint(DISABLE_TEXTURE_MIPMAPS);
  ((PGraphicsOpenGL)g).textureSampling(2);
} 

void draw() {
  if (frameCount == 1) {
    surface.setLocation(180, -10);
  }
  
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
  if (mouseButton == LEFT) {
    panX -= pmouseX - mouseX;
    panY -= pmouseY - mouseY;
  }
  redraw();
}

void keyPressed()
{
  if (key == ' ') {
    processor.saveImageSimple();
  }
  if (key == 'o') {
    processor.saveImageFull();
  }
  if (key == 's') {
    processor.saveFeatures(featurePath);
  }
  if (key == 'l') {
    processor.loadFeatures(featurePath);
  }
  if (key == 'p') {
    processor.processAndSaveAllHands();
  }
  
  if (keyCode == RIGHT) {
    processor.nextInput();
  }
  if (keyCode == LEFT) {
    processor.previousInput();
  }
  redraw();
}

void keyReleased()
{
  redraw();
}

void mouseReleased()
{
  redraw();
}