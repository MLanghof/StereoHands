class ImageLoader
{
  public PImage openFile(String path)
  {
    if (path.endsWith(".mat")) {
      return loadAlbedo(path);
    } else {
      return loadImage(path);
    }
  }
  
  PImage loadAlbedo(String path)
  {
    DoubleBuffer db = getMatDoubles(path);
    if (db == null) return null;
    
    PImage img = createImage(SIZE, SIZE, RGB);
    img.loadPixels();
    for (int i = 0; i < sq(SIZE); i++)
    {
      color c = getColor(path, (float)db.get());
      img.pixels[i] = c;
    }
    img.updatePixels();
    return img;
  }
  
  int SIZE = 2048;
  int DATA_START = 420 * 8;
  int DATA_LENGTH = SIZE * SIZE * 8;
  int TOTAL_LENGTH = DATA_START + DATA_LENGTH;
  
  DoubleBuffer getMatDoubles(String path)
  {
    byte[] matData = loadBytes(path);
    if (matData.length < TOTAL_LENGTH) return null;
    return ByteBuffer.wrap(matData, DATA_START, DATA_LENGTH).order(ByteOrder.LITTLE_ENDIAN).asDoubleBuffer();
  }
  
  // Produces a color scale appropriate for the file opened
  color getColor(String path, float value)
  {
    // Default (a.mat)
    color ret = color((int)(255 * value));
    
    // Vectors
    
    if (path.endsWith("px.mat") || path.endsWith("py.mat"))
    {
      colorMode(HSB, 1.0f);
      ret = color(value, 1.0f, (abs(value)));
      colorMode(RGB, 255);
    }
    if (path.endsWith("pz.mat")) {
      ret = color(255 * 1.4 * (1.0 - value));
    }
    return ret;
  }
  
  
}