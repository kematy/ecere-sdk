namespace gfx::vector;

import "Geometry"
import "SemanticEntity"
import "DisplayLine"

public class BlockDefinition
{
public:
   char * name;
   List<SemanticEntity> entities { };

   BlockDefinition()
   {
      name = CopyString("");
   }

   ~BlockDefinition()
   {
      delete name;
      entities.Free();
   }

   void SetName(const char * value)
   {
      delete name;
      name = CopyString(value ? value : "");
   }

   SemanticEntity AddEntity(SemanticEntity entity)
   {
      if(entity)
         entities.Add(entity);
      return entity;
   }
};

public class CADDocument
{
public:
   uint64 nextEntityId;
   List<SemanticEntity> entities { };
   List<DisplayLine> displayLines { };
   List<BlockDefinition> blocks { };

   CADDocument()
   {
      nextEntityId = 1;
   }

   ~CADDocument()
   {
      entities.Free();
      displayLines.Free();
      blocks.Free();
   }

   SemanticEntity AddEntity(SemanticEntity entity)
   {
      if(entity)
      {
         entity.id = nextEntityId++;
         entities.Add(entity);
      }
      return entity;
   }

   BlockDefinition AddBlock(const char * name)
   {
      BlockDefinition block { };
      block.SetName(name);
      blocks.Add(block);
      return block;
   }

   BlockDefinition FindBlock(const char * name)
   {
      Link link;
      if(name)
      {
         for(link = blocks.first; link; link = link.next)
         {
            BlockDefinition block = (BlockDefinition)blocks.GetData(link);
            if(block && block.name && !strcmp(block.name, name))
               return block;
         }
      }
      return null;
   }

   VectorPoint TransformInsertPoint(InsertEntity insert, VectorPoint p)
   {
      double angle = VectorDegreesToRadians(insert.angle);
      double c = cos(angle), s = sin(angle);
      double x = p.x * insert.xScale;
      double y = p.y * insert.yScale;
      double z = p.z * insert.zScale;
      return
      {
         insert.position.x + x * c - y * s,
         insert.position.y + x * s + y * c,
         insert.position.z + z
      };
   }

   void AddTransformedDisplayLine(DisplayLine source, InsertEntity insert)
   {
      uint c;
      DisplayLine display
      {
         ownerEntityId = insert.id, kind = source.kind, implementation = source.implementation,
         closed = source.closed, stroke = source.stroke, cachedVersion = insert.version,
         radiusX = source.radiusX * insert.xScale,
         radiusY = source.radiusY * insert.yScale,
         rotation = source.rotation + insert.angle,
         startAngle = source.startAngle,
         endAngle = source.endAngle
      };

      display.center = TransformInsertPoint(insert, source.center);
      if(source.pointCount)
      {
         VectorPoint * points = new VectorPoint[source.pointCount];
         for(c = 0; c < source.pointCount; c++)
            points[c] = TransformInsertPoint(insert, source.points[c]);
         display.SetPoints(points, source.pointCount);
         delete points;
      }
      else
         display.RebuildBounds();

      displayLines.Add(display);
   }

   bool AddInsertDisplayLinesDepth(InsertEntity insert, int depth)
   {
      BlockDefinition block = FindBlock(insert.name);
      Link link;
      bool added = false;
      if(block && depth < 8)
      {
         for(link = block.entities.first; link; link = link.next)
         {
            SemanticEntity entity = (SemanticEntity)block.entities.GetData(link);
            if(entity && entity.type == entityInsert)
            {
               InsertEntity child = (InsertEntity)entity;
               InsertEntity combined
               {
                  position = TransformInsertPoint(insert, child.position),
                  xScale = insert.xScale * child.xScale,
                  yScale = insert.yScale * child.yScale,
                  zScale = insert.zScale * child.zScale,
                  angle = insert.angle + child.angle
               };
               combined.SetName(child.name);
               if(AddInsertDisplayLinesDepth(combined, depth + 1))
                  added = true;
             }
             else
             {
               if(entity && entity.type == entityPolyline && AddTransformedPolylineDisplayLines((PolylineEntity)entity, insert))
                  added = true;
               else if(entity && entity.type == entitySpline && AddTransformedSplineDisplayLine((SplineEntity)entity, insert))
                  added = true;
               else
               {
                  DisplayLine display = entity ? entity.CreateDisplayLine(entity.GetFamily()) : null;
                  if(display)
                  {
                     AddTransformedDisplayLine(display, insert);
                     delete display;
                     added = true;
                  }
               }
             }
         }
      }
      return added;
   }

