import java.io.*;

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
  FeatureStep featureStep;
  
  Mouseover mouseover;
  
  public HandProcessor()
  {
    int y = 0;
    uiSelector = new SimpleSelectorBar(2, y);
    uiSelector.HEIGHT = 20; y += 25;
    fileSelector = new FileSelectorBar(new File(baseFolder), y); y += 3*40 + 10;
    stepSelector = new ObjectSelectorBar<Step>(y); y += 40;
    paramSelector = new SimpleSelectorBar(8, y);
    
    openFile();
    if (loadAlbedo) stepSelector.add(new AlbedoStep(currentTake));
    shapeIndexStep = new ShapeIndexStep(currentTake);
    stepSelector.add(shapeIndexStep);
    stepSelector.add(new LandmarksStep(currentTake));
    if (loadNormals) {
      stepSelector.add(new NormalsStep(currentTake));
      smoothNormalsStep = new SmoothNormalsStep(shapeIndexStep);
      stepSelector.add(smoothNormalsStep);
      flowStep = new FlowStep(smoothNormalsStep);
      stepSelector.add(flowStep);
      stepSelector.add(new DownsampleFlowStep(flowStep));
    }
    dctStep = new DftStep(shapeIndexStep);
    stepSelector.add(dctStep);
    stepSelector.add(new FlowFromDftStep(dctStep));
    stepSelector.add(new FullDftStep(shapeIndexStep));
    stepSelector.add(new FullDctStep(shapeIndexStep));
    stepSelector.add(new FlowFinder(shapeIndexStep));
    featureStep = new FeatureStep(shapeIndexStep);
    stepSelector.add(featureStep);
    
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
  
  public void saveImageSimple() {
    saveImage("out" + outCount++ + ".png");
  }
  
  public void saveImageFull() {
    String name = fileSelector.getUsableFileNamePath();
    name += "_" + stepSelector.getCurrent().toString();
    saveImage(resultImageFolder + name + ".png");
  }
  
  public void saveImage(String path)
  {
    if (inStepUI()) {
      Step currentStep = stepSelector.getCurrent();
      int s = 1;
      PGraphics pg = createGraphics(currentStep.w * s, currentStep.h * s);
      pg.beginDraw();
      pg.scale(s);
      currentStep.drawOn(pg);
      pg.endDraw();
      pg.save(path);
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
    int m1 = millis();
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
  
  boolean nextInput()
  {
    if (fileSelector.recursiveNext()) {
      openFile();
      return true;
    }
    return false;
  }
  
  boolean previousInput()
  {
    if (fileSelector.recursivePrevious()) {
      openFile();
      return true;
    }
    return false;
  }
  
  // TODO: Move to featureStep?
  void saveFeatures(String path)
  {
    try {
      FileOutputStream fileOut = new FileOutputStream(path);
      ObjectOutputStream out = new ObjectOutputStream(fileOut);
      out.writeObject(featureStep.features);
      out.close();
      fileOut.close();
      println("Saved features!");
    } catch(IOException e) {
      e.printStackTrace();
    }
  }
  
  void loadFeatures(String path)
  {
    try {
      FileInputStream fileIn = new FileInputStream(path);
      ObjectInputStream in = new ObjectInputStream(fileIn);
      featureStep.features = (ArrayList<Feature>)in.readObject();
      featureStep.calculated = true;
      in.close();
      fileIn.close();
      println("Loaded features!");
    } catch(IOException i) {
      i.printStackTrace();
      return;
    } catch(ClassNotFoundException c) {
      System.out.println("Original class not found for deserialization!");
      c.printStackTrace();
      return;
    }
  }
  
  void processAndSaveAllHands()
  {
    
    for (boolean haveInput = true; haveInput; haveInput = nextInput()) {
      println("Processing " + fileSelector.getFile().getPath());
      featureStep.calculate();
      String path = featuresFolder + fileSelector.getUsableFileNamePath() + ".ser";
      saveFeatures(path);
    }
  }
}

// This isn't actually a real step
class Mouseover extends Step
{
  RidgeDetector ridger;

  // Graphics buffer for mouse highlight
  PImage mouseDetail;
  
  // Window size
  final int ts;
  
  public Mouseover(Take take)
  {
    super(take);
    ridger = new RidgeDetector(s);
    ts = ridger.s;
    ridger.input = this;
    mouseDetail = createImage(ts, ts, RGB);
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
    if (imgX < ts/2 || imgY < ts/2 || imgX >= w-ts/2 || imgY >= h-ts/2) return;

    if (keyPressed && (keyCode == KeyEvent.VK_SHIFT))
    {
      /*Mat newMat = ridger.eliminateRidgeAt(imgX, imgY);*/
      Mat complexMat = ridger.getFrequencySpaceAt(imgX, imgY);
      Mat newComplexMat = ridger.isolateTwoRidgeFrequencies(complexMat);
      fillMouseImageDC(newComplexMat, 0, 0);
      g.image(mouseDetail, imgX-ts/2, imgY-ts/2);
    }
    else
    {
      Mat complexMat = ridger.getFrequencySpaceAt(imgX, imgY);
      Ridge ridge = ridger.findPotentialRidge(complexMat, true, true, false);
      fillMouseImageDC(complexMat, (int)ridge.fx(), (int)ridge.fy());
      float dc = ridger.getAmplitudeAt(complexMat, 0, 0);
      g.pushMatrix();
      g.resetMatrix();
      g.translate(mouseX, mouseY);
      g.scale(2);
      g.fill(255);
      float r = ridge.response.mag();
      String text = "Amplitude:" + r + "\nRelative:" + r/dc + "\nRescaled:" + rescaleAmplitude(r/dc);
      text += "\nPhase:" + degrees(ridge.response.heading()) + "\nx:" + ridge.x + "\ny:" + ridge.y;
      g.text(text, 4, -61);
      g.fill(0);
      g.text(text, 5, -60);
      g.scale(1.0/2);
      int scale = 8;
      g.scale(scale);
      g.image(mouseDetail, -ts, -ts);
      g.stroke(0);
      g.strokeWeight(0.1);
      g.noFill();
      g.rect(-ts, -ts, ts, ts);
      g.translate(-ts/2 + 0.5, -ts/2 + 0.5);
      g.stroke(color(0, 200, 0, 100));
      // Apparently we're using rectMode CENTER?
      g.ellipse(0, 0, 2*minDftMagRidge, 2*minDftMagRidge);
      g.ellipse(0, 0, 2*maxDftMagRidge, 2*maxDftMagRidge);
      g.ellipse(0, 0, 2*minDftMagWrinkle, 2*minDftMagWrinkle);
      g.popMatrix();
    }
  }

  void fillMouseImageDC(Mat mat, int highlightX, int higlightY)
  {
    mouseDetail.loadPixels();
    //colorMode(HSB, TWO_PI, 1, 1);
    float dc = ridger.getAmplitudeAt(mat, 0, 0);
    for (int ys = 0; ys < ts; ys++) {
      for (int xs = 0; xs < ts; xs++) {
        int pos = ((ys + ts/2) % ts) * ts + (xs + ts/2) % ts;
        float mag = ridger.getAmplitudeAt(mat, xs, ys);
        float val = rescaleAmplitude(mag / dc) * 255;
        if ((xs == (highlightX + ts) % ts) && (ys == (higlightY + ts) % ts)) {
          mouseDetail.pixels[pos] = color(0, val, 0);
        } else {
          mouseDetail.pixels[pos] = color(val);//color(response.heading() + PI, 0.5, val);
        }
      }
    }
    //colorMode(RGB, 256);
    mouseDetail.updatePixels();
  }

  float rescaleAmplitude(float amp)
  {
    return sqrt(sqrt(amp));
  }

  void fillMouseImage(Mat mat)
  {
    mouseDetail.loadPixels();
    for (int ys = 0; ys < ts; ys++) {
      for (int xs = 0; xs < ts; xs++) {
        int pos = ys * ts + xs;
        float mag = ridger.getAmplitudeAt(mat, xs, ys);
        mouseDetail.pixels[pos] = color(mag);
      }
    }
    mouseDetail.updatePixels();
  }
}