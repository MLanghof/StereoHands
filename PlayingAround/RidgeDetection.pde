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
  
  boolean eliminateLowStrength = true; 
  // Amplitude threshold for accepting a maximum strength amplitude as ridge.
  float minRidgeStrength = 1500;

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
    Mat complexMat = new Mat();
    PVector complexF = new PVector(0, 0);
    for (int y = 0; y < hd; y++) {
      for (int x = 0; x < wd; x++)
      {
        complexMat = getFrequencySpaceAt(x*d + s/2, y*d + s/2);
        PVector maximum = findMainFrequency(complexMat, true);
        complexF.x = maximum.x;
        complexF.y = maximum.y;
        // TODO: If there's a stronger signal with lower than allowed frequency, check if it's in the same direction
        //         if yes: discard (just harmonics of a wrinkle or main line)
        
        float mag = complexF.mag();
        
        if (eliminateLowStrength && (maximum.z < minRidgeStrength)) mag = 0;

        // Heading assumes a 2D vector so discards the strength in z
        flowAngle[y * wd + x] = complexF.heading() + HALF_PI;
        flowMag[y * wd + x] = mag * d/s;
      }
    }
  }
  
  Mat getFrequencySpaceAt(int x, int y)
  {
    fillSubmatAround(x, y, subMat);
    Mat frequencyMat = new Mat();
    Core.dft(subMat, frequencyMat, Core.DFT_COMPLEX_OUTPUT, 0);
    return frequencyMat;
  }
  
  // Assumes the subMat to be properly set up.
  void fillSubmatAround(int x, int y, Mat subMat)
  {
    for (int ys = -s/2; ys < s/2; ys++) {
      for (int xs = -s/2; xs < s/2; xs++) {
        int pos = (y + ys) * w + x + xs;
        subMat.put(ys + s/2, xs + s/2, red(take.shapeIndex.pixels[pos]));
      }
    }
  }
  
  // Returns the (eligible) complex frequency of maximum magnitude as a PVector,
  // with the amplitude as z component.
  PVector findMainFrequency(Mat mat, boolean boundsCheck)
  {
    float maxStrength = 0;
    PVector maxLoc = new PVector();

    for (int ys = 0; ys < s; ys++) {
      for (int xs = 0; xs < s; xs++)
      {
        if ((xs == 0) && (ys == 0)) continue; // Not interested in dc component
        
        PVector complexF = new PVector((xs + s/2) % s - s/2, (ys + s/2) % s - s/2);
        if (boundsCheck && (complexF.mag() <= minDctMag)) continue;
        if (boundsCheck && (complexF.mag() >= maxDctMag)) continue;

        float strength = getAmplitudeAt(mat, xs, ys);
        if (strength > maxStrength) {
          maxStrength = strength;
          maxLoc = complexF;
        }
      }
    }
    // TODO: Aggregate nearby strength?
    maxLoc.z = maxStrength;
    return maxLoc;
  }

  float getAmplitudeAt(Mat mat, int x, int y)
  {
    double[] tmp = mat.get(y, x);
    return mag((float)tmp[0], (float)tmp[1]);
  }

  void drawImpl(PGraphics g)
  {
    g.image(take.shapeIndex, 0, 0);
    if (!(keyPressed && (keyCode == KeyEvent.VK_SHIFT)))
    {
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
    }

    if (mousePressed && (mouseButton == RIGHT)) {
      drawMouseHighlight(g);
    }
  }

  void drawMouseHighlight(PGraphics g)
  {
    int imgX = (int)imageX(mouseX);
    int imgY = (int)imageY(mouseY);
    if (imgX < s/2 || imgY < s/2 || imgX >= w-s/2 || imgY >= h-s/2) return;

    Mat complexMat = getFrequencySpaceAt(imgX, imgY);

    if (keyPressed && (keyCode == KeyEvent.VK_SHIFT))
    {
      Mat newMat = eliminateMainFrequency(complexMat);
      fillMouseImage(newMat);
      g.image(mouseDetail, imgX-s/2, imgY-s/2);
    } else
    {
      fillMouseImageDC(complexMat);
      PVector mainF = findMainFrequency(complexMat, true);
      float dc = getAmplitudeAt(complexMat, 0, 0);
      // TODO: Show selected main frequency?
      g.pushMatrix();
      g.resetMatrix();
      g.translate(mouseX, mouseY);
      g.scale(2);
      g.fill(255);
      g.text("Amplitude:" + mainF.z + "\nRelative:" + mainF.z/dc + "\nRescaled:" + rescaleAmplitude(mainF.z/dc), 4, -61);
      g.fill(0);
      g.text("Amplitude:" + mainF.z + "\nRelative:" + mainF.z/dc + "\nRescaled:" + rescaleAmplitude(mainF.z/dc), 5, -60);
      g.scale(1.0/2);
      int scale = 8;
      g.scale(scale);
      g.image(mouseDetail, -s, -s);
      g.stroke(0);
      g.strokeWeight(0.1);
      g.noFill();
      g.rect(-s, -s, s, s);
      g.translate(-s/2 + 0.5, -s/2 + 0.5);
      g.stroke(color(0, 200, 0, 100));
      // Apparently we're using rectMode CENTER?
      g.ellipse(0, 0, 2*minDctMag, 2*minDctMag);
      g.ellipse(0, 0, 2*maxDctMag, 2*maxDctMag);
      g.popMatrix();
    }
  }

  Mat eliminateMainFrequency(Mat complexMat)
  {
    PVector maxLoc = findMainFrequency(complexMat, true);
    int maxX = ((int)maxLoc.x + s) % s;
    int maxY = ((int)maxLoc.y + s) % s;
    
    // Radius of frequency area to clear.
    int sp = 2;
    for (int y = max(maxY-sp, 0); y < min(maxY+sp+1, s); y++) {
      for (int x = max(maxX-sp, 0); x < min(maxX+sp+1, s); x++) {
        if ((x == 0) && (y == 0)) continue; 
        complexMat.put(y, x, 0.0, 0.0);
        complexMat.put(s-y, s-x, 0.0, 0.0);
      }
    }
    // Invert
    Mat newMat = new Mat();
    Core.dft(complexMat, newMat, Core.DFT_INVERSE | Core.DFT_SCALE, 0);
    return newMat;
  }

  void fillMouseImageDC(Mat mat)
  {
    mouseDetail.loadPixels();
    float dc = getAmplitudeAt(mat, 0, 0);
    for (int ys = 0; ys < s; ys++) {
      for (int xs = 0; xs < s; xs++) {
        int pos = ((ys + s/2) % s) * s + (xs + s/2) % s;
        float mag = getAmplitudeAt(mat, xs, ys);
        mouseDetail.pixels[pos] = color(rescaleAmplitude(mag / dc) * 255);
      }
    }
    mouseDetail.updatePixels();
  }

  float rescaleAmplitude(float amp)
  {
    return sqrt(sqrt(amp));
  }

  void fillMouseImage(Mat mat)
  {
    mouseDetail.loadPixels();
    for (int ys = 0; ys < s; ys++) {
      for (int xs = 0; xs < s; xs++) {
        int pos = ys * s + xs;
        float mag = getAmplitudeAt(mat, xs, ys);
        mouseDetail.pixels[pos] = color(mag);
      }
    }
    mouseDetail.updatePixels();
  }
}