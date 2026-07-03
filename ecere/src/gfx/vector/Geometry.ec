namespace gfx::vector;

default:
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <math.h>

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

public enum DimensionKind
{
   dimensionLinear,
   dimensionAligned,
   dimensionAngular,
   dimensionDiameter,
   dimensionRadius,
   dimensionOrdinate
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

// CAD/double-precision constants shared across DXF I/O and geometry code.
public define VECTOR_PI = 3.141592653589793238462643383279502884;
public define VECTOR_DEG2RAD = (VECTOR_PI / 180.0);
public define VECTOR_RAD2DEG = (180.0 / VECTOR_PI);
public define VECTOR_COORD_EPSILON = 1e-9;
public define VECTOR_GEOM_EPSILON = 1e-10;
public define VECTOR_BULGE_EPSILON = 1e-12;
public define VECTOR_DXF_DECIMALS = 15;

public bool VectorIsZero(double value, double epsilon)
{
   return value >= -epsilon && value <= epsilon;
}

public bool VectorEqual(double a, double b, double epsilon)
{
   return VectorIsZero(a - b, epsilon);
}

public double VectorNormalizeZero(double value, double epsilon)
{
   return VectorIsZero(value, epsilon) ? 0 : value;
}

public double VectorDegreesToRadians(double degrees)
{
   return degrees * VECTOR_DEG2RAD;
}

public double VectorRadiansToDegrees(double radians)
{
   return radians * VECTOR_RAD2DEG;
}

// Parse ASCII DXF numeric values with full double precision (strtod, not atof).
public double ParseDXFDouble(const char * value)
{
   char * end;
   double result;

   if(!value || !value[0])
      return 0;

   result = strtod(value, &end);
   return VectorNormalizeZero(result, VECTOR_COORD_EPSILON);
}

// Format coordinates for ASCII DXF with 15 significant digits (not printf %f).
public void FormatDXFDouble(char * buffer, int bufferSize, double value)
{
   if(!buffer || bufferSize <= 0)
      return;

   if(VectorIsZero(value, VECTOR_COORD_EPSILON))
   {
      strcpy(buffer, "0");
      return;
   }

   snprintf(buffer, bufferSize, "%.*G", VECTOR_DXF_DECIMALS, value);

   if(!buffer[0])
      strcpy(buffer, "0");
}

public uint VectorArcSampleCount(double sweepDegrees, double radius, double minSteps, double maxSteps)
{
   double sweep = fabs(sweepDegrees);
   uint steps;

   if(sweep <= 0)
      return (uint)minSteps;

   steps = (uint)(sweep * 2.0);
   if(radius > 0)
   {
      double radiusSteps = radius * sweep * VECTOR_DEG2RAD * 4.0;
      if(radiusSteps > steps)
         steps = (uint)radiusSteps;
   }

   if(steps < (uint)minSteps)
      steps = (uint)minSteps;
   if(steps > (uint)maxSteps)
      steps = (uint)maxSteps;

   return steps;
}
