class FileSelectorBar {
  
  File root;
  public File[] files;
  
  FileSelectorBar child;
  
  public int selected = 0;
  
  public FileSelectorBar(File root, int Y)
  {
    this.root = root;
    this.Y = Y;
    
    update();
  }
  
  void update()
  {
    files = root.listFiles();
    selected = min(selected, files.length);
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
  
  public void draw() {
    float interval = width / (float)getMax();
    stroke(255);
    for (int i = 0; i < getMax(); i++)
    {
      float x = i * interval;
      
      line(x, Y, x, Y + HEIGHT);
      
      if (i == selected) {
        fill(120, 255);
      } else {
        fill(40, 255);
      }
      rect(x, Y, interval, HEIGHT);
    
      fill(255);
      text(files[i].getName(), x, Y, interval, HEIGHT);
    }
    
    if (mustDescend()) {
      child.draw();
    }
  }
  
  public void handleClick(int x, int y)
  {
    if ((y > Y) && (y < Y + HEIGHT)) {
      selected = getMax() * x / width;
      update();
    }
    else
    {
      if (mustDescend()) {
        child.handleClick(x, y);
      }
    }
  }
  
  public void setRoot(File newRoot)
  {
    root = newRoot;
    update();
  }
  
  public int Y = 0;
  public int HEIGHT = 40;
}