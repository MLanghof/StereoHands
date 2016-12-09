class HandProcessor
{
  Take currentTake;
  
  PImage img;


  public SimpleSelectorBar stepSelector = new SimpleSelectorBar(1, 0);
  public FileSelectorBar fileSelector = new FileSelectorBar(new File("D:/PSHands/"), 50);

  ArrayList<Step> steps = new ArrayList<Step>();
  
  public HandProcessor()
  {
    openFile();
    steps.add(new AlbedoStep(currentTake));
    steps.add(new ShapeIndexStep(currentTake));
    steps.add(new NormalsStep(currentTake));
    steps.add(new FlowStep(steps.get(1)));
    stepSelector.max = steps.size();
  }

  public PImage getCurrentImage()
  {
    return currentTake.shapeIndex;
    //return img;
  }
  
  public void drawUI()
  {
    stepSelector.draw();
    fileSelector.draw();
  }
  
  public void drawImage()
  {
    getCurrentStep().draw();
  }
  
  public void handleClick(int x, int y)
  {
    if (stepSelector.handleClick(mouseX, mouseY)) {
      redraw();
    }
    if (fileSelector.handleClick(mouseX, mouseY)) {
      openFile();
    }
  }
  
  void openFile()
  {
    //img = new ImageLoader().openFile(fileSelector.getFile().getPath());
    currentTake = new Take(fileSelector.getFile().getPath());
    
    redraw();
  }
  
  Step getCurrentStep()
  {
    return steps.get(stepSelector.getCurrent());
  }
  
  
 
  float v = 1.0 / 9.0;
  float[][] kernel = {{ v, v, v }, 
                      { v, v, v }, 
                      { v, v, v }};
  
  void convolute()
  {
    img.loadPixels();
  
    // Create an opaque image of the same size as the original
    PImage edgeImg = createImage(img.width, img.height, RGB);
  
    // Loop through every pixel in the image
    for (int y = 1; y < img.height-1; y++) {   // Skip top and bottom edges
      for (int x = 1; x < img.width-1; x++) {  // Skip left and right edges
        float sum = 0; // Kernel sum for this pixel
        for (int ky = -1; ky <= 1; ky++) {
          for (int kx = -1; kx <= 1; kx++) {
            // Calculate the adjacent pixel for this kernel point
            int pos = (y + ky)*img.width + (x + kx);
            // Image is grayscale, red/green/blue are identical
            float val = red(img.pixels[pos]);
            // Multiply adjacent pixels based on the kernel values
            sum += kernel[ky+1][kx+1] * val;
          }
        }
        // For this pixel in the new image, set the gray value
        // based on the sum from the kernel
        edgeImg.pixels[y*img.width + x] = color(sum);
      }
    }
    // State that there are changes to edgeImg.pixels[]
    edgeImg.updatePixels();
  }
}