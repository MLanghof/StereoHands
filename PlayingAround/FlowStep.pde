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
  
  void drawImpl()
  {
    int d = 1;
    below.draw();
    pushMatrix();
    translate(0.5, 0.5);
    stroke(color(0, 0, 255));
    strokeWeight(d / 20.0);
    for (int y = screenStartY(); y < screenEndY(); y += d) {
      for (int x = screenStartX(); x < screenEndX(); x += d)
      {
        float angle = flowAngle[y*w + x];
        float mag = flowMag[y*w + x];
        float dx = cos(angle) * d * mag;
        float dy = sin(angle) * d * mag;
        line(x - dx * 10, y - dy * 10, x + dx * 10, y + dy * 10);
        line(x - dy, y + dx, x + dy, y - dx);
      }
    }
    popMatrix();
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
  
  public void drawImpl()
  {
    int d = 1;
    //below.draw();
    pushMatrix();
    translate(0.5, 0.5);
    stroke(color(255, 170, 0));
    strokeWeight(d / 20.0);
    
    println(screenStartY(), screenEndY(), screenStartX(), screenEndX());
    for (int y = screenStartY(); y < screenEndY(); y += d) {
      for (int x = screenStartX(); x < screenEndX(); x += d)
      {
        PVector n = normals[y*w + x];
        float dx = n.x * d;
        float dy = n.y * d;
        line(x, y, x + dx * 8, y + dy * 8);
        line(x - dy, y + dx, x + dy, y - dx);
      }
    }
    popMatrix();
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
    wd = w/d;
    hd = h/d;
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
  
  void drawImpl()
  {
    below.draw();
    pushMatrix();
    translate(d/2, d/2);
    scale(d, d);
    stroke(color(0, 0, 255));
    strokeWeight(1 / 20.0);
    for (int y = screenStartY() / d; y < screenEndY() / d; y++) {
      for (int x = screenStartX() / d; x < screenEndX() / d; x++)
      {
        float angle = flowAngle[y*wd + x];
        float mag = flowMag[y*wd + x];
        float dx = cos(angle) * mag;
        float dy = sin(angle) * mag;
        line(x - dx * 10, y - dy * 10, x + dx * 10, y + dy * 10);
        line(x - dy, y + dx, x + dy, y - dx);
      }
    }
    popMatrix();
  }
}