   bool AddInsertDisplayLines(InsertEntity insert)
   {
      int row, col;
      int rows = insert.rowCount > 0 ? insert.rowCount : 1;
      int cols = insert.colCount > 0 ? insert.colCount : 1;
      bool added = false;
      double angle = VectorDegreesToRadians(insert.angle);
      double c = cos(angle), s = sin(angle);

      for(row = 0; row < rows; row++)
      {
         for(col = 0; col < cols; col++)
         {
            InsertEntity instance
            {
               position =
               {
                  insert.position.x + (col * insert.colSpace) * c - (row * insert.rowSpace) * s,
                  insert.position.y + (col * insert.colSpace) * s + (row * insert.rowSpace) * c,
                  insert.position.z
               },
               xScale = insert.xScale,
               yScale = insert.yScale,
               zScale = insert.zScale,
               angle = insert.angle,
               colCount = 1,
               rowCount = 1,
               lineTypeScale = insert.lineTypeScale
            };
            instance.SetName(insert.name);
            instance.id = insert.id;
            instance.version = insert.version;
            if(AddInsertDisplayLinesDepth(instance, 0))
               added = true;
         }
      }
      return added;
   }

   bool AddHatchDisplayLines(HatchEntity hatch)
   {
      Link link;
      bool added = false;
      DisplayLineKind kind = industrial;

      for(link = hatch.boundaryLines.first; link; link = link.next)
      {
         DisplayLine source = (DisplayLine)hatch.boundaryLines.GetData(link);
         if(source)
         {
            DisplayLine display
            {
               ownerEntityId = hatch.id, kind = source.kind, implementation = source.implementation,
               closed = source.closed, stroke = source.stroke, cachedVersion = hatch.version,
               center = source.center, radiusX = source.radiusX, radiusY = source.radiusY,
               rotation = source.rotation, startAngle = source.startAngle, endAngle = source.endAngle
            };
            display.SetPoints(source.points, source.pointCount);
            if(!source.pointCount)
               display.RebuildBounds();
            displayLines.Add(display);
            added = true;
         }
      }

      if(hatch.boundaryPointCount >= 3 && hatch.boundaryPoints)
      {
         AddHatchOutline(hatch, kind);
         added = true;
         if(!hatch.solid || (hatch.hPattern && strcmp(hatch.hPattern, "SOLID")))
            AddHatchPatternLines(hatch, kind);
      }

      return added;
   }

