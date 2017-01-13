

class FlowFinder extends CalculationStep
{
  RidgeDetector ridger;
  
  float[] flowAngle;
  float[] flowMag;

  // Kernel is applied with this spacing
  final int d = 2;

  int wd, hd;

  public FlowFinder(Step below)
  {
    super(below.take);
    ridger = new RidgeDetector();
    ridger.input = this;
  }

  public void allocateResources()
  {
    wd = (w - s) / d;
    hd = (h - s) / d;
    flowAngle = new float[wd * hd];
    flowMag = new float[wd * hd];
  }

  public void calculateImpl()
  {
    for (int y = 0; y < hd; y++) {
      for (int x = 0; x < wd; x++)
      {
        Ridge ridge = ridger.findRidgeAt(x*d + s/2, y*d + s/2);

        flowAngle[y * wd + x] = ridge.heading() + HALF_PI;
        flowMag[y * wd + x] = ridge.mag() * d/s;
      }
    }
  }

  void drawImpl(PGraphics g)
  {
    g.image(take.shapeIndex, 0, 0);
    if (!(keyPressed && (keyCode == KeyEvent.VK_SHIFT)))
    {
      g.pushMatrix();
      g.translate(s/2, s/2);
      g.scale(d, d);
      g.stroke(color(255, 0, 0));
      g.strokeWeight(1 / 10.0);
      for (int y = screenStartY() / d; y < screenEndY() / d; y++) {
        for (int x = screenStartX() / d; x < screenEndX() / d; x++)
        {
          if (x >= wd || y >= hd) continue; // FIXME?
          float angle = flowAngle[y*wd + x];
          float mag = flowMag[y*wd + x];
          float dx = cos(angle) * mag / 8;
          float dy = sin(angle) * mag / 8;
          g.line(x - dx * 10, y - dy * 10, x + dx * 10, y + dy * 10);
          g.line(x - dy, y + dx, x + dy, y - dx);
        }
      }
      g.popMatrix();
    }
  }
}


class FeatureStep extends CalculationStep
{
  RidgeDetector ridger;
  
  PImage modified;
  ArrayList<Feature> features;

  // Features are searched with this spacing
  // d=1 is almost indistinguishable but way more work than d=2
  // d=4 is noticably worse but also MUCH faster
  final int d = 4;
  
  final int s;
  
  int wd, hd;
  
  public FeatureStep(Step below)
  {
    super(below.take);
    ridger = new RidgeDetector();
    ridger.input = this;
    s = ridger.s;
  }

  public void allocateResources()
  {
    wd = (w - s) / d;
    hd = (h - s) / d;
    modified = createImage(w, h, RGB);
    features = new ArrayList<Feature>();
  }
  
  public void calculateImpl()
  {
    modified.loadPixels();
    for (int yd = 0; yd < hd; yd++) {
      for (int xd = 0; xd < wd; xd++)
      {
        int x = xd*d + s/2;
        int y = yd*d + s/2;
        Extracted ex = ridger.getRawFeatureAt(x, y);
        
        Feature f = featureMeMaybe(x, y, ex);
        if (f != null) {
          features.add(new Feature(x, y, ex.ridge1, ex.ridge2));
        }
        
        for (int ydd = 0; ydd < d; ydd++) {
          for (int xdd = 0; xdd < d; xdd++) {
            int pos = (y + ydd) * w + x + xdd;
            modified.pixels[pos] = color(ridger.getAmplitudeAt(ex.out(), xdd + s/2, ydd + s/2));
          }
        }
      }
    }
    modified.updatePixels();
  }
  
  void drawImpl(PGraphics g)
  {
    g.image(modified, 0, 0);
    if (!(keyPressed && (keyCode == KeyEvent.VK_SHIFT)))
    {
      g.strokeWeight(d / 20.0);
      for (Feature f : features)
      {
        if (!onScreen(f.x, f.y, g)) continue;
        if (!(keyPressed && (key == '2'))) {
          g.stroke(0, 0, 200);
          drawFlowIndicator(g, f.x, f.y, f.ridge.strength() * d, f.ridge.angle());
        }
        if (!(keyPressed && (key == '1'))) {
          g.stroke(200, 0, 0);
          drawFlowIndicator(g, f.x, f.y, f.wrinkle.strength() * d, f.wrinkle.angle());
        }
      }
    }
  }
}

/*class WrinkleAngleStep extends CalculationStep
{
  RidgeDetector ridger;
  
  final int s;
  
  public WrinkleAngleStep(Step below)
  {
    super(below.take);
    ridger = new RidgeDetector();
    ridger.input = this;
    s = ridger.s;
  }
  
}*/


class FlowStep extends CalculationStep
{
  SmoothNormalsStep below;
  //PVector[] flow;
  float[] flowAngle;
  float[] flowMag;
  
  int k = 3;
  
  public FlowStep(SmoothNormalsStep below)
  {
    super(below.take);
    this.below = below;
  }
  
