import java.awt.Rectangle;

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
  
  int DATA_START = 420 * 8;
  int DATA_LENGTH = SIZE * SIZE * 8;
  int TOTAL_LENGTH = DATA_START + DATA_LENGTH;
  
  public DoubleBuffer getMatDoubles(String path)
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

class Take
{
  public String path;
  
  public PImage shapeIndex;
  public PImage albedo;
  public PVector[] normals;
  
  ImageLoader loader = new ImageLoader(); // Screw processing for not allowing static classes...
  
  Rectangle roi;
  
  public Take(String folderPath)
  {
    this.path = folderPath;
    shapeIndex = loadImage(folderPath + "/si.bmp");
    roi = getRoi(shapeIndex);
    shapeIndex = shapeIndex.get(roi.x, roi.y, roi.width, roi.height);
    albedo = loadAlbedo(folderPath + "/a.mat");
    normals = loadNormals(folderPath);
  }
  
  public PImage loadAlbedo(String path)
  {
    DoubleBuffer db = loader.getMatDoubles(path);
    PImage ret = createImage(roi.width, roi.height, RGB);
    // Find maximum value
    float max = 0;
    for (int i = 0; i < sq(SIZE); i++) {
      max = max((float)db.get(), max);
    }
    db.rewind();
    // Write data to image
    ret.loadPixels();
    for (int i = 0; i < sq(SIZE); i++)
    {
      int x = i % SIZE;
      int y = i / SIZE;
      float val = (float)db.get();
      if (roi.contains(x, y)) {
        ret.pixels[(x - roi.x) + (y - roi.y) * roi.width] = color(val/max * 255);
      }
    }
    ret.updatePixels();
    return ret;
  }
  
  public PVector[] loadNormals(String folderPath)
  {
    DoubleBuffer dbX = loader.getMatDoubles(folderPath + "/px.mat");
    DoubleBuffer dbY = loader.getMatDoubles(folderPath + "/py.mat");
    DoubleBuffer dbZ = loader.getMatDoubles(folderPath + "/pz.mat");
    
    PVector[] ret = new PVector[getArea()];
    for (int i = 0; i < sq(SIZE); i++)
    {
      int x = i % SIZE;
      int y = i / SIZE;
      PVector val = new PVector((float)dbX.get(), -(float)dbY.get(), (float)dbZ.get());
      if (roi.contains(x, y)) {
        ret[(x - roi.x) + (y - roi.y) * roi.width] = val;
      }
    }
    return ret;
  }
  
  private Rectangle getRoi(PImage image)
  {
    image.loadPixels();
    int minX = SIZE, maxX = 0, minY = SIZE, maxY = 0;
    for (int y = 0; y < SIZE; y++) {
      for (int x = 0; x < SIZE; x++) {
        if (image.pixels[x + y * SIZE] != color(0)) {
          minX = min(minX, x);
          maxX = max(maxX, x);
          minY = min(minY, y);
          maxY = max(maxY, y);
        }
      }
    }
    println("ROI of take: [", minX, ",", minY, "] - [", maxX, ",", maxY, "]");
    return new Rectangle(minX, minY, maxX - minX, maxY - minY);
  }
  
  int getArea()
  {
    return roi.width * roi.height;
  }
}