   bool AddDimensionDisplayLines(DimensionEntity dim, DisplayLineKind kind)
   {
      VectorPoint dim1, dim2;
      VectorPoint ext1Line[2], ext2Line[2], dimLine[2];

      if(!dim)
         return false;

      switch(dim.GetKind())
      {
         case dimensionAngular:
         {
            VectorPoint center = dim.defPoint;
            double dx1 = dim.extLine1.x - center.x;
            double dy1 = dim.extLine1.y - center.y;
            double dx2 = dim.extLine2.x - center.x;
            double dy2 = dim.extLine2.y - center.y;
            double r1 = sqrt(dx1 * dx1 + dy1 * dy1);
            double r2 = sqrt(dx2 * dx2 + dy2 * dy2);
            double radius = r1 > r2 ? r1 : r2;
            double a1 = VectorRadiansToDegrees(atan2(dy1, dx1));
            double a2 = VectorRadiansToDegrees(atan2(dy2, dx2));
            VectorPoint ray1[2] = { center, dim.extLine1 };
            VectorPoint ray2[2] = { center, dim.extLine2 };

            if(VectorIsZero(radius, VECTOR_GEOM_EPSILON))
               radius = 30;

            {
               DisplayLine display
               {
                  ownerEntityId = dim.id, kind = kind, implementation = polyline,
                  closed = false, cachedVersion = dim.version
               };
               display.SetPoints(ray1, 2);
               displayLines.Add(display);
            }
            {
               DisplayLine display
               {
                  ownerEntityId = dim.id, kind = kind, implementation = polyline,
                  closed = false, cachedVersion = dim.version
               };
               display.SetPoints(ray2, 2);
               displayLines.Add(display);
            }
            {
               DisplayLine display
               {
                  ownerEntityId = dim.id, kind = kind, implementation = ellipseArc,
                  closed = false, cachedVersion = dim.version,
                  center = center, radiusX = radius, radiusY = radius,
                  startAngle = a1, endAngle = a2
               };
               display.RebuildBounds();
               displayLines.Add(display);
            }
            return true;
         }
         case dimensionRadius:
         {
            VectorPoint center = dim.defPoint;
            VectorPoint radiusLine[2] = { center, dim.extLine2 };
            DisplayLine display
            {
               ownerEntityId = dim.id, kind = kind, implementation = polyline,
               closed = false, cachedVersion = dim.version
            };
            display.SetPoints(radiusLine, 2);
            displayLines.Add(display);
            return true;
         }
         case dimensionDiameter:
         {
            VectorPoint center = dim.defPoint;
            VectorPoint diameterLine[2] =
            {
               { 2 * center.x - dim.extLine2.x, 2 * center.y - dim.extLine2.y, center.z },
               dim.extLine2
            };
            DisplayLine display
            {
               ownerEntityId = dim.id, kind = kind, implementation = polyline,
               closed = false, cachedVersion = dim.version
            };
            display.SetPoints(diameterLine, 2);
            displayLines.Add(display);
            return true;
         }
         case dimensionOrdinate:
         {
            bool ordinateX = (dim.dimType & 64) != 0;
            VectorPoint leader[2], tick[2];

            if(ordinateX)
            {
               leader[0] = dim.extLine1;
               leader[1] = { dim.dimLinePoint.x, dim.extLine1.y, dim.extLine1.z };
               tick[0] = leader[1];
               tick[1] = dim.dimLinePoint;
            }
            else
            {
               leader[0] = dim.extLine1;
               leader[1] = { dim.extLine1.x, dim.dimLinePoint.y, dim.extLine1.z };
               tick[0] = leader[1];
               tick[1] = dim.dimLinePoint;
            }

            {
               DisplayLine display
               {
                  ownerEntityId = dim.id, kind = kind, implementation = polyline,
                  closed = false, cachedVersion = dim.version
               };
               display.SetPoints(leader, 2);
               displayLines.Add(display);
            }
            {
               DisplayLine display
               {
                  ownerEntityId = dim.id, kind = kind, implementation = polyline,
                  closed = false, cachedVersion = dim.version
               };
               display.SetPoints(tick, 2);
               displayLines.Add(display);
            }
            return true;
         }
         default:
            break;
      }

      dim.ProjectDimPoints(&dim1, &dim2);
      ext1Line[0] = dim.extLine1;
      ext1Line[1] = dim1;
      ext2Line[0] = dim.extLine2;
      ext2Line[1] = dim2;
      dimLine[0] = dim1;
      dimLine[1] = dim2;

      {
         DisplayLine display
         {
            ownerEntityId = dim.id, kind = kind, implementation = polyline,
            closed = false, cachedVersion = dim.version
         };
         display.SetPoints(ext1Line, 2);
         displayLines.Add(display);
      }
      {
         DisplayLine display
         {
            ownerEntityId = dim.id, kind = kind, implementation = polyline,
            closed = false, cachedVersion = dim.version
         };
         display.SetPoints(ext2Line, 2);
         displayLines.Add(display);
      }
      {
         DisplayLine display
         {
            ownerEntityId = dim.id, kind = kind, implementation = polyline,
            closed = false, cachedVersion = dim.version
         };
         display.SetPoints(dimLine, 2);
         displayLines.Add(display);
      }
      return true;
   }

   void AddHatchOutline(HatchEntity hatch, DisplayLineKind kind)
   {
      if(hatch.boundaryPointCount >= 3 && hatch.boundaryPoints)
      {
         DisplayLine display
         {
            ownerEntityId = hatch.id, kind = kind, implementation = polyline,
            closed = true, cachedVersion = hatch.version
         };
         display.SetPoints(hatch.boundaryPoints, hatch.boundaryPointCount);
         displayLines.Add(display);
      }
   }

   bool PointInPolygon(VectorPoint p, VectorPoint * polygon, uint count)
   {
      bool inside = false;
      uint i, j;

      if(!polygon || count < 3)
         return false;

      for(i = 0, j = count - 1; i < count; j = i++)
      {
         if(((polygon[i].y > p.y) != (polygon[j].y > p.y)) &&
            (p.x < (polygon[j].x - polygon[i].x) * (p.y - polygon[i].y) / (polygon[j].y - polygon[i].y + 1.0e-300) + polygon[i].x))
            inside = !inside;
      }
      return inside;
   }

   VectorPoint LerpPoint(VectorPoint a, VectorPoint b, double t)
   {
      return { a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t, a.z + (b.z - a.z) * t };
   }

