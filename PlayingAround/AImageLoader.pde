import java.awt.Rectangle;
import java.util.Comparator;

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
    // Load shape index and find ROI from it
    shapeIndex = loadImage(folderPath + shapeIndexPath);
    roi = getRoi(shapeIndex);
    // Reduce to base of hand
    if (cutArm) roi = cutOffArm(roi, shapeIndex);
    // Trim shape index and load remaining files
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
        color c = (val/max < albedoThreshold ? color(0) : color(255)); 
        ret.pixels[y * roi.width + x] = c;//color(val/max * 255);
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

  private Rectangle cutOffArm(Rectangle roi, PImage image)
  {
    image.loadPixels();
    // First, go downwards from a certain point
    int startX = round(roi.x + 0.75 * roi.width);
    int maxY = -1;
    for (int y = roi.y; y < roi.y + roi.width; y++)
    {
      int index = y * SIZE + startX;
      if (isForeground(image, index)) {
        maxY = y;
        break;
      }
      if (debugArmStart) image.pixels[index] = color(0, 255, 0);
    }
    if (maxY == -1) {
      println("Couldn't determine start of arm! Are you sure this picture contains a hand?");
      return roi;
    }

    // Then try to keep descending to the right along the contour
    int maxYX = startX;
    int y = maxY;
    int x;
    for (x = startX; x < roi.x + roi.width; x++) {
      // Start a bit higher to account for noise      
      for (y = max(0, y - 2); y < roi.y + roi.height; y++) {
        if (isForeground(image, y * SIZE + x)) {
          break;
        }
      }
      if (debugArmStart) image.pixels[y * SIZE + x] = color(255, 0, 0);

      if (y >= maxY) {
        maxY = y;
        maxYX = x;
      }

      // If we're ascending, cut it off
      if ((y < maxY - 1) && (x - maxYX > 2)) {
        break;
      }
    }
    if (x == roi.x + roi.width)
    {  
      //println("Couldn't determine start of arm!");
      return roi;
    }
    if (debugArmStart) image.updatePixels();
    return new Rectangle(roi.x, roi.y, maxYX - roi.x, roi.height);
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

public boolean isBackground(PImage image, int index)
{
  return image.pixels[index] == color(0);
}
public boolean isForeground(PImage image, int index)
{
  return !isBackground(image, index);
}

class LandmarksStep extends CalculationStep
{
  PImage image;

  public PVector armThumb;
  public PVector armOther;
  public PVector gapThumb;
  public PVector gapIM;
  public PVector gapMR;
  public PVector gapRP;

  boolean complete = false;

  public LandmarksStep(Take take)
  {
    super(take);
  }

  public void setTake(Take take)
  {
    super.setTake(take);
    image = take.shapeIndex;
  }

  public void calculateImpl()
  {
    complete = findLandmarksInInput();
    calculateCorners();
  }

  public boolean findLandmarksInInput()
  {
    nullLandmarks();
    image.loadPixels();

    findArmLandmarks();
    findGapLandmarks();

    image.updatePixels();

    if ((armThumb == null) || (armOther == null) || (gapThumb == null) ||
      (gapIM == null) || (gapMR == null) || (gapRP == null)) {
      return false;
    }
    // Assert thumb is higher than the others
    if (gapThumb.y > gapIM.y) return false;
    return false;
  }

  public void nullLandmarks()
  {
    armThumb = null;
    armOther = null;
    gapThumb = null;
    gapIM = null;
    gapMR = null;
    gapRP = null;
  }

  private void findArmLandmarks()
  {
    println("Finding arm landmarks");
    int x;
    int y = 0;
    int dy = 0;
    // Go from right until a column has any foreground.
    // I don't think this loop will ever execute more than once, making sure though.
    for (x = w-1; x > 0; x--)
    {
      y = findNextForeground(x, 0);
      if (y != -1) break;
    }
    while (dy < minArmThickness && y != -1)
    {
      armThumb = new PVector(x, y);
      y = findNextBackground(x, y);
      if (y == -1) return;
      armOther = new PVector(x, y);
      dy = (int)(armOther.y - armThumb.y);
      y = findNextForeground(x, y);
    }
  }

  private void findGapLandmarks()
  {
    println("Finding gap landmarks");
    // Find four landmarks in order of appearance from right to left
    ArrayList<PVector> foundGaps = new ArrayList<PVector>();
    for (int x = w; x > 0; x--)
    {
      // Gaps go from foreground to background to foreground
      int y = findNextForeground(x, 0);
      while (true)
      {
        y = findNextBackground(x, y + minFingerThickness);
        y = findNextForeground(x, y);
        if (y == -1) break;
        y--; // go back up to the background
        if (!acceptGap(x, y)) {
          image.pixels[y * w + x] = color(1); // Isolated black pixels aren't actually background
        } else {
          if (!infringingOtherGaps(x, y, foundGaps)) {
            foundGaps.add(new PVector(x, y));
            image.pixels[y * w + x] = color(0, 0, 255);
          }
        }
        y += 10;
      }
      // We only use the first four gaps
      if (foundGaps.size() >= 4) break;
    }

    if (foundGaps.size() < 4) return;
    // Rightmost is always the thumb gap
    gapThumb = foundGaps.remove(0);
    // Manual sorting... Because java straight up refuses my Comparator<PVector>.
    /*List<PVector> sortedList = new ArrayList<PVector>();
     sortedList.add(foundGaps.remove(0));
     PVector v2 = foundGaps.remove(0);
     //if (v2 <*/
    java.util.Collections.sort(foundGaps, new GapYComparer());
    gapIM = foundGaps.remove(0);
    gapMR = foundGaps.remove(0);
    gapRP = foundGaps.remove(0);
  }

  private boolean isIsolatedBackground(int x, int y)
  {
    // It's valid if there's an adjacent background pixel
    return
      isForeground(image, max(y-1, 0)   * w + x) &&
      isForeground(image, min(y+1, h-1) * w + x) &&
      isForeground(image, min(y+1, h-1) * w + max(x-1, 0)) &&
      //isForeground(image, y * w + min(x+1,w-1)) &&
      isForeground(image, y * w + max(x-1, 0)  );
    // Note: This treats image borders as background.
  }

  private boolean acceptGap(int x, int y)
  {
    int nextBackground = findNextBackground(x, y+1);
    if (nextBackground == -1) nextBackground = h;
    if ((nextBackground - y) < minFingerThickness) return false;

    if ((x == 0) || (y <= 1) || (x >= w-5) || (y == h-1)) return false;
    if (isBackground(image, y * w + x) &&
      isBackground(image, y * w + x-1) &&
      isBackground(image, (y-1) * w + x-1) &&
      isBackground(image, (y-1) * w + x)) return true;
    for (int i = 1; i < 4; i++) {
      if (isForeground(image, y * w + x-i)) return false;
    }
    return true;
  }

  private boolean infringingOtherGaps(int x, int y, ArrayList<PVector> foundGaps)
  {
    for (PVector gap : foundGaps)
    {
      if (abs(gap.y - y) < gapExclusionHeight * h) {
        return true;
      }
    }
    return false;
  }

  private int findNextForeground(int x, int startRow)
  {
    if (startRow == -1) return -1; 
    for (int y = startRow; y < h-1; y++)
    {
      if (isForeground(image, y * w + x)) {
        return y;
      }
    }
    return -1;
  }

  private int findNextBackground(int x, int startRow)
  {
    if (startRow == -1) return -1; 
    for (int y = startRow; y < h-1; y++)
    {
      if (isBackground(image, y * w + x)) {
        return y;
      }
    }
    return -1;
  }
  
  PVector Mh, Mt, Mw, Ot, Oo, Et, It, Ip;
  
  void calculateCorners()
  {
    Mw = PVector.add(armThumb, armOther).mult(0.5);
    Mt = PVector.add(gapIM, gapThumb).mult(0.5);
    Mh = PVector.add(gapRP, gapThumb).mult(0.5);
    Oo = PVector.add(gapRP, PVector.sub(gapRP, gapMR));
    Ot = PVector.add(gapIM, PVector.sub(gapIM, gapMR)); //temp
    
    Ip = intersectEnds(Mw, gapMR, armOther, Mt);
    It = intersectDirections(Mh, PVector.sub(gapIM, gapMR), armOther, PVector.sub(armOther, Mt));
    
    Et = intersectEnds(Mh, It, gapThumb, Ot);
  }
  
  PVector intersectEnds(PVector a, PVector aEnd, PVector b, PVector bEnd)
  {
    PVector da = PVector.sub(aEnd, a);
    PVector db = PVector.sub(bEnd, b);
    return intersectDirections(a, da, b, db);
  }
  
  PVector intersectDirections(PVector a, PVector da, PVector b, PVector db)
  {
    float parallelRate = da.x * db.y - da.y * db.x;
    println("Parallel: ", parallelRate);
    println(da, db);
    if (abs(parallelRate) < EPSILON) return new PVector(a.x, a.y);
    if (abs(db.y) > EPSILON) {
      float x = (b.x - a.x + db.x/db.y * (a.y - b.y)) / parallelRate * db.y;
      return PVector.add(a, da.mult(x));
    }
    if (abs(db.x) > EPSILON) {
      float x = -(b.y - a.y + db.y/db.x * (a.x - b.x)) / parallelRate * db.x;
      return PVector.add(a, da.mult(x));
    }
    // Well if both are (almost) zero then there's nothing to intersect, duh.
    return new PVector(a.x, a.y);
  }

  public void drawImpl(PGraphics g)
  {
    g.image(image, 0, 0);
    g.stroke(255, 0, 0);
    g.strokeWeight(1);
    g.noFill();
    drawIndicator(g, armThumb);
    drawIndicator(g, armOther);
    drawIndicator(g, gapThumb);
    drawIndicator(g, gapIM);
    drawIndicator(g, gapMR);
    drawIndicator(g, gapRP);
    
    g.stroke(0, 127, 255);
    g.line(armOther.x, armOther.y, Mw.x, Mw.y);
    g.line(Mw.x, Mw.y, Ip.x, Ip.y);
    g.line(Ip.x, Ip.y, It.x, It.y);
    g.line(It.x, It.y, Et.x, Et.y);
    g.line(Et.x, Et.y, Ot.x, Ot.y);
    g.line(Ot.x, Ot.y, gapMR.x, gapMR.y);
    g.line(gapMR.x, gapMR.y, Oo.x, Oo.y);
    g.line(Oo.x, Oo.y, armOther.x, armOther.y);
    g.stroke(0, 0, 255);
    drawIndicator(g, Ip, "Ip");
    drawIndicator(g, Mt, "Mt");
    drawIndicator(g, Mw, "Mw");
  }

  public void drawIndicator(PGraphics g, PVector p)
  {
    drawIndicator(g, p, null);
  }
  public void drawIndicator(PGraphics g, PVector p, String text)
  {
    if (p == null) return;
    g.ellipse(p.x, p.y, 10, 10);
    if (text != null) g.text(text, p.x+6, p.y+20);
  }
}

static public class GapYComparer implements Comparator<PVector>
{
  public int compare(PVector v1, PVector v2)
  {
    float d = v1.y - v2.y;
    return (d > 0 ? 1 : (d < 0 ? -1 : 0));
  }
}