import java.awt.Rectangle;

class Take
{
  public String path;
  
  public PImage shapeIndex;
  public PImage albedo;
  public PVector[] normals;
  
  Rectangle roi;
  
  final String shapeIndexPath = "/si.bmp";
  final String albedoPath = "/a.mat";
  final String pxPath = "/px.mat";
  final String pyPath = "/py.mat";
  final String pzPath = "/pz.mat";

  // Constants for .mat files
  final int SIZE = 2048;
  final int DATA_START = 420 * 8;
  final int DATA_LENGTH = SIZE * SIZE * 8;
  final int TOTAL_LENGTH = DATA_START + DATA_LENGTH;
  
  public Take(String folderPath)
  {
    this.path = folderPath;
    shapeIndex = loadImage(folderPath + shapeIndexPath);
    roi = getRoi(shapeIndex);
    shapeIndex = shapeIndex.get(roi.x, roi.y, roi.width, roi.height);
    if (loadAlbedo) albedo = loadAlbedo(folderPath + albedoPath);
    if (loadNormals) normals = loadNormals(folderPath);
  }
  
  public PImage loadAlbedo(String path)
  {
    DoubleBuffer db = readDotMatFile(path);
    PImage ret = createImage(roi.width, roi.height, RGB);
    
    // Find maximum value
    float max = 0;
    for (int i = 0; i < sq(SIZE); i++) {
      max = max((float)db.get(), max);
    }
    db.rewind();
    
    // Write data to image
    ret.loadPixels();
    for (int y = 0; y < roi.height; y++) {
      for (int x = 0; x < roi.width; x++)
      {
        float val = (float)db.get((y + roi.y) * SIZE + (x + roi.x));
        ret.pixels[y * roi.width + x] = color(val/max * 255);
      }
    }
    ret.updatePixels();
    return ret;
  }
  
  public PVector[] loadNormals(String folderPath)
  {
    DoubleBuffer dbX = readDotMatFile(folderPath + pxPath);
    DoubleBuffer dbY = readDotMatFile(folderPath + pyPath);
    DoubleBuffer dbZ = readDotMatFile(folderPath + pzPath);
    
    PVector[] ret = new PVector[getArea()];
    for (int y = 0; y < roi.height; y++) {
      for (int x = 0; x < roi.width; x++)
      {
        int bufferIndex = (y + roi.y) * SIZE + (x + roi.x);
        PVector val = new PVector((float)dbX.get(bufferIndex), -(float)dbY.get(bufferIndex), (float)dbZ.get(bufferIndex));
        ret[y * roi.width + x] = val;
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
  
  public DoubleBuffer readDotMatFile(String path)
  { 
    byte[] matData = loadBytes(path);
    if (matData.length < TOTAL_LENGTH) return null;
    return ByteBuffer.wrap(matData, DATA_START, DATA_LENGTH).order(ByteOrder.LITTLE_ENDIAN).asDoubleBuffer();
  }
}