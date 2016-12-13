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
  
  public HandProcessor()
  {
    int y = 0;
    uiSelector = new SimpleSelectorBar(2, y);
    uiSelector.HEIGHT = 20; y += 25;
    fileSelector = new FileSelectorBar(new File("D:/PSHands/"), y); y += 3*40 + 10;
    stepSelector = new ObjectSelectorBar<Step>(y); y += 40;
    paramSelector = new SimpleSelectorBar(8, y);
    
    openFile();
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
  }
  
  boolean inStepUI()
  {
    return uiSelector.getCurrentIndex() == 0;
  }
}