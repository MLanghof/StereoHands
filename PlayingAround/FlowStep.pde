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
  
  public void setTake(Take take)
  {
    super.setTake(take);
    flowAngle = new float[w * h];
    flowMag = new float[w * h];
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
  
  public void setTake(Take take)
  {
    super.setTake(take);
    normals = new PVector[w * h];
    for (int i = 0; i < take.getArea(); i++) {
      normals[i] = take.normals[i].copy();
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
}

class DownsampleFlowStep extends CalculationStep
{
  FlowStep below;
  
  float[] flowAngle;
  float[] flowMag;
  
  final int s = 16;
  
  final float maxThreshold = 0.1;
  
  int ws, hs;
  
  public DownsampleFlowStep(FlowStep below)
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
    int d = 1;
    below.draw();
    pushMatrix();
    translate(0.5 + s/2, 0.5 + s/2);
    scale(s, s);
    stroke(color(0, 0, 255));
    strokeWeight(d / 20.0);
    for (int y = screenStartY() / s; y < screenEndY() / s; y += d) {
      for (int x = screenStartX() / s; x < screenEndX() / s; x += d)
      {
        float angle = flowAngle[y*ws + x];
        float mag = flowMag[y*ws + x];
        float dx = cos(angle) * d * mag;
        float dy = sin(angle) * d * mag;
        line(x - dx * 10, y - dy * 10, x + dx * 10, y + dy * 10);
        line(x - dy, y + dx, x + dy, y - dx);
      }
    }
    popMatrix();
  }
  
  public void calculateImpl()
  {
    below.calculate();
    for (int y = 0; y < hs; y += 1) {
      for (int x = 0; x < ws; x += 1)
      {
        int pos0 = y * ws + x;
        PVector sum = new PVector(0, 0);
        for (int ky = 0; ky <= s; ky++) {
          for (int kx = 0; kx <= s; kx++) {
            int pos = (y*s + ky) * w + (x*s + kx);
            if (below.flowMag[pos] < maxThreshold) {
              PVector add = PVector.fromAngle(below.flowAngle[pos]);
              if (sum.dot(add) < 0) {
                add.mult(-1);
              }
              add.mult(1.0/sq(s));
              sum.add(add);
            }
          }
        }
        
        flowAngle[pos0] = sum.heading();
        flowMag[pos0] = sum.mag() / s;
      }
    }
  }
}