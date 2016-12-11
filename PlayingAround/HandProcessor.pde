class HandProcessor
{
  Take currentTake;

  public StepSelectorBar stepSelector = new StepSelectorBar(0);
  public SimpleSelectorBar paramSelector = new SimpleSelectorBar(8, 40);
  public FileSelectorBar fileSelector = new FileSelectorBar(new File("D:/PSHands/"), 90);
  
  ShapeIndexStep shapeIndexStep;
  SmoothNormalsStep smoothNormalsStep;
  FlowStep flowStep;
  
  public HandProcessor()
  {
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
    stepSelector.add(new DctStep(shapeIndexStep));
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
    stepSelector.draw();
    paramSelector.draw();
    fileSelector.draw();
  }
  
  public void drawImage()
  {
    stepSelector.getStep().draw();
  }
  
  public void handleClick(int x, int y)
  {
    if (stepSelector.handleClick(mouseX, mouseY)) {
      redraw();
    }
    if (paramSelector.handleClick(mouseX, mouseY)) {
      if (stepSelector.getStep() == smoothNormalsStep) {
        smoothNormalsStep.k = paramSelector.getCurrent();
        openFile();
      }
      if (stepSelector.getStep() == flowStep) {
        flowStep.k = paramSelector.getCurrent();
        openFile();
      }
      redraw();
    }
    if (fileSelector.handleClick(mouseX, mouseY)) {
      openFile();
    }
  }
  
  void openFile()
  {
    String path = fileSelector.getFile().getPath();
    if (currentTake == null || currentTake.path != path) {
      currentTake = new Take(path);
    }
    for (Step step : stepSelector.steps) {
      step.setTake(currentTake);
    }
    redraw();
  }
}