  public void allocateResources()
  {
    flowAngle = new float[w * h];
    flowMag = new float[w * h];
  }
  
 
  float v = 1.0 / 9.0;
  /*float[][] kernel = {{ 0, -1, 0 }, 
                      { 1, 0, 1 }, 
                      { 0, -1, 0 }};/**/
  float[][] kernel = {{ 0, 0, 0 }, 
                      { 1, 0, 0 }, 
                      { 0, 0, 0 }};/**/
                      
                      
  void calculateImpl()
  {
    below.calculate();
    // Loop through every pixel in the image
    for (int y = k; y < h-k; y++) {   // Skip top and bottom edges
      for (int x = k; x < w-k; x++) {  // Skip left and right edges
        PVector sum = new PVector(0, 0); // Kernel sum for this pixel
        int pos0 = y * w + x;
        PVector n0 = below.normals[pos0];
        for (int ky = -k; ky <= k; ky++) {
          for (int kx = -k; kx <= k; kx++) {
            // Calculate the adjacent pixel for this kernel point
            int pos = (y + ky)*w + (x + kx);
            PVector diff = PVector.sub(below.normals[pos], n0);
            diff.z = 0;
            
            if (sum.dot(diff) < 0) {
              diff.mult(-1);
            }
            //sum.add(PVector.mult(diff, kernel[kx+k][ky+k]));
            sum.add(diff);
          }
        }/**/
        
        flowAngle[pos0] = atan2(sum.y, sum.x) + HALF_PI;//color(sum);
        flowMag[pos0] = sum.mag() / sq(2 * k + 1);
      }
    }
  }
  
  void drawImpl(PGraphics g)
  {
    int d = 1;
    below.drawOn(g);
    g.pushMatrix();
    g.translate(0.5, 0.5);
    g.stroke(color(0, 0, 255));
    g.strokeWeight(d / 20.0);
    for (int y = screenStartY(); y < screenEndY(); y += d) {
      for (int x = screenStartX(); x < screenEndX(); x += d)
      {
        float angle = flowAngle[y*w + x];
        float mag = flowMag[y*w + x];
        drawFlowIndicator(g, x, y, mag * 10 * d, angle);
      }
    }
    g.popMatrix();
  }
}


class SmoothNormalsStep extends CalculationStep
{
  Step below;
  
  PVector[] normals;
  
  int k = 5;
  
  public SmoothNormalsStep(Step below)
  {
    super(below.take);
    this.below = below;
  }
  
  public void allocateResources()
  {
    normals = new PVector[w * h];
    for (int i = 0; i < take.getArea(); i++) {
      normals[i] = take.normals[i].copy();
    }
  }
  
  public void calculateImpl()
  {
    // Loop through every pixel in the image
    for (int y = k; y < h - k; y++) {   // Skip top and bottom edges
      for (int x = k; x < w - k; x++)
      {
        int pos0 = y * w + x;
        PVector sum = new PVector(0, 0); // Kernel sum for this pixel
        PVector n0 = normals[pos0];
        for (int ky = -k; ky <= k; ky++) {
          for (int kx = -k; kx <= k; kx++) {
            int pos = (y + ky) * w + (x + kx);
            sum.add(take.normals[pos]);
          }
        }
        sum.mult(1.0 / sq(2*k+1));
        
        n0.sub(sum);
      }
    }
  }
  
  public void drawImpl(PGraphics g)
  {
    int d = 1;
    //below.drawOn(g);
    g.pushMatrix();
    g.translate(0.5, 0.5);
    g.stroke(color(255, 170, 0));
    g.strokeWeight(d / 20.0);
    
    println(screenStartY(), screenEndY(), screenStartX(), screenEndX());
    for (int y = screenStartY(); y < screenEndY(); y += d) {
      for (int x = screenStartX(); x < screenEndX(); x += d)
      {
        PVector n = normals[y*w + x];
        drawFlowIndicator(g, x, y, n.mag() * d * 8, n.heading());
      }
    }
    g.popMatrix();
  }
}

class DownsampleFlowStep extends CalculationStep
{
  FlowStep below;
  
  float[] flowAngle;
  float[] flowMag;
  
  // Downsample factor
  final int d = 16;
  
  // Flows above this are ignored when aggregating
  final float maxThreshold = 0.1;
  
  int wd, hd;
  
  public DownsampleFlowStep(FlowStep below)
  {
    super(below.take);
    this.below = below;
  }
  
  public void allocateResources()
  {
    wd = (w-1)/d;
    hd = (h-1)/d;
    flowAngle = new float[wd * hd];
    flowMag = new float[wd * hd];
  }
  
  public void calculateImpl()
  {
    below.calculate();
    for (int y = 0; y < hd; y += 1) {
      for (int x = 0; x < wd; x += 1)
      {
        int pos0 = y * wd + x;
        PVector sum = new PVector(0, 0);
        for (int ky = 0; ky <= d; ky++) {
          for (int kx = 0; kx <= d; kx++) {
            int pos = (y*d + ky) * w + (x*d + kx);
            if (below.flowMag[pos] < maxThreshold) {
              PVector add = PVector.fromAngle(below.flowAngle[pos]);
              if (sum.dot(add) < 0) {
                add.mult(-1);
              }
              add.mult(1.0/sq(d));
              sum.add(add);
            }
          }
        }
        
        flowAngle[pos0] = sum.heading();
        flowMag[pos0] = sum.mag() / d;
      }
    }
  }
  
  void drawImpl(PGraphics g)
  {
    below.drawOn(g);
    g.pushMatrix();
    g.translate(d/2, d/2);
    g.scale(d, d);
    g.stroke(color(0, 0, 255));
    g.strokeWeight(1 / 20.0);
    for (int y = screenStartY() / d; y < min(screenEndY() / d, hd); y++) {
      for (int x = screenStartX() / d; x < min(screenEndX() / d, wd); x++)
      {
        float mag = flowMag[y*wd + x];
        float angle = flowAngle[y*wd + x];
        drawFlowIndicator(g, x, y, mag * 10, angle);
      }
    }
    g.popMatrix();
  }
}


void drawFlowIndicator(PGraphics g, float x, float y, float mag, float angle)
{
  float dx = cos(angle) * mag;
  float dy = sin(angle) * mag;
  g.line(x - dx, y - dy, x + dx, y + dy);
  g.line(x - dy / 10, y + dx / 10, x + dy / 10, y - dx / 10);
}