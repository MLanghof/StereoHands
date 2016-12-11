
final int s = 8;

OpenCV cv = new OpenCV(this, s, s);

class DctStep extends CalculationStep
{
  PImage frequencies;
  
  final float maxThreshold = 0.1;
  
  int ws, hs;
  
  
  public DctStep(Step below)
  {
    super(below.take);
  }
  
  public void setTake(Take take)
  {
    super.setTake(take);
    ws = w/s;
    hs = h/s;
    frequencies = createImage(w, h, RGB);
  }
  
  void drawImpl()
  {
    image(frequencies, 0, 0);
  }
  
  public void calculateImpl()
  {
    Mat subMat = new Mat(s, s, CvType.CV_32FC1);
    frequencies.loadPixels();
    take.shapeIndex.loadPixels();
    for (int y = 0; y < h - s; y += s) {
      for (int x = 0; x < w - s; x += s)
      {
        for (int ys = 0; ys < s; ys++) {
          for (int xs = 0; xs < s; xs++) {
            int pos = (y + ys) * w + x + xs;
            subMat.put(ys, xs, take.shapeIndex.pixels[pos]);
          }
        }
        
        Core.dft(subMat, subMat);
        
        for (int ys = 0; ys < s; ys++) {
          for (int xs = 0; xs < s; xs++) {
            int pos = (y + ys) * w + x + xs;
            frequencies.pixels[pos] = color(log(-(float)subMat.get(ys, xs)[0]) * 10);
          }
        }
      }
      frequencies.updatePixels();
    }
  }
}
class FullDftStep extends CalculationStep
{
  PImage frequencies;
  
  int m;
  
  public FullDftStep(Step below)
  {
    super(below.take);
  }
  
  public void setTake(Take take)
  {
    super.setTake(take);
    m = max(h, w);
    m += m % 2;
    frequencies = createImage(m, m, RGB);
  }
  
  void drawImpl()
  {
    image(frequencies, 0, 0);
  }
  
  public void calculateImpl()
  {
    Mat mat = new Mat(m, m, CvType.CV_32FC1);
    Mat matI = Mat.zeros(m, m, CvType.CV_32FC1);
    take.shapeIndex.loadPixels();
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++)
      {
        mat.put(y, x, take.shapeIndex.pixels[y * w + x]);
      }
    }
    java.util.List<Mat> mv = new ArrayList<Mat>();
    mv.add(mat); mv.add(matI);
    Mat mats = new Mat();
    Core.merge(mv, mats);
    Core.dft(mats, mats);
    Core.split(mats, mv);
    mat = mv.get(0);
    matI = mv.get(1);
    Mat mag = new Mat();
    Core.magnitude(mat, matI, mag);
    
    float min = 0;
    float max = 0;
    for (int y = 0; y < m; y++) {
      for (int x = 0; x < m; x++)
      {
        float val = log(1.0 + (float)mag.get(y, x)[0]);
        min = min(val, min);
        max = max(val, max);
      }
    }
    
    frequencies.loadPixels();
    for (int y = 0; y < m; y++) {
      for (int x = 0; x < m; x++)
      {
         frequencies.pixels[y * m + x] = color(map(log(1.0 + (float)mag.get(y, x)[0]), min, max, 0, 255));
      }
    }
    frequencies.updatePixels();
  }
}

class FullDctStep extends CalculationStep
{
  PImage frequencies;
  
  int m;
  
  public FullDctStep(Step below)
  {
    super(below.take);
  }
  
  public void setTake(Take take)
  {
    super.setTake(take);
    m = max(h, w);
    m += m % 2;
    frequencies = createImage(m, m, RGB);
  }
  
  void drawImpl()
  {
    image(frequencies, 0, 0);
  }
  
  public void calculateImpl()
  {
    Mat mat = new Mat(m, m, CvType.CV_32FC1);
    take.shapeIndex.loadPixels();
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++)
      {
        mat.put(y, x, take.shapeIndex.pixels[y * w + x]);
      }
    }
    Core.dct(mat, mat);
    
    float min = 0;
    float max = 0;
    for (int y = 0; y < m; y++) {
      for (int x = 0; x < m; x++)
      {
        float val = (float)mat.get(y, x)[0];
        min = min(val, min);
        max = max(val, max);
      }
    }
    
    frequencies.loadPixels();
    for (int y = 0; y < m; y++) {
      for (int x = 0; x < m; x++)
      {
         frequencies.pixels[y * m + x] = color(map((float)mat.get(y, x)[0], min, max, 0, 255));
      }
    }
    frequencies.updatePixels();
  }
}