
class SelectorBar {
  
  public int max = 0;
  
  public int selected = 0;
  
  public SelectorBar(int max, int Y)
  {
    this.max = max;
    this.Y = Y;
  }
  
  public void draw() {
    float interval = width / max;
    stroke(255);
    fill(120, 255);
    
    for (int i = 0; i <= max; i++)
    {
      float x = i * interval;
      line(x, Y, x, Y + HEIGHT);
      if (i == selected) {
        rect(x, Y, interval, HEIGHT);
      }
    }
  }
  
  public boolean handleClick(int x, int y)
  {
    if (y < Y) return false;
    if (y > Y + HEIGHT) return false;
    selected = max * x / width; 
    return true;
  }
  
  public int Y = 0;
  public int HEIGHT = 40;
}