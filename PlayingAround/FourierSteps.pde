
final int s = 8;

OpenCV cv = new OpenCV(this, s, s);

class DctStep extends CalculationStep
{
  PImage frequencies;
  
  public DctStep(Step below)
  {
    super(below.take);
  }
  
  public void setTake(Take take)
  {
    super.setTake(take);
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
        
        float dc = abs((float)subMat.get(0, 0)[0]);
        for (int ys = 0; ys < s; ys++) {
          for (int xs = 0; xs < s; xs++) {
            int pos = (y + (ys + s/2) % s) * w + x + xs;
            frequencies.pixels[pos] = color(sqrt(abs((float)subMat.get(ys, xs)[0] / dc)) * 255);
          }
        }
        frequencies.pixels[(y + s/2) * w + x] = color(255, 0, 0);
      }
      frequencies.updatePixels();
    }
  }
}

class FlowFromDctStep extends CalculationStep
{
  DctStep below;
  
  float[] flowAngle;
  float[] flowMag;
  
  int ws, hs;
  
  public FlowFromDctStep(DctStep below)
  {
    super(below.take);
    this.below = below;
  }
  
  public void setTake(Take take)
  {
    super.setTake(take);
    ws = w/s;
    hs = h/s;
    flowAngle = new float[ws * hs];
    flowMag = new float[ws * hs];
  }
  
  void drawImpl()
  {
    //below.draw();
    image(take.shapeIndex, 0, 0);
    pushMatrix();
    translate(0.5 + s/2, 0.5 + s/2);
    scale(s, s);
    stroke(color(0, 0, 255));
    strokeWeight(1 / 20.0);
    for (int y = screenStartY() / s; y < screenEndY() / s; y++) {
      for (int x = screenStartX() / s; x < screenEndX() / s; x++)
      {
        float angle = flowAngle[y*ws + x];
        float mag = flowMag[y*ws + x];
        float dx = cos(angle) * mag / 10;
        float dy = sin(angle) * mag / 10;
        line(x - dx * 10, y - dy * 10, x + dx * 10, y + dy * 10);
        line(x - dy, y + dx, x + dy, y - dx);
      }
    }
    popMatrix();
  }
  
  public void calculateImpl()
  {
    below.calculate();
    below.frequencies.loadPixels();
    for (int y = 0; y < hs; y += 1) {
      for (int x = 0; x < ws; x += 1)
      {
        float max = 0;
        PVector maxLoc = new PVector();
        
        for (int ys = 0; ys < s; ys++) {
          for (int xs = 0; xs < s; xs++) {
            int pos = (y*s + ys) * w + x*s + xs;
            color c = below.frequencies.pixels[pos];
            if (c == color(255, 0, 0)) continue;
            PVector v = new PVector(xs, ys - s/2);
            //if (v.mag() < 3) continue;
            if (red(c) > max) {
              max = red(c);
              maxLoc.x = xs;
              maxLoc.y = ys - s/2;
            }
          }
        }
        
        flowAngle[y * ws + x] = maxLoc.heading() + HALF_PI;
        flowMag[y * ws + x] = maxLoc.mag() / s * max / 255.0;
      }
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
    println(min, max);
    
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