   bool SegmentEdgeIntersection(VectorPoint a, VectorPoint b, VectorPoint c, VectorPoint d, double * tOut)
   {
      double abx = b.x - a.x, aby = b.y - a.y;
      double cdx = d.x - c.x, cdy = d.y - c.y;
      double denom = abx * cdy - aby * cdx;
      double acx, acy, t, u;

      if(VectorIsZero(fabs(denom), VECTOR_GEOM_EPSILON))
         return false;

      acx = c.x - a.x;
      acy = c.y - a.y;
      t = (acx * cdy - acy * cdx) / denom;
      u = (acx * aby - acy * abx) / denom;

      if(u >= -VECTOR_GEOM_EPSILON && u <= 1.0 + VECTOR_GEOM_EPSILON &&
         t >= -VECTOR_GEOM_EPSILON && t <= 1.0 + VECTOR_GEOM_EPSILON)
      {
         if(tOut)
            *tOut = t;
         return true;
      }
      return false;
   }

   void InsertSortedT(double * values, uint * count, double t, uint maxCount)
   {
      uint i;

      if(!values || !count || *count >= maxCount)
         return;

      for(i = 0; i < *count; i++)
      {
         if(fabs(values[i] - t) <= VECTOR_GEOM_EPSILON)
            return;
      }

      values[*count] = t;
      (*count)++;

      for(i = *count - 1; i > 0; i--)
      {
         if(values[i - 1] <= values[i])
            break;
         {
            double swap = values[i - 1];
            values[i - 1] = values[i];
            values[i] = swap;
         }
      }
   }

   void AddClippedHatchSegment(HatchEntity hatch, DisplayLineKind kind, VectorPoint a, VectorPoint b, VectorPoint * polygon, uint count)
   {
      double tValues[64];
      uint tCount = 0;
      uint i, j, seg;

      tValues[tCount++] = 0;
      tValues[tCount++] = 1;

      for(i = 0, j = count - 1; i < count; j = i++)
      {
         double t;
         if(SegmentEdgeIntersection(a, b, polygon[j], polygon[i], &t))
            InsertSortedT(tValues, &tCount, t, sizeof(tValues) / sizeof(tValues[0]));
      }

      for(seg = 0; seg + 1 < tCount; seg++)
      {
         double t0 = tValues[seg];
         double t1 = tValues[seg + 1];
         VectorPoint mid = LerpPoint(a, b, (t0 + t1) * 0.5);

         if(PointInPolygon(mid, polygon, count))
         {
            VectorPoint segment[2] = { LerpPoint(a, b, t0), LerpPoint(a, b, t1) };
            DisplayLine display
            {
               ownerEntityId = hatch.id, kind = kind, implementation = polyline,
               closed = false, cachedVersion = hatch.version
            };
            display.SetPoints(segment, 2);
            displayLines.Add(display);
         }
      }
   }

   bool AddHatchPatternLines(HatchEntity hatch, DisplayLineKind kind)
   {
      VectorBounds bounds;
      double spacing, angleRad, nx, ny, px, py;
      double minProj, maxProj, minPerp, maxPerp;
      double start, end, pos;
      uint i;

      if(!hatch || hatch.boundaryPointCount < 3 || !hatch.boundaryPoints)
         return false;

      bounds.Reset();
      for(i = 0; i < hatch.boundaryPointCount; i++)
         bounds.IncludePoint(hatch.boundaryPoints[i]);

      spacing = hatch.scale > 0 ? hatch.scale : 3;
      if(hatch.angle != 0)
         angleRad = VectorDegreesToRadians(hatch.angle);
      else if(hatch.hPattern && !strcmp(hatch.hPattern, "ANSI31"))
         angleRad = VectorDegreesToRadians(45);
      else
         angleRad = VectorDegreesToRadians(45);

      nx = cos(angleRad);
      ny = sin(angleRad);
      px = -ny;
      py = nx;

      minProj = maxProj = hatch.boundaryPoints[0].x * nx + hatch.boundaryPoints[0].y * ny;
      minPerp = maxPerp = hatch.boundaryPoints[0].x * px + hatch.boundaryPoints[0].y * py;
      for(i = 1; i < hatch.boundaryPointCount; i++)
      {
         double proj = hatch.boundaryPoints[i].x * nx + hatch.boundaryPoints[i].y * ny;
         double perp = hatch.boundaryPoints[i].x * px + hatch.boundaryPoints[i].y * py;
         if(proj < minProj) minProj = proj;
         if(proj > maxProj) maxProj = proj;
         if(perp < minPerp) minPerp = perp;
         if(perp > maxPerp) maxPerp = perp;
      }

      minPerp -= spacing;
      maxPerp += spacing;

      for(pos = minPerp; pos <= maxPerp; pos += spacing)
      {
         VectorPoint a = { nx * minProj + px * pos, ny * minProj + py * pos, 0 };
         VectorPoint b = { nx * maxProj + px * pos, ny * maxProj + py * pos, 0 };
         AddClippedHatchSegment(hatch, kind, a, b, hatch.boundaryPoints, hatch.boundaryPointCount);
      }

      return true;
   }

