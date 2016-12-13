
// Window size of dct sampling
final int s = 16;

final float maxRidgeInterval = 7; // Maximum pixel distance between ridge tops that is considered a ridge
final float minRidgeFrequency = 1.0 / maxRidgeInterval;
// s / 2 periods in s -> f = 1/2    -> mag = s;
// 1 / 2 periods in s -> f = 1/(2s) -> mag = 1;
// -> mag = f * 2s
final float minDctMag = minRidgeFrequency * 2 * s;

final float minRidgeInterval = 2 * sqrt(2);
final float maxRidgeFrequency = 1.0 / minRidgeInterval;
final float maxDctMag = maxRidgeFrequency * 2 * s;

// This is necessary to actually load the OpenCV library
OpenCV cv = new OpenCV(this, s, s);

class DctStep extends CalculationStep
{
  PImage frequencies;
  
  // Spacing between DCTs.
  int d = 2;
  
  public DctStep(Step below)
  {
    super(null); // Polymorphy is fun >_>
    setTake(below.take);
  }
   //<>//
  public void setTake(Take take)
  {
    super.setTake(take);
    frequencies = createImage(w * s / d, h * s / d, RGB); //<>//
  }
  
  void drawImpl()
  {
    scale((float)d / s);
    image(frequencies, 0, 0);
  }
  
  public void calculateImpl()
  {
    Mat subMat = new Mat(s, s, CvType.CV_32FC1);
    frequencies.loadPixels();
    take.shapeIndex.loadPixels();
    for (int y = 0; y < h - s; y += d) {
      for (int x = 0; x < w - s; x += d)
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
            int pos = (y * s/d + (ys + s/2) % s) * w * s/d + x * s/d + xs;
            frequencies.pixels[pos] = color(sqrt(abs((float)subMat.get(ys, xs)[0] / dc)) * 255);
          }
        }
        frequencies.pixels[(y * s/d + s/2) * w * s/d + x * s/d] = color(255, 0, 0);
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
  
  int d;
  
  int wd, hd;
  
  public FlowFromDctStep(DctStep below)
  {
    super(null);
    this.below = below;
    d = below.d;
    setTake(below.take);
  }
  
  public void setTake(Take take)
  {
    super.setTake(take);
    wd = w / d;
    hd = h / d;
    flowAngle = new float[wd * hd];
    flowMag = new float[wd * hd];
  }
  
  void drawImpl()
  {
    //below.draw();
    image(take.shapeIndex, 0, 0);
    pushMatrix();
    translate(d/2, d/2);
    int p = d;
    scale(p, p);
    stroke(color(255, 0, 0));
    strokeWeight(1 / 10.0);
    for (int y = screenStartY() / p; y < screenEndY() / p; y++) {
      for (int x = screenStartX() / p; x < screenEndX() / p; x++)
      {
        float angle = flowAngle[y*wd + x];
        float mag = flowMag[y*wd + x];
        float dx = cos(angle) * mag / 5;
        float dy = sin(angle) * mag / 5;
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
    for (int y = 0; y < hd; y += 1) {
      for (int x = 0; x < wd; x += 1)
      {
        float max = 0;
        PVector maxLoc = new PVector();
        
        for (int ys = 0; ys < s; ys++) {
          for (int xs = 0; xs < s; xs++) {
            int pos = (y*s + ys) * w * s/d + x*s + xs;
            color c = below.frequencies.pixels[pos];
            if (c == color(255, 0, 0)) continue;
            PVector v = new PVector(xs, ys - s/2);
            if (v.mag() <= minDctMag) continue;
            if (v.mag() >= maxDctMag) continue;
            float strength = red(c) * sqrt(v.mag() / s);
            if (strength > max) {
              max = strength;
              maxLoc = v;
            }
          }
        }
        
        flowAngle[y * wd + x] = maxLoc.heading() + HALF_PI;
        flowMag[y * wd + x] = maxLoc.mag() * d/s * max / 255.0;
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