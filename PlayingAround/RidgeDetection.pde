import java.awt.event.KeyEvent;

class RidgeDetector
{
  // Filter kernel (DFT window) size
  final int s = 16;
  
  // Image to process
  Step input;
  
  // Matrix storing data in window, used for dft
  Mat subMat, complexMat;
  
  boolean eliminateLowStrength = true; 
  // Amplitude threshold for accepting a maximum strength amplitude as ridge.
  float minRidgeStrength = 1500;
  
  public RidgeDetector()
  {
    subMat = new Mat(s, s, CvType.CV_32FC1);
  }
  
  public Ridge findRidgeAt(int x, int y)
  {
    complexMat = getFrequencySpaceAt(x, y);
    Ridge ridge = findPotentialRidge(complexMat, true);
    // TODO: If there's a stronger signal with lower than allowed frequency, check if it's in the same direction
    //         if yes: discard (just harmonics of a wrinkle or main line)
    
    if (eliminateLowStrength && (ridge.response.mag() < minRidgeStrength)) {
      ridge.response.mult(0);
      ridge.mult(0);
    }
    return ridge;
  }
  
  Mat getFrequencySpaceAt(int x, int y)
  {
    fillSubmatAround(x, y, subMat);
    Mat frequencyMat = new Mat();
    Core.dft(subMat, frequencyMat, Core.DFT_COMPLEX_OUTPUT, 0);
    return frequencyMat;
  }
  
  // Assumes the subMat to be properly set up.
  void fillSubmatAround(int x, int y, Mat subMat)
  {
    for (int ys = -s/2; ys < s/2; ys++) {
      for (int xs = -s/2; xs < s/2; xs++) {
        int pos = (y + ys) * input.w + x + xs;
        subMat.put(ys + s/2, xs + s/2, red(input.take.shapeIndex.pixels[pos]));
      }
    }
  }
  
  Ridge findPotentialRidge(Mat mat, boolean boundsCheck)
  {
    PVector maxReponse = new PVector();
    PVector maxLoc = new PVector();

    for (int ys = 0; ys < s; ys++) {
      for (int xs = 0; xs < s; xs++)
      {
        if ((xs == 0) && (ys == 0)) continue; // Not interested in dc component
        
        PVector complexF = new PVector((xs + s/2) % s - s/2, (ys + s/2) % s - s/2);
        if (boundsCheck && (complexF.mag() <= minDctMag)) continue;
        if (boundsCheck && (complexF.mag() >= maxDctMag)) continue;

        PVector response = getResponseAt(mat, xs, ys);
        if (response.mag() > maxReponse.mag()) {
          maxReponse = response;
          maxLoc = complexF;
        }
      }
    }
    // TODO: Aggregate nearby strength?
    return new Ridge(maxLoc, maxReponse);
  }

  // TODO: Does this thrash the stack with tiny vectors?
  PVector getResponseAt(Mat mat, int x, int y)
  {
    double[] tmp = mat.get(y, x);
    return new PVector((float)tmp[0], (float)tmp[1]);
  }
  
  float getAmplitudeAt(Mat mat, int x, int y)
  {
    double[] tmp = mat.get(y, x);
    return mag((float)tmp[0], (float)tmp[1]);
  }
  
  Mat eliminateRidgeAt(int x, int y)
  {
    complexMat = getFrequencySpaceAt(x, y);
    Ridge ridge = findPotentialRidge(complexMat, true);
    return eliminateRidge(complexMat, ridge);
  }

  Mat eliminateRidge(Mat complexMat, Ridge ridge)
  {
    int maxX = ((int)ridge.fx() + s) % s;
    int maxY = ((int)ridge.fy() + s) % s;
    
    // Radius of frequency area to clear.
    int sp = 1;
    // This may wrap a bit more than intended but it's no big deal
    for (int y = maxY-sp; y <= maxY+sp; y++) {
      for (int x = maxX-sp; x <= maxX+sp; x++) {
        if ((((x+s)%s) == 0) && (((y+s)%s) == 0)) continue;
        complexMat.put((y+s)%s, (x+s)%s, 0.0, 0.0);
        complexMat.put((s-y)%s, (s-x)%s, 0.0, 0.0);
      }
    }
    // Invert
    Mat newMat = new Mat();
    Core.dft(complexMat, newMat, Core.DFT_INVERSE | Core.DFT_SCALE, 0);
    return newMat;
  }
  
  Mat isolateRidgeAt(int x, int y)
  {
    complexMat = getFrequencySpaceAt(x, y);
    Ridge ridge = findPotentialRidge(complexMat, true);
    return isolateRidge(complexMat, ridge);
  }

  Mat isolateRidge(Mat complexMat, Ridge ridge)
  {
    int maxX = ((int)ridge.fx() + s) % s;
    int maxY = ((int)ridge.fy() + s) % s;
    
    // Radius of frequency area to retain.
    int sp = 1;
    Mat newComplexMat = Mat.zeros(complexMat.size(), complexMat.type());
    for (int y = maxY-sp; y <= maxY+sp; y++) {
      for (int x = maxX-sp; x <= maxX+sp; x++) {
        double[] data = complexMat.get((y+s)%s, (x+s)%s);
        newComplexMat.put((y+s)%s, (x+s)%s, data);
        // Complex conjugate
        data[1] = -data[1];
        newComplexMat.put((s-y)%s, (s-x)%s, data);
      }
    }
    // Transfer dc
    double[] dc = complexMat.get(0, 0);
    //dc[0] = 50000; dc[1] = 0;
    newComplexMat.put(0, 0, dc);
    // Invert
    Mat newMat = new Mat();
    Core.dft(newComplexMat, newMat, Core.DFT_INVERSE | Core.DFT_SCALE, 0);
    return newMat;
  }
}

class Ridge extends PVector
{
  PVector response;
  
  public Ridge(PVector complexF, PVector response)
  {
    super(complexF.x, complexF.y);
    this.response = response;
  }
  
  public float fx() {
    return x;
  }
  public float fy() {
    return y;
  }
}