   bool PolylineHasSegmentDisplayProperties(PolylineEntity entity)
   {
      uint c;
      if(entity)
      {
         uint segmentCount = entity.closed ? entity.pointCount : (entity.pointCount > 1 ? entity.pointCount - 1 : 0);
         for(c = 0; c < segmentCount; c++)
         {
            double bulge = entity.bulges ? entity.bulges[c] : 0;
            double startWidth = entity.startWidths ? entity.startWidths[c] : 0;
            double endWidth = entity.endWidths ? entity.endWidths[c] : 0;
            if(!VectorIsZero(bulge, VECTOR_BULGE_EPSILON) ||
               !VectorIsZero(startWidth, VECTOR_GEOM_EPSILON) ||
               !VectorIsZero(endWidth, VECTOR_GEOM_EPSILON))
               return true;
         }
      }
      return false;
   }

   double PolylineSegmentWidth(PolylineEntity entity, uint index)
   {
      double startWidth = entity.startWidths ? entity.startWidths[index] : 0;
      double endWidth = entity.endWidths ? entity.endWidths[index] : 0;
      if(startWidth > 0 && endWidth > 0)
         return (startWidth + endWidth) * 0.5;
      if(startWidth > 0)
         return startWidth;
      if(endWidth > 0)
         return endWidth;
      return 0;
   }

   DisplayLine CreatePolylineSegmentDisplay(PolylineEntity entity, uint index, DisplayLineKind kind)
   {
      uint next = index + 1;
      VectorPoint start = entity.points[index];
      VectorPoint end;
      double bulge = entity.bulges ? entity.bulges[index] : 0;

      if(next >= entity.pointCount)
         next = 0;
      end = entity.points[next];

      if(!VectorIsZero(bulge, VECTOR_BULGE_EPSILON))
      {
         double dx = end.x - start.x;
         double dy = end.y - start.y;
         double chord = sqrt(dx * dx + dy * dy);
         if(!VectorIsZero(chord, VECTOR_GEOM_EPSILON))
         {
            double midX = (start.x + end.x) * 0.5;
            double midY = (start.y + end.y) * 0.5;
            double offset = chord * (1 - bulge * bulge) / (4 * bulge);
            double nx = -dy / chord;
            double ny = dx / chord;
            double radius = chord * (1 + bulge * bulge) / (4 * fabs(bulge));
            double startAngle, endAngle;
            DisplayLine display
            {
               ownerEntityId = entity.id, kind = kind, implementation = ellipseArc,
               closed = false, cachedVersion = entity.version,
               center = { midX + nx * offset, midY + ny * offset, start.z },
               radiusX = radius, radiusY = radius
            };
            display.stroke.width = PolylineSegmentWidth(entity, index);
            startAngle = VectorRadiansToDegrees(atan2(start.y - display.center.y, start.x - display.center.x));
            endAngle = VectorRadiansToDegrees(atan2(end.y - display.center.y, end.x - display.center.x));
            if(bulge < 0)
            {
               double swap = startAngle;
               startAngle = endAngle;
               endAngle = swap;
            }
            display.startAngle = startAngle;
            display.endAngle = endAngle;
            display.RebuildBounds();
            return display;
         }
      }

      {
         VectorPoint points[2] = { start, end };
         DisplayLine display { ownerEntityId = entity.id, kind = kind, implementation = polyline, closed = false, cachedVersion = entity.version };
         display.stroke.width = PolylineSegmentWidth(entity, index);
         display.SetPoints(points, 2);
         return display;
      }
   }

   bool AddPolylineDisplayLines(PolylineEntity entity, DisplayLineKind kind)
   {
      uint c;
      uint segmentCount = entity.closed ? entity.pointCount : (entity.pointCount > 1 ? entity.pointCount - 1 : 0);
      if(!PolylineHasSegmentDisplayProperties(entity))
         return false;
      for(c = 0; c < segmentCount; c++)
         displayLines.Add(CreatePolylineSegmentDisplay(entity, c, kind));
      return segmentCount > 0;
   }

   bool AddTransformedPolylineDisplayLines(PolylineEntity entity, InsertEntity insert)
   {
      uint c;
      uint segmentCount = entity.closed ? entity.pointCount : (entity.pointCount > 1 ? entity.pointCount - 1 : 0);
      if(!PolylineHasSegmentDisplayProperties(entity))
         return false;
      for(c = 0; c < segmentCount; c++)
      {
         DisplayLine display = CreatePolylineSegmentDisplay(entity, c, entity.GetFamily());
         AddTransformedDisplayLine(display, insert);
         delete display;
      }
      return segmentCount > 0;
   }

