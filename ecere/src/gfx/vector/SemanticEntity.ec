namespace gfx::vector;

import "Geometry"
import "DisplayLine"

public enum SemanticEntityType
{
   entityLine,
   entityCircle,
   entityArc,
   entityEllipse,
   entityPolyline,
   entitySpline,
   entityText,
   entityInsert,
   entityLeader,
   entityHatch
};

public class SemanticEntity
{
public:
   uint64 id;
   SemanticEntityType type;
   char * layer;
   char * lineType;
   int color;
   double lineWeight;
   bool visible, locked;
   uint version;

   SemanticEntity()
   {
      visible = true;
      layer = CopyString("0");
      lineType = CopyString("BYLAYER");
      color = 256;
   }

   ~SemanticEntity()
   {
      delete layer;
      delete lineType;
   }

   void SetLineType(const char * value)
   {
      delete lineType;
      lineType = CopyString(value ? value : "BYLAYER");
      Touch();
   }

   void Touch()
   {
      version++;
   }

   virtual DisplayLine CreateDisplayLine(DisplayLineKind kind)
   {
      return null;
   }

   virtual DisplayLineKind GetFamily()
   {
      return industrial;
   }

   virtual bool IsClosed()
   {
      return false;
   }
};

public class LineEntity : SemanticEntity
{
public:
   VectorPoint start, end;

   LineEntity()
   {
      type = entityLine;
   }

   DisplayLine CreateDisplayLine(DisplayLineKind kind)
   {
      VectorPoint points[2] = { start, end };
      DisplayLine display { ownerEntityId = id, kind = kind, implementation = polyline, closed = false, cachedVersion = version };
      display.SetPoints(points, 2);
      return display;
   }
};

public class CircleEntity : SemanticEntity
{
public:
   VectorPoint center;
   double radius;

   CircleEntity()
   {
      type = entityCircle;
   }

   property double Radius
   {
      set { radius = value; Touch(); }
      get { return radius; }
   }

   DisplayLine CreateDisplayLine(DisplayLineKind kind)
   {
      DisplayLine display
      {
         ownerEntityId = id, kind = kind, implementation = ellipseArc, closed = true,
         center = center, radiusX = radius, radiusY = radius,
         startAngle = 0, endAngle = 360, cachedVersion = version
      };
      display.RebuildBounds();
      return display;
   }

   DisplayLineKind GetFamily()
   {
      return artistic;
   }

   bool IsClosed()
   {
      return true;
   }
};

public class ArcEntity : SemanticEntity
{
public:
   VectorPoint center;
   double radius;
   double startAngle, endAngle;

   ArcEntity()
   {
      type = entityArc;
   }

   DisplayLine CreateDisplayLine(DisplayLineKind kind)
   {
      DisplayLine display
      {
         ownerEntityId = id, kind = kind, implementation = ellipseArc, closed = false,
         center = center, radiusX = radius, radiusY = radius,
         startAngle = startAngle, endAngle = endAngle, cachedVersion = version
      };
      display.RebuildBounds();
      return display;
   }

   DisplayLineKind GetFamily()
   {
      return artistic;
   }
};

public class EllipseEntity : SemanticEntity
{
public:
   VectorPoint center;
   double radiusX, radiusY;
   double rotation;

   EllipseEntity()
   {
      type = entityEllipse;
   }

   DisplayLine CreateDisplayLine(DisplayLineKind kind)
   {
      DisplayLine display
      {
         ownerEntityId = id, kind = kind, implementation = ellipseArc, closed = true,
         center = center, radiusX = radiusX, radiusY = radiusY, rotation = rotation,
         startAngle = 0, endAngle = 360, cachedVersion = version
      };
      display.RebuildBounds();
      return display;
   }

   DisplayLineKind GetFamily()
   {
      return artistic;
   }

   bool IsClosed()
   {
      return true;
   }
};

public class PolylineEntity : SemanticEntity
{
public:
   bool closed;
   uint pointCount;
   VectorPoint * points;
   double * bulges;
   double * startWidths;
   double * endWidths;
   uint flagBits;

   PolylineEntity()
   {
      type = entityPolyline;
   }

   ~PolylineEntity()
   {
      delete points;
      delete bulges;
      delete startWidths;
      delete endWidths;
   }

   void SetPoints(VectorPoint * source, uint count)
   {
      delete points;
      points = count ? new VectorPoint[count] : null;
      pointCount = count;

      if(points && source)
         memcpy(points, source, sizeof(VectorPoint) * count);

      Touch();
   }

