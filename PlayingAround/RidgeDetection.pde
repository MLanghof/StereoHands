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
    
    if (eliminateLowStrength && (ridge.strength < minRidgeStrength)) {
      ridge.strength = 0;
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
    float maxStrength = 0;
    PVector maxLoc = new PVector();

    for (int ys = 0; ys < s; ys++) {
      for (int xs = 0; xs < s; xs++)
      {
        if ((xs == 0) && (ys == 0)) continue; // Not interested in dc component
        
        PVector complexF = new PVector((xs + s/2) % s - s/2, (ys + s/2) % s - s/2);
        if (boundsCheck && (complexF.mag() <= minDctMag)) continue;
        if (boundsCheck && (complexF.mag() >= maxDctMag)) continue;

        float strength = getAmplitudeAt(mat, xs, ys);
        if (strength > maxStrength) {
          maxStrength = strength;
          maxLoc = complexF;
        }
      }
    }
    // TODO: Aggregate nearby strength?
    return new Ridge(maxLoc, maxStrength);
  }

  float getAmplitudeAt(Mat mat, int x, int y)
  {
    double[] tmp = mat.get(y, x);
    return mag((float)tmp[0], (float)tmp[1]);
  }
}

class Ridge extends PVector
{
  float strength;
  
  public Ridge(PVector complexF, float strength)
  {
    super(complexF.x, complexF.y);
    this.strength = strength;
  }
  
  public float fx() {
    return x;
  }
  public float fy() {
    return y;
  }
}