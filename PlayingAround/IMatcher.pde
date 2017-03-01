class FeatureMatcher
{
  ArrayList<Feature> features1;
  ArrayList<Feature> features2;
  
  void setFeatures(ArrayList<Feature> features1, ArrayList<Feature> features2)
  {
    this.features1 = features1;
    this.features2 = features2;
  }
  
  float getMatchingScore()
  {
    float sum = 0;
    for (Feature f1 : features1)
    {
      Feature f2 = findNearestNeighbour(f1, features2);
      sum += featureMatch(f1, f2);
    }
    return sum;
  }
  
  // Very naive implementation
  Feature findNearestNeighbour(Feature home, ArrayList<Feature> neighbours)
  {
    float minDistance = 9e9;
    Feature ret = null;
    for (Feature neighbour : neighbours) {
      float distance = home.getPos().dist(neighbour.getPos());
      if (distance < minDistance) {
        ret = neighbour;
        minDistance = distance;
      }
    }
    return ret;
  }
  
  float featureMatch(Feature f1, Feature f2)
  {
    float a1 = 2 * f1.getAngle();
    if (abs(a1) > PI) a1 = TWO_PI - abs(a1);
    float a2 = 2 * f2.getAngle();
    if (abs(a2) > PI) a2 = TWO_PI - abs(a2);
    return f1.getWeight() * f2.getWeight() * cos(a1 - a2);
  }
  
}