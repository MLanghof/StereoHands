import java.lang.reflect.*;

abstract class Step
{
  Take take;
  
  int h, w;
  
  public Step(Take take)
  {
    setTake(take);    
  }
  
  abstract public void draw();
  
  public void setTake(Take take)
  {
    this.take = take;
    h = take.roi.height;
    w = take.roi.width;
  }
  
  public boolean onScreen(float x, float y)
  {
    float sx = screenX(x, y);
    float sy = screenY(x, y);
    return (sx > 0 && sx < width && sy > 0 && sy < height);
  }
  
  public int screenStartX() {
    return floor(constrain(-panX / zoom, 0, w));
  }
  
  public int screenStartY() {
    return floor(constrain(-panY / zoom, 0, h));
  }
  
  public int screenEndX() {
    return ceil(constrain((width - panX) / zoom, 0, w));
  }
  
  public int screenEndY() {
    return ceil(constrain((height - panY) / zoom, 0, h));
  }
  
  public String toString()
  {
    return this.getClass().getSimpleName();
  }
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
  boolean allocated = false;
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
  
  public void calculate()
  {
    if (!calculated) {
      allocateResources();
      calculateImpl();
    }
    calculated = true;
  }
  
  public void allocateResources()
  { /*Empty so children that don't need this don't have to redeclare*/ }
  
  abstract public void calculateImpl();
  
  public void setTake(Take take)
  {
    super.setTake(take);
    calculated = false;
  }
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
    image(take.shapeIndex, 0, 0);
    int d = 1;
    pushMatrix();
    translate(0.5, 0.5);
    stroke(color(255, 0, 0));
    strokeWeight(d / 20.0);
    for (int y = 0; y < h; y+=d) {
      for (int x = 0; x < w; x+=d) {
        if (!onScreen(x, y)) continue;
        PVector n = take.normals[y*w + x];
        float dx = n.x * d / 5;
        float dy = n.y * d / 5;
        line(x, y, x + dx * 8, y + dy * 8);
        line(x - dy, y + dx, x + dy, y - dx);
      }
    }
    popMatrix();
  }
}