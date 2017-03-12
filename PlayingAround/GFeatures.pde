float angleThreshold = radians(10);

float weightThreshold = 0; // TODO: TBD

// Yay, empirical constants
float minRidgeResponse = (RidgeDetector.a == 1 ? 15000 * pow(s/16, 1.7) : minRidgeStrength);

//
float minWrinkleResponse = 0.9 * minRidgeResponse;

Feature featureMeMaybe(int x, int y, Extracted ex)
{
  if (ex.ridgeCount() != 2) return null;
  
  Feature feature = new Feature(x, y, ex.ridge1, ex.ridge2);
  if (feature.ridge.response.mag() < minRidgeResponse) return null;
  if (feature.wrinkle.response.mag() < minWrinkleResponse) return null;
  
  if (feature.getAngle() < angleThreshold) return null;
  if (feature.getWeight() < weightThreshold) return null;
  return feature;
}

static class Feature implements java.io.Serializable
{
  int x, y;

  Ridge ridge;
  Ridge wrinkle;

  public Feature(int x, int y, Ridge ridge1, Ridge ridge2)
  {
    this.x = x;
    this.y = y;
    // The wrinkle is always the lower frequency one
    if (ridge1.f() > ridge2.f()) {
      this.ridge = ridge1;
      this.wrinkle = ridge2;
    } else {
      this.ridge = ridge2;
      this.wrinkle = ridge1;
    }
  }

  public PVector getPos()
  {
    return new PVector(x, y, 0);
  }
  
  public float getAngle()
  {
    return PVector.angleBetween(ridge, wrinkle);
  }

  public float getWeight()
  {
    return ridge.strength() * wrinkle.strength();
  }
}



class FeatureStep extends CalculationStep
{
  RidgeDetector ridger;

  PImage modified;
  ArrayList<Feature> features;
  Ridge[] ridges;

  // Features are searched with this spacing
  // d=1 is almost indistinguishable but way more work than d=2
  // d=4 is noticably worse but also MUCH faster
  final int d = 4;

  final int ts;

  int wd, hd;

  public FeatureStep(Step below)
  {
    super(below.take);
    ridger = new RidgeDetector(s);
    ridger.input = this;
    ts = ridger.s;
  }

  public void allocateResources()
  {
    wd = (w - ts) / d;
    hd = (h - ts) / d;
    modified = createImage(w, h, RGB);
    features = new ArrayList<Feature>();
    ridges = new Ridge[wd * hd];
  }

  public void calculateImpl()
  {
    modified.loadPixels();
    for (int yd = 0; yd < hd; yd++) {
      for (int xd = 0; xd < wd; xd++)
      {
        int x = xd*d + ts/2;
        int y = yd*d + ts/2;
        Extracted ex = ridger.getRawFeatureAt(x, y);

        Feature f = featureMeMaybe(x, y, ex);
        if (f != null) {
          features.add(new Feature(x, y, ex.ridge1, ex.ridge2));
        }
        ridges[yd * wd + xd] = ex.ridge1;

        for (int ydd = 0; ydd < d; ydd++) {
          for (int xdd = 0; xdd < d; xdd++) {
            int pos = (y + ydd) * w + x + xdd;
            modified.pixels[pos] = color(ridger.getAmplitudeAt(ex.out(), xdd + ts/2, ydd + ts/2));
          }
        }
      }
    }
    modified.updatePixels();
  }

  void drawImpl(PGraphics g)
  {
    g.image(modified, 0, 0);
    g.pushMatrix();
    if (!(keyPressed && (keyCode == KeyEvent.VK_SHIFT)))
    {
      g.translate(d/2, d/2);
      if (!(keyPressed && (key == '3')))
      {
        g.strokeWeight(d / 20.0);
        for (Feature f : features)
        {
          if (!onScreen(f.x, f.y, g)) continue;
          if (!(keyPressed && (key == '2'))) {
            g.stroke(0, 0, 200);
            g.strokeWeight(d * f.ridge.strength() / 10);
            drawFlowIndicator(g, f.x, f.y, f.ridge.strength() * d, f.ridge.angle());
          }
          if (!(keyPressed && (key == '1'))) {
            g.stroke(200, 0, 0);
            g.strokeWeight(d * f.wrinkle.strength() / 10);
            drawFlowIndicator(g, f.x, f.y, f.wrinkle.strength() * d, f.wrinkle.angle());
          }
        }
      } else
      {
        g.scale(d, d);
        g.stroke(0, 0, 200);
        g.translate(ts/d/2, ts/d/2);
        for (int y = screenStartY() / d; y < min(screenEndY() / d, hd); y++) {
          for (int x = screenStartX() / d; x < min(screenEndX() / d, wd); x++)
          {
            int pos = y * wd + x;
            Ridge ridge = ridges[pos];
            if (ridge == null) continue;
            g.strokeWeight(ridge.strength() / 10);
            drawFlowIndicator(g, x, y, ridge.strength(), ridge.angle());
          }
        }
      }
    }
    g.popMatrix();
  }
}

class HandDescriptor
{
  ArrayList<Feature> features;
  Landmarks landmarks;
  
  public HandDescriptor(ArrayList features, Landmarks landmarks)
  {
    this.features = features;
    this.landmarks = landmarks;
  }
}