   VectorPoint SplineControlPoint(SplineEntity entity, int index)
   {
      if(index < 0)
         index = 0;
      if(index >= (int)entity.controlPointCount)
         index = (int)entity.controlPointCount - 1;
      return entity.controlPoints[index];
   }

   VectorPoint SplineFitPoint(SplineEntity entity, int index)
   {
      if(!entity.fitPoints || entity.fitPointCount < 1)
         return { 0, 0, 0 };
      if(index < 0)
         index = 0;
      if(index >= (int)entity.fitPointCount)
         index = (int)entity.fitPointCount - 1;
      return entity.fitPoints[index];
   }

   VectorPoint EvaluateFitSplinePreview(SplineEntity entity, int segment, double t)
   {
      VectorPoint p0 = SplineFitPoint(entity, segment - 1);
      VectorPoint p1 = SplineFitPoint(entity, segment);
      VectorPoint p2 = SplineFitPoint(entity, segment + 1);
      VectorPoint p3 = SplineFitPoint(entity, segment + 2);
      double t2 = t * t;
      double t3 = t2 * t;
      return
      {
         0.5 * ((2 * p1.x) + (-p0.x + p2.x) * t + (2 * p0.x - 5 * p1.x + 4 * p2.x - p3.x) * t2 + (-p0.x + 3 * p1.x - 3 * p2.x + p3.x) * t3),
         0.5 * ((2 * p1.y) + (-p0.y + p2.y) * t + (2 * p0.y - 5 * p1.y + 4 * p2.y - p3.y) * t2 + (-p0.y + 3 * p1.y - 3 * p2.y + p3.y) * t3),
         0.5 * ((2 * p1.z) + (-p0.z + p2.z) * t + (2 * p0.z - 5 * p1.z + 4 * p2.z - p3.z) * t2 + (-p0.z + 3 * p1.z - 3 * p2.z + p3.z) * t3)
      };
   }

   VectorPoint EvaluateSplinePreview(SplineEntity entity, int segment, double t)
   {
      VectorPoint p0 = SplineControlPoint(entity, segment - 1);
      VectorPoint p1 = SplineControlPoint(entity, segment);
      VectorPoint p2 = SplineControlPoint(entity, segment + 1);
      VectorPoint p3 = SplineControlPoint(entity, segment + 2);
      double t2 = t * t;
      double t3 = t2 * t;
      return
      {
         0.5 * ((2 * p1.x) + (-p0.x + p2.x) * t + (2 * p0.x - 5 * p1.x + 4 * p2.x - p3.x) * t2 + (-p0.x + 3 * p1.x - 3 * p2.x + p3.x) * t3),
         0.5 * ((2 * p1.y) + (-p0.y + p2.y) * t + (2 * p0.y - 5 * p1.y + 4 * p2.y - p3.y) * t2 + (-p0.y + 3 * p1.y - 3 * p2.y + p3.y) * t3),
         0.5 * ((2 * p1.z) + (-p0.z + p2.z) * t + (2 * p0.z - 5 * p1.z + 4 * p2.z - p3.z) * t2 + (-p0.z + 3 * p1.z - 3 * p2.z + p3.z) * t3)
      };
   }

   DisplayLine CreateSplinePreviewDisplay(SplineEntity entity, DisplayLineKind kind)
   {
      uint c, step;
      uint stepsPerSegment = 8;
      uint segmentCount = entity.controlPointCount > 1 ? entity.controlPointCount - 1 : 0;
      uint pointCount = segmentCount ? segmentCount * stepsPerSegment + 1 : entity.controlPointCount;
      VectorPoint * points = pointCount ? new VectorPoint[pointCount] : null;
      uint out = 0;
      DisplayLine display { ownerEntityId = entity.id, kind = kind, implementation = polyline, closed = entity.closed, cachedVersion = entity.version };

      if(segmentCount)
      {
         for(c = 0; c < segmentCount; c++)
         {
            for(step = 0; step < stepsPerSegment; step++)
               points[out++] = EvaluateSplinePreview(entity, (int)c, (double)step / (double)stepsPerSegment);
         }
         points[out++] = entity.controlPoints[entity.controlPointCount - 1];
      }
      else if(entity.controlPointCount == 1)
         points[out++] = entity.controlPoints[0];

      display.SetPoints(points, out);
      delete points;
      return display;
   }

