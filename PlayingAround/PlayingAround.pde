import java.nio.*; //<>//
 
float v = 1.0 / 9.0;
float[][] kernel = {{ v, v, v }, 
                    { v, v, v }, 
                    { v, v, v }};
                    
PImage img;

FileSelectorBar fileSelection = new FileSelectorBar(new File("D:/PSHands/"), 0);


float zoom = 0.9f;
float panX = 0;
float panY = 0;

void setup() {
  size(2048, 1400, P2D);
  noLoop();
  
  openFile();
  
  // Crisp pixels pls
  hint(DISABLE_TEXTURE_MIPMAPS);
  ((PGraphicsOpenGL)g).textureSampling(2);
} 

void draw() {
  background(0);
  if (img != null)
  {
    pushMatrix();
    translate(panX, panY);
    scale(zoom);
    
    image(img, 0, 0); // Displays the image from point (0,0) 
    popMatrix();
  }
  
  fileSelection.draw();
}

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

void mouseClicked()
{
  fileSelection.handleClick(mouseX, mouseY);
  openFile();
}

void openFile()
{
  String path = fileSelection.getFile().getPath();
  if (path.endsWith(".mat")) {
    loadAlbedo(path);
  } else {
    img = loadImage(path);
  }
  redraw();
}

DoubleBuffer getMatDoubles(String path)
{
  byte[] matData = loadBytes(path);
  return ByteBuffer.wrap(matData, 420 * 8, 2048 * 2048 * 8).order(ByteOrder.LITTLE_ENDIAN).asDoubleBuffer();
}

void loadAlbedo(String path)
{
  loadAlbedo(path, 0.0, 1.0);
}
  
void loadAlbedo(String path, double offset, double scale)
{
  DoubleBuffer db = getMatDoubles(path);
  
  img = createImage(2048, 2048, RGB);
  img.loadPixels();
  for (int i = 0; i < sq(2048); i++)
  {
    // TODO: Color scales based on file name
    //color c = color((int)(255 * (db.get() + offset) / scale));
    color c = getColor((float)db.get());
    img.pixels[i] = c;
  }
  img.updatePixels();
}

color getColor(float value) {
  colorMode(HSB, 1.0f);
  color c = color(value / 2, 1.0f, abs(value));
  colorMode(RGB, 255);
  return c;
}

void mouseWheel(MouseEvent event)
{
  zoom(event.getCount());
  redraw();
}

void zoom(float distance)
{
  float newZoom = zoom * pow(0.9, distance);
  PVector centre = new PVector(mouseX, mouseY);
  PVector pan = new PVector(panX, panY);
  PVector diff = PVector.sub(pan, centre).mult(newZoom/zoom);
  PVector newPan = PVector.add(centre, diff);
  panX = newPan.x; //<>//
  panY = newPan.y;
  zoom = newZoom;
}


void mouseDragged()
{
  panX -= pmouseX - mouseX;
  panY -= pmouseY - mouseY;
  redraw();
}