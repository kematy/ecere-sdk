namespace gfx::vector;

import "Geometry"

public class DisplayLine
{
public:
   uint64 ownerEntityId;
   DisplayLineKind kind;
   DisplayLineImplementation implementation;
   bool closed;
   VectorStroke stroke;
   VectorBounds bounds;
   uint cachedVersion;

   uint pointCount;
   VectorPoint * points;

   VectorPoint center;
   double radiusX, radiusY;
   double rotation;
   double startAngle, endAngle;

   ~DisplayLine()
   {
      delete points;
   }

   void SetPoints(VectorPoint * source, uint count)
   {
      delete points;
      points = count ? new VectorPoint[count] : null;
      pointCount = count;

      if(points && source)
         memcpy(points, source, sizeof(VectorPoint) * count);

      RebuildBounds();
   }

   void RebuildBounds()
   {
      uint c;
      bounds.Reset();

      if(implementation == ellipseArc)
      {
         // Sample the actual sweep so rotation and partial arcs produce a tight, correct box
         // (the previous full-AABB estimate over-reported bounds for rotated / partial arcs).
         double pi = 3.14159265358979323846;
         double a0 = startAngle, a1 = endAngle;
         double rot = rotation * pi / 180.0;
         double cr = cos(rot), sr = sin(rot);
         uint steps = 64, i;
         double sweep;

         if(a1 < a0) a1 += 360;
         sweep = a1 - a0;
         for(i = 0; i <= steps; i++)
         {
            double ang = (a0 + sweep * (double)i / (double)steps) * pi / 180.0;
            double ex = radiusX * cos(ang);
            double ey = radiusY * sin(ang);
            VectorPoint p =
            {
               center.x + ex * cr - ey * sr,
               center.y + ex * sr + ey * cr,
               center.z
            };
            bounds.IncludePoint(p);
         }
      }
      else
      {
         for(c = 0; c < pointCount; c++)
            bounds.IncludePoint(points[c]);
      }
   }
};
