
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
      // Intentionally always (even if selection didn't change)
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
        fill(128, 180);
      } else {
        fill(128, 80);
      }
      rect(x, Y, interval, HEIGHT);
    
      fill(255);
      text(getName(i), x+3, Y+2, interval, HEIGHT);
    }
  }
  
  public int getCurrentIndex()
  {
    return selected;
  }
  
  public void update()
  { /*Empty so children that don't need this don't have to redeclare*/ }
  
  public abstract int getMax();
  
  public abstract String getName(int index);
  
  public boolean isMaxSelected()
  {
    return selected == getMax() - 1;
  }
  public boolean isMinSelected()
  {
    return selected == 0;
  }
}

class SimpleSelectorBar extends SelectorBar
{
  public int max = 0;
  
  public SimpleSelectorBar(int max, int Y)
  {
    super(Y);
    this.max = max;
  }
  
  public int getMax()
  {
    return max;
  }
  
  public String getName(int index)
  {
    return Integer.toString(index);
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
    files = filterFiles(root.listFiles());
    selected = min(selected, getMax()-1);
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
    //return getSelected().isDirectory();
    String[] matches = match(getSelected().getName(), "\\A\\d\\d\\d");
    return matches == null;
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
  
  // Selects the next file recursively (DFS).
  // Returns whether another file could be chosen at this level or below.
  public boolean recursiveNext()
  {
    if (mustDescend() && child.recursiveNext()) {
      return true;
    }
    if (isMaxSelected()) {
      return false;
    }
    selected++;
    update();
    if (mustDescend()) {
      child = new FileSelectorBar(getSelected(), Y + HEIGHT);
    }
    return true;
  }
  
  // Selects the previous file recursively (DFS).
  // Returns whether another file could be chosen at this level or below.
  public boolean recursivePrevious()
  {
    if (mustDescend() && child.recursivePrevious()) {
      return true;
    }
    if (isMinSelected()) {
      return false;
    }
    selected--;
    update();
    if (mustDescend()) {
      child = new FileSelectorBar(getSelected(), Y + HEIGHT);
    }
    return true;
  }
  
  private File[] filterFiles(File[] files)
  {
    if (!(reducedSampleSize || ignoreNIR)) return files;
    ArrayList<File> newFiles = new ArrayList<File>();
    for (File file : files) {
      String name = file.getName();
      // Don't care about NIR
      if (ignoreNIR && (match(name, "NIR") != null)) continue;
      // Only use image 001 for now.
      if (reducedSampleSize && (match(name, "00\\d") != null) && (match(name, "001") == null)) continue;
      newFiles.add(file);
    }
    // TODO: This is a real danger
    //if (newFiles.isEmpty()) 
    //return files;
    return newFiles.toArray(new File[0]); // This is one weird function
  }
  
  public String getUsableFileNamePath()
  {
    return getFile().getPath().replaceAll("[^a-zA-Z0-9\\._]+", "_");
  }
}

class ObjectSelectorBar<T> extends SelectorBar
{
  ArrayList<T> objects;
  
  public ObjectSelectorBar(int Y)
  {
    super(Y);
    objects = new ArrayList<T>();
  }
  
  public int getMax()
  {
    return objects.size();
  }
  
  public String getName(int index)
  {
    return objects.get(index).toString();
  }
  
  public T getCurrent()
  {
    return objects.get(getCurrentIndex());
  }
  
  public void add(T object)
  {
    objects.add(object);
  }
}