
abstract class SelectorBar
{
  public int selected = 0;
  
  public int Y = 0;
  public int HEIGHT = 40;
  
  public SelectorBar(int Y)
  {
    this.Y = Y;
  }
  
  public boolean handleClick(int x, int y)
  {
    if ((y > Y) && (y < Y + HEIGHT)) {
      selected = getMax() * x / width;
      update();
      return true;
    }
    return false;
  }
  
  public void draw()
  {
    float interval = width / (float)getMax();
    stroke(255);
    for (int i = 0; i < getMax(); i++)
    {
      float x = i * interval;
      
      line(x, Y, x, Y + HEIGHT);
      
      if (i == selected) {
        fill(255, 120);
      } else {
        fill(255, 40);
      }
      rect(x, Y, interval, HEIGHT);
    
      fill(255);
      text(getName(i), x+3, Y+2, interval, HEIGHT);
    }
  }
  
  public abstract void update();
  
  public abstract int getMax();
  
  public abstract String getName(int index);
}



class SimpleSelectorBar extends SelectorBar
{
  public int max = 0;
  
  public SimpleSelectorBar(int max, int Y)
  {
    super(Y);
    this.max = max;
  }
  
  public void update()
  {
  }
  
  public int getMax()
  {
    return max;
  }
  
  public String getName(int index)
  {
    return Integer.toString(index);
  }
  
  public int getCurrent()
  {
    return selected;
  }
}



class FileSelectorBar extends SelectorBar
{
  
  File root;
  public File[] files;
  
  FileSelectorBar child;
  
  public FileSelectorBar(File root, int Y)
  {
    super(Y);
    this.root = root;
    
    update();
  }
  
  void update()
  {
    files = root.listFiles();
    selected = min(selected, getMax());
    if (mustDescend()) {
      if (child == null) {
        child = new FileSelectorBar(getSelected(), Y + HEIGHT);
      } else {
        child.setRoot(getSelected());
      }
    }
  }
  
  public File getFile()
  {
    if (mustDescend())
    {
      return child.getFile();
    }
    return getSelected();
  }
  
  public boolean mustDescend() {
    return getSelected().isDirectory();
  }
  
  public int getMax()
  {
    return files.length;
  }
  
  public File getSelected()
  {
    return files[selected];
  }
  
  public void draw()
  {
    super.draw();
    
    if (mustDescend()) {
      child.draw();
    }
  }
  
  public String getName(int index)
  {
    return files[index].getName();
  }
  
  public boolean handleClick(int x, int y)
  {
    if (super.handleClick(x, y)) {
      return true;
    }
    else {
      if (mustDescend()) {
        return child.handleClick(x, y);
      }
    }
      return false;
  }
  
  public void setRoot(File newRoot)
  {
    root = newRoot;
    update();
  }
}