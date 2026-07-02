namespace gfx::vector;

public struct VectorPoint
{
   double x, y, z;
};

public struct VectorBounds
{
   double left, top, right, bottom;

   void Reset()
   {
      left = top = 1.0e300;
      right = bottom = -1.0e300;
   }

   void IncludePoint(VectorPoint p)
   {
      if(p.x < left) left = p.x;
      if(p.x > right) right = p.x;
      if(p.y < top) top = p.y;
      if(p.y > bottom) bottom = p.y;
   }
};

public enum DisplayLineKind
{
   industrial,
   artistic
};

public enum DisplayLineImplementation
{
   polyline,
   ellipseArc,
   cubicSpline
};

public struct VectorStroke
{
   int color;
   double width;
};
