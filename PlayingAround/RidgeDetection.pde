import java.awt.event.KeyEvent;

class FlowFinder extends CalculationStep
{
  float[] flowAngle;
  float[] flowMag;
  
  // Filter kernel (DFT window) size
  int s = 16;
  
  // Kernel is applied with this spacing
  int d = 2;
  
  int wd, hd;
  
  // Matrix storing data in window, used for dft
  Mat subMat;
  
  // Graphics buffer for mouse highlight
  PImage mouseDetail;
  
  public FlowFinder(Step below)
  {
    super(below.take);
  }
  
  public void allocateResources()
  {
    wd = (w - s) / d;
    hd = (h - s) / d;
    flowAngle = new float[wd * hd];
    flowMag = new float[wd * hd];
    subMat = new Mat(s, s, CvType.CV_32FC1);
    mouseDetail = createImage(s, s, RGB);
  }
  
  public void calculateImpl()
  {
    subMat = new Mat(s, s, CvType.CV_32FC1);
    Mat complexMat = new Mat();
    for (int y = 0; y < hd; y++) {
      for (int x = 0; x < wd; x++)
      {
        fillSubmatAround(x * d + s/2, y * d + s/2, subMat);
        
        Core.dft(subMat, complexMat, Core.DFT_COMPLEX_OUTPUT, 0);
        
        PVector maxLoc = evaluateSubmat(complexMat);
        
        flowAngle[y * wd + x] = maxLoc.heading() + HALF_PI;
        flowMag[y * wd + x] = maxLoc.mag() * d/s;
      }
    }
  }
  
  void fillSubmatAround(int x, int y, Mat subMat)
  {
    for (int ys = -s/2; ys < s/2; ys++) {
      for (int xs = -s/2; xs < s/2; xs++) {
        int pos = (y + ys) * w + x + xs;
        subMat.put(ys + s/2, xs + s/2, red(take.shapeIndex.pixels[pos]));
      }
    }
  }
  
  PVector evaluateSubmat(Mat subMat)
  {
    float dc = (float)subMat.get(0, 0)[0];
    
    float maxStrength = 0;
    PVector maxLoc = new PVector();
    
    for (int ys = 0; ys < s; ys++) {
      for (int xs = 0; xs < s; xs++) {
        PVector complexF = new PVector((xs + s/2) % s - s/2, (ys + s/2) % s - s/2);
        if (complexF.mag() <= minDctMag) continue;
        if (complexF.mag() >= maxDctMag) continue;
        
        float strength = getMagnitudeAt(subMat, xs, ys) / dc;
        if (strength > maxStrength) {
          maxStrength = strength;
          maxLoc = complexF;
        }
      }
    }
    //maxLoc.mult(maxStrength);
    return maxLoc;
  }
  
  float getMagnitudeAt(Mat mat, int x, int y)
  {
    double[] tmp = mat.get(y, x);
    float magnitude = mag((float)tmp[0], (float)tmp[1]);
    // Rescale for easier visibility
    return sqrt(sqrt(magnitude)); 
  }
  
  void drawSubmat()
  {
    
  }
  
  float getStrength(float amplitude, float frequency)
  {
    return sqrt(sqrt(abs(amplitude)) * frequency);
  }
  
  void drawImpl(PGraphics g)
  {
    g.image(take.shapeIndex, 0, 0);
    if (keyPressed && (keyCode == KeyEvent.VK_SHIFT)) return;
    g.pushMatrix();
    g.translate(s/2, s/2);
    g.scale(d, d);
    g.stroke(color(255, 0, 0));
    g.strokeWeight(1 / 10.0);
    for (int y = screenStartY() / d; y < screenEndY() / d; y++) {
      for (int x = screenStartX() / d; x < screenEndX() / d; x++)
      {
        if (x >= wd || y >= hd) continue; // FIXME?
        float angle = flowAngle[y*wd + x];
        float mag = flowMag[y*wd + x];
        float dx = cos(angle) * mag / 8;
        float dy = sin(angle) * mag / 8;
        g.line(x - dx * 10, y - dy * 10, x + dx * 10, y + dy * 10);
        g.line(x - dy, y + dx, x + dy, y - dx);
      }
    }
    g.popMatrix();
    
    if (mousePressed && (mouseButton == RIGHT)) {
      drawAroundMouse(g);
    }
  }
  
  void drawAroundMouse(PGraphics g)
  {
    int imgX = (int)imageX(mouseX);
    int imgY = (int)imageY(mouseY);
    if (imgX < s/2 || imgY < s/2 || imgX >= w-s/2 || imgY >= h-s/2) return;
    
    fillSubmatAround(imgX, imgY, subMat);
    
    Mat complexMat = new Mat();
    Core.dft(subMat, complexMat, Core.DFT_COMPLEX_OUTPUT, 0);
    fillMouseImage(complexMat);
    
    g.pushMatrix();
    g.resetMatrix();
    g.translate(mouseX, mouseY);
    int scale = 5;
    g.scale(scale);
    g.image(mouseDetail, -s, -s);
    g.popMatrix();
  }
  
  void fillMouseImage(Mat mat)
  {
    mouseDetail.loadPixels();
    float dc = getMagnitudeAt(mat, 0, 0);
    for (int ys = 0; ys < s; ys++) {
      for (int xs = 0; xs < s; xs++) {
        int pos = ((ys + s/2) % s) * s + (xs + s/2) % s;
        float mag = getMagnitudeAt(mat, xs, ys);
        mouseDetail.pixels[pos] = color(mag / dc * 255);
      }
    }
    mouseDetail.updatePixels();
  }
}