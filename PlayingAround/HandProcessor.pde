class HandProcessor
{
  Take currentTake;

  public SimpleSelectorBar uiSelector;

  public ObjectSelectorBar<Step> stepSelector;
  public SimpleSelectorBar paramSelector;
  public FileSelectorBar fileSelector;
  
  ShapeIndexStep shapeIndexStep;
  SmoothNormalsStep smoothNormalsStep;
  FlowStep flowStep;
  DftStep dctStep;
  
  Mouseover mouseover;
  
  public HandProcessor()
  {
    int y = 0;
    uiSelector = new SimpleSelectorBar(2, y);
    uiSelector.HEIGHT = 20; y += 25;
    fileSelector = new FileSelectorBar(new File("D:/PSHands/"), y); y += 3*40 + 10;
    stepSelector = new ObjectSelectorBar<Step>(y); y += 40;
    paramSelector = new SimpleSelectorBar(8, y);
    
    openFile(); //<>//
    stepSelector.add(new AlbedoStep(currentTake));
    shapeIndexStep = new ShapeIndexStep(currentTake);
    stepSelector.add(shapeIndexStep);
    stepSelector.add(new NormalsStep(currentTake));
    smoothNormalsStep = new SmoothNormalsStep(shapeIndexStep);
    stepSelector.add(smoothNormalsStep);
    flowStep = new FlowStep(smoothNormalsStep);
    stepSelector.add(flowStep);
    stepSelector.add(new DownsampleFlowStep(flowStep));
    dctStep = new DftStep(shapeIndexStep);
    stepSelector.add(dctStep);
    stepSelector.add(new FlowFromDftStep(dctStep));
    stepSelector.add(new FullDftStep(shapeIndexStep));
    stepSelector.add(new FullDctStep(shapeIndexStep));
    stepSelector.add(new FlowFinder(shapeIndexStep));
    
    mouseover = new Mouseover(currentTake);
  }

  public PImage getCurrentImage()
  {
    return currentTake.shapeIndex;
    //return img;
  }
  
  public void drawUI()
  {
    uiSelector.draw();
    fileSelector.draw();
    if (inStepUI()) {
      stepSelector.draw();
      paramSelector.draw();
    }
  }
  
  public void drawImage()
  {
    if (inStepUI()) {
      stepSelector.getCurrent().draw();
    }
    mouseover.draw();
  }
  
  int outCount = 0;
  
  public void saveImage()
  {
    if (inStepUI()) {
      Step currentStep = stepSelector.getCurrent();
      int s = 2;
      PGraphics pg = createGraphics(currentStep.w * s, currentStep.h * s);
      pg.beginDraw();
      pg.scale(s);
      currentStep.drawOn(pg);
      pg.endDraw();
      pg.save("out" + outCount++ + ".png");
    }
  }
  
  public void handleClick(int x, int y)
  {
    uiSelector.handleClick(x, y);
    stepSelector.handleClick(x, y);
    if (paramSelector.handleClick(x, y)) {
      if (stepSelector.getCurrent() == smoothNormalsStep) {
        smoothNormalsStep.k = paramSelector.getCurrentIndex();
        openFile();
      }
      if (stepSelector.getCurrent() == flowStep) {
        flowStep.k = paramSelector.getCurrentIndex();
        openFile();
      }
    }
    if (fileSelector.handleClick(x, y)) {
      openFile();
    }
    redraw();
  }
  
  void openFile()
  {
    String path = fileSelector.getFile().getPath();
    if (currentTake == null || currentTake.path != path) {
      currentTake = new Take(path);
    }
    for (Step step : stepSelector.objects) {
      step.setTake(currentTake);
    }
    if (mouseover != null) mouseover.setTake(currentTake);
  }
  
  boolean inStepUI()
  {
    return uiSelector.getCurrentIndex() == 0;
  }
}

// This isn't actually a real step
class Mouseover extends Step
{
  RidgeDetector ridger;

  // Graphics buffer for mouse highlight
  PImage mouseDetail;
  
  // Window size
  final int s;
  
  public Mouseover(Take take)
  {
    super(take);
    ridger = new RidgeDetector();
    s = ridger.s;
    ridger.input = this;
    mouseDetail = createImage(s, s, RGB);
  }
  
  public void drawOn(PGraphics g)
  {
    if (mousePressed && (mouseButton == RIGHT)) {
      drawMouseHighlight(g);
    }
  }

  void drawMouseHighlight(PGraphics g)
  {
    int imgX = (int)imageX(mouseX);
    int imgY = (int)imageY(mouseY);
    if (imgX < s/2 || imgY < s/2 || imgX >= w-s/2 || imgY >= h-s/2) return;

    Mat complexMat = ridger.getFrequencySpaceAt(imgX, imgY);

    if (keyPressed && (keyCode == KeyEvent.VK_SHIFT))
    {
      Mat newMat = eliminateMainFrequency(complexMat);
      fillMouseImage(newMat);
      g.image(mouseDetail, imgX-s/2, imgY-s/2);
    }
    else
    {
      Ridge ridge = ridger.findPotentialRidge(complexMat, true);
      fillMouseImageDC(complexMat, ridge);
      float dc = ridger.getAmplitudeAt(complexMat, 0, 0);
      // TODO: Show selected main frequency?
      g.pushMatrix();
      g.resetMatrix();
      g.translate(mouseX, mouseY);
      g.scale(2);
      g.fill(255);
      g.text("Amplitude:" + ridge.strength + "\nRelative:" + ridge.strength/dc + "\nRescaled:" + rescaleAmplitude(ridge.strength/dc), 4, -61);
      g.fill(0);
      g.text("Amplitude:" + ridge.strength + "\nRelative:" + ridge.strength/dc + "\nRescaled:" + rescaleAmplitude(ridge.strength/dc), 5, -60);
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
    Ridge ridge = ridger.findPotentialRidge(complexMat, true);
    int maxX = ((int)ridge.fx() + s) % s;
    int maxY = ((int)ridge.fy() + s) % s;
    
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

  void fillMouseImageDC(Mat mat, Ridge ridge)
  {
    mouseDetail.loadPixels();
    float dc = ridger.getAmplitudeAt(mat, 0, 0);
    for (int ys = 0; ys < s; ys++) {
      for (int xs = 0; xs < s; xs++) {
        int pos = ((ys + s/2) % s) * s + (xs + s/2) % s;
        float mag = ridger.getAmplitudeAt(mat, xs, ys);
        float val = rescaleAmplitude(mag / dc) * 255;
        if ((xs == ((int)ridge.fx() + s) % s) && (ys == ((int)ridge.fy() + s) % s)) {
          mouseDetail.pixels[pos] = color(0, val, 0);
        } else {
          mouseDetail.pixels[pos] = color(val);
        }
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
        float mag = ridger.getAmplitudeAt(mat, xs, ys);
        mouseDetail.pixels[pos] = color(mag);
      }
    }
    mouseDetail.updatePixels();
  }
  
  
}