   DisplayLine CreateFitSplinePreviewDisplay(SplineEntity entity, DisplayLineKind kind)
   {
      uint c, step;
      uint stepsPerSegment = 8;
      uint segmentCount = entity.fitPointCount > 1 ? entity.fitPointCount - 1 : 0;
      uint pointCount = segmentCount ? segmentCount * stepsPerSegment + 1 : entity.fitPointCount;
      VectorPoint * points = pointCount ? new VectorPoint[pointCount] : null;
      uint out = 0;
      DisplayLine display { ownerEntityId = entity.id, kind = kind, implementation = polyline, closed = entity.closed, cachedVersion = entity.version };

      if(segmentCount)
      {
         for(c = 0; c < segmentCount; c++)
         {
            for(step = 0; step < stepsPerSegment; step++)
               points[out++] = EvaluateFitSplinePreview(entity, (int)c, (double)step / (double)stepsPerSegment);
         }
         points[out++] = entity.fitPoints[entity.fitPointCount - 1];
      }
      else if(entity.fitPointCount == 1)
         points[out++] = entity.fitPoints[0];

      display.SetPoints(points, out);
      delete points;
      return display;
   }

   bool AddSplineDisplayLine(SplineEntity entity, DisplayLineKind kind)
   {
      if(entity && entity.fitPointCount >= 2)
      {
         displayLines.Add(CreateFitSplinePreviewDisplay(entity, kind));
         return true;
      }
      if(entity && entity.controlPointCount > 2)
      {
         displayLines.Add(CreateSplinePreviewDisplay(entity, kind));
         return true;
      }
      return false;
   }

   bool AddTransformedSplineDisplayLine(SplineEntity entity, InsertEntity insert)
   {
      if(entity && (entity.fitPointCount >= 2 || entity.controlPointCount > 2))
      {
         DisplayLine display = entity.fitPointCount >= 2 ?
            CreateFitSplinePreviewDisplay(entity, entity.GetFamily()) :
            CreateSplinePreviewDisplay(entity, entity.GetFamily());
         AddTransformedDisplayLine(display, insert);
         delete display;
         return true;
      }
      return false;
   }

   // Shared display-line rebuild. When useEntityFamily is true, each entity picks its own
   // industrial/artistic family (GetFamily); otherwise the caller-supplied kind is used.
   void RebuildDisplayLinesInternal(DisplayLineKind kind, bool useEntityFamily)
   {
      Link link;

      displayLines.Free();
      for(link = entities.first; link; link = link.next)
      {
         SemanticEntity entity = (SemanticEntity)entities.GetData(link);
         DisplayLineKind useKind = (useEntityFamily && entity) ? entity.GetFamily() : kind;
         if(entity && entity.type == entityInsert && AddInsertDisplayLines((InsertEntity)entity))
            continue;
         else if(entity && entity.type == entityHatch && AddHatchDisplayLines((HatchEntity)entity))
            continue;
         else if(entity && entity.type == entityDimension && AddDimensionDisplayLines((DimensionEntity)entity, useKind))
            continue;
         else if(entity && entity.type == entityPolyline && AddPolylineDisplayLines((PolylineEntity)entity, useKind))
            continue;
         else if(entity && entity.type == entitySpline && AddSplineDisplayLine((SplineEntity)entity, useKind))
            continue;
         else
         {
            DisplayLine display = entity ? entity.CreateDisplayLine(useKind) : null;
            if(display)
               displayLines.Add(display);
         }
      }
   }

   void RebuildDisplayLines(DisplayLineKind kind)
   {
      RebuildDisplayLinesInternal(kind, false);
   }

   void RebuildSemanticDisplayLines()
   {
      RebuildDisplayLinesInternal(industrial, true);
   }

   LineEntity CreateLine(VectorPoint start, VectorPoint end, const char * layer)
   {
      LineEntity entity { start = start, end = end };
      if(layer)
      {
         delete entity.layer;
         entity.layer = CopyString(layer);
      }
      return (LineEntity)AddEntity(entity);
   }

   CircleEntity CreateCircle(VectorPoint center, double radius, const char * layer)
   {
      CircleEntity entity { center = center, radius = radius };
      if(layer)
      {
         delete entity.layer;
         entity.layer = CopyString(layer);
      }
      return (CircleEntity)AddEntity(entity);
   }

   ArcEntity CreateArc(VectorPoint center, double radius, double startAngle, double endAngle, const char * layer)
   {
      ArcEntity entity { center = center, radius = radius, startAngle = startAngle, endAngle = endAngle };
      if(layer)
      {
         delete entity.layer;
         entity.layer = CopyString(layer);
      }
      return (ArcEntity)AddEntity(entity);
   }

