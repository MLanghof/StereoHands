class HandProcessor
{
  Take currentTake;

  public SimpleSelectorBar stepSelector = new SimpleSelectorBar(1, 0);
  public SimpleSelectorBar paramSelector = new SimpleSelectorBar(8, 40);
  public FileSelectorBar fileSelector = new FileSelectorBar(new File("D:/PSHands/"), 90);
  
  SmoothNormalsStep smoothNormalsStep;
  FlowStep flowStep;

  ArrayList<Step> steps = new ArrayList<Step>();
  
  public HandProcessor()
  {
    openFile();
    steps.add(new AlbedoStep(currentTake));
    steps.add(new ShapeIndexStep(currentTake));
    steps.add(new NormalsStep(currentTake));
    smoothNormalsStep = new SmoothNormalsStep(steps.get(1));
    steps.add(smoothNormalsStep);
    flowStep = new FlowStep(smoothNormalsStep);
    steps.add(flowStep);
    steps.add(new DownsampleFlowStep(flowStep));
    stepSelector.max = steps.size();
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
    getCurrentStep().draw();
  }
  
  public void handleClick(int x, int y)
  {
    if (stepSelector.handleClick(mouseX, mouseY)) {
      redraw();
    }
    if (paramSelector.handleClick(mouseX, mouseY)) {
      if (getCurrentStep() == smoothNormalsStep) {
        smoothNormalsStep.k = paramSelector.getCurrent();
        openFile();
      }
      if (getCurrentStep() == flowStep) {
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
    for (Step step : steps) {
      step.setTake(currentTake);
    }
    redraw();
  }
  
  Step getCurrentStep()
  {
    return steps.get(stepSelector.getCurrent());
  }
}