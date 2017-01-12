import java.awt.event.KeyEvent;

// Ugly, I know.
final int SSS = s;

class RidgeDetector
{
  // Filter kernel (DFT window) size
  final int s = SSS;

  // Image to process
  Step input;

  // Matrix storing data in window, used for dft
  Mat subMat, complexMat;

  boolean eliminateLowStrength = true; 
  // Amplitude threshold for accepting a maximum strength amplitude as ridge.
  //float minRidgeStrength = 1500;
  //float minRidgeStrength = 1300;
  float minRidgeStrength = 80 * s; // Empirical

  public RidgeDetector()
  {
    subMat = new Mat(s, s, CvType.CV_32FC1);
  }

  public Ridge findRidgeAt(int x, int y)
  {
    complexMat = getFrequencySpaceAt(x, y);
    Ridge ridge = findPotentialRidge(complexMat, true, true, false);
    // TODO: If there's a stronger signal with lower than allowed frequency, check if it's in the same direction
    //         if yes: discard (just harmonics of a wrinkle or main line)

    if (!qualifiesAsRidge(ridge)) {
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

  Ridge findPotentialRidge(Mat mat, boolean minRidgeCheck, boolean maxRidgeCheck, boolean wrinkleCheck)
  {
    PVector maxReponse = new PVector();
    PVector maxLoc = new PVector();

    for (int ys = 0; ys < s; ys++) {
      for (int xs = 0; xs < s; xs++)
      {
        if ((xs == 0) && (ys == 0)) continue; // Not interested in dc component

        PVector complexF = new PVector((xs + s/2) % s - s/2, (ys + s/2) % s - s/2);
        if (minRidgeCheck && (complexF.mag() >= maxDftMagRidge)) continue;
        if (maxRidgeCheck && (complexF.mag() <= minDftMagRidge)) continue;
        if (wrinkleCheck && (complexF.mag() <= minDftMagWrinkle)) continue;

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

  boolean qualifiesAsRidge(Ridge ridge)
  {
    if (eliminateLowStrength && (ridge.response.mag() < minRidgeStrength)) return false;
    return true;
  }

  Mat eliminateRidgeAt(int x, int y)
  {
    complexMat = getFrequencySpaceAt(x, y);
    Ridge ridge = findPotentialRidge(complexMat, true, true, false);
    // Invert
    Mat newMat = new Mat();
    Core.dft(eliminateRidge(complexMat, ridge), newMat, Core.DFT_INVERSE | Core.DFT_SCALE, 0);
    return newMat;
  }

  Mat eliminateRidge(Mat complexMat, Ridge ridge)
  {
    int maxX = ((int)ridge.fx() + s) % s;
    int maxY = ((int)ridge.fy() + s) % s;

    Mat newComplexMat = complexMat.clone();
    // Radius of frequency area to clear.
    int sp = 1;
    // This may wrap a bit more than intended but it's no big deal
    for (int y = maxY-sp; y <= maxY+sp; y++) {
      for (int x = maxX-sp; x <= maxX+sp; x++) {
        if ((((x+s)%s) == 0) && (((y+s)%s) == 0)) continue;
        newComplexMat.put((y+s)%s, (x+s)%s, 0.0, 0.0);
        newComplexMat.put((s-y)%s, (s-x)%s, 0.0, 0.0);
      }
    }
    return newComplexMat;
  }

  Mat isolateRidgeAt(int x, int y)
  {
    complexMat = getFrequencySpaceAt(x, y);
    Ridge ridge = findPotentialRidge(complexMat, true, true, false);
    // Invert
    Mat newMat = new Mat();
    Core.dft(isolateRidgeFrequencies(complexMat, ridge), newMat, Core.DFT_INVERSE | Core.DFT_SCALE, 0);
    return newMat;
  }

  Mat isolateRidgeFrequencies(Mat complexMat, Ridge ridge)
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
    //if (mag((float)dc[0], (float)dc[1]) > 20000) { dc[0] = 50000; dc[1] = 0; }
    newComplexMat.put(0, 0, dc);
    return newComplexMat;
  }

  Mat isolateTwoRidgesAt(int x, int y)
  {
    complexMat = getFrequencySpaceAt(x, y);
    Mat newComplexMat = isolateTwoRidgeFrequencies(complexMat);
    // Invert
    Mat result = new Mat();
    Core.dft(newComplexMat, result, Core.DFT_INVERSE | Core.DFT_SCALE, 0);
    return result;
  }

  Mat isolateTwoRidgeFrequencies(Mat complexMat)
  {
    Ridge ridge1 = findPotentialRidge(complexMat, true, true, false);
    if (!qualifiesAsRidge(ridge1)) return dcOnly(complexMat);
    Mat ridgeMat1 = isolateRidgeFrequencies(complexMat, ridge1);
    Mat searchMat2 = eliminateRidge(complexMat, ridge1);
    Ridge ridge2 = findPotentialRidge(searchMat2, true, false, true);
    if (!qualifiesAsRidge(ridge2)) return ridgeMat1;

    Mat ridgeMat2 = isolateRidgeFrequencies(complexMat, ridge2);
    //float angleOffset = PVector.angleBetween(ridge, wrinkle);
    Mat newComplexMat = new Mat();
    boolean test = false;
    if (test) {
      newComplexMat = eliminateRidge(complexMat, ridge1);
      return eliminateRidge(newComplexMat, ridge2);
    } else {
      Core.bitwise_or(ridgeMat1, ridgeMat2, newComplexMat);
      return newComplexMat;
    }
  }
  
  Mat dcOnly(Mat complexMat)
  {
    Mat newComplexMat = Mat.zeros(complexMat.size(), complexMat.type());
    double[] dc = complexMat.get(0, 0);
    //dc[0] = 50000; dc[1] = 0;
    newComplexMat.put(0, 0, dc);
    return newComplexMat;
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