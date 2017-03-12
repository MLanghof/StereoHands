import java.awt.event.KeyEvent;


// Amplitude threshold for accepting a maximum strength amplitude as ridge.
float minRidgeStrength =  (RidgeDetector.a == 1 ? 12000 * pow(s/16, 1.7) : 80 * s); // Empirical

class RidgeDetector
{
  // Filter kernel (DFT window) size
  final int s;

  // Image to process
  Step input;

  // Matrix storing data in window, used for dft
  Mat subMat, complexMat;

  boolean eliminateLowStrength = true; 

  // Aggregation area radius: 
  final static int a = 1;

  public RidgeDetector(int s)
  {
    this.s = s;
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
        // TODO: Isolated black pixels do appear in the input image
        int val = (int)red(input.take.shapeIndex.pixels[pos]);
        if (val == 0) {
          // Any area with background pixels in it is made uniform
          val = (int)red(input.take.shapeIndex.pixels[y*input.w + x]);
          subMat.setTo(Scalar.all(val));
          return;
        }
        subMat.put(ys + s/2, xs + s/2, val);
      }
    }
  }

  Ridge findPotentialRidge(Mat complexMat, boolean minRidgeCheck, boolean maxRidgeCheck, boolean wrinkleCheck)
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

        PVector response = getResponseAround(complexMat, xs, ys);
        if (response.mag() > maxReponse.mag()) {
          maxReponse = response;
          maxLoc = complexF;
        }
      }
    }
    return new Ridge(maxLoc, maxReponse, getAmplitudeAt(complexMat, 0, 0));
  }

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
  
  PVector getResponseAround(Mat mat, int x, int y)
  {
    double rx = 0;
    double ry = 0;
    for (int j = -a; j <= a; j++) {
      for (int i = -a; i <= a; i++) {
        int xs = (x + i) % s;
        int ys = (y + j) % s;
        if ((xs == 0) && (ys == 0)) continue; // Ignore DC
        double[] tmp = mat.get(y, x);
        double weight = sqrt((abs(i)+1) * (abs(j)+1));
        rx += tmp[0] / weight;
        ry += tmp[1] / weight;
      }
    }
    return new PVector((float)rx*1.8, (float)ry*1.8);
  }
  
  float getAmplitudeAround(Mat mat, int x, int y)
  {
    return getResponseAround(mat, x, y).mag();
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
    // This may wrap a bit more than intended but it's no big deal
    for (int y = maxY-a; y <= maxY+a; y++) {
      for (int x = maxX-a; x <= maxX+a; x++) {
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

    Mat newComplexMat = Mat.zeros(complexMat.size(), complexMat.type());
    for (int y = maxY-a; y <= maxY+a; y++) {
      for (int x = maxX-a; x <= maxX+a; x++) {
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
  
  Extracted getRawFeatureAt(int x, int y)
  {
    complexMat = getFrequencySpaceAt(x, y);
    return extractRawFeature(complexMat);
  }
  
  Extracted extractRawFeature(Mat complexMat)
  {
    Extracted ex = new Extracted();
    Ridge ridge1 = findPotentialRidge(complexMat, true, true, false);
    if (!qualifiesAsRidge(ridge1)) {
      ex.complexF = dcOnly(complexMat);
      return ex;
    }
    ex.ridge1 = ridge1;
    Mat ridgeMat1 = isolateRidgeFrequencies(complexMat, ridge1);

    Mat searchMat2 = eliminateRidge(complexMat, ridge1);
    Ridge ridge2 = findPotentialRidge(searchMat2, true, false, true);
    if (!qualifiesAsRidge(ridge2)) {
      ex.complexF = ridgeMat1;
      return ex;
    }
    ex.ridge2 = ridge2;
    Mat ridgeMat2 = isolateRidgeFrequencies(complexMat, ridge2);

    if (false) {
      ex.complexF = eliminateRidge(complexMat, ridge1);
    } else {
      Core.bitwise_or(ridgeMat1, ridgeMat2, ex.complexF);
    }
    return ex;
  }
}


static class Ridge extends PVector
{
  PVector response;
  float dc;

  public Ridge(PVector complexF, PVector response, float dc)
  {
    super(complexF.x, complexF.y);
    this.response = response;
    this.dc = dc;
  }

  public float angle() {
    return heading() + HALF_PI;
  }

  public float fx() {
    return x;
  }
  public float fy() {
    return y;
  }
  public float f() {
    return mag();
  }
  
  public float strength() {
    return response.mag() / dc;
  }
}
// TODO: That's a shitty name
class Extracted
{
  Mat complexF;
  private Mat out;
  Ridge ridge1, ridge2;

  public Extracted()
  {
    complexF = new Mat();
    out = new Mat();
  }

  public Extracted(Ridge ridge1, Ridge ridge2, Mat complexF)
  {
    this.ridge1 = ridge1;
    this.ridge2 = ridge2;
    this.complexF = complexF;
  }
  
  public int ridgeCount()
  {
    return (ridge1 == null ? 0 : 1) + (ridge2 == null ? 0 : 1);
  }
  
  public Mat out()
  {
    if (out.empty()) {
      Core.dft(complexF, out, Core.DFT_INVERSE | Core.DFT_SCALE, 0);
    }
    return out;
  }
}