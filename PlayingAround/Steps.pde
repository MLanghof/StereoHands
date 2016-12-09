abstract class Step
{
  Take take;
  
  public Step(Take take)
  {
    this.take = take;    
  }
  
  abstract public void draw();
}

abstract class InputStep extends Step
{
  public InputStep(Take take)
  {
    super(take);
  }
}

abstract class CalculationStep extends Step
{
  boolean calculated = false;
  
  public CalculationStep(Take take)
  {
    super(take);
  }
  
  public void draw()
  {
    if (!calculated) {
      calculate();
    }
    drawImpl();
  }
  
  abstract public void drawImpl();
  
  abstract public void calculate();
}

class ShapeIndexStep extends InputStep
{
  public ShapeIndexStep(Take take)
  {
    super(take);
  }
  
  public void draw()
  {
    image(take.shapeIndex, 0, 0);
  }
}

class AlbedoStep extends InputStep
{
  public AlbedoStep(Take take)
  {
    super(take);
  }
  
  public void draw()
  {
    image(take.albedo, 0, 0);
  }
}

class NormalsStep extends InputStep
{
  public NormalsStep(Take take)
  {
    super(take);
  }
  
  public void draw()
  {
    for (int y = 0; y < take.roi.height; y++) {
      for (int x = 0; x < take.roi.width; x++) {
        
      }
    }
  }
}