   void SetBulges(double * source, uint count)
   {
      delete bulges;
      bulges = count ? new double[count] : null;
      if(bulges && source)
         memcpy(bulges, source, sizeof(double) * count);
      Touch();
   }

   void SetStartWidths(double * source, uint count)
   {
      delete startWidths;
      startWidths = count ? new double[count] : null;
      if(startWidths && source)
         memcpy(startWidths, source, sizeof(double) * count);
      Touch();
   }

   void SetEndWidths(double * source, uint count)
   {
      delete endWidths;
      endWidths = count ? new double[count] : null;
      if(endWidths && source)
         memcpy(endWidths, source, sizeof(double) * count);
      Touch();
   }

   DisplayLine CreateDisplayLine(DisplayLineKind kind)
   {
      DisplayLine display { ownerEntityId = id, kind = kind, implementation = polyline, closed = closed, cachedVersion = version };
      display.SetPoints(points, pointCount);
      return display;
   }

   bool IsClosed()
   {
      return closed;
   }
};

public class SplineEntity : SemanticEntity
{
public:
   bool closed;
   uint degree;
   uint controlPointCount;
   VectorPoint * controlPoints;
   uint flagBits;
   uint knotCount;
   double * knots;
   uint weightCount;
   double * weights;

   SplineEntity()
   {
      type = entitySpline;
      degree = 3;
   }

   ~SplineEntity()
   {
      delete controlPoints;
      delete knots;
      delete weights;
   }

   void SetControlPoints(VectorPoint * source, uint count)
   {
      delete controlPoints;
      controlPoints = count ? new VectorPoint[count] : null;
      controlPointCount = count;

      if(controlPoints && source)
         memcpy(controlPoints, source, sizeof(VectorPoint) * count);

      Touch();
   }

   void SetKnots(double * source, uint count)
   {
      delete knots;
      knots = count ? new double[count] : null;
      knotCount = count;
      if(knots && source)
         memcpy(knots, source, sizeof(double) * count);
      Touch();
   }

   void SetWeights(double * source, uint count)
   {
      delete weights;
      weights = count ? new double[count] : null;
      weightCount = count;
      if(weights && source)
         memcpy(weights, source, sizeof(double) * count);
      Touch();
   }

   DisplayLine CreateDisplayLine(DisplayLineKind kind)
   {
      DisplayLine display { ownerEntityId = id, kind = kind, implementation = cubicSpline, closed = closed, cachedVersion = version };
      display.SetPoints(controlPoints, controlPointCount);
      return display;
   }

   DisplayLineKind GetFamily()
   {
      return artistic;
   }

   bool IsClosed()
   {
      return closed;
   }
};

public class TextEntity : SemanticEntity
{
public:
   VectorPoint position, alignment;
   char * text;
   char * style;
   double height;
   double angle;
   double widthScale;
   double oblique;
   int alignH;
   int alignV;

   TextEntity()
   {
      type = entityText;
      text = CopyString("");
      style = CopyString("STANDARD");
      height = 1;
      widthScale = 1;
   }

   ~TextEntity()
   {
      delete text;
      delete style;
   }

   void SetText(const char * value)
   {
      delete text;
      text = CopyString(value ? value : "");
      Touch();
   }

   void SetStyle(const char * value)
   {
      delete style;
      style = CopyString(value ? value : "STANDARD");
      Touch();
   }

   DisplayLine CreateDisplayLine(DisplayLineKind kind)
   {
      double width = (double)strlen(text) * height * 0.6;
      VectorPoint points[2] =
      {
         position,
         { position.x + width, position.y, position.z }
      };
      DisplayLine display { ownerEntityId = id, kind = kind, implementation = polyline, closed = false, cachedVersion = version };
      display.SetPoints(points, 2);
      return display;
   }

   DisplayLineKind GetFamily()
   {
      return artistic;
   }
};

public class InsertEntity : SemanticEntity
{
public:
   VectorPoint position;
   char * name;
   double xScale, yScale, zScale;
   double angle;
   int colCount;
   int rowCount;
   double colSpace;
   double rowSpace;
   double lineTypeScale;

   InsertEntity()
   {
      type = entityInsert;
      name = CopyString("");
      xScale = yScale = zScale = 1;
      colCount = rowCount = 1;
      lineTypeScale = 1;
   }

   ~InsertEntity()
   {
      delete name;
   }

