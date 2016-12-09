class FlowStep extends CalculationStep
{
  Step below;
  //PVector[] flow;
  float[] flowAngle;
  
  public FlowStep(Step below)
  {
    super(below.take);
    this.below = below;
    //flow = new PVector[take.roi.width * take.roi.height];
    flowAngle = new float[take.roi.width * take.roi.height];
  }
  
  void drawImpl()
  {
    below.draw();
    stroke(color(0, 0, 255));
    strokeWeight(0.5);
    for (int y = 0; y < take.roi.height; y += 8) {
      for (int x = 0; x < take.roi.width; x += 8) {
        float angle = flowAngle[y*take.roi.width + x];
        float dx = cos(angle) * 4;
        float dy = sin(angle) * 4;
        line(x - dx, y - dy, x + dx, y + dy);
      }
    }
  }
  
 
  float v = 1.0 / 9.0;
  float[][] kernel = {{ 0, 1, 0 }, 
                      { 1, 0, -1 }, 
                      { 0, -1, 0 }};
                      
                      
  void calculate()
  {
    // Loop through every pixel in the image
    for (int y = 1; y < take.roi.height-1; y++) {   // Skip top and bottom edges
      for (int x = 1; x < take.roi.width-1; x++) {  // Skip left and right edges
        PVector sum = new PVector(0, 0); // Kernel sum for this pixel
        for (int ky = -1; ky <= 1; ky++) {
          for (int kx = -1; kx <= 1; kx++) {
            // Calculate the adjacent pixel for this kernel point
            int pos = (y + ky)*take.roi.width + (x + kx);
            sum.add(PVector.mult(take.normals[pos], kernel[kx+1][ky+1]));
            // Image is grayscale, red/green/blue are identical
            //float val = red(img.pixels[pos]);
            // Multiply adjacent pixels based on the kernel values
            //sum += kernel[ky+1][kx+1] * val;
          }
        }
        // For this pixel in the new image, set the gray value
        // based on the sum from the kernel
        flowAngle[y*take.roi.width + x] = atan2(sum.y, sum.x) + HALF_PI;//color(sum);
      }
    }
  }
}