   EllipseEntity CreateEllipse(VectorPoint center, double radiusX, double radiusY, double rotation, const char * layer)
   {
      EllipseEntity entity { center = center, radiusX = radiusX, radiusY = radiusY, rotation = rotation };
      if(layer)
      {
         delete entity.layer;
         entity.layer = CopyString(layer);
      }
      return (EllipseEntity)AddEntity(entity);
   }

   PolylineEntity CreatePolyline(VectorPoint * points, uint count, bool closed, const char * layer)
   {
      PolylineEntity entity { closed = closed };
      entity.SetPoints(points, count);
      if(layer)
      {
         delete entity.layer;
         entity.layer = CopyString(layer);
      }
      return (PolylineEntity)AddEntity(entity);
   }

   SplineEntity CreateSpline(VectorPoint * controlPoints, uint count, uint degree, bool closed, const char * layer)
   {
      SplineEntity entity { degree = degree, closed = closed };
      entity.SetControlPoints(controlPoints, count);
      if(layer)
      {
         delete entity.layer;
         entity.layer = CopyString(layer);
      }
      return (SplineEntity)AddEntity(entity);
   }

   TextEntity CreateText(VectorPoint position, VectorPoint alignment, const char * text, double height, const char * style, const char * layer)
   {
      TextEntity entity { position = position, alignment = alignment, height = height };
      entity.SetText(text);
      entity.SetStyle(style);
      if(layer)
      {
         delete entity.layer;
         entity.layer = CopyString(layer);
      }
      return (TextEntity)AddEntity(entity);
   }

   InsertEntity CreateInsert(VectorPoint position, const char * name, double xScale, double yScale, double zScale, double angle, const char * layer)
   {
      InsertEntity entity { position = position, xScale = xScale, yScale = yScale, zScale = zScale, angle = angle };
      entity.SetName(name);
      if(layer)
      {
         delete entity.layer;
         entity.layer = CopyString(layer);
      }
      return (InsertEntity)AddEntity(entity);
   }

   LeaderEntity CreateLeader(VectorPoint * points, uint count, const char * layer)
   {
      LeaderEntity entity { };
      entity.SetPoints(points, count);
      if(layer)
      {
         delete entity.layer;
         entity.layer = CopyString(layer);
      }
      return (LeaderEntity)AddEntity(entity);
   }

   HatchEntity CreateHatch(VectorPoint seed, VectorPoint * boundaryPoints, uint boundaryPointCount, const char * name, const char * layer)
   {
      HatchEntity entity { seed = seed };
      entity.SetName(name);
      entity.SetHPattern(name);
      entity.solid = !name || !strcmp(name, "SOLID");
      entity.SetBoundaryPoints(boundaryPoints, boundaryPointCount);
      if(layer)
      {
         delete entity.layer;
         entity.layer = CopyString(layer);
      }
      return (HatchEntity)AddEntity(entity);
   }

   HatchEntity CreatePatternHatch(VectorPoint seed, VectorPoint * boundaryPoints, uint boundaryPointCount, const char * pattern, double angle, double scale, const char * layer)
   {
      HatchEntity entity { seed = seed, solid = false, angle = angle, scale = scale };
      entity.SetName(pattern);
      entity.SetHPattern(pattern);
      entity.SetBoundaryPoints(boundaryPoints, boundaryPointCount);
      if(layer)
      {
         delete entity.layer;
         entity.layer = CopyString(layer);
      }
      return (HatchEntity)AddEntity(entity);
   }

   DimensionEntity CreateDimension(VectorPoint extLine1, VectorPoint extLine2, VectorPoint dimLinePoint, VectorPoint textMidPoint, const char * text, const char * layer)
   {
      DimensionEntity entity
      {
         extLine1 = extLine1,
         extLine2 = extLine2,
         dimLinePoint = dimLinePoint,
         textMidPoint = textMidPoint,
         defPoint = textMidPoint
      };
      entity.SetText(text);
      if(layer)
      {
         delete entity.layer;
         entity.layer = CopyString(layer);
      }
      return (DimensionEntity)AddEntity(entity);
   }

   DimensionEntity CreateTypedDimension(int dimType, VectorPoint defPoint, VectorPoint extLine1, VectorPoint extLine2, VectorPoint dimLinePoint, VectorPoint textMidPoint, const char * text, const char * layer)
   {
      DimensionEntity entity
      {
         defPoint = defPoint,
         extLine1 = extLine1,
         extLine2 = extLine2,
         dimLinePoint = dimLinePoint,
         textMidPoint = textMidPoint,
         dimType = dimType
      };
      entity.SetText(text);
      if(layer)
      {
         delete entity.layer;
         entity.layer = CopyString(layer);
      }
      return (DimensionEntity)AddEntity(entity);
   }
};