   void SetName(const char * value)
   {
      delete name;
      name = CopyString(value ? value : "");
      Touch();
   }

   DisplayLine CreateDisplayLine(DisplayLineKind kind)
   {
      double size = 5;
      VectorPoint points[4] =
      {
         { position.x - size, position.y, position.z },
         { position.x + size, position.y, position.z },
         { position.x, position.y - size, position.z },
         { position.x, position.y + size, position.z }
      };
      DisplayLine display { ownerEntityId = id, kind = kind, implementation = polyline, closed = false, cachedVersion = version };
      display.SetPoints(points, 4);
      return display;
   }
};

public class LeaderEntity : SemanticEntity
{
public:
   uint pointCount;
   VectorPoint * points;
   char * dimStyle;
   bool arrow;
   int flag;
   double textHeight;
   double textWidth;

   LeaderEntity()
   {
      type = entityLeader;
      dimStyle = CopyString("STANDARD");
      arrow = true;
   }

   ~LeaderEntity()
   {
      delete points;
      delete dimStyle;
   }

   void SetDimStyle(const char * value)
   {
      delete dimStyle;
      dimStyle = CopyString(value ? value : "STANDARD");
      Touch();
   }

   void SetPoints(VectorPoint * source, uint count)
   {
      delete points;
      points = count ? new VectorPoint[count] : null;
      pointCount = count;
      if(points && source)
         memcpy(points, source, sizeof(VectorPoint) * count);
      Touch();
   }

   DisplayLine CreateDisplayLine(DisplayLineKind kind)
   {
      DisplayLine display { ownerEntityId = id, kind = kind, implementation = polyline, closed = false, cachedVersion = version };
      display.SetPoints(points, pointCount);
      return display;
   }
};

public class HatchEntity : SemanticEntity
{
public:
   VectorPoint seed;
   uint boundaryPointCount;
   VectorPoint * boundaryPoints;
   List<DisplayLine> boundaryLines { };
   char * name;
   bool solid;
   int hStyle;
   char * hPattern;
   double angle;
   double scale;
   bool associative;
   bool doubleFlag;
   int loopsNum;

   HatchEntity()
   {
      type = entityHatch;
      name = CopyString("SOLID");
      solid = true;
      hPattern = CopyString("SOLID");
      scale = 1;
   }

   ~HatchEntity()
   {
      delete boundaryPoints;
      boundaryLines.Free();
      delete name;
      delete hPattern;
   }

   void SetName(const char * value)
   {
      delete name;
      name = CopyString(value ? value : "SOLID");
      Touch();
   }

   void SetHPattern(const char * value)
   {
      delete hPattern;
      hPattern = CopyString(value ? value : "SOLID");
      Touch();
   }

   void SetBoundaryPoints(VectorPoint * source, uint count)
   {
      delete boundaryPoints;
      boundaryPoints = count ? new VectorPoint[count] : null;
      boundaryPointCount = count;
      if(boundaryPoints && source)
         memcpy(boundaryPoints, source, sizeof(VectorPoint) * count);
      Touch();
   }

   void AddBoundaryLine(DisplayLine line)
   {
      if(line)
      {
         boundaryLines.Add(line);
         Touch();
      }
   }

   DisplayLine CreateDisplayLine(DisplayLineKind kind)
   {
      DisplayLine display { ownerEntityId = id, kind = kind, implementation = polyline, closed = boundaryPointCount > 2, cachedVersion = version };
      if(boundaryLines.count)
      {
         Link link = boundaryLines.first;
         DisplayLine first = link ? (DisplayLine)boundaryLines.GetData(link) : null;
         if(first)
         {
            display.implementation = first.implementation;
            display.closed = first.closed;
            display.center = first.center;
            display.radiusX = first.radiusX;
            display.radiusY = first.radiusY;
            display.rotation = first.rotation;
            display.startAngle = first.startAngle;
            display.endAngle = first.endAngle;
            display.SetPoints(first.points, first.pointCount);
         }
      }
      else if(boundaryPointCount)
         display.SetPoints(boundaryPoints, boundaryPointCount);
      else
      {
         VectorPoint points[4] =
         {
            { seed.x - 2, seed.y - 2, seed.z },
            { seed.x + 2, seed.y - 2, seed.z },
            { seed.x + 2, seed.y + 2, seed.z },
            { seed.x - 2, seed.y + 2, seed.z }
         };
         display.closed = true;
         display.SetPoints(points, 4);
      }
      return display;
   }
};
