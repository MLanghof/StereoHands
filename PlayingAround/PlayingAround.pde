import java.nio.*; //<>//
 
float v = 1.0 / 9.0;
float[][] kernel = {{ v, v, v }, 
                    { v, v, v }, 
                    { v, v, v }};
                    
PImage img;

SelectorBar subjectSelector, lightSelector, trialSelector, dataSelector;

File root = new File("D:/PSHands/");
File[] subjectFolders = root.listFiles(); 
File[] lightFolders, trialFolders, dataFiles;
File currentFile;


void setup() {
  size(2048, 2048);
  noLoop();
  
  subjectSelector = new SelectorBar(subjectFolders.length, 0);
  lightSelector = new SelectorBar(0, subjectSelector.HEIGHT);
  trialSelector = new SelectorBar(0, lightSelector.Y + lightSelector.HEIGHT);
  subjectSelector.max = subjectFolders.length;
  
  openSubject();
} 

void draw() {
  if (img == null) return;
  image(img, 0, 0); // Displays the image from point (0,0) 
  
  subjectSelector.draw();
  lightSelector.draw();
  trialSelector.draw();
  
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

void mouseClicked()
{
  if (subjectSelector.handleClick(mouseX, mouseY)) {
    openSubject();
  }
  if (lightSelector.handleClick(mouseX, mouseY)) {
    openLight();
  }
  if (trialSelector.handleClick(mouseX, mouseY)) {
    opentrial();
  }
}

void openSubject()
{
  File subjectFolder = subjectFolders[subjectSelector.selected];
  lightFolders = subjectFolder.listFiles();
  lightSelector.max = lightFolders.length;
  
  openLight();
}

void openLight()
{
  File lightFolder = lightFolders[lightSelector.selected];
  trialFolders = lightFolder.listFiles();
  trialSelector.max = trialFolders.length;
  
  opentrial();
}

void opentrial()
{
  File trialFolder = trialFolders[trialSelector.selected];
  
  // TODO: async
  if (lightSelector.selected == 0) {
    loadAlbedo(trialFolder.getPath() + "/a.mat", 0.0, 1.1);
  } else {
    img = loadImage(trialFolder.getPath() + "/si.bmp");
    //loadAlbedo(trialFolder.getPath() + "/px.mat", 1.0, 2.0);
  }
  redraw();
}

// byte[] matData;

DoubleBuffer getMatDoubles(String path)
{
  byte[] matData = loadBytes(path);
  return ByteBuffer.wrap(matData, 420 * 8, 2048 * 2048 * 8).order(ByteOrder.LITTLE_ENDIAN).asDoubleBuffer();
}
  
  
void loadAlbedo(String path, double offset, double scale)
{
  DoubleBuffer db = getMatDoubles(path);
  
  img = createImage(2048, 2048, RGB);
  img.loadPixels();
  for (int i = 0; i < sq(2048); i++)
  {
    color c = color((int)(255 * (db.get() + offset) / scale));
    img.pixels[i] = c;
  }
  img.updatePixels();
}


/*
    long a = 0;
    a |= 0x00000000000000FFL & ((long)(data[i]));
    a |= 0x000000000000FF00L & ((long)(data[i+1]) << 8);
    a |= 0x0000000000FF0000L & ((long)(data[i+2]) << 16);
    a |= 0x00000000FF000000L & ((long)(data[i+3]) << 24);
    a |= 0x000000FF00000000L & ((long)(data[i+4]) << 32);
    a |= 0x0000FF0000000000L & ((long)(data[i+5]) << 40);
    a |= 0x00FF000000000000L & ((long)(data[i+6]) << 48);
    a |= 0xFF00000000000000L & ((long)(data[i+7]) << 56);
    color c = color((int)(255 * Double.longBitsToDouble(a)));
    img.pixels[(i - start) / 8] = c;
    /*long b = 0;
    b |= 0xFF00000000000000L & ((long)(data[i]) << 56);
    b |= 0x00FF000000000000L & ((long)(data[i+1]) << 48);
    b |= 0x0000FF0000000000L & ((long)(data[i+2]) << 40);
    b |= 0x000000FF00000000L & ((long)(data[i+3]) << 32);
    b |= 0x00000000FF000000L & ((long)(data[i+4]) << 24);
    b |= 0x0000000000FF0000L & ((long)(data[i+5]) << 16);
    b |= 0x000000000000FF00L & ((long)(data[i+6]) << 8);
    b |= 0x00000000000000FFL & ((long)(data[i+7]));*/
    
    /*print("a: " + a + " --- " + Long.toBinaryString(a) + " --- ");
    println(Double.longBitsToDouble(a));*/
    /*print("b: " + b + " --- " + Long.toBinaryString(b) + " --- ");
    println(Double.longBitsToDouble(b));*/